-- Operator Dispatch: lets an operations_admin/super_admin create a real
-- trip on behalf of a customer who called the dispatch center. The created
-- trip is indistinguishable from a mobile-originated one to captains - it
-- lands in `status = 'searching'`, `captain_id is null`, so it enters the
-- exact same broadcast pool the "Open trip requests are visible to active
-- captains" policy (20260713000029_open_trip_lifecycle.sql) already shows
-- to every online, approved captain via RideRepository.watchIncomingRequests.
-- No separate dispatch mechanism was introduced.

-- Tags a trip as operator-created and by whom, for the audit trail /
-- admin trips list to distinguish it from a customer self-service request.
alter table public.trips
  add column if not exists dispatched_by uuid references auth.users (id);

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
  p_timeout_seconds integer default 45
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

  if v_customer_id is null then
    raise exception 'CUSTOMER_NOT_FOUND';
  end if;

  insert into public.trips (
    customer_id, status, trip_type,
    pickup_address, pickup_lat, pickup_lng,
    destination_address, destination_lat, destination_lng,
    vehicle_type, payment_method, customer_note,
    estimated_price, estimated_duration_minutes, distance_km,
    dispatched_by, requested_at, expires_at
  ) values (
    v_customer_id, 'searching', p_trip_type,
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
      'trip_type', p_trip_type,
      'vehicle_type', p_vehicle_type
    ),
    null
  );

  return v_row;
end;
$$;
