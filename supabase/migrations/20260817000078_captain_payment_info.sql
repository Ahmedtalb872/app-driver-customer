-- Adds the columns lib/features/profile/captain_edit_info_screen.dart and
-- lib/features/authentication/captain_register_stepper_screen.dart (in the
-- aihoudhoud repo - same shared Supabase project, no separate migration
-- needed there) already read/write via AuthRepository.updateCaptainPayoutInfo
-- (payout_method/payout_phone) - that feature shipped without ever adding
-- these columns, so every save has been failing against a nonexistent
-- column until now. Lets a captain record their own payout details from
-- their own app profile, so the admin dashboard's captain file shows what
-- the company should use when paying that captain directly or giving them
-- a bonus/reward - entirely separate from the existing in-app wallet/
-- commission flow. No new RLS needed: captains can already update their
-- own row ("Captains updatable by owner" in 20260712000006_rls_policies.sql)
-- and admins already have full access ("Captains are updatable by admin" in
-- 20260712000026_admin_rls.sql).
alter table public.captains
  add column if not exists payout_method text
    check (payout_method in ('bankily', 'masrvi', 'sedad', 'banky', 'other')),
  add column if not exists payout_phone text;
