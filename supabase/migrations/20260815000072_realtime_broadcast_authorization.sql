-- Requested: in-app calling between customer and captain isn't connecting
-- ("المكالمة لا تذهب للكابتن"). The WebRTC offer/answer/ICE signaling rides
-- on a plain Supabase Realtime Broadcast channel (call_trip_<tripId>, see
-- call_signaling_service.dart in both apps) - no application table
-- involved, so there was nothing in *this* schema for it to fail against.
-- The likely cause is Supabase's Realtime Authorization: broadcast/presence
-- messages are gated by RLS on realtime.messages, and a project with no
-- policy there silently drops every broadcast for any client that isn't
-- explicitly authorized - it doesn't surface as a Dart-side error, which
-- matches "compiles and runs fine, just never arrives".
--
-- Scoped to authenticated users only (every customer/captain is signed in
-- to place or receive a call) - not scoped further to specific trip
-- participants, since realtime.messages' topic is just the free-text
-- channel name and a trip's UUID is already unguessable/one-call-at-a-time,
-- matching the same trade-off already made in call_signaling_service.dart's
-- own comments.
alter table realtime.messages enable row level security;

drop policy if exists "authenticated can receive broadcast" on realtime.messages;
create policy "authenticated can receive broadcast"
on realtime.messages for select
to authenticated
using (true);

drop policy if exists "authenticated can send broadcast" on realtime.messages;
create policy "authenticated can send broadcast"
on realtime.messages for insert
to authenticated
with check (true);
