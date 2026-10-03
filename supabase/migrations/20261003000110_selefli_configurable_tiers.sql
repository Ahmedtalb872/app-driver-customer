-- Requested: the normal (non-promo) Selefli eligibility tiers - previously
-- hardcoded in selefli_credit_cap() as "> 10 completed trips -> 100" /
-- ">= 30 completed trips -> 200" - should also be admin-configurable, not
-- just the promo-mode cap (already configurable via
-- app_settings.selefli_promo_enabled/selefli_promo_cap, added in
-- 20260817000079_selefli_promo_toggle.sql). Defaults match the previous
-- hardcoded values exactly, so this changes nothing for existing
-- customers until an admin edits it from the new "سلفلي" admin screen.
alter table public.app_settings
  add column if not exists selefli_tier1_min_trips integer not null default 10,
  add column if not exists selefli_tier1_cap numeric(10, 2) not null default 100,
  add column if not exists selefli_tier2_min_trips integer not null default 30,
  add column if not exists selefli_tier2_cap numeric(10, 2) not null default 200;

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
    when (select completed_trips_count from public.customers where id = p_customer_id)
         >= (select selefli_tier2_min_trips from public.app_settings where id = true)
      then (select selefli_tier2_cap from public.app_settings where id = true)
    when (select completed_trips_count from public.customers where id = p_customer_id)
         > (select selefli_tier1_min_trips from public.app_settings where id = true)
      then (select selefli_tier1_cap from public.app_settings where id = true)
    else null
  end;
$$;
