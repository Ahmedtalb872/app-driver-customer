-- Additive columns the admin dashboard needs that neither Phase 1 nor
-- Phase 2 had a reason to create yet: account status + admin notes for
-- customers (customers had neither before), admin notes + vehicle details
-- for captains (the mobile registration stepper already collects vehicle
-- info, but Phase 1 deliberately left it client-side only - see that
-- phase's captains table comment). Document upload/verification (photos,
-- national ID, license, insurance, ...) is a separate, larger Supabase
-- Storage feature and is intentionally NOT added here - the admin
-- dashboard's captain documents panel says so explicitly.

alter table public.customers
  add column if not exists status text not null default 'active'
    check (status in ('active', 'suspended'));

alter table public.customers
  add column if not exists admin_notes text;

alter table public.captains
  add column if not exists admin_notes text;

alter table public.captains
  add column if not exists vehicle_type text
    check (vehicle_type in ('economy', 'comfort', 'family'));

alter table public.captains add column if not exists vehicle_brand text;
alter table public.captains add column if not exists vehicle_model text;
alter table public.captains add column if not exists vehicle_year integer;
alter table public.captains add column if not exists vehicle_color text;
alter table public.captains add column if not exists vehicle_plate text;
alter table public.captains add column if not exists vehicle_seats integer;
alter table public.captains add column if not exists is_online boolean not null default false;
alter table public.captains add column if not exists rejection_reason text;
