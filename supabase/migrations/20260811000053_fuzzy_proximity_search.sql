-- Widens search_destinations (20260717000035_destination_search.sql,
-- bounded to Nouakchott by 20260809000052_nouakchott_bounds_search.sql)
-- with the two changes that most affect whether a typed or voice search
-- actually finds the place someone meant:
--
--   1. Arabic text normalization + trigram similarity (pg_trgm, already
--      enabled and indexed on public.places by
--      20260712000015_destinations_indexes.sql, but never actually used by
--      any search function until now) - so "تفرغ زينه" still finds "تفرغ
--      زينة", a dropped/extra diacritic or hamza variant doesn't fail a
--      match, and a misheard word from voice search still surfaces the
--      intended place via similarity ranking instead of "no results".
--   2. Optional proximity ordering (p_near_lat/p_near_lng, both default
--      null so every existing caller is unaffected) - when the caller
--      passes the customer's current location, results are ordered by
--      actual distance from it ahead of popularity, the same way every
--      major ride-hailing app ranks "closest first" once text relevance is
--      roughly equal. A flat-earth squared-distance is enough for ORDER BY
--      purposes over an area as small as Nouakchott - no need for
--      PostGIS/earthdistance just to rank, not measure, results.

create extension if not exists pg_trgm;

-- Deterministic Arabic text normalization shared by every search
-- comparison below: lowercases, strips diacritics/tatweel, and unifies
-- hamza (أ/إ/آ/ٱ -> ا), alef maksura (ى -> ي), and ta marbuta (ة -> ه) so
-- common spelling variants of the same word compare equal.
create or replace function public.normalize_arabic_text(input text)
returns text
language sql
immutable
as $$
  select translate(
    regexp_replace(lower(btrim(coalesce(input, ''))), '[ًٌٍَُِّْٰـ]', '', 'g'),
    'أإآٱىة',
    'اااايه'
  );
$$;

create or replace function public.search_destinations(
  p_query text,
  p_limit integer default 15,
  p_near_lat double precision default null,
  p_near_lng double precision default null
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
      (p.name_ar ilike p_query || '%' or p.name_fr ilike p_query || '%') as is_prefix,
      greatest(
        similarity(public.normalize_arabic_text(p.name_ar), public.normalize_arabic_text(p_query)),
        similarity(public.normalize_arabic_text(p.name_fr), public.normalize_arabic_text(p_query)),
        similarity(public.normalize_arabic_text(p.address_ar), public.normalize_arabic_text(p_query))
      ) as sim_score,
      case when p_near_lat is not null and p_near_lng is not null
        then (p.latitude - p_near_lat) ^ 2 + (p.longitude - p_near_lng) ^ 2
      end as dist_sq
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
        p.address_fr ilike '%' || p_query || '%' or
        public.normalize_arabic_text(p.name_ar) ilike '%' || public.normalize_arabic_text(p_query) || '%' or
        public.normalize_arabic_text(p.name_fr) ilike '%' || public.normalize_arabic_text(p_query) || '%' or
        similarity(public.normalize_arabic_text(p.name_ar), public.normalize_arabic_text(p_query)) > 0.25 or
        similarity(public.normalize_arabic_text(p.name_fr), public.normalize_arabic_text(p_query)) > 0.25
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
      (d.name_ar ilike p_query || '%' or d.name_fr ilike p_query || '%'),
      greatest(
        similarity(public.normalize_arabic_text(d.name_ar), public.normalize_arabic_text(p_query)),
        similarity(public.normalize_arabic_text(d.name_fr), public.normalize_arabic_text(p_query))
      ),
      case when p_near_lat is not null and p_near_lng is not null
        and d.latitude is not null and d.longitude is not null
        then (d.latitude - p_near_lat) ^ 2 + (d.longitude - p_near_lng) ^ 2
      end
    from public.districts d
    where d.is_active = true
      and (d.latitude is null or d.latitude between 17.90 and 18.30)
      and (d.longitude is null or d.longitude between -16.20 and -15.75)
      and btrim(coalesce(p_query, '')) <> ''
      and (
        d.name_ar ilike '%' || p_query || '%' or
        d.name_fr ilike '%' || p_query || '%' or
        public.normalize_arabic_text(d.name_ar) ilike '%' || public.normalize_arabic_text(p_query) || '%' or
        public.normalize_arabic_text(d.name_fr) ilike '%' || public.normalize_arabic_text(p_query) || '%' or
        similarity(public.normalize_arabic_text(d.name_ar), public.normalize_arabic_text(p_query)) > 0.25 or
        similarity(public.normalize_arabic_text(d.name_fr), public.normalize_arabic_text(p_query)) > 0.25
      )

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
      (n.name_ar ilike p_query || '%' or n.name_fr ilike p_query || '%'),
      greatest(
        similarity(public.normalize_arabic_text(n.name_ar), public.normalize_arabic_text(p_query)),
        similarity(public.normalize_arabic_text(n.name_fr), public.normalize_arabic_text(p_query))
      ),
      case when p_near_lat is not null and p_near_lng is not null
        and n.latitude is not null and n.longitude is not null
        then (n.latitude - p_near_lat) ^ 2 + (n.longitude - p_near_lng) ^ 2
      end
    from public.neighborhoods n
    left join public.districts pd on pd.id = n.district_id
    where n.is_active = true
      and (n.latitude is null or n.latitude between 17.90 and 18.30)
      and (n.longitude is null or n.longitude between -16.20 and -15.75)
      and btrim(coalesce(p_query, '')) <> ''
      and (
        n.name_ar ilike '%' || p_query || '%' or
        n.name_fr ilike '%' || p_query || '%' or
        public.normalize_arabic_text(n.name_ar) ilike '%' || public.normalize_arabic_text(p_query) || '%' or
        public.normalize_arabic_text(n.name_fr) ilike '%' || public.normalize_arabic_text(p_query) || '%' or
        similarity(public.normalize_arabic_text(n.name_ar), public.normalize_arabic_text(p_query)) > 0.25 or
        similarity(public.normalize_arabic_text(n.name_fr), public.normalize_arabic_text(p_query)) > 0.25
      )
  )
  select
    result_type, id, title, subtitle, district_id, category_code,
    is_verified, is_popular, latitude, longitude
  from matches
  order by
    is_exact desc,
    is_prefix desc,
    sim_score desc,
    dist_sq asc nulls last,
    is_popular desc,
    is_verified desc,
    title asc
  limit greatest(p_limit, 0);
$$;
