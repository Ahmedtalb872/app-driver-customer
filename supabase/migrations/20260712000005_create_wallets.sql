-- Phase 1: one wallet per user (customer or captain), created automatically
-- on signup. Balance mutation logic (top-ups, trip payments, payouts) is
-- added in a later phase - this migration only establishes the ledger row.

create table if not exists public.wallets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.profiles (id) on delete cascade,
  balance numeric(12, 2) not null default 0,
  currency text not null default 'MRU',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists wallets_set_updated_at on public.wallets;
create trigger wallets_set_updated_at
before update on public.wallets
for each row execute function public.set_updated_at();
