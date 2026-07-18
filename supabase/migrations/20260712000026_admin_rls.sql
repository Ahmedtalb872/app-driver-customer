-- RLS for every admin-dashboard table. General shape:
--   - trips: owner (customer/captain) or admin can read; narrow, safe
--     client writes only (insert own, limited self-service updates) -
--     the sensitive write (cancel-with-reason, admin_notes) goes through
--     admin_cancel_trip() in 20260712000027_admin_functions.sql.
--   - money ledgers (wallet_transactions, recharge/withdrawal_requests):
--     readable by the owner or admin, but there is NO client update/insert
--     path for money movement itself - only the SECURITY DEFINER functions
--     (owned by the migration role, which bypasses RLS the same way
--     handle_new_user already does in Phase 1) can move money.
--   - audit_logs: admin-read only, no client write path at all.
--   - app_settings / pricing_config: authenticated read, admin write.

alter table public.trips enable row level security;
alter table public.wallet_transactions enable row level security;
alter table public.recharge_requests enable row level security;
alter table public.withdrawal_requests enable row level security;
alter table public.audit_logs enable row level security;
alter table public.app_settings enable row level security;
alter table public.pricing_config enable row level security;

-- trips
drop policy if exists "Trips are readable by owner, assigned captain, or admin" on public.trips;
create policy "Trips are readable by owner, assigned captain, or admin"
  on public.trips for select
  to authenticated
  using (auth.uid() = customer_id or auth.uid() = captain_id or public.is_admin());

drop policy if exists "Customers can create their own trips" on public.trips;
create policy "Customers can create their own trips"
  on public.trips for insert
  to authenticated
  with check (auth.uid() = customer_id);

drop policy if exists "Trip owner, assigned captain, or admin can update" on public.trips;
create policy "Trip owner, assigned captain, or admin can update"
  on public.trips for update
  to authenticated
  using (auth.uid() = customer_id or auth.uid() = captain_id or public.is_admin())
  with check (auth.uid() = customer_id or auth.uid() = captain_id or public.is_admin());

-- wallet_transactions (read-only from the client; all writes are via
-- SECURITY DEFINER functions)
drop policy if exists "Wallet transactions are readable by owner or admin" on public.wallet_transactions;
create policy "Wallet transactions are readable by owner or admin"
  on public.wallet_transactions for select
  to authenticated
  using (auth.uid() = user_id or public.is_admin());

-- recharge_requests
drop policy if exists "Recharge requests are readable by owner or admin" on public.recharge_requests;
create policy "Recharge requests are readable by owner or admin"
  on public.recharge_requests for select
  to authenticated
  using (auth.uid() = user_id or public.is_admin());

drop policy if exists "Users can submit their own recharge request" on public.recharge_requests;
create policy "Users can submit their own recharge request"
  on public.recharge_requests for insert
  to authenticated
  with check (auth.uid() = user_id);

-- withdrawal_requests
drop policy if exists "Withdrawal requests are readable by owner or admin" on public.withdrawal_requests;
create policy "Withdrawal requests are readable by owner or admin"
  on public.withdrawal_requests for select
  to authenticated
  using (auth.uid() = user_id or public.is_admin());

drop policy if exists "Users can submit their own withdrawal request" on public.withdrawal_requests;
create policy "Users can submit their own withdrawal request"
  on public.withdrawal_requests for insert
  to authenticated
  with check (auth.uid() = user_id);

-- audit_logs (admin-read only; no client write path)
drop policy if exists "Audit logs are readable by admin" on public.audit_logs;
create policy "Audit logs are readable by admin"
  on public.audit_logs for select
  to authenticated
  using (public.is_admin());

-- app_settings
drop policy if exists "App settings are readable by authenticated users" on public.app_settings;
create policy "App settings are readable by authenticated users"
  on public.app_settings for select
  to authenticated
  using (true);

drop policy if exists "App settings are updatable by admin" on public.app_settings;
create policy "App settings are updatable by admin"
  on public.app_settings for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- pricing_config
drop policy if exists "Pricing config is readable by authenticated users" on public.pricing_config;
create policy "Pricing config is readable by authenticated users"
  on public.pricing_config for select
  to authenticated
  using (true);

drop policy if exists "Pricing config is updatable by admin" on public.pricing_config;
create policy "Pricing config is updatable by admin"
  on public.pricing_config for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- Phase 1 only ever gave admins SELECT on customers/captains/admin_users
-- (there was no admin dashboard yet). The admin dashboard needs to edit
-- admin_notes etc. directly; sensitive status transitions (suspend,
-- approve/reject) still go through the audited SECURITY DEFINER functions
-- in 20260712000028_admin_functions.sql regardless of this policy.
drop policy if exists "Customers are updatable by admin" on public.customers;
create policy "Customers are updatable by admin"
  on public.customers for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists "Captains are updatable by admin" on public.captains;
create policy "Captains are updatable by admin"
  on public.captains for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- admin_users: only a super_admin may provision/edit/disable other admins.
drop policy if exists "Admin users are manageable by super_admin" on public.admin_users;
create policy "Admin users are manageable by super_admin"
  on public.admin_users for update
  to authenticated
  using (public.has_admin_role('super_admin'))
  with check (public.has_admin_role('super_admin'));
