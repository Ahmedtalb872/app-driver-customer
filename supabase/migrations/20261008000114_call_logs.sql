-- Requested: a reviewable record of every in-app voice call (who called
-- whom, whether it was answered, how long it lasted) - call_signals itself
-- is the wrong place to read this from (it's raw WebRTC signaling rows -
-- offer/answer/ICE/hangup - with no single row representing "one call" or
-- its outcome). This is a separate, much smaller table: one row per call
-- attempt, written by CallScreen at the few points that already know the
-- outcome (see call_screen.dart's CallLogService usage).

create table if not exists public.call_logs (
  id bigint generated always as identity primary key,
  trip_id uuid not null references public.trips (id) on delete cascade,
  caller_role text not null check (caller_role in ('customer', 'captain', 'admin')),
  callee_role text not null check (callee_role in ('customer', 'captain', 'admin')),
  started_at timestamptz not null default now(),
  answered_at timestamptz,
  ended_at timestamptz,
  -- 'ringing' is the transient state between insert and the call actually
  -- being decided one way or another - every row should end up in one of
  -- the other four, but isn't guaranteed to (e.g. the app was killed
  -- mid-call) rather than ever being cleaned up/guessed at after the fact.
  outcome text not null default 'ringing'
    check (outcome in ('ringing', 'answered', 'missed', 'declined', 'failed')),
  duration_seconds integer
);

create index if not exists call_logs_trip_id_idx on public.call_logs (trip_id);
create index if not exists call_logs_started_at_idx on public.call_logs (started_at desc);

alter table public.call_logs enable row level security;

-- Same participant-or-admin shape as call_signals itself
-- (20261008000112_admin_call_customer.sql) - a trip's own customer/captain
-- sees only their own calls, admin sees every call for review.
drop policy if exists "trip participants can read call logs" on public.call_logs;
create policy "trip participants can read call logs"
on public.call_logs for select
to authenticated
using (public.is_trip_participant(trip_id) or public.is_admin());

drop policy if exists "trip participants can insert call logs" on public.call_logs;
create policy "trip participants can insert call logs"
on public.call_logs for insert
to authenticated
with check (public.is_trip_participant(trip_id) or public.is_admin());

-- Update (not just insert) is needed too: the same row is updated in place
-- as a call progresses (ringing -> answered_at set -> outcome/ended_at set
-- at the end) rather than inserting a new row per transition.
drop policy if exists "trip participants can update call logs" on public.call_logs;
create policy "trip participants can update call logs"
on public.call_logs for update
to authenticated
using (public.is_trip_participant(trip_id) or public.is_admin());
