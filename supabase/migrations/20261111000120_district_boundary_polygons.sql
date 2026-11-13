-- Fixes district labels that were wrong for points near a shared border -
-- reported as e.g. a point actually in Arafat getting labeled Toujounine,
-- and a point in Toujounine getting labeled Ksar. nearest_place_area()
-- (20260831000086) only ever compared a point against each district's
-- single centroid (latitude/longitude on public.districts) - for two
-- districts that share a long border, a point can easily sit closer to
-- the *other* district's centroid than to its own, especially right near
-- that shared edge (which is exactly the Arafat/Toujounine and
-- Toujounine/Ksar borders - see assets/geo/nouakchott_districts.geojson,
-- already bundled in the app but never actually read by any Dart or SQL
-- code until now).
--
-- This adds the real district boundary polygons (from that same geojson -
-- geoBoundaries MRT-ADM2, simplified) to public.districts and rewrites
-- nearest_place_area() to check real polygon containment first, falling
-- back to the old nearest-centroid guess only for a point that doesn't
-- fall inside any mapped district (e.g. well outside the city).
create extension if not exists postgis;

alter table public.districts
  add column if not exists boundary geometry(Polygon, 4326);

update public.districts set boundary = st_setsrid(st_geomfromgeojson('{"type":"Polygon","coordinates":[[[-15.94879999899996,18.029899999000065],[-15.9385,18.05660000100005],[-15.937100000999976,18.0616],[-15.9385,18.0623],[-15.935799998999983,18.071],[-15.9652,18.0791],[-15.97000000099996,18.068299999000033],[-15.9756,18.053400001000057],[-15.9724,18.039100001000065],[-15.973099998999942,18.0319],[-15.9647,18.0306],[-15.964500000999976,18.02920000100005],[-15.94879999899996,18.029899999000065]]]}'), 4326) where code = 'arafat';
update public.districts set boundary = st_setsrid(st_geomfromgeojson('{"type":"Polygon","coordinates":[[[-15.935799998999983,18.071],[-15.932700000999944,18.087300001000074],[-15.92139999899996,18.09830000100004],[-15.888800000999936,18.1416],[-15.9179,18.1414],[-15.9384,18.117000001000065],[-15.960999998999966,18.088],[-15.9652,18.0791],[-15.935799998999983,18.071]]]}'), 4326) where code = 'dar_naim';
update public.districts set boundary = st_setsrid(st_geomfromgeojson('{"type":"Polygon","coordinates":[[[-15.97000000099996,18.068299999000033],[-15.975500000999943,18.07090000100004],[-15.9746,18.077299999000047],[-15.977,18.0777],[-15.982100000999935,18.078400001000034],[-15.985099998999942,18.074100001000033],[-16.01129999899996,18.058],[-16.0439,18.050899999000023],[-16.0436,17.976],[-15.9724,17.976500001000034],[-15.97770000099996,18.008099999000024],[-15.973099998999942,18.0319],[-15.9724,18.039100001000065],[-15.9756,18.053400001000057],[-15.97000000099996,18.068299999000033]]]}'), 4326) where code = 'el_mina';
update public.districts set boundary = st_setsrid(st_geomfromgeojson('{"type":"Polygon","coordinates":[[[-15.9652,18.0791],[-15.960999998999966,18.088],[-15.9384,18.117000001000065],[-15.943700000999968,18.1209],[-15.944499998999959,18.11989999900004],[-15.9519,18.12340000100005],[-15.947000000999935,18.176899999000057],[-15.9965,18.1767],[-15.971899998999959,18.111099999000032],[-15.9714,18.1086],[-15.9748,18.1043],[-15.9756,18.10019999900004],[-15.9682,18.0988],[-15.97000000099996,18.0866],[-15.9749,18.08740000100005],[-15.977,18.0777],[-15.9746,18.077299999000047],[-15.975500000999943,18.07090000100004],[-15.97000000099996,18.068299999000033],[-15.9652,18.0791]]]}'), 4326) where code = 'ksar';
update public.districts set boundary = st_setsrid(st_geomfromgeojson('{"type":"Polygon","coordinates":[[[-15.973099998999942,18.0319],[-15.97770000099996,18.008099999000024],[-15.9724,17.976500001000034],[-15.887700000999928,17.9769],[-15.8882,18.030300001000057],[-15.94879999899996,18.029899999000065],[-15.964500000999976,18.02920000100005],[-15.9647,18.0306],[-15.973099998999942,18.0319]]]}'), 4326) where code = 'riadh';
update public.districts set boundary = st_setsrid(st_geomfromgeojson('{"type":"Polygon","coordinates":[[[-15.982100000999935,18.078400001000034],[-15.984999998999967,18.081499999000073],[-15.986300000999961,18.0867],[-15.99389999899995,18.0843],[-15.999199998999927,18.0845],[-16.0188,18.097200001000033],[-16.044299998999975,18.0996],[-16.0439,18.050899999000023],[-16.01129999899996,18.058],[-15.985099998999942,18.074100001000033],[-15.982100000999935,18.078400001000034]]]}'), 4326) where code = 'sebkha';
update public.districts set boundary = st_setsrid(st_geomfromgeojson('{"type":"Polygon","coordinates":[[[-15.977,18.0777],[-15.9749,18.08740000100005],[-15.97000000099996,18.0866],[-15.9682,18.0988],[-15.9756,18.10019999900004],[-15.9748,18.1043],[-15.9714,18.1086],[-15.971899998999959,18.111099999000032],[-15.9965,18.1767],[-16.0448,18.1764],[-16.044299998999975,18.0996],[-16.0188,18.097200001000033],[-15.999199998999927,18.0845],[-15.99389999899995,18.0843],[-15.986300000999961,18.0867],[-15.984999998999967,18.081499999000073],[-15.982100000999935,18.078400001000034],[-15.977,18.0777]]]}'), 4326) where code = 'tevragh_zeina';
update public.districts set boundary = st_setsrid(st_geomfromgeojson('{"type":"Polygon","coordinates":[[[-15.9179,18.1414],[-15.8934,18.177200001000074],[-15.947000000999935,18.176899999000057],[-15.9519,18.12340000100005],[-15.944499998999959,18.11989999900004],[-15.943700000999968,18.1209],[-15.9384,18.117000001000065],[-15.9179,18.1414]]]}'), 4326) where code = 'teyarett';
update public.districts set boundary = st_setsrid(st_geomfromgeojson('{"type":"Polygon","coordinates":[[[-15.94879999899996,18.029899999000065],[-15.8882,18.030300001000057],[-15.888800000999936,18.1416],[-15.92139999899996,18.09830000100004],[-15.932700000999944,18.087300001000074],[-15.935799998999983,18.071],[-15.9385,18.0623],[-15.937100000999976,18.0616],[-15.9385,18.05660000100005],[-15.94879999899996,18.029899999000065]]]}'), 4326) where code = 'toujounine';

