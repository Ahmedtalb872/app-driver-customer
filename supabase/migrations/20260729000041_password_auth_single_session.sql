-- Adds phone+password login (a real OTP is still required once, at sign-up,
-- to prove ownership of the number - see AuthService.setPasswordForCurrentUser)
-- and single-active-session enforcement: signing in on a new device
-- overwrites profiles.active_session_id, and every other already-signed-in
-- device is watching that same column via Realtime (SessionGuardService) -
-- the moment it sees a value that isn't its own, it signs itself out.

-- Phone-OTP sign-ups never sent `phone` in the auth metadata (only
-- password sign-ups do - see AuthService.signUp), so handle_new_user was
-- leaving public.profiles.phone null for every real customer created via
-- the normal OTP flow. That silently broke anything keyed on profiles.phone,
-- including the new check_phone_registered() below - fall back to the
-- native auth.users.phone column, which Supabase always populates for a
-- phone-OTP account.
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

-- One-time backfill for any account already affected by the bug above.
update public.profiles p
set phone = u.phone
from auth.users u
where p.id = u.id and p.phone is null and u.phone is not null;

alter table public.profiles
  add column if not exists active_session_id uuid;

-- Lets the client decide, before any auth session exists, whether the
-- phone step should send an OTP (new account) or ask for a password
-- (existing account) - callable by the anon role.
create or replace function public.check_phone_registered(p_phone text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.profiles where phone = p_phone);
$$;

-- Called right after a successful login (password or fresh OTP sign-up)
-- with a new client-generated id, overwriting whatever was there before -
-- see the module comment above for how that enforces a single session.
create or replace function public.set_active_session(p_session_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;
  update public.profiles set active_session_id = p_session_id where id = auth.uid();
end;
$$;

-- profiles needs to be on the realtime publication for SessionGuardService's
-- .stream() subscription (each signed-in device watching its own row) to
-- see active_session_id change after the initial snapshot.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'profiles'
  ) then
    alter publication supabase_realtime add table public.profiles;
  end if;
end $$;
