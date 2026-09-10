-- Parcel delivery service: reuses the existing trips broadcast/accept/
-- pricing infrastructure end to end (see 20260713000029_open_trip_lifecycle.sql)
-- instead of a parallel system. A delivery is modeled as an ordinary trip
-- row with service_type = 'delivery', vehicle_type = 'motorcycle', and the
-- customer/destination fields repurposed as sender/recipient - captains and
-- admins query the same `trips` table either way.
--
-- Eligibility is intentionally two conditions, both required: the captain's
-- own vehicle_type must be 'motorcycle' *and* they must have opted in via
-- accepts_delivery. A captain who happens to ride a motorcycle but never
-- toggled delivery on must never receive a delivery broadcast, and a car
-- captain must never see one at all regardless of any toggle.

-- ---------------------------------------------------------------------
-- 1. vehicle_type vocabulary: add 'motorcycle' everywhere the existing car
-- classes (economy/comfort/family) are enumerated, rather than introducing
-- a separate "vehicle kind" column - a captain/trip already only ever has
-- one vehicle_type, so a motorcycle captain's own class is just
-- 'motorcycle', matching how a delivery trip is priced.
-- ---------------------------------------------------------------------
alter table public.pricing_config drop constraint if exists pricing_config_vehicle_type_check;
alter table public.pricing_config
  add constraint pricing_config_vehicle_type_check
  check (vehicle_type in ('economy', 'comfort', 'family', 'motorcycle'));

alter table public.trips drop constraint if exists trips_vehicle_type_check;
alter table public.trips
  add constraint trips_vehicle_type_check
  check (vehicle_type in ('economy', 'comfort', 'family', 'motorcycle'));

alter table public.captains drop constraint if exists captains_vehicle_type_check;
alter table public.captains
  add constraint captains_vehicle_type_check
  check (vehicle_type in ('economy', 'comfort', 'family', 'motorcycle'));

-- Deliberately cheaper than every car tier (economy: base_fare 50,
-- price_per_km 25, minimum_fare 100) per spec - delivery must always price
-- lower than any car trip.
insert into public.pricing_config (
  vehicle_type, base_fare, price_per_km, price_per_minute,
  minimum_fare, waiting_fee_per_minute, cancellation_fee
) values (
  'motorcycle', 35, 15, 2, 70, 1, 0
)
on conflict (vehicle_type) do nothing;

-- ---------------------------------------------------------------------
-- 2. Captain opt-in flag.
-- ---------------------------------------------------------------------
alter table public.captains
  add column if not exists accepts_delivery boolean not null default false;

-- ---------------------------------------------------------------------
-- 3. Trip columns for the delivery case.
-- ---------------------------------------------------------------------
alter table public.trips
  add column if not exists service_type text not null default 'ride'
    check (service_type in ('ride', 'delivery'));

alter table public.trips add column if not exists recipient_name text;
alter table public.trips add column if not exists recipient_phone text;
alter table public.trips add column if not exists package_description text;

-- ---------------------------------------------------------------------
-- 4. Visibility: a delivery request is only ever visible to an approved
-- motorcycle captain who has opted into delivery; a ride request keeps
-- exactly its prior visibility (any approved captain). Re-declares the
-- policy from 20260713000029_open_trip_lifecycle.sql with that one added
-- branch - everything else about it is unchanged.
-- ---------------------------------------------------------------------
drop policy if exists "Open trip requests are visible to active captains" on public.trips;
create policy "Open trip requests are visible to active captains"
  on public.trips for select
  to authenticated
  using (
    status = 'searching'
    and captain_id is null
    and exists (
      select 1 from public.captains c
      where c.id = auth.uid()
        and c.status = 'approved'
        and (
          service_type = 'ride'
          or (service_type = 'delivery' and c.vehicle_type = 'motorcycle' and c.accepts_delivery)
        )
    )
  );

-- ---------------------------------------------------------------------
-- 5. Server-side re-check on accept/assign - never trust the client filter
-- alone, exactly the reasoning already documented in
-- 20260717000036_captain_online_dispatch_guard.sql for is_online.
-- ---------------------------------------------------------------------
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

-- ---------------------------------------------------------------------
-- 6. customer_request_trip: optional service_type + recipient/package
-- fields. Defaults keep every existing caller (mobile customer app on an
-- older build, admin dispatch) behaving exactly as before - service_type
-- only ever becomes 'delivery' when a caller explicitly asks for it.
-- ---------------------------------------------------------------------
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
  p_package_description text default null
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
begin
  if v_customer_id is null then
    raise exception 'Not authenticated';
  end if;
  if not exists (select 1 from public.customers where id = v_customer_id) then
    raise exception 'Only a customer account may request a trip';
  end if;
  if p_service_type not in ('ride', 'delivery') then
    raise exception 'Invalid service type: %', p_service_type;
  end if;
  if p_pickup_lat is null or p_pickup_lng is null then
    raise exception 'Pickup coordinates are required';
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
