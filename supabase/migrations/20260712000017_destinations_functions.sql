-- Phase 2: secure PostgreSQL functions backing the destination-selection
-- feature. Every function that touches a table sets `search_path = public`
-- so a search_path hijack can't redirect it to an attacker-controlled
-- object (standard Supabase SECURITY DEFINER hardening, matching the
-- pattern already used by public.is_admin() in Phase 1).

-- 1. Coordinate validation, reused by the write functions below.
create or replace function public.validate_lat_lng(
  p_latitude double precision,
  p_longitude double precision
)
returns boolean
language sql
immutable
as $$
  select p_latitude is not null and p_longitude is not null
     and p_latitude between -90 and 90
     and p_longitude between -180 and 180;
$$;

-- 2. Ownership check for a custom (private) destination.
create or replace function public.is_custom_destination_owner(p_destination_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.custom_destinations
    where id = p_destination_id and user_id = auth.uid()
  );
$$;

-- 3. Active places in a district/category, popular first - powers the
-- "registered place list" screen.
create or replace function public.get_places_by_district_category(
  p_district_id uuid,
  p_category_id uuid,
  p_limit integer default 50,
  p_offset integer default 0
)
returns setof public.places
language sql
stable
security definer
set search_path = public
as $$
  select *
  from public.places
  where district_id = p_district_id
    and category_id = p_category_id
    and is_active = true
  order by is_popular desc, name_ar asc
  limit greatest(p_limit, 0)
  offset greatest(p_offset, 0);
$$;

-- 4. Popular places in a district (any category) - used for "saved/recent"
-- style suggestions and category-screen highlights.
create or replace function public.get_popular_places_by_district(
  p_district_id uuid,
  p_limit integer default 10
)
returns setof public.places
language sql
stable
security definer
set search_path = public
as $$
  select *
  from public.places
  where district_id = p_district_id
    and is_active = true
    and is_popular = true
  order by name_ar asc
  limit greatest(p_limit, 0);
$$;

-- 5. Count of active places per category within a district - powers the
-- "N places available" badge on the category grid.
create or replace function public.get_category_place_counts(p_district_id uuid)
returns table (category_id uuid, place_count bigint)
language sql
stable
security definer
set search_path = public
as $$
  select category_id, count(*) as place_count
  from public.places
  where district_id = p_district_id
    and is_active = true
  group by category_id;
$$;

-- 6. Place search: Arabic/French name + address, exact/prefix/popular/
-- district-priority ranking, with category filter and pagination.
create or replace function public.search_places(
  p_query text,
  p_district_id uuid default null,
  p_category_id uuid default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns setof public.places
language sql
stable
security definer
set search_path = public
as $$
  select p.*
  from public.places p
  where p.is_active = true
    and (p_district_id is null or p.district_id = p_district_id)
    and (p_category_id is null or p.category_id = p_category_id)
    and (
      p_query is null or btrim(p_query) = '' or
      p.name_ar ilike '%' || p_query || '%' or
      p.name_fr ilike '%' || p_query || '%' or
      p.address_ar ilike '%' || p_query || '%' or
      p.address_fr ilike '%' || p_query || '%'
    )
  order by
    -- exact name match first
    (p.name_ar = p_query or p.name_fr = p_query) desc,
    -- then prefix match
    (p.name_ar ilike p_query || '%' or p.name_fr ilike p_query || '%') desc,
    -- then the caller's currently-selected district
    (p_district_id is not null and p.district_id = p_district_id) desc,
    -- then popular places
    p.is_popular desc,
    p.name_ar asc
  limit greatest(p_limit, 0)
  offset greatest(p_offset, 0);
$$;

-- 7. Record (or bump the usage count of) a recent destination for the
-- current user. Dedupes on place_id when the destination is an official
-- place, otherwise on rounded coordinates (~1m precision) for custom pins,
-- so repeatedly picking "the same spot" never creates duplicate rows.
create or replace function public.record_recent_destination(
  p_destination_type text,
  p_address text,
  p_latitude double precision,
  p_longitude double precision,
  p_place_id uuid default null,
  p_district_id uuid default null,
  p_nearby_landmark text default null,
  p_customer_note text default null
)
returns public.recent_places
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_row public.recent_places;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;
  if not public.validate_lat_lng(p_latitude, p_longitude) then
    raise exception 'Invalid coordinates';
  end if;

  if p_place_id is not null then
    update public.recent_places
      set usage_count = usage_count + 1,
          last_used_at = now(),
          address = p_address,
          district_id = coalesce(p_district_id, district_id),
          nearby_landmark = p_nearby_landmark,
          customer_note = p_customer_note
      where user_id = v_user_id and place_id = p_place_id
      returning * into v_row;
  else
    update public.recent_places
      set usage_count = usage_count + 1,
          last_used_at = now(),
          address = p_address,
          nearby_landmark = p_nearby_landmark,
          customer_note = p_customer_note
      where user_id = v_user_id
        and place_id is null
        and round(latitude::numeric, 5) = round(p_latitude::numeric, 5)
        and round(longitude::numeric, 5) = round(p_longitude::numeric, 5)
      returning * into v_row;
  end if;

  if not found then
    insert into public.recent_places (
      user_id, place_id, district_id, destination_type, address,
      latitude, longitude, nearby_landmark, customer_note
    ) values (
      v_user_id, p_place_id, p_district_id, p_destination_type, p_address,
      p_latitude, p_longitude, p_nearby_landmark, p_customer_note
    ) returning * into v_row;
  end if;

  return v_row;
end;
$$;

-- 8. Save (or update) one of the current user's saved places. For the
-- fixed labels (home/work/airport) this upserts the single row for that
-- label; 'custom' always inserts a new favorite.
create or replace function public.save_or_update_saved_place(
  p_label text,
  p_destination_type text,
  p_address text,
  p_latitude double precision,
  p_longitude double precision,
  p_custom_label text default null,
  p_place_id uuid default null,
  p_district_id uuid default null,
  p_nearby_landmark text default null,
  p_customer_note text default null
)
returns public.saved_places
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_row public.saved_places;
begin
  if v_user_id is null then
    raise exception 'Not authenticated';
  end if;
  if p_label not in ('home', 'work', 'airport', 'custom') then
    raise exception 'Invalid label: %', p_label;
  end if;
  if not public.validate_lat_lng(p_latitude, p_longitude) then
    raise exception 'Invalid coordinates';
  end if;

  if p_label <> 'custom' then
    update public.saved_places
      set custom_label = p_custom_label,
          place_id = p_place_id,
          district_id = p_district_id,
          destination_type = p_destination_type,
          address = p_address,
          latitude = p_latitude,
          longitude = p_longitude,
          nearby_landmark = p_nearby_landmark,
          customer_note = p_customer_note
      where user_id = v_user_id and label = p_label
      returning * into v_row;

    if found then
      return v_row;
    end if;
  end if;

  insert into public.saved_places (
    user_id, label, custom_label, place_id, district_id, destination_type,
    address, latitude, longitude, nearby_landmark, customer_note
  ) values (
    v_user_id, p_label, p_custom_label, p_place_id, p_district_id, p_destination_type,
    p_address, p_latitude, p_longitude, p_nearby_landmark, p_customer_note
  ) returning * into v_row;

  return v_row;
end;
$$;
