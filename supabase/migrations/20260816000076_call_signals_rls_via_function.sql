-- The call_signals table + .stream() rebuild (20260816000075) still isn't
-- delivering offers to the other side - call never rings. The remaining
-- difference from the proven-working `trips` realtime policies (simple
-- direct-column comparisons, no join) is that call_signals' select/insert
-- policies use an `exists (select 1 from public.trips t where ...)`
-- subquery joining a different table. Supabase Realtime evaluates
-- postgres_changes RLS through its own internal connection, and is known
-- to unreliably (or silently) fail authorization checks that join to
-- another table from inside the policy - the fix is to move that check
-- into a security definer function instead, exactly like public.is_admin()
-- already does elsewhere in this project (20260712000006_rls_policies.sql).
-- A security definer function runs as the function owner (bypassing RLS
-- on the table it reads internally) and is evaluated as a single self-
-- contained call rather than a join, which Realtime's authorization path
-- handles correctly.
create or replace function public.is_trip_participant(p_trip_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.trips t
    where t.id = p_trip_id
      and (t.customer_id = auth.uid() or t.captain_id = auth.uid())
  );
$$;

drop policy if exists "trip participants can read call signals" on public.call_signals;
create policy "trip participants can read call signals"
on public.call_signals for select
to authenticated
using (public.is_trip_participant(trip_id));

drop policy if exists "trip participants can send call signals" on public.call_signals;
create policy "trip participants can send call signals"
on public.call_signals for insert
to authenticated
with check (public.is_trip_participant(trip_id));
