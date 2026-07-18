-- Phase 2: lookup/filter indexes for the destination-selection feature, plus
-- a functional unique index that prevents obvious duplicate official places
-- (same district + normalized name + ~11m-precision coordinates).
--
-- pg_trgm note: enabling it requires superuser/owner privileges on some
-- managed Postgres hosts. On Supabase it is available as a standard
-- extension and `create extension if not exists` succeeds for the
-- `postgres` role used by migrations. If it is ever unavailable in a given
-- environment, this block is written so the trigram indexes are simply
-- skipped (via the `has_pg_trgm` check) and search still works correctly,
-- just via the plain `ilike` matching already used in search_places() -
-- only fuzzy/typo-tolerant ranking is lost, not functionality.

create index if not exists districts_code_idx on public.districts (code);
create index if not exists districts_is_active_idx on public.districts (is_active);

create index if not exists neighborhoods_district_id_idx on public.neighborhoods (district_id);
create index if not exists neighborhoods_is_active_idx on public.neighborhoods (is_active);

create index if not exists places_district_id_idx on public.places (district_id);
create index if not exists places_neighborhood_id_idx on public.places (neighborhood_id);
create index if not exists places_category_id_idx on public.places (category_id);
create index if not exists places_is_popular_idx on public.places (is_popular);
create index if not exists places_is_verified_idx on public.places (is_verified);
create index if not exists places_is_active_idx on public.places (is_active);
create index if not exists places_name_ar_idx on public.places (name_ar);
create index if not exists places_name_fr_idx on public.places (name_fr);

-- Practical duplicate guard for official places: same district, same
-- normalized Arabic name, coordinates rounded to ~11m precision.
create unique index if not exists places_dedupe_idx
  on public.places (district_id, lower(btrim(name_ar)), round(latitude::numeric, 4), round(longitude::numeric, 4));

create index if not exists saved_places_user_id_idx on public.saved_places (user_id);

create index if not exists recent_places_user_id_idx on public.recent_places (user_id);
create index if not exists recent_places_last_used_at_idx on public.recent_places (last_used_at);

create index if not exists custom_destinations_user_id_idx on public.custom_destinations (user_id);
create index if not exists custom_destinations_district_id_idx on public.custom_destinations (district_id);

-- Neighborhood name de-dupe within a district, used by the seed file's
-- ON CONFLICT clause to stay idempotent.
create unique index if not exists neighborhoods_dedupe_idx
  on public.neighborhoods (district_id, lower(btrim(name_ar)));

do $$
declare
  has_pg_trgm boolean;
begin
  begin
    create extension if not exists pg_trgm;
    has_pg_trgm := true;
  exception when insufficient_privilege then
    has_pg_trgm := false;
  end;

  if has_pg_trgm then
    execute 'create index if not exists places_name_ar_trgm_idx on public.places using gin (name_ar gin_trgm_ops)';
    execute 'create index if not exists places_name_fr_trgm_idx on public.places using gin (name_fr gin_trgm_ops)';
    execute 'create index if not exists places_address_ar_trgm_idx on public.places using gin (address_ar gin_trgm_ops)';
    execute 'create index if not exists places_address_fr_trgm_idx on public.places using gin (address_fr gin_trgm_ops)';
  end if;
end $$;
