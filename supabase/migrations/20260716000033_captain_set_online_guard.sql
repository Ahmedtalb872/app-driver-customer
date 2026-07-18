-- Guards `captain_set_online` (added in 20260713000029_open_trip_lifecycle)
-- so only an approved captain can actually go online. Previously the RPC
-- only checked that a `captains` row existed for auth.uid() - it had zero
-- business-rule gating, so a pending/rejected/suspended captain could set
-- is_online = true and start receiving live ride broadcasts. Going
-- *offline* is still always allowed regardless of status - harmless, and
-- lets a captain who gets suspended/rejected while online be taken offline
-- without a stuck row.
--
-- The exception messages below are already the exact, specific Arabic
-- reason shown to the captain client-side (see
-- captain_home_screen.dart's _describeOnlineError) - no separate
-- client-side copy of this business rule to keep in sync.
create or replace function public.captain_set_online(p_is_online boolean)
returns public.captains
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.captains;
  v_status text;
begin
  select status into v_status from public.captains where id = auth.uid();

  if v_status is null then
    raise exception 'No captain profile found for the current user';
  end if;

  if p_is_online and v_status <> 'approved' then
    raise exception '%', case v_status
      when 'pending' then 'حسابك قيد المراجعة حالياً، لا يمكنك الاتصال قبل اعتماده من الإدارة.'
      when 'rejected' then 'تم رفض طلب انضمامك ككابتن، تواصل مع الدعم لمزيد من التفاصيل.'
      when 'suspended' then 'تم إيقاف حسابك مؤقتاً من قبل الإدارة، تواصل مع الدعم.'
      else 'حسابك غير معتمد حالياً، لا يمكنك الاتصال.'
    end;
  end if;

  update public.captains set is_online = p_is_online where id = auth.uid()
    returning * into v_row;

  return v_row;
end;
$$;
