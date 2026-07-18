-- Enables Supabase Realtime (logical replication) for the tables that
-- `.stream()` subscribers depend on: the captain app's incoming-ride-request
-- feed (RideRepository.watchIncomingRequests/watchTrip) and the admin
-- dashboard's Live Operations feed (AdminTripsRepository.watchActiveTrips,
-- AdminCaptainsRepository.watchOnlineCaptains). The `supabase_realtime`
-- publication exists by default but starts with zero tables attached, so
-- without this, those subscriptions receive only their initial snapshot and
-- never see subsequent changes.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'trips'
  ) then
    alter publication supabase_realtime add table public.trips;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'captains'
  ) then
    alter publication supabase_realtime add table public.captains;
  end if;
end $$;
