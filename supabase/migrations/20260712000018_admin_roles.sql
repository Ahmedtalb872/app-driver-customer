-- Admin dashboard: fine-grained admin sub-roles, layered on top of Phase 1's
-- profiles.role = 'admin' gate (public.is_admin()) and admin_users table.
-- profiles.role itself is NOT touched - it stays exactly ('customer',
-- 'captain', 'admin') as every RLS policy and the handle_new_user trigger
-- already depend on that fixed set.

alter table public.admin_users
  add column if not exists admin_role text
    check (admin_role in (
      'super_admin', 'operations_admin', 'finance_admin',
      'support_admin', 'content_admin'
    ));

alter table public.admin_users
  add column if not exists full_name text;

alter table public.admin_users
  add column if not exists is_active boolean not null default true;

alter table public.admin_users
  add column if not exists updated_at timestamptz not null default now();

drop trigger if exists admin_users_set_updated_at on public.admin_users;
create trigger admin_users_set_updated_at
before update on public.admin_users
for each row execute function public.set_updated_at();

-- Returns the current user's admin_role, or null if they aren't an admin
-- (or their admin_users row predates this migration and has none set yet).
create or replace function public.current_admin_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select admin_role from public.admin_users where id = auth.uid();
$$;

-- True when the current user is an active admin whose admin_role is one of
-- the given roles, or is a super_admin (always passes). Used to gate
-- sensitive SECURITY DEFINER admin functions - never trust the client for
-- this, always re-check here.
create or replace function public.has_admin_role(variadic roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admin_users
    where id = auth.uid()
      and is_active = true
      and (admin_role = 'super_admin' or admin_role = any(roles))
  );
$$;
