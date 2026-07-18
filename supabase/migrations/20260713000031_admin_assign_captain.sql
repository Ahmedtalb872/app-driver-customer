-- Lets an operations_admin/super_admin manually assign or reassign a
-- captain to a trip from the admin dashboard. No new table/column - the
-- captain<->trip link is (and remains) only `trips.captain_id`, matching
-- every other trip-lifecycle function in this project
-- (20260713000029_open_trip_lifecycle.sql's captain_accept_trip).

create or replace function public.admin_assign_captain(
  p_trip_id uuid,
  p_captain_id uuid,
  p_reason text default null
)
returns public.trips
language plpgsql
security definer
set search_path = public
as $$
declare
  v_trip public.trips;
  v_old_captain_id uuid;
begin
  if not public.has_admin_role('operations_admin') then
    raise exception 'Only operations_admin or super_admin may assign a captain to a trip';
  end if;

  if not exists (
    select 1 from public.captains where id = p_captain_id and status = 'approved'
  ) then
    raise exception 'CAPTAIN_NOT_APPROVED';
  end if;

  select captain_id into v_old_captain_id from public.trips where id = p_trip_id;

  update public.trips
    set captain_id = p_captain_id,
        status = case when status = 'searching' then 'accepted' else status end,
        accepted_at = coalesce(accepted_at, now())
    where id = p_trip_id
      and status in ('searching', 'accepted', 'arrived', 'in_progress')
    returning * into v_trip;

  if not found then
    raise exception 'TRIP_NOT_ASSIGNABLE';
  end if;

  perform public.log_admin_action(
    'trip_captain_assigned', 'trip', p_trip_id::text,
    jsonb_build_object('captain_id', v_old_captain_id),
    jsonb_build_object('captain_id', p_captain_id),
    p_reason
  );

  return v_trip;
end;
$$;
