-- Finds the nearest registered neighborhood/district center to a point, so
-- a Google Places result (places-search Edge Function) whose own
-- formatted_address is just a Plus Code or "Unnamed Road" - common in
-- Nouakchott's less-mapped areas on Google's side - can still be labeled
-- with a real district/neighborhood name from this app's own registry.
--
-- Same flat-earth squared-distance approach 20260811000053's
-- search_destinations already uses for ORDER BY over an area this small -
-- no PostGIS/earthdistance needed just to find the closest of a few dozen
-- rows. Thresholds are in squared degrees (~111km/degree at this
-- latitude): 0.0004 =~ 2.2km for a neighborhood match, 0.0025 =~ 5.5km for
-- a district-only fallback when no neighborhood is close enough.
create or replace function public.nearest_place_area(
  p_lat double precision,
  p_lng double precision
)
returns table (
  district_name text,
  neighborhood_name text
)
language sql
stable
security definer
set search_path = public
as $$
  with nearest_neighborhood as (
    select
      d.name_ar as district_name,
      n.name_ar as neighborhood_name,
      (n.latitude - p_lat) ^ 2 + (n.longitude - p_lng) ^ 2 as dist_sq
    from public.neighborhoods n
    join public.districts d on d.id = n.district_id
    where n.is_active = true
      and n.latitude is not null
      and n.longitude is not null
    order by dist_sq asc
    limit 1
  ),
  nearest_district as (
    select
      name_ar as district_name,
      (latitude - p_lat) ^ 2 + (longitude - p_lng) ^ 2 as dist_sq
    from public.districts
    where is_active = true
      and latitude is not null
      and longitude is not null
    order by dist_sq asc
    limit 1
  )
  select
    case
      when (select dist_sq from nearest_neighborhood) < 0.0004
        then (select district_name from nearest_neighborhood)
      when (select dist_sq from nearest_district) < 0.0025
        then (select district_name from nearest_district)
      else null
    end as district_name,
    case
      when (select dist_sq from nearest_neighborhood) < 0.0004
        then (select neighborhood_name from nearest_neighborhood)
      else null
    end as neighborhood_name;
$$;
