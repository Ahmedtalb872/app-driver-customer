-- Ledger for public.wallets (created in Phase 1 but never populated - no
-- transaction history existed anywhere in the backend before this). Every
-- row is an immutable fact; balances are only ever changed by the
-- SECURITY DEFINER functions in 20260712000027_admin_functions.sql, which
-- write the wallet's new balance and the matching ledger row atomically.

create table if not exists public.wallet_transactions (
  id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references public.wallets (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  type text not null
    check (type in ('recharge', 'payment', 'refund', 'withdraw', 'commission', 'transfer', 'adjustment')),
  amount numeric(10, 2) not null,
  balance_before numeric(10, 2) not null,
  balance_after numeric(10, 2) not null,
  is_credit boolean not null,
  reference_type text,
  reference_id uuid,
  description text,
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now()
);
