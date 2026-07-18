-- Phase 2: fixed, admin-managed list of destination categories (restaurants,
-- hospitals, mosques, ...). A table rather than a Postgres enum so new
-- categories can be added/reordered/disabled without a migration.

create table if not exists public.place_categories (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  name_ar text not null,
  name_fr text,
  icon_name text,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
