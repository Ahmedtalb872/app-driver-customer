-- Per-vehicle-type fare/commission configuration (section 11 of the admin
-- dashboard spec). Mirrors the shape already used client-side in
-- lib/core/constants/fare_config.dart, but as live, admin-editable rows
-- instead of hardcoded Dart constants. "Save history" is satisfied by
-- audit_logs (before/after jsonb) rather than a second history table.

create table if not exists public.pricing_config (
  id uuid primary key default gen_random_uuid(),
  vehicle_type text not null unique check (vehicle_type in ('economy', 'comfort', 'family')),
  base_fare numeric(10, 2) not null default 50,
  price_per_km numeric(10, 2) not null default 25,
  price_per_minute numeric(10, 2) not null default 3,
  minimum_fare numeric(10, 2) not null default 100,
  waiting_fee_per_minute numeric(10, 2) not null default 2,
  cancellation_fee numeric(10, 2) not null default 0,
  commission_percentage numeric(5, 2) not null default 15,
  surge_multiplier numeric(4, 2) not null default 1.0,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id)
);

insert into public.pricing_config (vehicle_type)
values ('economy'), ('comfort'), ('family')
on conflict (vehicle_type) do nothing;

drop trigger if exists pricing_config_set_updated_at on public.pricing_config;
create trigger pricing_config_set_updated_at
before update on public.pricing_config
for each row execute function public.set_updated_at();
