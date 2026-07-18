-- Secure PostgreSQL functions backing every sensitive admin-dashboard
-- action. Every function re-validates the caller's admin role itself
-- (never trusts the Flutter Web client) and uses `set search_path = public`
-- per Supabase's SECURITY DEFINER hardening guidance (same pattern as
-- public.is_admin() from Phase 1).
--
-- Money movement (wallets, recharge/withdrawal) and every other action
-- listed in the Phase 3 spec's "record these" list (section 18) is only
-- ever performed by one of these functions, so the write and its
-- audit_logs row are always atomic - there is no code path that moves
-- money or changes a status without also logging it.

-- ---------------------------------------------------------------------
-- Shared helper: writes one audit_logs row for the *current* admin.
-- Callable directly (e.g. from a simple settings/pricing update) or from
-- inside another SECURITY DEFINER function.
-- ---------------------------------------------------------------------
create or replace function public.log_admin_action(
  p_action text,
  p_entity_type text default null,
  p_entity_id text default null,
  p_before_value jsonb default null,
  p_after_value jsonb default null,
  p_reason text default null
)
returns public.audit_logs
language plpgsql
security definer
set search_path = public
as $$
declare
  v_admin_id uuid := auth.uid();
  v_admin_name text;
  v_admin_role text;
  v_row public.audit_logs;
begin
  if v_admin_id is null or not public.is_admin() then
    raise exception 'Only admins may write audit log entries';
  end if;

  select full_name into v_admin_name from public.profiles where id = v_admin_id;
  select admin_role into v_admin_role from public.admin_users where id = v_admin_id;

  insert into public.audit_logs (
    admin_id, admin_name, admin_role, action, entity_type, entity_id,
    before_value, after_value, reason
  ) values (
    v_admin_id, v_admin_name, v_admin_role, p_action, p_entity_type, p_entity_id,
    p_before_value, p_after_value, p_reason
  ) returning * into v_row;

  return v_row;
end;
$$;

-- ---------------------------------------------------------------------
-- Wallets
-- ---------------------------------------------------------------------
create or replace function public.admin_adjust_wallet_balance(
  p_user_id uuid,
  p_amount numeric,
  p_is_credit boolean,
  p_reason text
)
returns public.wallets
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet public.wallets;
  v_before numeric;
  v_after numeric;
begin
  if not public.has_admin_role('finance_admin') then
    raise exception 'Only finance_admin or super_admin may adjust wallet balances';
  end if;
  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'A reason is required to adjust a wallet balance';
  end if;
  if p_amount is null or p_amount <= 0 then
    raise exception 'Amount must be positive';
  end if;

  select * into v_wallet from public.wallets where user_id = p_user_id for update;
  if not found then
    raise exception 'No wallet found for user %', p_user_id;
  end if;

  v_before := v_wallet.balance;
  v_after := v_before + (case when p_is_credit then p_amount else -p_amount end);
  if v_after < 0 then
    raise exception 'Adjustment would make the wallet balance negative';
  end if;

  update public.wallets set balance = v_after where id = v_wallet.id
    returning * into v_wallet;

  insert into public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    is_credit, reference_type, description, created_by
  ) values (
    v_wallet.id, p_user_id, 'adjustment', p_amount, v_before, v_after,
    p_is_credit, 'manual', p_reason, auth.uid()
  );

  perform public.log_admin_action(
    'wallet_adjustment', 'wallet', v_wallet.id::text,
    jsonb_build_object('balance', v_before), jsonb_build_object('balance', v_after),
    p_reason
  );

  return v_wallet;
end;
$$;

create or replace function public.admin_approve_recharge(
  p_request_id uuid,
  p_notes text default null
)
returns public.recharge_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request public.recharge_requests;
  v_wallet public.wallets;
  v_before numeric;
  v_after numeric;
