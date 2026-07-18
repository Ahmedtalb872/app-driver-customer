-- Phase 1: customer-specific extension of profiles. Kept minimal for now -
-- trip/payment history is added in a later phase.

create table if not exists public.customers (
  id uuid primary key references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists customers_set_updated_at on public.customers;
create trigger customers_set_updated_at
before update on public.customers
for each row execute function public.set_updated_at();
