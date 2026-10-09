-- Tracks whether an admin has already reached out to a captain (phone call,
-- SMS follow-up, etc.) separately from the formal approval workflow - useful
-- for the large batch of "قيد المراجعة" captains recruited via the SMS
-- campaign, where an admin works through the list calling people and needs
-- to remember who's already been contacted. No RLS policy needed: the
-- existing "Captains are updatable by admin" policy
-- (20260712000026_admin_rls.sql) already allows an admin to update any
-- column on this table.
alter table public.captains
  add column if not exists contacted_by_admin boolean not null default false;
