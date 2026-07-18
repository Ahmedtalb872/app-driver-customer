-- Phase 1: automatic profile + role-row + wallet creation right after a
-- user signs up, driven entirely by the metadata AuthService.signUp() sends
-- (full_name, phone, role). Runs as security definer so it can write to
-- tables the new user has no RLS insert access to.

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
  v_phone := new.raw_user_meta_data ->> 'phone';

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

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();
