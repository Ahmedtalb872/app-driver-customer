-- Finance reporting for the admin dashboard's "المالية" section.
--
-- Answers the two questions the finance page asks per period: how many
-- captains recharged their wallet, and how much was credited in total.
--
-- Source of truth is public.recharge_requests with status = 'approved',
-- because that is the only path that ever mints a 'recharge' row in
-- public.wallet_transactions (admin_approve_recharge, latest definition
-- in 20260812000055_selefli_credit.sql). Requests are bucketed by
-- reviewed_at - the moment the money actually landed in the wallet - not
-- by created_at, which is only when the captain uploaded the receipt and
-- can be days earlier. coalesce() covers rows approved before
-- 20260712000028_admin_functions.sql started writing reviewed_at.
--
-- Mauritania is UTC+0 (Africa/Nouakchott), so Postgres' default UTC
-- date_trunc already produces local calendar days - no timezone shifting
-- needed here.

create index if not exists recharge_requests_reviewed_at_idx
  on public.recharge_requests (reviewed_at)
  where status = 'approved';

-- Per-bucket breakdown. p_granularity 'day' gives one row per calendar
-- day, 'month' one row per month; every bucket in the range is returned
-- even when nothing was recharged that day (generate_series + left join),
-- so a printed report has no silent gaps.
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
  -- ~5 years of daily rows; keeps a mistyped range from building a
  -- million-row result set.
  if p_to - p_from > 1830 then
    raise exception 'RANGE_TOO_LARGE';
  end if;

  return query
  with approved as (
    select
      date_trunc(v_g, coalesce(r.reviewed_at, r.created_at))::date as b,
      r.amount as amt,
      r.user_id as uid,
      p.role as prole
    from public.recharge_requests r
    left join public.profiles p on p.id = r.user_id
    where r.status = 'approved'
      and coalesce(r.reviewed_at, r.created_at) >= p_from::timestamptz
      and coalesce(r.reviewed_at, r.created_at) < (p_to + 1)::timestamptz
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
    count(distinct a.uid) filter (where a.prole = 'captain')::integer,
    coalesce(sum(a.amt) filter (where a.prole = 'captain'), 0)::numeric,
    count(distinct a.uid) filter (where a.prole = 'customer')::integer,
    coalesce(sum(a.amt) filter (where a.prole = 'customer'), 0)::numeric,
    count(a.uid)::integer,
    coalesce(sum(a.amt), 0)::numeric
  from buckets k
  left join approved a on a.b = k.b
  group by k.b
  order by k.b desc;
end;
$$;

-- Range totals. Deliberately a separate call rather than summing the
-- per-bucket rows client-side: a captain who recharged on three different
-- days counts once here and three times there, and the header card is
-- meant to say how many distinct captains recharged in the period.
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
  with approved as (
    select r.amount as amt, r.user_id as uid, p.role as prole
    from public.recharge_requests r
    left join public.profiles p on p.id = r.user_id
    where r.status = 'approved'
      and coalesce(r.reviewed_at, r.created_at) >= p_from::timestamptz
      and coalesce(r.reviewed_at, r.created_at) < (p_to + 1)::timestamptz
  )
  select
    count(distinct a.uid) filter (where a.prole = 'captain')::integer,
    coalesce(sum(a.amt) filter (where a.prole = 'captain'), 0)::numeric,
    count(distinct a.uid) filter (where a.prole = 'customer')::integer,
    coalesce(sum(a.amt) filter (where a.prole = 'customer'), 0)::numeric,
    count(a.uid)::integer,
    coalesce(sum(a.amt), 0)::numeric
  from approved a;
end;
$$;

revoke all on function public.admin_finance_recharge_report(date, date, text) from public;
revoke all on function public.admin_finance_recharge_totals(date, date) from public;
grant execute on function public.admin_finance_recharge_report(date, date, text) to authenticated;
grant execute on function public.admin_finance_recharge_totals(date, date) to authenticated;