begin
  if not public.has_admin_role('finance_admin') then
    raise exception 'Only finance_admin or super_admin may approve recharge requests';
  end if;

  select * into v_request from public.recharge_requests where id = p_request_id for update;
  if not found then
    raise exception 'Recharge request % not found', p_request_id;
  end if;
  if v_request.status <> 'pending' then
    raise exception 'Recharge request % is not pending', p_request_id;
  end if;

  select * into v_wallet from public.wallets where id = v_request.wallet_id for update;
  v_before := v_wallet.balance;
  v_after := v_before + v_request.amount;

  update public.wallets set balance = v_after where id = v_wallet.id;

  insert into public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    is_credit, reference_type, reference_id, description, created_by
  ) values (
    v_wallet.id, v_request.user_id, 'recharge', v_request.amount, v_before, v_after,
    true, 'recharge_request', v_request.id, p_notes, auth.uid()
  );

  update public.recharge_requests
    set status = 'approved', admin_notes = p_notes, reviewed_by = auth.uid(), reviewed_at = now()
    where id = p_request_id
    returning * into v_request;

  perform public.log_admin_action(
    'recharge_approved', 'recharge_request', p_request_id::text,
    jsonb_build_object('status', 'pending'), jsonb_build_object('status', 'approved', 'amount', v_request.amount),
    p_notes
  );

  return v_request;
end;
$$;

create or replace function public.admin_reject_recharge(
  p_request_id uuid,
  p_reason text
)
returns public.recharge_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request public.recharge_requests;
begin
  if not public.has_admin_role('finance_admin') then
    raise exception 'Only finance_admin or super_admin may reject recharge requests';
  end if;
  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'A reason is required to reject a recharge request';
  end if;

  update public.recharge_requests
    set status = 'rejected', admin_notes = p_reason, reviewed_by = auth.uid(), reviewed_at = now()
    where id = p_request_id and status = 'pending'
    returning * into v_request;

  if not found then
    raise exception 'Recharge request % not found or not pending', p_request_id;
  end if;

  perform public.log_admin_action(
    'recharge_rejected', 'recharge_request', p_request_id::text,
    jsonb_build_object('status', 'pending'), jsonb_build_object('status', 'rejected'),
    p_reason
  );

  return v_request;
end;
$$;

create or replace function public.admin_approve_withdrawal(
  p_request_id uuid,
  p_notes text default null
)
returns public.withdrawal_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request public.withdrawal_requests;
  v_wallet public.wallets;
  v_before numeric;
  v_after numeric;
begin
  if not public.has_admin_role('finance_admin') then
    raise exception 'Only finance_admin or super_admin may approve withdrawal requests';
  end if;

  select * into v_request from public.withdrawal_requests where id = p_request_id for update;
  if not found then
    raise exception 'Withdrawal request % not found', p_request_id;
  end if;
  if v_request.status <> 'pending' then
    raise exception 'Withdrawal request % is not pending', p_request_id;
  end if;

  select * into v_wallet from public.wallets where id = v_request.wallet_id for update;
  v_before := v_wallet.balance;
  if v_before < v_request.amount then
    raise exception 'Wallet balance is insufficient for this withdrawal';
  end if;
  v_after := v_before - v_request.amount;

  update public.wallets set balance = v_after where id = v_wallet.id;

  insert into public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    is_credit, reference_type, reference_id, description, created_by
  ) values (
    v_wallet.id, v_request.user_id, 'withdraw', v_request.amount, v_before, v_after,
    false, 'withdrawal_request', v_request.id, p_notes, auth.uid()
  );

  update public.withdrawal_requests
    set status = 'approved', admin_notes = p_notes, reviewed_by = auth.uid(), reviewed_at = now()
    where id = p_request_id
    returning * into v_request;

  perform public.log_admin_action(
    'withdrawal_approved', 'withdrawal_request', p_request_id::text,
    jsonb_build_object('status', 'pending'), jsonb_build_object('status', 'approved', 'amount', v_request.amount),
    p_notes
  );

  return v_request;
end;
$$;

create or replace function public.admin_reject_withdrawal(
  p_request_id uuid,
  p_reason text
)
returns public.withdrawal_requests
language plpgsql
security definer
set search_path = public
as $$
declare
  v_request public.withdrawal_requests;
