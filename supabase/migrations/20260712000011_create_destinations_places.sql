-- Phase 2: public/official destinations only (restaurants, hospitals,
-- mosques, landmarks, ...). Private homes and unregistered locations never
-- live here - see custom_destinations.

create table if not exists public.places (
  id uuid primary key default gen_random_uuid(),
  district_id uuid not null references public.districts (id),
  neighborhood_id uuid references public.neighborhoods (id) on delete set null,
  category_id uuid not null references public.place_categories (id),
  name_ar text not null,
  name_fr text,
  address_ar text,
  address_fr text,
  latitude double precision not null,
  longitude double precision not null,
  google_place_id text,
  phone text,
  description_ar text,
  is_popular boolean not null default false,
  is_verified boolean not null default false,
  is_active boolean not null default true,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists places_set_updated_at on public.places;
create trigger places_set_updated_at
before update on public.places
for each row execute function public.set_updated_at();
