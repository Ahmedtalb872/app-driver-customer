-- Admin-controlled Selefli promo mode: a single on/off switch (plus a
-- fixed cap while it's on) that makes every customer eligible for Selefli
-- regardless of their actual completed_trips_count - a launch incentive
-- ("جرّب التطبيق، اطلب بلا رصيد") the admin can flip back off once the
-- promo period ends, without touching the normal trip-count tiers
-- (selefli_credit_cap) that resume automatically the moment it's off.
alter table public.app_settings
  add column if not exists selefli_promo_enabled boolean not null default false,
  add column if not exists selefli_promo_cap numeric(10, 2) not null default 100;

create or replace function public.selefli_credit_cap(p_customer_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select case
    when (select selefli_promo_enabled from public.app_settings where id = true)
      then (select selefli_promo_cap from public.app_settings where id = true)
    when (select completed_trips_count from public.customers where id = p_customer_id) >= 30 then 200
    when (select completed_trips_count from public.customers where id = p_customer_id) > 10 then 100
    else null
  end;
$$;
