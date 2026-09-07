-- Fixes a signup bug where a genuinely returning customer's phone number
-- was never recognized as already registered, so the login screen kept
-- sending them through the OTP sign-up path a second time - which then
-- crashed with an opaque "Database error saving new user"
-- (profiles_phone_key unique violation) instead of ever reaching the
-- password sign-in step.
--
-- Root cause: Supabase's native phone-OTP auth stores auth.users.phone
-- WITHOUT a leading "+" (e.g. "22230776985"), but every other read/write of
-- a phone number in this app's own code uses the "+222..." E.164-with-plus
-- form (AuthService._phoneToEmail, phone_code_login_screen.dart's
-- '+222${digits}'). handle_new_user() (20260729000041) wrote
-- profiles.phone straight from new.phone (no plus) for a phone-OTP signup,
-- while check_phone_registered(p_phone) - an exact string match against
-- that same column - is always called with the "+222..." form. The two
-- never matched, so a real second attempt with the same number was
-- (wrongly) treated as brand new every time.
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
  if v_role not in ('customer', 'captain', 'admin') then
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
  elsif v_role = 'admin' then
    insert into public.admin_users (id) values (new.id)
    on conflict (id) do nothing;
  end if;

  insert into public.wallets (user_id) values (new.id)
  on conflict (user_id) do nothing;

  return new;
end;
$$;

-- One-time backfill: any existing profiles row whose phone was stored
-- without the leading "+" (every phone-OTP account created before this
-- fix) gets the same normalization applied, so check_phone_registered()
-- recognizes them too. Skipped if it would collide with an already-correct
-- "+"-prefixed row for the same number (shouldn't happen in practice, but
-- keeps this safe to re-run).
update public.profiles p
set phone = '+' || p.phone
where p.phone is not null
  and p.phone !~ '^\+'
  and not exists (
    select 1 from public.profiles p2
    where p2.phone = '+' || p.phone and p2.id <> p.id
  );
