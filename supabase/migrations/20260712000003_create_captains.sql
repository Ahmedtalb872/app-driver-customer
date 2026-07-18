-- Phase 1: captain-specific extension of profiles. Vehicle info and
-- document verification are added in a later phase; for now a captain
-- account exists in 'pending' status until reviewed.

create table if not exists public.captains (
  id uuid primary key references public.profiles (id) on delete cascade,
  city text,
  address text,
  date_of_birth date,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'suspended')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists captains_status_idx on public.captains (status);

drop trigger if exists captains_set_updated_at on public.captains;
create trigger captains_set_updated_at
before update on public.captains
for each row execute function public.set_updated_at();
