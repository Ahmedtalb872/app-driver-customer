-- Fixes a dead end in the trip lifecycle: `passenger_board_trip`
-- (20260713000029_open_trip_lifecycle.sql) is gated to
-- `customer_id = auth.uid()`, i.e. only the trip's own passenger can move a
-- trip from 'arrived' to 'in_progress'. That is correct for a
-- self-service customer app, but this project's customer-facing screens
-- were removed (operator/admin now dispatches trips on behalf of phone-in
-- customers who never sign into any app - see admin_dispatch_trip,
-- 20260713000030_operator_dispatch.sql), so nothing could ever call
-- passenger_board_trip for those trips. Without this, captain_end_trip
-- (which requires status = 'in_progress') could never succeed for an
-- admin-dispatched trip - a captain could arrive but never start or
-- complete the ride.
--
-- This adds an admin-side equivalent, mirroring the existing
-- admin_assign_captain / admin_cancel_trip pattern: same state transition
-- as passenger_board_trip, gated by operations_admin/super_admin instead of
-- passenger ownership. passenger_board_trip itself is untouched, so a
-- future real customer app can still use it directly.
create or replace function public.admin_board_trip(p_trip_id uuid)
returns public.trips
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.trips;
begin
  if not public.has_admin_role('operations_admin') then
    raise exception 'Only operations_admin or super_admin may mark a trip boarded';
  end if;

  update public.trips
    set status = 'in_progress', boarded_at = now(), started_at = now()
    where id = p_trip_id and status = 'arrived'
    returning * into v_row;

  if not found then
    raise exception 'TRIP_INVALID_STATE';
  end if;

  perform public.log_admin_action(
    'trip_boarded', 'trip', p_trip_id::text, null, null, null
  );

  return v_row;
end;
$$;
