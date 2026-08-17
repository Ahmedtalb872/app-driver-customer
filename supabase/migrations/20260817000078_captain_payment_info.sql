-- Lets a captain record their own payout details (mobile-money app +
-- number) from their own app profile, so the admin dashboard's captain
-- file shows what the company should use when paying that captain
-- directly or giving them a bonus/reward - entirely separate from the
-- existing in-app wallet/commission flow. No new RLS needed: captains can
-- already update their own row ("Captains updatable by owner" in
-- 20260712000006_rls_policies.sql) and admins already have full access
-- ("Captains are updatable by admin" in 20260712000026_admin_rls.sql).
alter table public.captains
  add column if not exists payment_app text
    check (payment_app in ('bankily', 'sedad', 'masrvi', 'banky')),
  add column if not exists payment_number text;
