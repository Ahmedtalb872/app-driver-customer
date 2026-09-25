-- Lets an operator remove a captain's profile entirely - e.g. a spam/
-- duplicate signup, or an applicant rejected during document review who
-- should stop cluttering the captains list - instead of the only options
-- being "leave it pending/rejected forever" or "suspend" (which still
-- shows up everywhere as a captain, just blocked from going online).
--
-- Deliberately only deletes the `captains` row (and, via its existing
-- `on delete cascade`, `captain_documents`) - never `profiles` or
-- `auth.users`. Those require the Supabase service-role key to remove
-- properly (see docs/admin_web_deployment.md section 3: this project never
-- ships that key to a client), so a full account deletion isn't something
-- this dashboard can safely do. The person's login and profile row simply
-- stop having any captain-specific data attached.
--
-- `trips.captain_id references public.captains (id)` has no `on delete`
-- clause, i.e. `no action` - Postgres itself already refuses this delete
-- for any captain who was ever actually assigned a trip, protecting trip/
-- financial history for free. That FK violation is caught below and
-- turned into one clear, catchable error instead of a raw Postgres
-- exception, so the UI can tell the operator to suspend the account
-- instead when that happens.
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
begin
  if not public.has_admin_role('operations_admin') then
    raise exception 'Only operations_admin or super_admin may delete a captain profile';
  end if;
  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'A reason is required to delete a captain profile';
  end if;

  select full_name into v_full_name from public.profiles where id = p_captain_id;

  begin
    delete from public.captains where id = p_captain_id;
  exception when foreign_key_violation then
    raise exception 'CAPTAIN_HAS_TRIP_HISTORY: captain % has trip history and cannot be deleted - suspend the account instead', p_captain_id;
  end;

  if not found then
    raise exception 'Captain % not found', p_captain_id;
  end if;

  perform public.log_admin_action(
    'captain_deleted', 'captain', p_captain_id::text,
    jsonb_build_object('full_name', v_full_name),
    null,
    p_reason
  );
end;
$$;
