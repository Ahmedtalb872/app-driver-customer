-- Requested: after a trip ends, let the customer save the pickup/
-- destination as a labeled place (المنزل/العمل/المدرسة) so they don't have
-- to search for it again next time - see TripSummaryScreen and
-- saved_places_repository.dart.
create table if not exists public.saved_places (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references auth.users (id) on delete cascade,
  label text not null check (label in ('home', 'work', 'school')),
  address text not null,
  lat numeric not null,
  lng numeric not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- At most one "home"/"work"/"school" per customer - saving a new one
  -- overwrites the old (see SavedPlacesRepository.savePlace's upsert),
  -- same as every ride-hailing app's saved-places UX. A plain (non-
  -- partial) constraint, since every row's label is one of these three -
  -- needed as-is for upsert's ON CONFLICT target to work at all.
  unique (customer_id, label)
);

alter table public.saved_places enable row level security;

drop policy if exists "customers manage their own saved places" on public.saved_places;
create policy "customers manage their own saved places"
on public.saved_places for all
to authenticated
using (customer_id = auth.uid())
with check (customer_id = auth.uid());

drop trigger if exists saved_places_set_updated_at on public.saved_places;
create trigger saved_places_set_updated_at
before update on public.saved_places
for each row execute function public.set_updated_at();
