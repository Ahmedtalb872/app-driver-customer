-- admin_delete_captain (20260802000050) removed the captains row but left
-- profiles.phone untouched, so check_phone_registered() - which only ever
-- checks `exists (select 1 from public.profiles where phone = p_phone)`,
-- see 20260729000041_password_auth_single_session.sql - kept saying the
-- number was still registered, and the deleted captain's phone could never
-- be used for a fresh sign-up. profiles.phone is a plain `unique` column
-- (not a "nulls not distinct" one), so blanking it here doesn't block any
-- later row from taking that same number.
--
-- The profiles/auth.users rows themselves are still left alone (same
-- reasoning as before: no service-role key client-side to remove them
-- properly) - just no longer reachable by phone lookup, which is the part
-- that actually blocked re-registration.
create or replace function public.admin_delete_captain(
  p_captain_id uuid,
  p_reason text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_full_name text;
  v_phone text;
begin
  if not public.has_admin_role('operations_admin') then
    raise exception 'Only operations_admin or super_admin may delete a captain profile';
  end if;
  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'A reason is required to delete a captain profile';
  end if;

  select full_name, phone into v_full_name, v_phone
    from public.profiles where id = p_captain_id;

  begin
    delete from public.captains where id = p_captain_id;
  exception when foreign_key_violation then
    raise exception 'CAPTAIN_HAS_TRIP_HISTORY: captain % has trip history and cannot be deleted - suspend the account instead', p_captain_id;
  end;

  if not found then
    raise exception 'Captain % not found', p_captain_id;
  end if;

  update public.profiles set phone = null where id = p_captain_id;

  perform public.log_admin_action(
    'captain_deleted', 'captain', p_captain_id::text,
    jsonb_build_object('full_name', v_full_name, 'phone', v_phone),
    null,
    p_reason
  );
end;
$$;