create index if not exists districts_boundary_gist
  on public.districts using gist (boundary);

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
  with containing_district as (
    select d.id, d.name_ar as district_name
    from public.districts d
    where d.is_active = true
      and d.boundary is not null
      and st_contains(d.boundary, st_setsrid(st_makepoint(p_lng, p_lat), 4326))
    limit 1
  ),
  nearest_neighborhood as (
    select
      d.id as district_id,
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
  ),
  -- The real polygon is authoritative whenever the point falls inside one -
  -- beats any centroid-distance guess. Only a point outside every mapped
  -- district (no polygon contains it) falls back to the old nearest-
  -- centroid behaviour.
  resolved_district as (
    select coalesce(
      (select district_name from containing_district),
      (select district_name from nearest_district)
    ) as district_name
  )
  select
    (select district_name from resolved_district) as district_name,
    -- A neighborhood guess is only shown when it doesn't contradict the
    -- polygon-verified district - e.g. a neighborhood seeded under the
    -- wrong district (also a nearest-centroid guess, see
    -- 20260811000053/20260718000039 seed data) must not override a
    -- district the point is genuinely inside.
    case
      when (select dist_sq from nearest_neighborhood) < 0.0004
        and (select district_name from nearest_neighborhood)
          = (select district_name from resolved_district)
        then (select neighborhood_name from nearest_neighborhood)
      else null
    end as neighborhood_name;
$$;