begin
  if not public.has_admin_role('finance_admin') then
    raise exception 'Only finance_admin or super_admin may reject withdrawal requests';
  end if;
  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'A reason is required to reject a withdrawal request';
  end if;

  update public.withdrawal_requests
    set status = 'rejected', admin_notes = p_reason, reviewed_by = auth.uid(), reviewed_at = now()
    where id = p_request_id and status = 'pending'
    returning * into v_request;

  if not found then
    raise exception 'Withdrawal request % not found or not pending', p_request_id;
  end if;

  perform public.log_admin_action(
    'withdrawal_rejected', 'withdrawal_request', p_request_id::text,
    jsonb_build_object('status', 'pending'), jsonb_build_object('status', 'rejected'),
    p_reason
  );

  return v_request;
end;
$$;

-- ---------------------------------------------------------------------
-- Captains
-- ---------------------------------------------------------------------
create or replace function public.admin_approve_captain(p_captain_id uuid)
returns public.captains
language plpgsql
security definer
set search_path = public
as $$
declare
  v_captain public.captains;
begin
  if not public.has_admin_role('operations_admin') then
    raise exception 'Only operations_admin or super_admin may approve captains';
  end if;

  update public.captains
    set status = 'approved', rejection_reason = null
    where id = p_captain_id
    returning * into v_captain;

  if not found then
    raise exception 'Captain % not found', p_captain_id;
  end if;

  perform public.log_admin_action('captain_approved', 'captain', p_captain_id::text, null, null, null);

  return v_captain;
end;
$$;

create or replace function public.admin_reject_captain(p_captain_id uuid, p_reason text)
returns public.captains
language plpgsql
security definer
set search_path = public
as $$
declare
  v_captain public.captains;
begin
  if not public.has_admin_role('operations_admin') then
    raise exception 'Only operations_admin or super_admin may reject captains';
  end if;
  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'A reason is required to reject a captain';
  end if;

  update public.captains
    set status = 'rejected', rejection_reason = p_reason
    where id = p_captain_id
    returning * into v_captain;

  if not found then
    raise exception 'Captain % not found', p_captain_id;
  end if;

  perform public.log_admin_action('captain_rejected', 'captain', p_captain_id::text, null, null, p_reason);

  return v_captain;
end;
$$;

create or replace function public.admin_set_captain_suspension(
  p_captain_id uuid,
  p_suspended boolean,
  p_reason text default null
)
returns public.captains
language plpgsql
security definer
set search_path = public
as $$
declare
  v_captain public.captains;
  v_new_status text;
begin
  if not public.has_admin_role('operations_admin') then
    raise exception 'Only operations_admin or super_admin may suspend/reactivate captains';
  end if;
  if p_suspended and (p_reason is null or btrim(p_reason) = '') then
    raise exception 'A reason is required to suspend a captain';
  end if;

  v_new_status := case when p_suspended then 'suspended' else 'approved' end;

  update public.captains
    set status = v_new_status,
        rejection_reason = case when p_suspended then p_reason else null end
    where id = p_captain_id
    returning * into v_captain;

  if not found then
    raise exception 'Captain % not found', p_captain_id;
  end if;

  perform public.log_admin_action(
    case when p_suspended then 'captain_suspended' else 'captain_reactivated' end,
    'captain', p_captain_id::text, null, null, p_reason
  );

  return v_captain;
end;
$$;

-- ---------------------------------------------------------------------
-- Customers
-- ---------------------------------------------------------------------
create or replace function public.admin_set_customer_suspension(
  p_customer_id uuid,
  p_suspended boolean,
  p_reason text default null
)
returns public.customers
language plpgsql
security definer
set search_path = public
as $$
declare
  v_customer public.customers;
  v_new_status text;
