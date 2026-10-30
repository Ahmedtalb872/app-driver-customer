-- Fixes the "التقارير المالية" (finance reports) page always showing 0,
-- even for periods with real recharge activity.
--
-- admin_finance_recharge_report/totals (20260821000082) only ever read
-- public.recharge_requests with status = 'approved' - the old manual-
-- review recharge flow. That flow is no longer how money actually enters
-- either app's wallet:
--   - Customers now mostly recharge live via Bpay
--     (credit_wallet_from_bpay, 20260910000095_customer_bpay_wallet_credit.sql),
--     which writes straight to public.wallets/public.wallet_transactions
--     and never touches recharge_requests at all.
--   - Captains never went through recharge_requests to begin with once
--     Bpay shipped on that app - their prepaid balance is
--     profiles.wallet_balance, credited exclusively by the sibling
--     captain app's credit_captain_wallet_from_bpay into its own
--     public.captain_wallet_ledger table (see aihoudhoud's
--     0028_fix_wallet_ledger_insert.sql - the earlier
--     public.wallet_transactions insert there had a completely
--     mismatched column shape and was silently failing every call).
--
-- Real source of truth per role:
--   - customers: public.wallet_transactions (type = 'recharge', is_credit)
--     - covers both the still-supported manual-review path
--     (admin_approve_recharge also writes here) and live Bpay.
--   - captains: public.captain_wallet_ledger (type = 'bpay_recharge',
--     is_credit) - the only path a captain's balance goes up.
-- recharge_requests itself is no longer queried directly - every row it
-- produces already lands in wallet_transactions via admin_approve_recharge,
-- so reading requests too would double-count them.

create or replace function public.admin_finance_recharge_report(
  p_from date,
  p_to date,
  p_granularity text default 'day'
)
returns table (
  bucket date,
  captains_count integer,
  captains_amount numeric,
  customers_count integer,
  customers_amount numeric,
  requests_count integer,
  total_amount numeric
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_g text := case when coalesce(p_granularity, 'day') = 'month'
                   then 'month' else 'day' end;
  v_step interval := case when v_g = 'month'
                          then interval '1 month' else interval '1 day' end;
begin
  if not public.has_admin_role('finance_admin') then
    raise exception 'Only finance_admin or super_admin may read finance reports';
  end if;
  if p_from is null or p_to is null or p_to < p_from then
    raise exception 'INVALID_RANGE';
  end if;
  if p_to - p_from > 1830 then
    raise exception 'RANGE_TOO_LARGE';
  end if;

  return query
  with captain_by_bucket as (
    select
      date_trunc(v_g, cwl.created_at)::date as b,
      count(distinct cwl.captain_id) as ucnt,
      count(*) as tcnt,
      sum(cwl.amount) as amt
    from public.captain_wallet_ledger cwl
    where cwl.type = 'bpay_recharge' and cwl.is_credit
      and cwl.created_at >= p_from::timestamptz
      and cwl.created_at < (p_to + 1)::timestamptz
    group by 1
  ),
  customer_by_bucket as (
    select
      date_trunc(v_g, wt.created_at)::date as b,
      count(distinct wt.user_id) as ucnt,
      count(*) as tcnt,
      sum(wt.amount) as amt
    from public.wallet_transactions wt
    where wt.type = 'recharge' and wt.is_credit
      and wt.created_at >= p_from::timestamptz
      and wt.created_at < (p_to + 1)::timestamptz
    group by 1
  ),
  buckets as (
    select generate_series(
      date_trunc(v_g, p_from::timestamptz),
      date_trunc(v_g, p_to::timestamptz),
      v_step
    )::date as b
  )
  select
    k.b,
    coalesce(cb.ucnt, 0)::integer,
    coalesce(cb.amt, 0)::numeric,
    coalesce(ub.ucnt, 0)::integer,
    coalesce(ub.amt, 0)::numeric,
    (coalesce(cb.tcnt, 0) + coalesce(ub.tcnt, 0))::integer,
    (coalesce(cb.amt, 0) + coalesce(ub.amt, 0))::numeric
  from buckets k
  left join captain_by_bucket cb on cb.b = k.b
  left join customer_by_bucket ub on ub.b = k.b
  order by k.b desc;
end;
$$;

create or replace function public.admin_finance_recharge_totals(
  p_from date,
  p_to date
)
returns table (
  captains_count integer,
  captains_amount numeric,
  customers_count integer,
  customers_amount numeric,
  requests_count integer,
  total_amount numeric
)
language plpgsql
stable
security definer
set search_path = public
as $$
begin
  if not public.has_admin_role('finance_admin') then
    raise exception 'Only finance_admin or super_admin may read finance reports';
  end if;
  if p_from is null or p_to is null or p_to < p_from then
    raise exception 'INVALID_RANGE';
  end if;

  return query
  with captain_recharges as (
    select cwl.captain_id as uid, cwl.amount as amt
    from public.captain_wallet_ledger cwl
    where cwl.type = 'bpay_recharge' and cwl.is_credit
      and cwl.created_at >= p_from::timestamptz
      and cwl.created_at < (p_to + 1)::timestamptz
  ),
  customer_recharges as (
    select wt.user_id as uid, wt.amount as amt
    from public.wallet_transactions wt
    where wt.type = 'recharge' and wt.is_credit
      and wt.created_at >= p_from::timestamptz
      and wt.created_at < (p_to + 1)::timestamptz
  )
  select
    (select count(distinct uid) from captain_recharges)::integer,
    (select coalesce(sum(amt), 0) from captain_recharges)::numeric,
    (select count(distinct uid) from customer_recharges)::integer,
    (select coalesce(sum(amt), 0) from customer_recharges)::numeric,
    ((select count(*) from captain_recharges) + (select count(*) from customer_recharges))::integer,
    ((select coalesce(sum(amt), 0) from captain_recharges) + (select coalesce(sum(amt), 0) from customer_recharges))::numeric;
end;
$$;

revoke all on function public.admin_finance_recharge_report(date, date, text) from public;
revoke all on function public.admin_finance_recharge_totals(date, date) from public;
grant execute on function public.admin_finance_recharge_report(date, date, text) to authenticated;
grant execute on function public.admin_finance_recharge_totals(date, date) to authenticated;
