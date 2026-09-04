-- "سلفلي" (Selefli): lets a loyal customer request a normal ride on credit
-- instead of needing cash/wallet balance up front, once they've completed
-- enough trips - a small ride-now-pay-later line of credit, capped by
-- trip-count tier, with at most one outstanding debt at a time (must be
-- repaid before another Selefli ride can be requested).
--
-- Tiers (customers.completed_trips_count, wired up below - it existed on
-- the table since 20260713000029_open_trip_lifecycle.sql but nothing ever
-- incremented it until now):
--   more than 10 completed trips -> ride price capped at 100
--   30+ completed trips          -> ride price capped at 200
--
-- Repayment is automatic from wallet balance, per the product decision:
-- whenever a recharge is approved (admin_approve_recharge - the only real,
-- reviewed path money enters a wallet through), whatever of the freshly
-- credited balance is available is applied to the customer's oldest
-- outstanding Selefli debt first, partial repayment allowed, before the
-- rest sits in the wallet as spendable balance.

create table if not exists public.selefli_debts (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers (id) on delete cascade,
  trip_id uuid not null references public.trips (id) on delete restrict,
  amount numeric(10, 2) not null check (amount > 0),
  amount_paid numeric(10, 2) not null default 0 check (amount_paid >= 0),
  status text not null default 'outstanding' check (status in ('outstanding', 'paid')),
  created_at timestamptz not null default now(),
  paid_at timestamptz,
  unique (trip_id)
);

create index if not exists selefli_debts_customer_id_idx
  on public.selefli_debts (customer_id);

-- The actual server-side enforcement of "only one outstanding debt at a
-- time" - not just a client-side check that could be raced/bypassed.
create unique index if not exists selefli_debts_one_outstanding_per_customer
  on public.selefli_debts (customer_id)
  where status = 'outstanding';

alter table public.selefli_debts enable row level security;

drop policy if exists "Selefli debts are readable by owner or admin" on public.selefli_debts;
create policy "Selefli debts are readable by owner or admin"
  on public.selefli_debts for select
  to authenticated
  using (auth.uid() = customer_id or public.is_admin());

-- No insert/update/delete policy at all - every write happens inside
-- captain_end_trip (creates the debt) or admin_approve_recharge (repays
-- it), both SECURITY DEFINER, matching every other sensitive write in
-- this project.

-- Widen trips.payment_method to accept 'selefli' alongside the existing
-- 'cash'/'wallet'. The original check constraint was unnamed (Postgres
-- auto-names it), so find and drop whatever it's actually called rather
-- than guessing, then add a clearly-named replacement.
do $$
declare
  v_conname text;
begin
  select conname into v_conname
  from pg_constraint
  where conrelid = 'public.trips'::regclass
    and contype = 'c'
    and pg_get_constraintdef(oid) ilike '%payment_method%';
  if v_conname is not null then
    execute format('alter table public.trips drop constraint %I', v_conname);
  end if;
end $$;

alter table public.trips
  add constraint trips_payment_method_check
  check (payment_method in ('cash', 'wallet', 'selefli'));

