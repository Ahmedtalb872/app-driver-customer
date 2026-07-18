-- Customer wallet recharge requests and captain earnings withdrawal
-- requests. Both are review queues for finance admins - approving/
-- rejecting them (see 20260712000027_admin_functions.sql) is the only way
-- their linked wallet balance and wallet_transactions ledger change.

create table if not exists public.recharge_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  wallet_id uuid not null references public.wallets (id),
  amount numeric(10, 2) not null check (amount > 0),
  payment_method text,
  receipt_url text,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  admin_notes text,
  reviewed_by uuid references auth.users (id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.withdrawal_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  wallet_id uuid not null references public.wallets (id),
  amount numeric(10, 2) not null check (amount > 0),
  payout_method text,
  payout_account text,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  admin_notes text,
  reviewed_by uuid references auth.users (id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);
