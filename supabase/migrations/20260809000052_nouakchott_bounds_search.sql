-- Scope the customer app's text/voice destination search to Nouakchott
-- only. search_destinations (20260717000035_destination_search.sql)
-- matches purely on name/address text, with no geographic guard - the
-- seed data (destinations_seed.sql) happens to be Nouakchott-only today,
-- but nothing stops a place added later through the admin dashboard
-- (places_repository.dart's insertPlace, likewise districts/
-- neighborhoods) from getting a mistyped or out-of-country latitude/
-- longitude and then still surfacing in every customer's search results
-- since the RPC never checked location, only text.
--
-- Bounds are a generous box around Nouakchott (city center roughly
-- 18.08 N, -15.98 W) - wide enough to comfortably cover the whole urban
-- area and its outskirts (all seed coordinates fall well inside), tight
-- enough to reject gross errors like a flipped-sign longitude or a place
-- entered in a different city/country entirely.
--
-- Applied in two places:
--   1. search_destinations itself, so it's the search behavior fixes
--      immediately regardless of what's already in the tables.
--   2. NOT VALID check constraints on districts/neighborhoods/places, so
--      new/updated rows going forward can't violate the bounds either.
--      NOT VALID skips checking existing rows at migration time (so this
--      can't fail if some row already happens to be outside the box) -
--      only inserts/updates from here on are enforced.

create or replace function public.search_destinations(
  p_query text,
  p_limit integer default 15
)
returns table (
  result_type text,
  id uuid,
  title text,
  subtitle text,
  district_id uuid,
  category_code text,
  is_verified boolean,
  is_popular boolean,
  latitude double precision,
  longitude double precision
)
language sql
stable
security definer
set search_path = public
as $$
  with matches as (
    select
      'place'::text as result_type,
      p.id,
      coalesce(p.name_ar, p.name_fr) as title,
      coalesce(p.address_ar, p.address_fr, d.name_ar) as subtitle,
      p.district_id,
      pc.code as category_code,
      p.is_verified,
      p.is_popular,
      p.latitude,
      p.longitude,
      (p.name_ar = p_query or p.name_fr = p_query) as is_exact,
      (p.name_ar ilike p_query || '%' or p.name_fr ilike p_query || '%') as is_prefix
    from public.places p
    join public.place_categories pc on pc.id = p.category_id
    left join public.districts d on d.id = p.district_id
    where p.is_active = true
      and p.latitude between 17.90 and 18.30
      and p.longitude between -16.20 and -15.75
      and (
        btrim(coalesce(p_query, '')) = '' or
        p.name_ar ilike '%' || p_query || '%' or
        p.name_fr ilike '%' || p_query || '%' or
        p.address_ar ilike '%' || p_query || '%' or
        p.address_fr ilike '%' || p_query || '%'
      )

    union all

    select
      'district'::text,
      d.id,
      d.name_ar,
      d.name_fr,
      d.id,
      null::text,
      false,
      false,
      d.latitude,
      d.longitude,
      (d.name_ar = p_query or d.name_fr = p_query),
      (d.name_ar ilike p_query || '%' or d.name_fr ilike p_query || '%')
    from public.districts d
    where d.is_active = true
      and (d.latitude is null or d.latitude between 17.90 and 18.30)
      and (d.longitude is null or d.longitude between -16.20 and -15.75)
      and btrim(coalesce(p_query, '')) <> ''
      and (d.name_ar ilike '%' || p_query || '%' or d.name_fr ilike '%' || p_query || '%')

    union all

    select
      'neighborhood'::text,
      n.id,
      n.name_ar,
      coalesce(pd.name_ar, ''),
      n.district_id,
      null::text,
      false,
      false,
      n.latitude,
      n.longitude,
      (n.name_ar = p_query or n.name_fr = p_query),
      (n.name_ar ilike p_query || '%' or n.name_fr ilike p_query || '%')
    from public.neighborhoods n
    left join public.districts pd on pd.id = n.district_id
    where n.is_active = true
      and (n.latitude is null or n.latitude between 17.90 and 18.30)
      and (n.longitude is null or n.longitude between -16.20 and -15.75)
      and btrim(coalesce(p_query, '')) <> ''
      and (n.name_ar ilike '%' || p_query || '%' or n.name_fr ilike '%' || p_query || '%')
  )
  select
    result_type, id, title, subtitle, district_id, category_code,
    is_verified, is_popular, latitude, longitude
  from matches
  order by
    is_exact desc,
    is_prefix desc,
    is_popular desc,
    is_verified desc,
    title asc
  limit greatest(p_limit, 0);
$$;

alter table public.places
  drop constraint if exists places_within_nouakchott,
  add constraint places_within_nouakchott
    check (latitude between 17.90 and 18.30 and longitude between -16.20 and -15.75)
    not valid;

alter table public.districts
  drop constraint if exists districts_within_nouakchott,
  add constraint districts_within_nouakchott
    check (
      (latitude is null or latitude between 17.90 and 18.30)
      and (longitude is null or longitude between -16.20 and -15.75)
    )
    not valid;

alter table public.neighborhoods
  drop constraint if exists neighborhoods_within_nouakchott,
  add constraint neighborhoods_within_nouakchott
    check (
      (latitude is null or latitude between 17.90 and 18.30)
      and (longitude is null or longitude between -16.20 and -15.75)
    )
    not valid;