-- Null (not eligible yet) or the ride-price cap for the customer's current
-- trip-count tier.
create or replace function public.selefli_credit_cap(p_customer_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select case
    when (select completed_trips_count from public.customers where id = p_customer_id) >= 30 then 200
    when (select completed_trips_count from public.customers where id = p_customer_id) > 10 then 100
    else null
  end;
$$;

-- Single round trip for the customer app to render Selefli eligibility:
-- current cap (null if not eligible), any outstanding debt amount still
-- owed (0 if none), and the raw trip count (so the UI can say "N more
-- trips until Selefli").
create or replace function public.customer_selefli_status()
returns table (
  cap numeric,
  outstanding_amount numeric,
  completed_trips_count integer
)
language sql
stable
security definer
set search_path = public
as $$
  select
    public.selefli_credit_cap(auth.uid()),
    coalesce(
      (select amount - amount_paid from public.selefli_debts
        where customer_id = auth.uid() and status = 'outstanding' limit 1),
      0
    ),
    coalesce((select completed_trips_count from public.customers where id = auth.uid()), 0);
$$;

-- customer_request_trip: adds p_estimated_price (only meaningful/required
-- when p_payment_method = 'selefli') and the eligibility/cap/outstanding-
-- debt validation. Everything else is unchanged from
-- 20260802000047_self_heal_customer_row.sql.
create or replace function public.customer_request_trip(
  p_pickup_address text,
  p_pickup_lat double precision,
  p_pickup_lng double precision,
  p_trip_type text default 'normal',
  p_destination_address text default null,
  p_destination_lat double precision default null,
  p_destination_lng double precision default null,
  p_vehicle_type text default 'economy',
  p_payment_method text default 'cash',
  p_customer_note text default null,
  p_timeout_seconds integer default 300,
  p_passenger_count integer default 1,
  p_service_type text default 'ride',
  p_recipient_name text default null,
  p_recipient_phone text default null,
  p_package_description text default null,
  p_estimated_price numeric default null
)
returns public.trips
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid := auth.uid();
  v_row public.trips;
  v_vehicle_type text := p_vehicle_type;
  v_selefli_cap numeric;
begin
  if v_customer_id is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (select 1 from public.customers where id = v_customer_id) then
    if exists (
      select 1 from public.profiles
      where id = v_customer_id and role = 'customer'
    ) then
      insert into public.customers (id) values (v_customer_id)
      on conflict (id) do nothing;
      insert into public.wallets (user_id) values (v_customer_id)
      on conflict (user_id) do nothing;
    else
      raise exception 'Only a customer account may request a trip';
    end if;
  end if;

  if p_service_type not in ('ride', 'delivery') then
    raise exception 'Invalid service type: %', p_service_type;
  end if;
  if p_pickup_lat is null or p_pickup_lng is null then
    raise exception 'Pickup coordinates are required';
  end if;

  if p_payment_method = 'selefli' then
    if p_service_type <> 'ride' or p_trip_type <> 'normal' then
      raise exception 'SELEFLI_REQUIRES_NORMAL_RIDE';
    end if;

    if exists (
      select 1 from public.selefli_debts
      where customer_id = v_customer_id and status = 'outstanding'
    ) then
      raise exception 'SELEFLI_DEBT_OUTSTANDING';
    end if;

    v_selefli_cap := public.selefli_credit_cap(v_customer_id);
    if v_selefli_cap is null then
      raise exception 'SELEFLI_NOT_ELIGIBLE';
    end if;

    if p_estimated_price is null or p_estimated_price > v_selefli_cap then
      raise exception 'SELEFLI_OVER_CAP';
    end if;
  end if;

  if p_service_type = 'delivery' then
    if p_recipient_name is null or btrim(p_recipient_name) = '' then
      raise exception 'Recipient name is required for a delivery';
    end if;
    if p_recipient_phone is null or btrim(p_recipient_phone) = '' then
      raise exception 'Recipient phone is required for a delivery';
    end if;
    if p_destination_lat is null or p_destination_lng is null then
      raise exception 'Delivery drop-off coordinates are required';
    end if;
    -- A delivery is always priced and broadcast as a motorcycle job,
    -- regardless of whatever vehicle_type the caller passed.
    v_vehicle_type := 'motorcycle';
  else
    if p_trip_type not in ('normal', 'open') then
      raise exception 'Invalid trip type: %', p_trip_type;
    end if;
  end if;

  insert into public.trips (
    customer_id, status, trip_type,
    pickup_address, pickup_lat, pickup_lng,
    destination_address, destination_lat, destination_lng,
    vehicle_type, payment_method, customer_note, passenger_count,
    service_type, recipient_name, recipient_phone, package_description,
    requested_at, expires_at
  ) values (
    v_customer_id, 'searching',
    case when p_service_type = 'delivery' then 'normal' else p_trip_type end,
    p_pickup_address, p_pickup_lat, p_pickup_lng,
    p_destination_address, p_destination_lat, p_destination_lng,
    v_vehicle_type, p_payment_method, p_customer_note,
    greatest(coalesce(p_passenger_count, 1), 1),
    p_service_type,
    case when p_service_type = 'delivery' then p_recipient_name else null end,
    case when p_service_type = 'delivery' then p_recipient_phone else null end,
    case when p_service_type = 'delivery' then p_package_description else null end,
    now(), now() + make_interval(secs => greatest(p_timeout_seconds, 10))
  ) returning * into v_row;

  return v_row;
end;
$$;

-- captain_end_trip: adds the customer's completed_trips_count increment
-- (dead column until now - see the migration header above) and, when the
-- trip was requested with payment_method = 'selefli', creates the debt
-- row for the real final fare (not the pre-trip estimate the cap was
-- checked against - a captain-taken detour can change the actual price,
-- so the debt must reflect what was actually charged). Everything else is
-- unchanged from 20260729000042_open_trip_base_fare.sql.
create or replace function public.captain_end_trip(
  p_trip_id uuid,
  p_final_distance_km numeric
)
returns public.trips
language plpgsql
security definer
set search_path = public
as $$
declare
  v_trip public.trips;
  v_pricing public.pricing_config;
  v_duration_minutes numeric;
  v_subtotal numeric;
  v_final_fare numeric;
  v_commission numeric;
  v_net numeric;
  v_wallet public.wallets;
  v_extra_km numeric;
  v_extra_minutes numeric;
begin
  select * into v_trip from public.trips
    where id = p_trip_id and captain_id = auth.uid() and status = 'in_progress'
    for update;

  if not found then
    raise exception 'TRIP_INVALID_STATE';
  end if;

  select * into v_pricing from public.pricing_config
    where vehicle_type = coalesce(v_trip.vehicle_type, 'economy');
  if not found then
    raise exception 'No pricing configuration for vehicle type %', v_trip.vehicle_type;
  end if;

  v_duration_minutes := greatest(
    extract(epoch from (now() - v_trip.started_at)) / 60.0, 0
  );

  if v_trip.trip_type = 'open' then
    v_extra_km := greatest(p_final_distance_km - v_pricing.open_trip_base_distance_km, 0);
    v_extra_minutes := greatest(v_duration_minutes - v_pricing.open_trip_base_minutes, 0);
    v_subtotal := v_pricing.open_trip_base_fare
      + (v_extra_km * v_pricing.price_per_km)
      + (v_extra_minutes * v_pricing.price_per_minute);
  else
    v_subtotal := v_pricing.base_fare
      + (greatest(p_final_distance_km, 0) * v_pricing.price_per_km)
      + (v_duration_minutes * v_pricing.price_per_minute);
  end if;

  v_subtotal := v_subtotal * coalesce(v_pricing.surge_multiplier, 1.0);
  v_final_fare := greatest(v_subtotal, v_pricing.minimum_fare);
  v_commission := round(v_final_fare * coalesce(v_pricing.commission_percentage, 0) / 100.0, 2);
  v_net := round(v_final_fare - v_commission, 2);

  update public.trips
    set status = 'completed',
        completed_at = now(),
        distance_km = greatest(p_final_distance_km, 0),
        traveled_distance_km = greatest(p_final_distance_km, 0),
        actual_duration_minutes = round(v_duration_minutes)::integer,
        final_price = v_final_fare,
        commission_amount = v_commission,
        captain_net_earnings = v_net
    where id = p_trip_id
    returning * into v_trip;

  select * into v_wallet from public.wallets where user_id = v_trip.captain_id for update;
  if found then
    update public.wallets set balance = balance + v_net where id = v_wallet.id;
    insert into public.wallet_transactions (
      wallet_id, user_id, type, amount, balance_before, balance_after,
      is_credit, reference_type, reference_id, description
    ) values (
      v_wallet.id, v_trip.captain_id, 'adjustment', v_net,
      v_wallet.balance, v_wallet.balance + v_net,
      true, 'trip', v_trip.id, 'صافي أرباح مشوار مفتوح'
    );
  end if;

  if v_trip.customer_id is not null then
    update public.customers
      set completed_trips_count = completed_trips_count + 1
      where id = v_trip.customer_id;

    if v_trip.payment_method = 'selefli' then
      insert into public.selefli_debts (customer_id, trip_id, amount)
        values (v_trip.customer_id, v_trip.id, v_final_fare);
    end if;
  end if;

  return v_trip;
end;
$$;

-- admin_approve_recharge: adds automatic Selefli debt repayment from
-- whatever of the newly-credited balance is available, before the rest
-- stays spendable. Everything else is unchanged from
-- 20260712000028_admin_functions.sql.
create or replace function public.admin_approve_recharge(
  p_request_id uuid,
  p_notes text default null
)
returns public.recharge_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request public.recharge_requests;
  v_wallet public.wallets;
  v_before numeric;
  v_after numeric;
  v_debt public.selefli_debts;
  v_repay numeric;
begin
  if not public.has_admin_role('finance_admin') then
    raise exception 'Only finance_admin or super_admin may approve recharge requests';
  end if;

  select * into v_request from public.recharge_requests where id = p_request_id for update;
  if not found then
    raise exception 'Recharge request % not found', p_request_id;
  end if;
  if v_request.status <> 'pending' then
    raise exception 'Recharge request % is not pending', p_request_id;
  end if;

  select * into v_wallet from public.wallets where id = v_request.wallet_id for update;
  v_before := v_wallet.balance;
  v_after := v_before + v_request.amount;

  update public.wallets set balance = v_after where id = v_wallet.id;

  insert into public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    is_credit, reference_type, reference_id, description, created_by
  ) values (
    v_wallet.id, v_request.user_id, 'recharge', v_request.amount, v_before, v_after,
    true, 'recharge_request', v_request.id, p_notes, auth.uid()
  );

  select * into v_debt from public.selefli_debts
    where customer_id = v_request.user_id and status = 'outstanding'
    order by created_at
    limit 1
    for update;

  if found and v_after > 0 then
    v_repay := least(v_after, v_debt.amount - v_debt.amount_paid);
    if v_repay > 0 then
      update public.selefli_debts
        set amount_paid = amount_paid + v_repay,
            status = case when amount_paid + v_repay >= amount then 'paid' else 'outstanding' end,
            paid_at = case when amount_paid + v_repay >= amount then now() else null end
        where id = v_debt.id;

      update public.wallets set balance = v_after - v_repay where id = v_wallet.id;
      insert into public.wallet_transactions (
        wallet_id, user_id, type, amount, balance_before, balance_after,
        is_credit, reference_type, reference_id, description
      ) values (
        v_wallet.id, v_request.user_id, 'payment', v_repay,
        v_after, v_after - v_repay,
        false, 'selefli_debt', v_debt.id, 'سداد دين سلفلي تلقائي'
      );
    end if;
  end if;

  update public.recharge_requests
    set status = 'approved', admin_notes = p_notes, reviewed_by = auth.uid(), reviewed_at = now()
    where id = p_request_id
    returning * into v_request;

  perform public.log_admin_action(
    'recharge_approved', 'recharge_request', p_request_id::text,
    jsonb_build_object('status', 'pending'), jsonb_build_object('status', 'approved', 'amount', v_request.amount),
    p_notes
  );

  return v_request;
end;
$$;
