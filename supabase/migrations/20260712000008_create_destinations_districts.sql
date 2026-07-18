-- Phase 2: Nouakchott districts (moughataa). This is the top level of the
-- destination-selection hierarchy: district -> category -> place.

create table if not exists public.districts (
  id uuid primary key default gen_random_uuid(),
  name_ar text not null,
  name_fr text,
  code text unique not null,
  latitude double precision,
  longitude double precision,
  map_zoom double precision not null default 13,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists districts_set_updated_at on public.districts;
create trigger districts_set_updated_at
before update on public.districts
for each row execute function public.set_updated_at();
