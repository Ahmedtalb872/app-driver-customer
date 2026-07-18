-- Adds an optional contact email to `profiles`, shown in the admin
-- dashboard's captain detail view. Distinct from the synthetic
-- `{phone}@hudhud.app` address Supabase Auth stores internally
-- (auth_service.dart's `_phoneToEmail`) - that one is never a real address
-- and is not meant to be user-facing. This column is nullable: captains
-- authenticate by phone, so an email is optional contact info only, not a
-- login credential.
alter table public.profiles add column if not exists email text;
