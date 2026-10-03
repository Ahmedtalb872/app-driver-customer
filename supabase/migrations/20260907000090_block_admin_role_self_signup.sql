-- Security fix: handle_new_user() trusted raw_user_meta_data ->> 'role'
-- (only checking it was one of 'customer'/'captain'/'admin') to decide the
-- new profiles row's role. That metadata is caller-supplied data on
-- Supabase Auth's public signup endpoint (POST /auth/v1/signup with the
-- project's anon key, which every app build embeds and is not a secret) -
-- nothing server-side ever re-validated it. Anyone could call that
-- endpoint directly (bypassing the Flutter app entirely) with
-- data: {"role": "admin"} and get a real profiles.role = 'admin' row,
-- which public.is_admin() (every admin RLS policy in this project) accepts
-- outright - full read/write access to every customer's and captain's
-- wallets, trips, and personal data with no actual admin credential.
--
-- The only legitimate admin account creation path in this project has
-- always been a one-off direct `insert into auth.users` from the SQL
-- editor/a migration (20260730000044_create_real_admin_account.sql, whose
-- existing admin account is untouched by this change - it already has its
-- profiles/admin_users rows from before this fix). That migration relied
-- on this trigger auto-creating the admin_users row for role = 'admin';
-- since this trigger can no longer tell "trusted SQL-editor insert" apart
-- from "public signup" (both fire the exact same AFTER INSERT trigger),
-- the only safe fix is to stop auto-provisioning admin at all here - any
-- FUTURE admin account must have its migration also insert into
-- public.admin_users (and set profiles.role = 'admin') itself, explicitly,
-- rather than depending on this trigger to infer it from metadata.
-- 'captain' is left as-is: unlike 'admin', a self-registered captain has
-- no elevated access until an operations_admin explicitly approves them
-- (admin_approve_captain).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_role text;
  v_full_name text;
  v_phone text;
begin
  v_role := coalesce(new.raw_user_meta_data ->> 'role', 'customer');
  if v_role not in ('customer', 'captain') then
    v_role := 'customer';
  end if;
  v_full_name := coalesce(new.raw_user_meta_data ->> 'full_name', '');
  v_phone := coalesce(new.raw_user_meta_data ->> 'phone', new.phone);
  if v_phone is not null and v_phone !~ '^\+' then
    v_phone := '+' || v_phone;
  end if;

  insert into public.profiles (id, full_name, phone, role)
  values (new.id, v_full_name, v_phone, v_role)
  on conflict (id) do nothing;

  if v_role = 'customer' then
    insert into public.customers (id) values (new.id)
    on conflict (id) do nothing;
  elsif v_role = 'captain' then
    insert into public.captains (id) values (new.id)
    on conflict (id) do nothing;
  end if;

  insert into public.wallets (user_id) values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;
