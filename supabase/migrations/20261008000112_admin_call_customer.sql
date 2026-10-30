-- Requested: let an admin start a voice call with a customer about a
-- specific ride request directly from the admin dashboard (operator
-- support during an active request), not just customer<->captain calls.
-- Reuses the exact same signaling mechanism (call_signals,
-- CallSignalingService/CallService) rather than building a parallel
-- system - just widens from_role to accept 'admin' and lets any admin
-- read/send signals for any trip (a regular customer/captain still only
-- ever sees their own trip's signals, via is_trip_participant()).

alter table public.call_signals
  drop constraint if exists call_signals_from_role_check;
alter table public.call_signals
  add constraint call_signals_from_role_check
  check (from_role in ('customer', 'captain', 'admin'));

drop policy if exists "trip participants can read call signals" on public.call_signals;
create policy "trip participants can read call signals"
on public.call_signals for select
to authenticated
using (public.is_trip_participant(trip_id) or public.is_admin());

drop policy if exists "trip participants can send call signals" on public.call_signals;
create policy "trip participants can send call signals"
on public.call_signals for insert
to authenticated
with check (public.is_trip_participant(trip_id) or public.is_admin());
