-- Phase 2: neighborhoods (hay) within a district. Optional finer-grained
-- grouping used by places.neighborhood_id and by custom destination forms.

create table if not exists public.neighborhoods (
  id uuid primary key default gen_random_uuid(),
  district_id uuid not null references public.districts (id) on delete cascade,
  name_ar text not null,
  name_fr text,
  latitude double precision,
  longitude double precision,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists neighborhoods_set_updated_at on public.neighborhoods;
create trigger neighborhoods_set_updated_at
before update on public.neighborhoods
for each row execute function public.set_updated_at();
