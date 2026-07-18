-- Captain incoming-ride experience + Open Trip lifecycle.
--
-- Before this migration, `public.trips` existed (20260712000019) but no
-- mobile-app code ever wrote to it - the customer/captain flows were 100%
-- client-simulated (see AppStateProvider). This migration adds exactly what
-- real trip origination, broadcast-to-captains, accept/ignore, an Open Trip
-- (destination-unknown, metered) lifecycle, and live tracking need, without
-- touching any existing column or constraint that other code already reads.
--
-- Status lifecycle after this migration (superset of the original 6 values,
-- so nothing that already relied on the old set breaks):
--   searching  - request created, broadcast to online captains, no captain
--                assigned yet (this doubles as "offered_to_captain": every
--                online captain sees it until one accepts).
--   accepted   - a captain has claimed it and is en route to pickup.
--   arrived    - captain has marked arrival at the pickup point.
--   boarded    - reserved for future use; passenger_board_trip() currently
--                moves straight from arrived -> in_progress (see below) so
--                "passenger boarded" and "trip in progress" begin atomically
--                together, per spec section 21.
--   in_progress- trip is actively running (Open Trip meter is live).
--   completed  - trip ended, final fare/commission/net earnings recorded.
--   cancelled  - cancelled by customer, captain or admin.
--   expired    - no captain accepted before expires_at.

-- Passenger reputation fields the incoming-ride dialog needs to display
-- (rating, ratings count, completed trips, optional photo, verification
-- badge) - none of these existed anywhere before this migration. All
-- nullable/zero-defaulted so every existing customer row stays valid and
-- every existing query against `customers` is unaffected.
alter table public.customers
  add column if not exists avatar_url text;

alter table public.customers
  add column if not exists rating numeric(2, 1);

alter table public.customers
  add column if not exists ratings_count integer not null default 0;

alter table public.customers
  add column if not exists completed_trips_count integer not null default 0;

alter table public.customers
  add column if not exists is_verified boolean not null default false;

alter table public.trips
  add column if not exists trip_type text not null default 'normal'
    check (trip_type in ('normal', 'open'));

alter table public.trips
  add column if not exists customer_note text;

alter table public.trips
  add column if not exists passenger_count integer not null default 1
    check (passenger_count between 1 and 6);

alter table public.trips
  add column if not exists boarded_at timestamptz;

alter table public.trips
  add column if not exists expires_at timestamptz;

-- Live-tracking snapshot for an in-progress Open Trip. Deliberately a single
-- periodically-updated snapshot (not a row-per-GPS-point table) so live
-- tracking doesn't mean a database write on every GPS fix - the full-
-- resolution breadcrumb trail stays client-side in OpenTripController,
-- exactly like it already does today.
alter table public.trips
  add column if not exists traveled_distance_km numeric(8, 2);

alter table public.trips
  add column if not exists last_location_lat double precision;

alter table public.trips
  add column if not exists last_location_lng double precision;

alter table public.trips
  add column if not exists last_location_at timestamptz;

-- Captains who ignored this request while it was broadcasting, so the same
-- captain's dialog doesn't reappear for a request they already dismissed.
alter table public.trips
  add column if not exists ignored_by uuid[] not null default '{}';

-- Widen the status check constraint to the superset described above. Every
-- value the table already used to (or could) hold is still allowed.
alter table public.trips drop constraint if exists trips_status_check;
alter table public.trips add constraint trips_status_check
  check (status in (
    'searching', 'accepted', 'arrived', 'boarded', 'in_progress',
    'completed', 'cancelled', 'expired'
  ));

create index if not exists trips_broadcast_idx
  on public.trips (status, captain_id)
  where status = 'searching' and captain_id is null;

-- ---------------------------------------------------------------------
-- RLS: let an online, approved captain see a request before they own it
-- (the existing owner-only select policy from 20260712000026_admin_rls.sql
-- only lets auth.uid() = customer_id/captain_id/admin see a row - a captain
-- who hasn't accepted yet is none of those). Policies on the same table for
-- the same command are OR'd together, so this only ever widens visibility,
-- never narrows the existing policy.
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
      where c.id = auth.uid() and c.status = 'approved'
    )
  );

-- ---------------------------------------------------------------------
-- RPCs. Every function re-validates the caller's role/ownership itself
-- (never trusts client-supplied ids for who is acting), matching the
-- SECURITY DEFINER + `set search_path = public` hardening pattern already
-- used throughout 20260712000028_admin_functions.sql and
-- 20260712000017_destinations_functions.sql.
-- ---------------------------------------------------------------------

