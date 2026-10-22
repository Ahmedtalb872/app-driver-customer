-- Backs the admin dashboard's global incoming-call listener
-- (AdminIncomingCallListener), which polls call_signals every second for a
-- brand new customer-initiated offer across every trip at once (there's no
-- single trip_id to filter by - unlike every other call_signals query in
-- this app, which is always scoped to one specific trip). Without this
-- index that poll would have to scan the whole table - which only grows
-- (every ICE candidate for every call ever placed is its own row, never
-- deleted) - and get slower over time. A partial index matching exactly
-- that query's filter keeps it cheap regardless of table size.
create index if not exists call_signals_customer_offer_idx
  on public.call_signals (created_at)
  where type = 'offer' and from_role = 'customer';
