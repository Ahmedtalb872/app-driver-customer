-- Security cleanup: 20260815000072_realtime_broadcast_authorization.sql
-- granted every authenticated user SELECT/INSERT on realtime.messages for
-- ANY channel/topic (using (true)/with check (true)), not scoped to a
-- specific trip's call channel - rationalized at the time as safe only
-- because a trip UUID is unguessable. Two migrations later
-- (20260816000075/76_call_signals*), call signaling was moved off Realtime
-- Broadcast entirely onto a proper call_signals table scoped by
-- is_trip_participant() RLS (see call_signaling_service.dart's own doc
-- comment: "not Realtime Broadcast"), but this blanket broadcast grant was
-- never removed - a standing, channel-agnostic policy nothing in the
-- current app uses, that any future Broadcast usage would silently inherit
-- with no per-channel isolation. Removing it now that nothing depends on
-- it; a future real use of Realtime Broadcast should add a policy scoped
-- to its own specific topic naming instead of reinstating this blanket one.
drop policy if exists "authenticated can receive broadcast" on realtime.messages;
drop policy if exists "authenticated can send broadcast" on realtime.messages;
