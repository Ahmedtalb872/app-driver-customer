-- Phase 2: a user's saved destinations (home/work/airport/custom favorite).
-- Fully private - never joined against other users.

create table if not exists public.saved_places (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  label text not null check (label in ('home', 'work', 'airport', 'custom')),
  custom_label text,
  place_id uuid references public.places (id) on delete set null,
  district_id uuid references public.districts (id) on delete set null,
  destination_type text not null
    check (destination_type in ('official_place', 'custom_home', 'custom_location', 'map_pin')),
  address text not null,
  latitude double precision not null,
  longitude double precision not null,
  nearby_landmark text,
  customer_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- A user can only have one home / one work / one airport, but any number of
-- custom favorites - enforced so save_or_update_saved_place() can safely
-- upsert on (user_id, label) for the fixed labels.
create unique index if not exists saved_places_unique_fixed_label_idx
  on public.saved_places (user_id, label)
  where label <> 'custom';

drop trigger if exists saved_places_set_updated_at on public.saved_places;
create trigger saved_places_set_updated_at
before update on public.saved_places
for each row execute function public.set_updated_at();
