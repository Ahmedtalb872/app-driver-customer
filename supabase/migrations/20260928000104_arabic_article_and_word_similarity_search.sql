-- A very ordinary colloquial search ("المطار") was failing outright even
-- though the exact place is registered ("مطار نواكشوط أم تونسي الدولي"),
-- for two compounding reasons in search_destinations
-- (20260811000053_fuzzy_proximity_search.sql):
--   1. normalize_arabic_text never stripped the Arabic definite article
--      "ال", so "المطار" never became a substring of "مطار ..." for the
--      ILIKE checks.
--   2. Postgres trgm similarity() compares whole strings and penalizes a
--      short query matched against a much longer name - "المطار" (6
--      chars) against a 28-character official name scores far below the
--      0.25 threshold even when it's obviously the same place.
-- word_similarity() exists exactly for case 2 (best match of the query as
-- a fragment of the longer name, not penalized by the name's extra
-- length), added here alongside the existing similarity() rather than
-- replacing it, so ranking still prefers a closer overall match when one
-- exists.
create or replace function public.normalize_arabic_text(input text)
returns text
language sql
immutable
as $$
  select regexp_replace(
    translate(
      regexp_replace(lower(btrim(coalesce(input, ''))), '[ًٌٍَُِّْٰـ]', '', 'g'),
      'أإآٱىة',
      'اااايه'
    ),
    '^ال',
    ''
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
        similarity(public.normalize_arabic_text(p.address_ar), public.normalize_arabic_text(p_query)),
        word_similarity(public.normalize_arabic_text(p_query), public.normalize_arabic_text(p.name_ar)),
        word_similarity(public.normalize_arabic_text(p_query), public.normalize_arabic_text(p.name_fr))
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
        similarity(public.normalize_arabic_text(p.name_fr), public.normalize_arabic_text(p_query)) > 0.25 or
        word_similarity(public.normalize_arabic_text(p_query), public.normalize_arabic_text(p.name_ar)) > 0.4 or
        word_similarity(public.normalize_arabic_text(p_query), public.normalize_arabic_text(p.name_fr)) > 0.4
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
        similarity(public.normalize_arabic_text(d.name_fr), public.normalize_arabic_text(p_query)),
        word_similarity(public.normalize_arabic_text(p_query), public.normalize_arabic_text(d.name_ar)),
        word_similarity(public.normalize_arabic_text(p_query), public.normalize_arabic_text(d.name_fr))
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
        similarity(public.normalize_arabic_text(d.name_fr), public.normalize_arabic_text(p_query)) > 0.25 or
        word_similarity(public.normalize_arabic_text(p_query), public.normalize_arabic_text(d.name_ar)) > 0.4 or
        word_similarity(public.normalize_arabic_text(p_query), public.normalize_arabic_text(d.name_fr)) > 0.4
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
        similarity(public.normalize_arabic_text(n.name_fr), public.normalize_arabic_text(p_query)),
        word_similarity(public.normalize_arabic_text(p_query), public.normalize_arabic_text(n.name_ar)),
        word_similarity(public.normalize_arabic_text(p_query), public.normalize_arabic_text(n.name_fr))
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
        similarity(public.normalize_arabic_text(n.name_fr), public.normalize_arabic_text(p_query)) > 0.25 or
        word_similarity(public.normalize_arabic_text(p_query), public.normalize_arabic_text(n.name_ar)) > 0.4 or
        word_similarity(public.normalize_arabic_text(p_query), public.normalize_arabic_text(n.name_fr)) > 0.4
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
