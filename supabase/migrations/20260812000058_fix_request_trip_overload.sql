-- URGENT HOTFIX: every trip request (ride and delivery) is currently
-- broken in production with PostgREST error PGRST203 ("Could not choose
-- the best candidate function... customer_request_trip").
--
-- Root cause: 20260812000055_selefli_credit.sql added a new parameter
-- (p_estimated_price) to customer_request_trip via `create or replace
-- function`. Postgres identifies a function's identity by its name *and*
-- parameter types, not just its name - adding a parameter changes that
-- identity, so `create or replace` didn't update the existing (pre-Selefli,
-- 16-parameter -> now 17) function in place, it silently created a
-- *second*, parallel overload alongside the original one. With two
-- same-named functions both matching a client call (every new parameter
-- has a default, so the old, shorter-parameter-list overload is still a
-- valid match too), PostgREST can no longer tell which one the caller
-- meant and refuses to guess.
--
-- The fix: explicitly find and drop *every* existing overload of
-- customer_request_trip (whatever combination of prior migrations has or
-- hasn't been applied in this database), then recreate the single, current
-- version. Unlike every other migration in this project, this doesn't
-- assume a specific prior state - it's written to safely converge any
-- starting point to one correct function.
do $$
declare
  v_func record;
begin
  for v_func in
    select p.oid, pg_get_function_identity_arguments(p.oid) as args
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'customer_request_trip'
  loop
    execute format(
      'drop function public.customer_request_trip(%s)',
      v_func.args
    );
  end loop;
end $$;

-- Identical body to the version in 20260812000056_captain_subscriptions.sql
-- - this migration only fixes *how* it gets installed, not what it does.
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

-- Defensive audit of every other function this project has ever changed
-- the parameter list of (the only way this class of bug happens): none of
-- them ever added/removed a parameter across versions, only
-- customer_request_trip did (p_estimated_price, then later
-- subscribed_captain_id was added as a *column*, not a parameter) - so
-- this is the only function that needed this treatment. Recorded here so
-- the next migration that adds a parameter to an existing function
-- remembers to do the same drop-every-overload dance first.
