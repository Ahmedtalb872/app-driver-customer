-- Persisted answer to "which captains actually saw this request, and what
-- happened with each of them" - the admin dashboard's "كم كابتن يراها"
-- button (added just before this migration) could only ever report a
-- *live* count of currently-eligible captains, because nothing recorded
-- who was eligible at the moment a request actually went out. This adds
-- that record.
--
-- Still not a literal "captain's screen rendered this card" event - no
-- such event exists anywhere (the captain app isn't instrumented for it,
-- and doing so is out of this repo's scope). What this captures instead is
-- exactly who was eligible to receive the request the instant it was
-- created, which mirrors trips' own "Open trip requests are visible to
-- active captains" RLS policy (20260801000046_delivery_service.sql) -
-- i.e. the same set of captains whose apps would actually have shown it.

create table if not exists public.trip_captain_offers (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid not null references public.trips(id) on delete cascade,
  captain_id uuid not null references public.captains(id) on delete cascade,
  status text not null default 'offered'
    check (status in ('offered', 'accepted', 'missed')),
  offered_at timestamptz not null default now(),
  responded_at timestamptz,
  unique (trip_id, captain_id)
);

create index if not exists trip_captain_offers_trip_idx
  on public.trip_captain_offers (trip_id);
create index if not exists trip_captain_offers_captain_idx
  on public.trip_captain_offers (captain_id);

alter table public.trip_captain_offers enable row level security;

create policy "Admins can read trip captain offers"
  on public.trip_captain_offers for select
  to authenticated
  using (public.is_admin());

create policy "A captain can read their own trip offers"
  on public.trip_captain_offers for select
  to authenticated
  using (captain_id = auth.uid());

-- Snapshots every currently-eligible captain the moment a request is
-- created. Runs as the inserting customer (security invoker, not
-- definer) would fail RLS trying to read every captains row, so this is
-- security definer like every other cross-table helper in this project.
create or replace function public.snapshot_trip_captain_offers()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'searching' then
    insert into public.trip_captain_offers (trip_id, captain_id, status, offered_at)
    select new.id, c.id, 'offered', now()
    from public.captains c
    where c.status = 'approved'
      and c.is_online = true
      and (
        new.service_type = 'ride'
        or (new.service_type = 'delivery' and c.vehicle_type = 'motorcycle' and c.accepts_delivery)
      )
    on conflict (trip_id, captain_id) do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists trips_snapshot_captain_offers on public.trips;
create trigger trips_snapshot_captain_offers
  after insert on public.trips
  for each row execute function public.snapshot_trip_captain_offers();

-- Resolves every offer once the request leaves 'searching': whichever
-- captain ended up with the trip (however it happened - their own accept,
-- or an admin assigning it) is marked 'accepted'; every other captain who
-- was offered it and never acted is marked 'missed'.
create or replace function public.resolve_trip_captain_offers()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status = 'searching' and new.status is distinct from 'searching' then
    if new.captain_id is not null then
      update public.trip_captain_offers
        set status = 'accepted', responded_at = now()
        where trip_id = new.id and captain_id = new.captain_id;
    end if;
    update public.trip_captain_offers
      set status = 'missed', responded_at = now()
      where trip_id = new.id
        and status = 'offered'
        and (new.captain_id is null or captain_id <> new.captain_id);
  end if;
  return new;
end;
$$;

drop trigger if exists trips_resolve_captain_offers on public.trips;
create trigger trips_resolve_captain_offers
  after update on public.trips
  for each row execute function public.resolve_trip_captain_offers();
