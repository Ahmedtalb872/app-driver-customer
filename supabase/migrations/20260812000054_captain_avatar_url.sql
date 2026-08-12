-- Lets a trip's assigned captain have a photo shown to the customer during
-- tracking, the same way public.customers.avatar_url already lets a
-- captain see the customer's photo (added by
-- 20260713000029_open_trip_lifecycle.sql - this mirrors that column
-- exactly, just on the other side of the trip).
--
-- Deliberately a plain column, not a read from captain_documents'
-- 'profile_photo' row: that table's RLS is owner-or-admin only
-- (20260717000034_captain_documents.sql), by design, since it also holds
-- ID/license documents that must never be customer-readable. A photo a
-- captain has chosen to make customer-facing is a different, lighter-weight
-- thing - same distinction the customers table already draws.
--
-- Populating this column (from an approved profile_photo document, an
-- admin action, or a future captain-app upload flow) is out of scope here -
-- this only adds the column and makes it selectable/nullable so it's ready
-- whenever something starts writing to it. Every existing row/query is
-- unaffected.

alter table public.captains
  add column if not exists avatar_url text;