-- 1. Customer creates a real trip request (normal or Open Trip). Pickup is
-- always the passenger's current GPS location for an Open Trip; destination
-- is left null for one, exactly as the app already models it via
-- destination_address/lat/lng already being nullable columns.
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
  p_timeout_seconds integer default 45,
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

-- 2. Captain accepts a broadcasting request. Atomic compare-and-set: only
-- succeeds while the row is still unclaimed and not expired, so two captains
-- racing on the same request can never both "win".
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
    select 1 from public.captains where id = v_captain_id and status = 'approved'
  ) then
    raise exception 'Only an approved captain may accept a trip';
  end if;

  update public.trips
    set captain_id = v_captain_id, status = 'accepted', accepted_at = now()
    where id = p_trip_id
      and status = 'searching'
      and captain_id is null
      and (expires_at is null or expires_at > now())
    returning * into v_row;

  if not found then
    raise exception 'TRIP_UNAVAILABLE';
  end if;

  return v_row;
end;
$$;

-- 3. Captain ignores a broadcasting request - just hides it from that
-- captain's own dialog, never affects other captains or the request itself.
create or replace function public.captain_ignore_trip(p_trip_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_captain_id uuid := auth.uid();
begin
  update public.trips
    set ignored_by = array_append(ignored_by, v_captain_id)
    where id = p_trip_id
      and status = 'searching'
      and not (v_captain_id = any(ignored_by));
end;
$$;

-- 4. Captain marks arrival at the pickup point.
create or replace function public.captain_arrive_trip(p_trip_id uuid)
returns public.trips
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.trips;
begin
  update public.trips
    set status = 'arrived', arrived_at = now()
    where id = p_trip_id and captain_id = auth.uid() and status = 'accepted'
    returning * into v_row;

  if not found then
    raise exception 'TRIP_INVALID_STATE';
  end if;

  return v_row;
end;
$$;

-- 5. Passenger presses "ركبت" - the official, sole starting point of an
-- Open Trip. passenger_boarded and in_progress begin together here (spec
-- section 21), so boarded_at/started_at are stamped in the same update.
create or replace function public.passenger_board_trip(p_trip_id uuid)
returns public.trips
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.trips;
begin
  update public.trips
    set status = 'in_progress', boarded_at = now(), started_at = now()
    where id = p_trip_id and customer_id = auth.uid() and status = 'arrived'
    returning * into v_row;

  if not found then
    raise exception 'TRIP_INVALID_STATE';
  end if;

  return v_row;
end;
$$;

-- 6. Periodic live-tracking snapshot while an Open Trip is in progress.
-- Called every few seconds/meters from the captain's device, not on every
-- raw GPS fix - keeps write volume reasonable (spec section 16: "update the
-- displayed fare smoothly without excessive backend writes").
create or replace function public.update_trip_live_tracking(
  p_trip_id uuid,
  p_lat double precision,
  p_lng double precision,
  p_traveled_distance_km numeric
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.trips
    set last_location_lat = p_lat,
        last_location_lng = p_lng,
        last_location_at = now(),
        traveled_distance_km = greatest(p_traveled_distance_km, 0)
    where id = p_trip_id and captain_id = auth.uid() and status = 'in_progress';

  if not found then
    raise exception 'TRIP_INVALID_STATE';
  end if;
end;
$$;

-- 7. Captain ends the trip. Computes final fare from `pricing_config`
-- (never hardcoded), commission and net earnings, credits the captain's
-- wallet exactly once (the status='in_progress' guard makes this
-- idempotent - a retried call after the first success finds no matching row
-- and raises instead of double-crediting).
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

  v_subtotal := v_pricing.base_fare
    + (greatest(p_final_distance_km, 0) * v_pricing.price_per_km)
    + (v_duration_minutes * v_pricing.price_per_minute);
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

  return v_trip;
end;
$$;

-- 8. Captain online/offline toggle, now actually persisted (previously
-- local-only in AppStateProvider - see captain_home_screen.dart).
create or replace function public.captain_set_online(p_is_online boolean)
returns public.captains
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.captains;
begin
  update public.captains set is_online = p_is_online where id = auth.uid()
    returning * into v_row;

  if not found then
    raise exception 'No captain profile found for the current user';
  end if;

  return v_row;
end;
$$;

-- 9. Best-effort client-triggered expiry: called by a captain's dialog (or
-- the customer's waiting screen) once its own countdown reaches zero. Not a
-- server-side cron job (none is configured in this project), so a request
-- nobody is looking at anymore stays 'searching' until the next viewer's
-- countdown expires it - it can never be accepted past its expires_at
-- regardless (captain_accept_trip already checks that).
create or replace function public.expire_trip(p_trip_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.trips
    set status = 'expired'
    where id = p_trip_id
      and status = 'searching'
      and expires_at is not null
      and expires_at < now();
end;
$$;
