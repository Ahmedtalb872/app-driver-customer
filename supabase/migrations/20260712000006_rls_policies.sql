-- Phase 1: baseline role-based access architecture.
-- Rule of thumb for this phase: users can read/update their own rows;
-- admins can read everything; nothing is client-insertable (rows are
-- created exclusively by the handle_new_user trigger, which runs with
-- elevated privileges - see 20260712000007_handle_new_user_trigger.sql).

alter table public.profiles enable row level security;
alter table public.customers enable row level security;
alter table public.captains enable row level security;
alter table public.admin_users enable row level security;
alter table public.wallets enable row level security;

-- Returns true when the currently authenticated user has the admin role.
-- security definer + fixed search_path so it can read profiles regardless
-- of the caller's own RLS visibility, without being hijackable.
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

-- profiles
drop policy if exists "Profiles are viewable by owner or admin" on public.profiles;
create policy "Profiles are viewable by owner or admin"
  on public.profiles for select
  using (auth.uid() = id or public.is_admin());

drop policy if exists "Profiles are updatable by owner" on public.profiles;
create policy "Profiles are updatable by owner"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- customers
drop policy if exists "Customers viewable by owner or admin" on public.customers;
create policy "Customers viewable by owner or admin"
  on public.customers for select
  using (auth.uid() = id or public.is_admin());

drop policy if exists "Customers updatable by owner" on public.customers;
create policy "Customers updatable by owner"
  on public.customers for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- captains
drop policy if exists "Captains viewable by owner or admin" on public.captains;
create policy "Captains viewable by owner or admin"
  on public.captains for select
  using (auth.uid() = id or public.is_admin());

drop policy if exists "Captains updatable by owner" on public.captains;
create policy "Captains updatable by owner"
  on public.captains for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- admin_users (admins only - not owner-visible by design)
drop policy if exists "Admin users viewable by admin" on public.admin_users;
create policy "Admin users viewable by admin"
  on public.admin_users for select
  using (public.is_admin());

-- wallets (read-only from the client in this phase; balance changes will
-- be driven by trusted server-side logic in a later phase)
drop policy if exists "Wallets viewable by owner or admin" on public.wallets;
create policy "Wallets viewable by owner or admin"
  on public.wallets for select
  using (auth.uid() = user_id or public.is_admin());
