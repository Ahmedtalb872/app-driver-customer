-- A self-service B2B portal: a restaurant/institution signs up for its own
-- account (same underlying auth/profiles/customers rows any real customer
-- gets - see handle_new_user, 20260729000041_password_auth_single_session.sql
-- - so the existing customer_request_trip/cancel/watch RPCs and the
-- existing support_tickets system work for it completely unchanged) and
-- gets a dashboard to place delivery requests on a customer's behalf and
-- track them, instead of using the consumer mobile app. This table is
-- purely the extra "this customer is actually a business" marker plus the
-- admin review gate - everything about *placing and tracking a trip* is
-- the customer flow already built.
create table if not exists public.business_accounts (
  id uuid primary key references public.profiles(id) on delete cascade,
  business_name text not null,
  business_type text not null
    check (business_type in ('restaurant', 'institution', 'other')),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'suspended')),
  default_pickup_address text,
  default_pickup_lat double precision,
  default_pickup_lng double precision,
  rejection_reason text,
  admin_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists business_accounts_status_idx
  on public.business_accounts (status);

drop trigger if exists business_accounts_set_updated_at on public.business_accounts;
create trigger business_accounts_set_updated_at
before update on public.business_accounts
for each row execute function public.set_updated_at();

alter table public.business_accounts enable row level security;

-- A freshly signed-up account creates exactly its own row, once (there is
-- no admin "create business account" flow - self-service is the whole
-- point here), and can read/update the fields the dashboard itself lets it
-- change (name/type/default pickup) - never its own `status`, which only
-- an admin can move via the policy below.
create policy "A business account owner can create their own row"
  on public.business_accounts for insert
  to authenticated
  with check (id = auth.uid());

create policy "A business account owner can read their own row"
  on public.business_accounts for select
  to authenticated
  using (id = auth.uid());

-- The owner can update their own row (e.g. change their default pickup
-- address from the dashboard), but RLS alone can't stop that same policy
-- from also letting them set their own `status` to 'approved' - a plain
-- `using (id = auth.uid())` UPDATE policy has no column granularity. The
-- trigger below closes that: any non-admin update always keeps status/
-- rejection_reason/admin_notes exactly as they were before the update,
-- no matter what the request body tried to send.
create policy "A business account owner can update their own details"
  on public.business_accounts for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy "Admins can read business accounts"
  on public.business_accounts for select
  to authenticated
  using (public.is_admin());

create policy "Admins can update business accounts"
  on public.business_accounts for update
  to authenticated
  using (public.is_admin());

-- Covers both insert (a self-registering account could otherwise send
-- status: 'approved' in the very row it creates) and update.
create or replace function public.protect_business_account_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_admin() then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.status := 'pending';
    new.rejection_reason := null;
    new.admin_notes := null;
  else
    new.status := old.status;
    new.rejection_reason := old.rejection_reason;
    new.admin_notes := old.admin_notes;
  end if;
  return new;
end;
$$;

drop trigger if exists business_accounts_protect_status on public.business_accounts;
create trigger business_accounts_protect_status
before insert or update on public.business_accounts
for each row execute function public.protect_business_account_status();
