-- Monthly captain subscription ("اشتراك شهري"): a customer and a specific
-- captain negotiate a flat monthly price via an in-app chat; once the
-- captain accepts an offer, the full amount is deducted from the
-- customer's wallet immediately (protects the company - the captain is
-- guaranteed to be paid before committing a month of service) and the
-- subscription is active for 30 days, during which the customer can
-- request ordinary rides with that specific captain at no extra charge
-- (protects the customer - the service they already paid for can't be
-- revoked mid-month). The platform takes a flat 200 UM commission out of
-- every accepted subscription, credited to the captain net of that.
--
-- Only one active subscription per customer at a time (enforced by a
-- partial unique index, same pattern as selefli_debts in
-- 20260812000055_selefli_credit.sql) - a customer must let the current one
-- run out before starting another.

create table if not exists public.captain_subscriptions (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers (id) on delete cascade,
  captain_id uuid not null references public.captains (id) on delete cascade,
  status text not null default 'negotiating'
    check (status in ('negotiating', 'active', 'rejected', 'cancelled')),
  proposed_price numeric(10, 2) check (proposed_price is null or proposed_price > 0),
  proposed_by text check (proposed_by in ('customer', 'captain')),
  agreed_price numeric(10, 2) check (agreed_price is null or agreed_price > 0),
  commission_amount numeric(10, 2),
  started_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists captain_subscriptions_customer_id_idx
  on public.captain_subscriptions (customer_id);
create index if not exists captain_subscriptions_captain_id_idx
  on public.captain_subscriptions (captain_id);

-- Server-side enforcement (not just a client-side check) of "one active
-- subscription at a time" and "one open negotiation per captain at a time".
create unique index if not exists captain_subscriptions_one_active_per_customer
  on public.captain_subscriptions (customer_id)
  where status = 'active';
create unique index if not exists captain_subscriptions_one_negotiation_per_pair
  on public.captain_subscriptions (customer_id, captain_id)
  where status = 'negotiating';

drop trigger if exists captain_subscriptions_set_updated_at on public.captain_subscriptions;
create trigger captain_subscriptions_set_updated_at
before update on public.captain_subscriptions
for each row execute function public.set_updated_at();

alter table public.captain_subscriptions enable row level security;

drop policy if exists "Captain subscriptions are readable by either party or admin" on public.captain_subscriptions;
create policy "Captain subscriptions are readable by either party or admin"
  on public.captain_subscriptions for select
  to authenticated
  using (auth.uid() = customer_id or auth.uid() = captain_id or public.is_admin());

-- No insert/update/delete policy - every write happens inside the
-- SECURITY DEFINER functions below, same as selefli_debts.

create table if not exists public.captain_subscription_messages (
  id uuid primary key default gen_random_uuid(),
  subscription_id uuid not null references public.captain_subscriptions (id) on delete cascade,
  sender_id uuid not null references auth.users (id),
  sender_role text not null check (sender_role in ('customer', 'captain')),
  body text not null,
  offer_amount numeric(10, 2) check (offer_amount is null or offer_amount > 0),
  created_at timestamptz not null default now()
);

create index if not exists captain_subscription_messages_subscription_id_idx
  on public.captain_subscription_messages (subscription_id, created_at);

alter table public.captain_subscription_messages enable row level security;

drop policy if exists "Subscription chat is readable by either party or admin" on public.captain_subscription_messages;
create policy "Subscription chat is readable by either party or admin"
  on public.captain_subscription_messages for select
  to authenticated
  using (
    exists (
      select 1 from public.captain_subscriptions s
      where s.id = subscription_id
        and (auth.uid() = s.customer_id or auth.uid() = s.captain_id)
    )
    or public.is_admin()
  );

-- No insert policy - messages are only ever written through
-- send_subscription_message/customer_start_subscription_chat/
-- captain_accept_subscription/captain_reject_subscription below, so the
-- sender_id/sender_role pairing can never be spoofed.

-- ---------------------------------------------------------------------
-- Fixes a pre-existing gap: nothing ever let a customer read the profile
-- of the captain assigned to their own trip (captains/profiles select
-- policies were owner-or-admin only - see 20260712000006_rls_policies.sql),
-- which silently broke TripTrackingScreen's captain photo/plate/phone
-- display added earlier. Widened here because the subscription chat has
-- the exact same need (a customer must be able to see the captain they're
-- negotiating/subscribed with), so one policy covers both.
-- ---------------------------------------------------------------------
drop policy if exists "Captains viewable by a related customer" on public.captains;
create policy "Captains viewable by a related customer"
  on public.captains for select
  to authenticated
  using (
    exists (
      select 1 from public.trips
      where trips.captain_id = captains.id and trips.customer_id = auth.uid()
    )
    or exists (
      select 1 from public.captain_subscriptions
      where captain_subscriptions.captain_id = captains.id
        and captain_subscriptions.customer_id = auth.uid()
    )
  );

drop policy if exists "Profiles viewable by a related customer" on public.profiles;
create policy "Profiles viewable by a related customer"
  on public.profiles for select
  to authenticated
  using (
    exists (
      select 1 from public.trips
      where trips.captain_id = profiles.id and trips.customer_id = auth.uid()
    )
    or exists (
      select 1 from public.captain_subscriptions
      where captain_subscriptions.captain_id = profiles.id
        and captain_subscriptions.customer_id = auth.uid()
    )
  );

-- Public directory (name/photo/vehicle/rating only - no phone) of
-- approved, currently online captains, for the "browse captains to
-- subscribe with" screen. A SECURITY DEFINER function rather than an RLS
-- policy on captains/profiles: RLS is row-level, not column-level, and
-- phone numbers must stay hidden until a real relationship exists (the
-- policies above).
create or replace function public.browsable_captains()
returns table (
  captain_id uuid,
  full_name text,
  avatar_url text,
  vehicle_brand text,
  vehicle_model text,
  vehicle_color text,
  rating numeric,
  ratings_count integer
)
language sql
stable
security definer
set search_path = public
as $$
  select c.id, p.full_name, c.avatar_url, c.vehicle_brand, c.vehicle_model, c.vehicle_color,
         c.rating, c.ratings_count
  from public.captains c
  join public.profiles p on p.id = c.id
  where c.status = 'approved' and c.is_online = true
  order by c.rating desc nulls last, c.ratings_count desc;
$$;

-- Starts (or reuses, if one's already open with this captain) a
-- negotiation thread. Blocked while the customer already has an active
-- subscription - they must let it run out first.
create or replace function public.customer_start_subscription_chat(
  p_captain_id uuid,
  p_initial_message text default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid := auth.uid();
  v_id uuid;
begin
  if v_customer_id is null then
    raise exception 'Not authenticated';
  end if;

  if not exists (select 1 from public.customers where id = v_customer_id) then
    raise exception 'Only a customer account may start a subscription chat';
  end if;

  if not exists (
    select 1 from public.captains where id = p_captain_id and status = 'approved'
  ) then
    raise exception 'Captain not found or not approved';
  end if;

  if exists (
    select 1 from public.captain_subscriptions
    where customer_id = v_customer_id and status = 'active'
  ) then
    raise exception 'SUBSCRIPTION_ALREADY_ACTIVE';
  end if;

  select id into v_id from public.captain_subscriptions
    where customer_id = v_customer_id and captain_id = p_captain_id and status = 'negotiating';

  if v_id is null then
    insert into public.captain_subscriptions (customer_id, captain_id, status)
      values (v_customer_id, p_captain_id, 'negotiating')
      returning id into v_id;
  end if;

  if p_initial_message is not null and btrim(p_initial_message) <> '' then
    insert into public.captain_subscription_messages (subscription_id, sender_id, sender_role, body)
      values (v_id, v_customer_id, 'customer', p_initial_message);
  end if;

  return v_id;
end;
$$;

-- A free-text chat message, optionally carrying a structured price offer
-- (p_offer_amount) that becomes the thread's current proposed_price - either
-- side can send one, and a later offer simply replaces the earlier one.
create or replace function public.send_subscription_message(
  p_subscription_id uuid,
  p_body text,
  p_offer_amount numeric default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sub public.captain_subscriptions;
  v_role text;
begin
  select * into v_sub from public.captain_subscriptions where id = p_subscription_id for update;
  if not found then
    raise exception 'Subscription thread not found';
  end if;
  if v_sub.status <> 'negotiating' then
    raise exception 'SUBSCRIPTION_NOT_NEGOTIATING';
  end if;

  if auth.uid() = v_sub.customer_id then
    v_role := 'customer';
  elsif auth.uid() = v_sub.captain_id then
    v_role := 'captain';
  else
    raise exception 'Not a party to this subscription chat';
  end if;

  if p_body is null or btrim(p_body) = '' then
    raise exception 'Message body is required';
  end if;

  if p_offer_amount is not null and p_offer_amount <= 0 then
    raise exception 'Offer amount must be positive';
  end if;

  insert into public.captain_subscription_messages (
    subscription_id, sender_id, sender_role, body, offer_amount
  ) values (
    p_subscription_id, auth.uid(), v_role, p_body, p_offer_amount
  );

  if p_offer_amount is not null then
    update public.captain_subscriptions
      set proposed_price = p_offer_amount, proposed_by = v_role, updated_at = now()
      where id = p_subscription_id;
  end if;
end;
$$;

-- Captain accepts the thread's current proposed_price: charges the
-- customer's wallet immediately in full (raises SUBSCRIPTION_INSUFFICIENT_
-- BALANCE if they can't cover it - a subscription is never itself offered
-- on credit), takes a flat 200 UM platform commission, credits the captain
-- the rest, and activates the subscription for 30 days.
create or replace function public.captain_accept_subscription(p_subscription_id uuid)
returns public.captain_subscriptions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sub public.captain_subscriptions;
  v_wallet public.wallets;
  v_commission numeric := 200;
  v_net numeric;
  v_before numeric;
  v_after numeric;
begin
  select * into v_sub from public.captain_subscriptions where id = p_subscription_id for update;
  if not found then
    raise exception 'Subscription thread not found';
  end if;
  if v_sub.captain_id <> auth.uid() then
    raise exception 'Not authorized';
  end if;
  if v_sub.status <> 'negotiating' then
    raise exception 'SUBSCRIPTION_NOT_NEGOTIATING';
  end if;
  if v_sub.proposed_price is null then
    raise exception 'SUBSCRIPTION_NO_OFFER';
  end if;
  if v_sub.proposed_price <= v_commission then
    raise exception 'SUBSCRIPTION_PRICE_TOO_LOW';
  end if;
  if exists (
    select 1 from public.captain_subscriptions
    where customer_id = v_sub.customer_id and status = 'active'
  ) then
    raise exception 'SUBSCRIPTION_ALREADY_ACTIVE';
  end if;

  select * into v_wallet from public.wallets where user_id = v_sub.customer_id for update;
  if not found then
    raise exception 'Customer wallet not found';
  end if;
  if v_wallet.balance < v_sub.proposed_price then
    raise exception 'SUBSCRIPTION_INSUFFICIENT_BALANCE';
  end if;

  v_before := v_wallet.balance;
  v_after := v_before - v_sub.proposed_price;
  v_net := v_sub.proposed_price - v_commission;

  update public.wallets set balance = v_after where id = v_wallet.id;
  insert into public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    is_credit, reference_type, reference_id, description
  ) values (
    v_wallet.id, v_sub.customer_id, 'payment', v_sub.proposed_price, v_before, v_after,
    false, 'captain_subscription', v_sub.id, 'اشتراك شهري مع كابتن'
  );

  select * into v_wallet from public.wallets where user_id = v_sub.captain_id for update;
  if found then
    update public.wallets set balance = balance + v_net where id = v_wallet.id;
    insert into public.wallet_transactions (
      wallet_id, user_id, type, amount, balance_before, balance_after,
      is_credit, reference_type, reference_id, description
    ) values (
      v_wallet.id, v_sub.captain_id, 'adjustment', v_net, v_wallet.balance, v_wallet.balance + v_net,
      true, 'captain_subscription', v_sub.id, 'صافي اشتراك شهري من زبون'
    );
  end if;

  update public.captain_subscriptions
    set status = 'active',
        agreed_price = v_sub.proposed_price,
        commission_amount = v_commission,
        started_at = now(),
        expires_at = now() + interval '30 days',
        updated_at = now()
    where id = p_subscription_id
    returning * into v_sub;

  insert into public.captain_subscription_messages (subscription_id, sender_id, sender_role, body)
    values (p_subscription_id, auth.uid(), 'captain', 'تم قبول الاشتراك وتفعيله لمدة 30 يوماً.');

  return v_sub;
end;
$$;

create or replace function public.captain_reject_subscription(p_subscription_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sub public.captain_subscriptions;
begin
  select * into v_sub from public.captain_subscriptions where id = p_subscription_id for update;
  if not found then
    raise exception 'Subscription thread not found';
  end if;
  if v_sub.captain_id <> auth.uid() then
    raise exception 'Not authorized';
  end if;
  if v_sub.status <> 'negotiating' then
    raise exception 'SUBSCRIPTION_NOT_NEGOTIATING';
  end if;

  update public.captain_subscriptions
    set status = 'rejected', updated_at = now()
    where id = p_subscription_id;

  insert into public.captain_subscription_messages (subscription_id, sender_id, sender_role, body)
    values (p_subscription_id, auth.uid(), 'captain', 'اعتذر الكابتن عن هذا الاشتراك.');
end;
$$;

create or replace function public.customer_cancel_subscription(p_subscription_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sub public.captain_subscriptions;
begin
  select * into v_sub from public.captain_subscriptions where id = p_subscription_id for update;
  if not found then
    raise exception 'Subscription thread not found';
  end if;
  if v_sub.customer_id <> auth.uid() then
    raise exception 'Not authorized';
  end if;
  if v_sub.status <> 'negotiating' then
    raise exception 'SUBSCRIPTION_NOT_NEGOTIATING';
  end if;

  update public.captain_subscriptions
    set status = 'cancelled', updated_at = now()
    where id = p_subscription_id;
end;
$$;

-- The customer's currently-relevant subscription (the active one if there
-- is one, else the most recently updated negotiation), enriched with the
-- captain's public info so WalletScreen/the chat header can render it in
-- one round trip. Zero rows means "no subscription" client-side.
create or replace function public.customer_subscription_status()
returns table (
  id uuid,
  captain_id uuid,
  captain_name text,
  captain_avatar_url text,
  captain_phone text,
  vehicle_brand text,
  vehicle_model text,
  vehicle_color text,
  status text,
  proposed_price numeric,
  proposed_by text,
  agreed_price numeric,
  started_at timestamptz,
  expires_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    s.id, s.captain_id, p.full_name, c.avatar_url, p.phone,
    c.vehicle_brand, c.vehicle_model, c.vehicle_color,
    s.status, s.proposed_price, s.proposed_by, s.agreed_price,
    s.started_at, s.expires_at
  from public.captain_subscriptions s
  join public.captains c on c.id = s.captain_id
  join public.profiles p on p.id = s.captain_id
  where s.customer_id = auth.uid()
    and ((s.status = 'active' and s.expires_at > now()) or s.status = 'negotiating')
  order by (s.status = 'active') desc, s.updated_at desc
  limit 1;
$$;

-- ---------------------------------------------------------------------
-- Wires 'subscription' into the ordinary ride flow: a trip requested this
-- way is pinned to the subscribed captain (captain_accept_trip below
-- rejects any other captain) and never charges anything at completion -
-- it was already paid for when the subscription was accepted.
-- ---------------------------------------------------------------------
alter table public.trips
  add column if not exists subscribed_captain_id uuid references public.captains (id);

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
  check (payment_method in ('cash', 'wallet', 'selefli', 'subscription'));

-- customer_request_trip: adds the 'subscription' branch (resolves and
-- pins subscribed_captain_id) alongside the existing 'selefli' branch.
-- Everything else is unchanged from 20260812000055_selefli_credit.sql.
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
  v_subscribed_captain_id uuid;
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
  elsif p_payment_method = 'subscription' then
    if p_service_type <> 'ride' or p_trip_type <> 'normal' then
      raise exception 'SUBSCRIPTION_REQUIRES_NORMAL_RIDE';
    end if;

    select captain_id into v_subscribed_captain_id
      from public.captain_subscriptions
      where customer_id = v_customer_id and status = 'active' and expires_at > now()
      limit 1;

    if v_subscribed_captain_id is null then
      raise exception 'NO_ACTIVE_SUBSCRIPTION';
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
    subscribed_captain_id,
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
    v_subscribed_captain_id,
    now(), now() + make_interval(secs => greatest(p_timeout_seconds, 10))
  ) returning * into v_row;

  return v_row;
end;
$$;

-- captain_accept_trip: adds the subscribed_captain_id guard - when a trip
-- was requested against an active subscription, only that captain's
-- accept can claim it; any other captain's attempt simply misses the
-- WHERE clause and gets the exact same pre-existing TRIP_UNAVAILABLE the
-- client already handles for the ordinary "someone else already accepted
-- it" race. Everything else is unchanged from
-- 20260801000046_delivery_service.sql.
create or replace function public.captain_accept_trip(p_trip_id uuid)
returns public.trips
language plpgsql
security definer
set search_path = public
as $$
declare
  v_captain_id uuid := auth.uid();
  v_row public.trips;
begin
  if not exists (
    select 1 from public.captains
    where id = v_captain_id and status = 'approved' and is_online = true
  ) then
    raise exception 'Only an approved, online captain may accept a trip';
  end if;

  update public.trips
    set captain_id = v_captain_id, status = 'accepted', accepted_at = now()
    where id = p_trip_id
      and status = 'searching'
      and captain_id is null
      and (expires_at is null or expires_at > now())
      and (subscribed_captain_id is null or subscribed_captain_id = v_captain_id)
      and (
        service_type = 'ride'
        or (
          service_type = 'delivery'
          and exists (
            select 1 from public.captains c
            where c.id = v_captain_id
              and c.vehicle_type = 'motorcycle'
              and c.accepts_delivery
          )
        )
      )
    returning * into v_row;

  if not found then
    raise exception 'TRIP_UNAVAILABLE';
  end if;

  return v_row;
end;
$$;

-- Realtime: the subscription chat and status card both live-update.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'captain_subscriptions'
  ) then
    alter publication supabase_realtime add table public.captain_subscriptions;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'captain_subscription_messages'
  ) then
    alter publication supabase_realtime add table public.captain_subscription_messages;
  end if;
end $$;
