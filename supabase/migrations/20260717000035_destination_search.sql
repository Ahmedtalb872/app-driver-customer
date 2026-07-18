-- Unified destination autocomplete for the admin dispatch screen. Before
-- this migration, only public.places had any text search (search_places,
-- 20260712000017_destinations_functions.sql) - districts and neighborhoods
-- had none. This adds one read-only, SECURITY DEFINER RPC that searches
-- across places (name + address, which is where free-text "street" detail
-- already lives - there is no separate street table) and district/
-- neighborhood names, so a single debounced text field can resolve any of
-- "place, address, district, neighborhood, street, landmark" (landmarks
-- are just places under a landmark-flavored category, already covered by
-- the places branch below).
--
-- Read-only and additive: no existing table, RLS policy, or function is
-- modified. Mirrors the exact stable/security definer/set search_path
-- hardening pattern already used by public.search_places.

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
