-- Requested: the customer<->admin voice-call feature (request-a-ride call,
-- admin calling a customer back) turned out too fragile to keep debugging -
-- shelved as a future project. Replaced with a text-based "request a ride
-- by message" flow reusing the support_tickets/support_ticket_messages
-- thread already built for SupportScreen's "محادثة مباشرة". Customer<->
-- captain voice calls (call_signals, call_screen.dart) are untouched - this
-- only reverts the admin-specific widening on top of them.

-- Back to the original participant-only policy from
-- 20260816000076_call_signals_rls_via_function.sql - drops the "or
-- public.is_admin()" clause 20261008000112_admin_call_customer.sql added.
-- call_signals itself stays (still carries every captain<->customer call).
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

-- Only existed to back AdminIncomingCallListener's global cross-trip poll,
-- which is deleted along with the rest of the admin-call UI.
drop index if exists public.call_signals_customer_offer_idx;

-- call_logs had no viewer left once admin_call_logs_screen.dart is deleted
-- (it only ever recorded calls, captain ones included, for that one
-- screen) - dropped outright rather than left as silent dead writes.
drop table if exists public.call_logs;

-- New: lets a support thread reference the specific trip it's about, so
-- the admin can jump straight to that trip's pickup/destination editor
-- from inside the chat - the same convenience the deleted call feature's
-- "trip panel over the call screen" offered, for message requests instead.
alter table public.support_tickets
  add column if not exists trip_id uuid references public.trips (id) on delete set null;

create index if not exists support_tickets_trip_id_idx
  on public.support_tickets (trip_id);

-- An admin starting a conversation with a customer (replacing "اتصال
-- بالزبون") inserts a ticket on that customer's behalf - the original
-- policy only ever allowed a user to create their own ticket.
drop policy if exists "Support tickets insertable by owner" on public.support_tickets;
create policy "Support tickets insertable by owner"
  on public.support_tickets for insert
  with check (auth.uid() = user_id or public.is_admin());

-- Lets a customer attach/refocus their own existing ticket onto the trip
-- they just requested (e.g. reusing an older conversation for a new "راسل
-- لطلب مشوار" request) without a direct UPDATE grant on support_tickets -
-- that stays admin-only ("Support tickets updatable by admin" above), so
-- this is the one narrow, owner-checked exception.
create or replace function public.set_my_ticket_trip(p_ticket_id uuid, p_trip_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.support_tickets
    set trip_id = p_trip_id
    where id = p_ticket_id and user_id = auth.uid();
end;
$$;
