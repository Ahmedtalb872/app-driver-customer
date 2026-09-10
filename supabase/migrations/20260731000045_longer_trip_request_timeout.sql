-- The default 45-second expires_at window on a new trip request (both the
-- customer app's own request and an admin-dispatched one) is realistic for
-- production (captains are expected to already have the app open,
-- listening in real time), but far too short for manual end-to-end testing
-- across two physical phones - by the time a tester unlocks the captain
-- phone and opens the app, the request has often already expired and
-- silently vanished from the broadcast pool, which looks identical to "it
-- never arrived". Bumping the default to 5 minutes only changes what
-- happens when the caller doesn't pass p_timeout_seconds explicitly; both
-- functions are otherwise unchanged from their prior definitions.

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
  p_passenger_count integer default 1
)
returns public.trips
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer_id uuid := auth.uid();
  v_row public.trips;
begin
  if v_customer_id is null then
    raise exception 'Not authenticated';
  end if;
  if not exists (select 1 from public.customers where id = v_customer_id) then
    raise exception 'Only a customer account may request a trip';
  end if;
  if p_trip_type not in ('normal', 'open') then
    raise exception 'Invalid trip type: %', p_trip_type;
  end if;
  if p_pickup_lat is null or p_pickup_lng is null then
    raise exception 'Pickup coordinates are required';
  end if;

  insert into public.trips (
    customer_id, status, trip_type,
    pickup_address, pickup_lat, pickup_lng,
    destination_address, destination_lat, destination_lng,
    vehicle_type, payment_method, customer_note, passenger_count,
    requested_at, expires_at
  ) values (
    v_customer_id, 'searching', p_trip_type,
    p_pickup_address, p_pickup_lat, p_pickup_lng,
    p_destination_address, p_destination_lat, p_destination_lng,
    p_vehicle_type, p_payment_method, p_customer_note,
    greatest(coalesce(p_passenger_count, 1), 1),
    now(), now() + make_interval(secs => greatest(p_timeout_seconds, 10))
  ) returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.admin_dispatch_trip(
  p_customer_phone text,
  p_pickup_address text,
  p_pickup_lat double precision,
  p_pickup_lng double precision,
  p_trip_type text default 'normal',
  p_destination_address text default null,
  p_destination_lat double precision default null,
  p_destination_lng double precision default null,
  p_vehicle_type text default 'economy',
  p_payment_method text default 'cash',
  p_estimated_price numeric default null,
  p_estimated_duration_minutes integer default null,
  p_distance_km numeric default null,
  p_customer_note text default null,
  p_timeout_seconds integer default 300
)
returns public.trips
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id uuid := auth.uid();
  v_customer_id uuid;
  v_row public.trips;
begin
  if not public.has_admin_role('operations_admin') then
    raise exception 'Only operations_admin or super_admin may dispatch a trip manually';
  end if;
  if p_trip_type not in ('normal', 'open') then
    raise exception 'Invalid trip type: %', p_trip_type;
  end if;
  if p_pickup_lat is null or p_pickup_lng is null then
    raise exception 'Pickup coordinates are required';
  end if;
  if p_trip_type = 'normal' and (p_destination_lat is null or p_destination_lng is null) then
    raise exception 'A fixed trip requires a destination';
  end if;

  select c.id into v_customer_id
  from public.customers c
  join public.profiles p on p.id = c.id
  where p.phone = p_customer_phone
  limit 1;

  insert into public.trips (
    customer_id, guest_customer_phone, status, trip_type,
    pickup_address, pickup_lat, pickup_lng,
    destination_address, destination_lat, destination_lng,
    vehicle_type, payment_method, customer_note,
    estimated_price, estimated_duration_minutes, distance_km,
    dispatched_by, requested_at, expires_at
  ) values (
    v_customer_id,
    case when v_customer_id is null then p_customer_phone else null end,
    'searching', p_trip_type,
    p_pickup_address, p_pickup_lat, p_pickup_lng,
    p_destination_address, p_destination_lat, p_destination_lng,
    p_vehicle_type, p_payment_method, p_customer_note,
    p_estimated_price, p_estimated_duration_minutes, p_distance_km,
    v_admin_id, now(), now() + make_interval(secs => greatest(p_timeout_seconds, 10))
  ) returning * into v_row;

  perform public.log_admin_action(
    'trip_dispatched', 'trip', v_row.id::text, null,
    jsonb_build_object(
      'customer_phone', p_customer_phone,
      'customer_registered', v_customer_id is not null,
      'trip_type', p_trip_type,
      'vehicle_type', p_vehicle_type
    ),
    null
  );

  return v_row;
end;
$$;
