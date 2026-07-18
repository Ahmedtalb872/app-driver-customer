-- The `trips` table did not exist before the admin dashboard - Phase 2
-- explicitly stopped short of trip creation, so the mobile app has only
-- ever simulated trips client-side (see AppStateProvider). This is the
-- real, persisted trip record the admin dashboard (and, eventually, the
-- mobile trip-request flow) reads and writes.

create table if not exists public.trips (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.customers (id),
  captain_id uuid references public.captains (id),
  status text not null default 'searching'
    check (status in ('searching', 'accepted', 'arrived', 'in_progress', 'completed', 'cancelled')),

  pickup_address text not null,
  pickup_lat double precision not null,
  pickup_lng double precision not null,
  destination_address text,
  destination_lat double precision,
  destination_lng double precision,

  vehicle_type text default 'economy' check (vehicle_type in ('economy', 'comfort', 'family')),
  distance_km numeric(8, 2),
  estimated_duration_minutes integer,
  actual_duration_minutes integer,
  estimated_price numeric(10, 2),
  final_price numeric(10, 2),
  payment_method text default 'cash' check (payment_method in ('cash', 'wallet')),
  commission_amount numeric(10, 2),
  captain_net_earnings numeric(10, 2),

  cancellation_reason text,
  cancelled_by text check (cancelled_by in ('customer', 'captain', 'admin', 'system')),
  admin_notes text,

  requested_at timestamptz not null default now(),
  accepted_at timestamptz,
  arrived_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

drop trigger if exists trips_set_updated_at on public.trips;
create trigger trips_set_updated_at
before update on public.trips
for each row execute function public.set_updated_at();
