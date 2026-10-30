-- The in-app call still isn't connecting/ringing after the Realtime
-- Authorization RLS fix (20260815000072) - signaling was riding on plain
-- Realtime Broadcast (call_trip_<tripId> channel, no table behind it),
-- which this project has no other proven usage of to compare against.
-- watchTrip (RideRepository) already reliably pushes live trip updates via
-- the simplified `.from('trips').stream(...)` helper over a real table
-- with RLS - rebuilding signaling the same proven way instead of guessing
-- further at Broadcast's behavior.
create table if not exists public.call_signals (
  id bigint generated always as identity primary key,
  trip_id uuid not null references public.trips (id) on delete cascade,
  from_role text not null check (from_role in ('customer', 'captain')),
  type text not null check (type in ('offer', 'answer', 'ice', 'hangup')),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists call_signals_trip_id_idx on public.call_signals (trip_id);

alter table public.call_signals enable row level security;

-- Only the trip's own customer or captain can see/send its call signals.
drop policy if exists "trip participants can read call signals" on public.call_signals;
create policy "trip participants can read call signals"
on public.call_signals for select
to authenticated
using (
  exists (
    select 1 from public.trips t
    where t.id = trip_id
      and (t.customer_id = auth.uid() or t.captain_id = auth.uid())
  )
);

drop policy if exists "trip participants can send call signals" on public.call_signals;
create policy "trip participants can send call signals"
on public.call_signals for insert
to authenticated
with check (
  exists (
    select 1 from public.trips t
    where t.id = trip_id
      and (t.customer_id = auth.uid() or t.captain_id = auth.uid())
  )
);

-- Realtime only pushes changes for tables added to this publication -
-- `trips` already works (see watchTrip), so it's already in here, but a
-- brand new table needs adding explicitly.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'call_signals'
  ) then
    alter publication supabase_realtime add table public.call_signals;
  end if;
end $$;
