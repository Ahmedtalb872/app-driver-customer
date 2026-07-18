-- Phase 2: private homes and unregistered locations. Never promoted into
-- public.places automatically, never readable by anyone but the owner
-- (see the RLS migration) - this is the whole point of splitting it out
-- from the public places table.

create table if not exists public.custom_destinations (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  district_id uuid not null references public.districts (id),
  address text not null,
  neighborhood_name text,
  street_name text,
  nearby_landmark text,
  customer_note text,
  latitude double precision not null,
  longitude double precision not null,
  destination_type text not null default 'custom_home'
    check (destination_type in ('custom_home', 'custom_location', 'map_pin')),
  is_saved boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists custom_destinations_set_updated_at on public.custom_destinations;
create trigger custom_destinations_set_updated_at
before update on public.custom_destinations
for each row execute function public.set_updated_at();
