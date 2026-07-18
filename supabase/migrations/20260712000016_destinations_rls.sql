-- Phase 2: RLS for the destination-selection feature.
--
-- Reference data (districts/neighborhoods/place_categories/places):
--   - authenticated users can read active rows
--   - public.is_admin() (from Phase 1, security definer over profiles - see
--     20260712000006_rls_policies.sql) can additionally read inactive rows
--     and is the only role allowed to insert/update. There is no delete
--     policy anywhere - the workflow is "deactivate", never "delete".
--   - is_admin() does not itself read a table protected by these policies,
--     so none of this is recursive.
--
-- Private data (saved_places/recent_places/custom_destinations):
--   - strictly owner-only (auth.uid() = user_id) for every operation,
--     including select - a private home must never be readable by anyone
--     else, admins included, per the Phase 2 spec.

alter table public.districts enable row level security;
alter table public.neighborhoods enable row level security;
alter table public.place_categories enable row level security;
alter table public.places enable row level security;
alter table public.saved_places enable row level security;
alter table public.recent_places enable row level security;
alter table public.custom_destinations enable row level security;

-- districts
drop policy if exists "Districts are readable when active or by admin" on public.districts;
create policy "Districts are readable when active or by admin"
  on public.districts for select
  to authenticated
  using (is_active or public.is_admin());

drop policy if exists "Districts are insertable by admin" on public.districts;
create policy "Districts are insertable by admin"
  on public.districts for insert
  to authenticated
  with check (public.is_admin());

drop policy if exists "Districts are updatable by admin" on public.districts;
create policy "Districts are updatable by admin"
  on public.districts for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- neighborhoods
drop policy if exists "Neighborhoods are readable when active or by admin" on public.neighborhoods;
create policy "Neighborhoods are readable when active or by admin"
  on public.neighborhoods for select
  to authenticated
  using (is_active or public.is_admin());

drop policy if exists "Neighborhoods are insertable by admin" on public.neighborhoods;
create policy "Neighborhoods are insertable by admin"
  on public.neighborhoods for insert
  to authenticated
  with check (public.is_admin());

drop policy if exists "Neighborhoods are updatable by admin" on public.neighborhoods;
create policy "Neighborhoods are updatable by admin"
  on public.neighborhoods for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- place_categories
drop policy if exists "Categories are readable when active or by admin" on public.place_categories;
create policy "Categories are readable when active or by admin"
  on public.place_categories for select
  to authenticated
  using (is_active or public.is_admin());

drop policy if exists "Categories are insertable by admin" on public.place_categories;
create policy "Categories are insertable by admin"
  on public.place_categories for insert
  to authenticated
  with check (public.is_admin());

drop policy if exists "Categories are updatable by admin" on public.place_categories;
create policy "Categories are updatable by admin"
  on public.place_categories for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- places (regular users can only ever read; verifying/creating/editing is admin-only)
drop policy if exists "Places are readable when active or by admin" on public.places;
create policy "Places are readable when active or by admin"
  on public.places for select
  to authenticated
  using (is_active or public.is_admin());

drop policy if exists "Places are insertable by admin" on public.places;
create policy "Places are insertable by admin"
  on public.places for insert
  to authenticated
  with check (public.is_admin());

drop policy if exists "Places are updatable by admin" on public.places;
create policy "Places are updatable by admin"
  on public.places for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- saved_places (strictly owner-only)
drop policy if exists "Saved places are owner-only" on public.saved_places;
create policy "Saved places are owner-only"
  on public.saved_places for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- recent_places (strictly owner-only)
drop policy if exists "Recent places are owner-only" on public.recent_places;
create policy "Recent places are owner-only"
  on public.recent_places for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- custom_destinations (strictly owner-only - never admin, never other users)
drop policy if exists "Custom destinations are owner-only" on public.custom_destinations;
create policy "Custom destinations are owner-only"
  on public.custom_destinations for all
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
