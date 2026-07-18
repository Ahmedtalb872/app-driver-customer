-- Server-side guard: a trip must never end up assigned to (or accepted by)
-- a captain who is currently offline. Both admin_assign_captain and
-- captain_accept_trip previously checked only `status = 'approved'`, not
-- `is_online` - the admin dashboard's captain picker already filters to
-- online captains client-side (captain_picker_dialog.dart, onlineFilter:
-- true), but that is not a substitute for a server-side check: a captain
-- could go offline in the moment between the picker loading and the admin
-- clicking assign, or the RPC could be called directly, bypassing the UI
-- filter entirely. This re-implements both functions from
-- 20260713000029_open_trip_lifecycle.sql and
-- 20260713000031_admin_assign_captain.sql with the added `is_online = true`
-- condition, otherwise unchanged.

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
    select 1 from public.captains
    where id = p_captain_id and status = 'approved' and is_online = true
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
    returning * into v_row;

  if not found then
    raise exception 'TRIP_UNAVAILABLE';
  end if;

  return v_row;
end;
$$;
