-- Some profiles rows predate handle_new_user reliably creating the matching
-- customers/wallets row (e.g. accounts created during earlier phases of
-- this project, before the customer-only rework was complete) - and since
-- the trigger only ever runs on a new auth.users insert, it never
-- retroactively backfills those. customer_request_trip() requires a
-- customers row to exist for the caller, so such an account got
-- 'Only a customer account may request a trip' on every ride request.
insert into public.customers (id)
select p.id
from public.profiles p
where p.role = 'customer'
  and not exists (select 1 from public.customers c where c.id = p.id)
on conflict (id) do nothing;

insert into public.wallets (user_id)
select p.id
from public.profiles p
where p.role = 'customer'
  and not exists (select 1 from public.wallets w where w.user_id = p.id)
on conflict (user_id) do nothing;
