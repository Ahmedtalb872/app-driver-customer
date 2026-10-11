-- Live Bpay recharge for the customer app, mirroring the aihoudhoud
-- (captain app) repo's own Bpay integration (bpay-payment Edge Function +
-- credit_captain_wallet_from_bpay) - same Bankily merchant API, same
-- request/response shape - but crediting THIS app's own wallet schema
-- (public.wallets/public.wallet_transactions, 20260712000005/
-- 20260712000020) instead of aihoudhoud's captain-only
-- profiles.wallet_balance/captain_wallet_ledger. The two apps' wallet
-- tables are unrelated even though they share this Supabase project - see
-- aihoudhoud's own 0028_fix_wallet_ledger_insert.sql, which hit exactly
-- this mismatch the other way around.
--
-- Deliberately its own table/function/edge-function names (not reusing
-- aihoudhoud's bpay_transactions/credit_captain_wallet_from_bpay/
-- bpay-payment) even though both call the identical Bankily merchant API:
-- a single shared Supabase project can only have one Edge Function of a
-- given name, and the two apps deploy from separate repos - reusing a name
-- would mean whichever repo deploys last silently overwrites the other's
-- wallet-crediting logic.
create table if not exists public.customer_bpay_transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles (id) on delete cascade,
  operation_id text not null unique,
  amount numeric not null check (amount > 0),
  payer_phone text not null,
  status text not null check (status in ('success', 'failed', 'pending')),
  error_code integer,
  error_message text,
  transaction_id text,
  created_at timestamptz not null default now()
);

alter table public.customer_bpay_transactions enable row level security;

drop policy if exists "users_view_own_bpay_transactions" on public.customer_bpay_transactions;
create policy "users_view_own_bpay_transactions"
  on public.customer_bpay_transactions
  for select
  to authenticated
  using (user_id = auth.uid());

-- Atomically credits a user's wallet and logs the matching ledger entry,
-- the same two-step admin_approve_recharge (20260712000028) already does
-- for the manual-review flow - this is the real-time equivalent for a
-- bank-confirmed Bpay payment, so it skips the recharge_requests queue
-- entirely. Only callable by the service role (the customer-bpay-payment
-- Edge Function) after a confirmed successful Bpay payment - never
-- directly by a client, hence the revoke/grant below.
create or replace function public.credit_wallet_from_bpay(
  p_user_id uuid,
  p_amount numeric,
  p_title text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet public.wallets;
  v_before numeric;
  v_after numeric;
begin
  select * into v_wallet from public.wallets where user_id = p_user_id for update;
  if not found then
    raise exception 'wallet_not_found';
  end if;

  v_before := v_wallet.balance;
  v_after := v_before + p_amount;

  update public.wallets set balance = v_after where id = v_wallet.id;

  insert into public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    is_credit, reference_type, description
  ) values (
    v_wallet.id, p_user_id, 'recharge', p_amount, v_before, v_after,
    true, 'bpay', p_title
  );
end;
$$;

revoke execute on function public.credit_wallet_from_bpay(uuid, numeric, text) from public, authenticated;
grant execute on function public.credit_wallet_from_bpay(uuid, numeric, text) to service_role;