begin
  if not public.has_admin_role('operations_admin', 'support_admin') then
    raise exception 'Only operations_admin, support_admin, or super_admin may suspend/reactivate customers';
  end if;
  if p_suspended and (p_reason is null or btrim(p_reason) = '') then
    raise exception 'A reason is required to suspend a customer';
  end if;

  v_new_status := case when p_suspended then 'suspended' else 'active' end;

  update public.customers set status = v_new_status where id = p_customer_id
    returning * into v_customer;

  if not found then
    raise exception 'Customer % not found', p_customer_id;
  end if;

  perform public.log_admin_action(
    case when p_suspended then 'customer_suspended' else 'customer_reactivated' end,
    'customer', p_customer_id::text, null, null, p_reason
  );

  return v_customer;
end;
$$;

-- ---------------------------------------------------------------------
-- Trips
-- ---------------------------------------------------------------------
create or replace function public.admin_cancel_trip(p_trip_id uuid, p_reason text)
returns public.trips
language plpgsql
security definer
set search_path = public
as $$
declare
  v_trip public.trips;
begin
  if not public.has_admin_role('operations_admin') then
    raise exception 'Only operations_admin or super_admin may cancel a trip';
  end if;
  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'A reason is required to cancel a trip';
  end if;

  update public.trips
    set status = 'cancelled', cancelled_by = 'admin', cancellation_reason = p_reason, cancelled_at = now()
    where id = p_trip_id and status not in ('completed', 'cancelled')
    returning * into v_trip;

  if not found then
    raise exception 'Trip % not found or already finished', p_trip_id;
  end if;

  perform public.log_admin_action('trip_cancelled', 'trip', p_trip_id::text, null, null, p_reason);

  return v_trip;
end;
$$;

-- ---------------------------------------------------------------------
-- Admin user management (super_admin only). Promotes an existing
-- auth.users account to admin - it cannot create a brand new auth account
-- (that requires the Supabase service-role key, which per the Phase 3
-- spec must never be embedded in Flutter Web; use the Supabase dashboard
-- to create the underlying account first, exactly like Phase 1's
-- admin_users table already documented).
-- ---------------------------------------------------------------------
create or replace function public.admin_promote_to_admin(
  p_target_user_id uuid,
  p_admin_role text,
  p_full_name text default null
)
returns public.admin_users
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.admin_users;
begin
  if not public.has_admin_role('super_admin') then
    raise exception 'Only super_admin may create or promote admin users';
  end if;
  if p_admin_role not in ('super_admin', 'operations_admin', 'finance_admin', 'support_admin', 'content_admin') then
    raise exception 'Invalid admin role: %', p_admin_role;
  end if;
  if not exists (select 1 from public.profiles where id = p_target_user_id) then
    raise exception 'No profile found for user % - they must sign up first', p_target_user_id;
  end if;

  update public.profiles set role = 'admin' where id = p_target_user_id;

  insert into public.admin_users (id, admin_role, full_name, is_active)
  values (p_target_user_id, p_admin_role, p_full_name, true)
  on conflict (id) do update
    set admin_role = excluded.admin_role,
        full_name = coalesce(excluded.full_name, public.admin_users.full_name),
        is_active = true
  returning * into v_row;

  perform public.log_admin_action(
    'admin_promoted', 'admin_user', p_target_user_id::text, null,
    jsonb_build_object('admin_role', p_admin_role), null
  );

  return v_row;
end;
$$;

create or replace function public.admin_set_admin_active(
  p_target_admin_id uuid,
  p_is_active boolean
)
returns public.admin_users
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.admin_users;
begin
  if not public.has_admin_role('super_admin') then
    raise exception 'Only super_admin may enable/disable admin users';
  end if;
  if p_target_admin_id = auth.uid() then
    raise exception 'You cannot disable your own admin account';
  end if;

  update public.admin_users set is_active = p_is_active where id = p_target_admin_id
    returning * into v_row;

  if not found then
    raise exception 'Admin user % not found', p_target_admin_id;
  end if;

  perform public.log_admin_action(
    case when p_is_active then 'admin_enabled' else 'admin_disabled' end,
    'admin_user', p_target_admin_id::text, null, null, null
  );

  return v_row;
end;
$$;
