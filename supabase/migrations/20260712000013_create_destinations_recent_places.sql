-- Phase 2: a user's recently used destinations, with a usage counter so the
-- most-used ones can be surfaced. Fully private.

create table if not exists public.recent_places (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  place_id uuid references public.places (id) on delete set null,
  district_id uuid references public.districts (id) on delete set null,
  destination_type text not null
    check (destination_type in ('official_place', 'custom_home', 'custom_location', 'map_pin')),
  address text not null,
  latitude double precision not null,
  longitude double precision not null,
  nearby_landmark text,
  customer_note text,
  last_used_at timestamptz not null default now(),
  usage_count integer not null default 1
);

-- One row per (user, place) so re-selecting an official place increments
-- usage_count instead of creating a duplicate row (see record_recent_destination()).
create unique index if not exists recent_places_unique_place_idx
  on public.recent_places (user_id, place_id)
  where place_id is not null;
