-- Phase 1: core profile table, one row per auth.users user.
-- Holds the fields shared by every role; role-specific data lives in
-- customers / captains / admin_users.

create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '',
  phone text unique,
  role text not null check (role in ('customer', 'captain', 'admin')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists profiles_role_idx on public.profiles (role);

-- Shared helper trigger function: keeps updated_at current on every table
-- that has one (reused by customers, captains, wallets below).
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();
