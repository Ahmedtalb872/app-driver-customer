-- Lets an operator dispatch a parcel delivery on a caller's behalf, the
-- same way admin_dispatch_trip already does for a passenger ride - the
-- customer app has had this via customer_request_trip since
-- 20260801000046_delivery_service.sql, but the operator dispatch console
-- had no equivalent, so a customer calling in with a delivery instead of a
-- ride had no manual path at all. Mirrors customer_request_trip's own
-- delivery branch: service_type/recipient_name/recipient_phone/
-- package_description are optional so every existing ride-dispatch caller
-- keeps behaving exactly as before.
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
  p_timeout_seconds integer default 300,
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
  v_admin_id uuid := auth.uid();
  v_customer_id uuid;
  v_row public.trips;
  v_vehicle_type text := p_vehicle_type;
begin
  if not public.has_admin_role('operations_admin') then
    raise exception 'Only operations_admin or super_admin may dispatch a trip manually';
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
    -- Always broadcast/priced as a motorcycle job, same as
    -- customer_request_trip - regardless of whatever vehicle_type the
    -- operator's UI happened to have selected before switching modes.
    v_vehicle_type := 'motorcycle';
  else
    if p_trip_type not in ('normal', 'open') then
      raise exception 'Invalid trip type: %', p_trip_type;
    end if;
    if p_trip_type = 'normal' and (p_destination_lat is null or p_destination_lng is null) then
      raise exception 'A fixed trip requires a destination';
    end if;
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
    service_type, recipient_name, recipient_phone, package_description,
    dispatched_by, requested_at, expires_at
  ) values (
    v_customer_id,
    case when v_customer_id is null then p_customer_phone else null end,
    'searching',
    case when p_service_type = 'delivery' then 'normal' else p_trip_type end,
    p_pickup_address, p_pickup_lat, p_pickup_lng,
    p_destination_address, p_destination_lat, p_destination_lng,
    v_vehicle_type, p_payment_method, p_customer_note,
    p_estimated_price, p_estimated_duration_minutes, p_distance_km,
    p_service_type,
    case when p_service_type = 'delivery' then p_recipient_name else null end,
    case when p_service_type = 'delivery' then p_recipient_phone else null end,
    case when p_service_type = 'delivery' then p_package_description else null end,
    v_admin_id, now(), now() + make_interval(secs => greatest(p_timeout_seconds, 10))
  ) returning * into v_row;

  perform public.log_admin_action(
    'trip_dispatched', 'trip', v_row.id::text, null,
    jsonb_build_object(
      'customer_phone', p_customer_phone,
      'customer_registered', v_customer_id is not null,
      'service_type', p_service_type,
      'trip_type', p_trip_type,
      'vehicle_type', v_vehicle_type
    ),
    null
  );

  return v_row;
end;
$$;
