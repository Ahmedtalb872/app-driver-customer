-- Phase 1: admin-specific extension of profiles. Admin accounts are not
-- self-service - they are provisioned manually from the Supabase dashboard
-- (see project notes) by inserting into auth.users with role = 'admin'
-- metadata, which the handle_new_user trigger picks up.

create table if not exists public.admin_users (
  id uuid primary key references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now()
);
