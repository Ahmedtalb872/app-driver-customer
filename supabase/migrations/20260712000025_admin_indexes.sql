-- Lookup/filter indexes for the admin dashboard's tables.

create index if not exists trips_customer_id_idx on public.trips (customer_id);
create index if not exists trips_captain_id_idx on public.trips (captain_id);
create index if not exists trips_status_idx on public.trips (status);
create index if not exists trips_requested_at_idx on public.trips (requested_at);

create index if not exists wallet_transactions_wallet_id_idx on public.wallet_transactions (wallet_id);
create index if not exists wallet_transactions_user_id_idx on public.wallet_transactions (user_id);
create index if not exists wallet_transactions_created_at_idx on public.wallet_transactions (created_at);

create index if not exists recharge_requests_user_id_idx on public.recharge_requests (user_id);
create index if not exists recharge_requests_status_idx on public.recharge_requests (status);

create index if not exists withdrawal_requests_user_id_idx on public.withdrawal_requests (user_id);
create index if not exists withdrawal_requests_status_idx on public.withdrawal_requests (status);

create index if not exists audit_logs_admin_id_idx on public.audit_logs (admin_id);
create index if not exists audit_logs_entity_type_idx on public.audit_logs (entity_type);
create index if not exists audit_logs_created_at_idx on public.audit_logs (created_at);
