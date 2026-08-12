-- Staged payout + monthly renewal for "اشتراك شهري" (captain_subscriptions,
-- 20260812000056_captain_subscriptions.sql). Two changes to the money flow,
-- both by product decision:
--
-- 1. The FIRST month of any subscription no longer credits the captain's
--    net share the instant the customer pays. Instead the platform holds
--    it ("in deposits"): half is released to the captain on day 15, the
--    rest on day 30 - so a captain who stops serving mid-month never
--    collects the whole month up front, and a customer who's paid can't
--    be left with a captain who vanishes after day 1.
-- 2. Starting from the customer's second month with the same captain, they
--    can opt into "موثوق" (trusted) renewal: instead of the app moving
--    money at all, the customer pays the captain directly (cash, outside
--    the app) and both sides just confirm it happened in-app; the
--    platform then only pulls its flat commission from the CAPTAIN's
--    wallet (never having touched the rest). A renewal always defaults
--    back to the escrow flow above unless "موثوق" is explicitly chosen.
--
-- Nothing here uses a cron job (this project has never used pg_cron - every
-- other time-based transition, e.g. expire_trip in
-- 20260713000029_open_trip_lifecycle.sql, is a deterministic, idempotent
-- SECURITY DEFINER function the client calls opportunistically). Same
-- pattern here: run_subscription_housekeeping() below does every due
-- escrow release / renewal attempt / timeout check, and is safe to call as
-- often as any client likes since every branch is a plain "is this row
-- actually due" WHERE condition.
--
-- Anything ambiguous (early cancellation while money is still held; a
-- trusted renewal neither side confirmed within 5 days) is flagged
-- (payment_dispute) rather than guessed at automatically, and left for a
-- human admin to resolve - the same trust boundary already used for
-- recharge requests. The actual wallet fix an admin makes for a dispute
-- reuses the existing admin_adjust_wallet_balance
-- (20260712000028_admin_functions.sql) - no new money-moving admin
-- function was added here.

alter table public.captain_subscriptions
  add column if not exists payout_status text
    check (payout_status is null or payout_status in ('pending_first_half', 'pending_second_half', 'fully_paid_out')),
  add column if not exists first_half_paid_at timestamptz,
  add column if not exists second_half_paid_at timestamptz,
  add column if not exists renewal_mode text not null default 'escrow'
    check (renewal_mode in ('escrow', 'trusted')),
  add column if not exists cycle_count integer not null default 1,
  add column if not exists renewal_window_opened_at timestamptz,
  add column if not exists customer_confirmed_renewal_at timestamptz,
  add column if not exists captain_confirmed_renewal_at timestamptz,
  add column if not exists payment_dispute boolean not null default false,
  add column if not exists dispute_reason text,
  add column if not exists dispute_amount numeric(10, 2),
  add column if not exists admin_dispute_notes text;

create index if not exists captain_subscriptions_payment_dispute_idx
  on public.captain_subscriptions (payment_dispute)
  where payment_dispute = true;

-- captain_accept_subscription: identical to
-- 20260812000056_captain_subscriptions.sql except the captain's net share
-- is no longer credited here - it now enters escrow (payout_status =
-- 'pending_first_half') and is released by run_subscription_housekeeping().
create or replace function public.captain_accept_subscription(p_subscription_id uuid)
returns public.captain_subscriptions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sub public.captain_subscriptions;
  v_wallet public.wallets;
  v_commission numeric := 200;
  v_before numeric;
  v_after numeric;
begin
  select * into v_sub from public.captain_subscriptions where id = p_subscription_id for update;
  if not found then
    raise exception 'Subscription thread not found';
  end if;
  if v_sub.captain_id <> auth.uid() then
    raise exception 'Not authorized';
  end if;
  if v_sub.status <> 'negotiating' then
    raise exception 'SUBSCRIPTION_NOT_NEGOTIATING';
  end if;
  if v_sub.proposed_price is null then
    raise exception 'SUBSCRIPTION_NO_OFFER';
  end if;
  if v_sub.proposed_price <= v_commission then
    raise exception 'SUBSCRIPTION_PRICE_TOO_LOW';
  end if;
  if exists (
    select 1 from public.captain_subscriptions
    where customer_id = v_sub.customer_id and status = 'active'
  ) then
    raise exception 'SUBSCRIPTION_ALREADY_ACTIVE';
  end if;

  select * into v_wallet from public.wallets where user_id = v_sub.customer_id for update;
  if not found then
    raise exception 'Customer wallet not found';
  end if;
  if v_wallet.balance < v_sub.proposed_price then
    raise exception 'SUBSCRIPTION_INSUFFICIENT_BALANCE';
  end if;

  v_before := v_wallet.balance;
  v_after := v_before - v_sub.proposed_price;

  update public.wallets set balance = v_after where id = v_wallet.id;
  insert into public.wallet_transactions (
    wallet_id, user_id, type, amount, balance_before, balance_after,
    is_credit, reference_type, reference_id, description
  ) values (
    v_wallet.id, v_sub.customer_id, 'payment', v_sub.proposed_price, v_before, v_after,
    false, 'captain_subscription', v_sub.id, 'اشتراك شهري مع كابتن'
  );

  update public.captain_subscriptions
    set status = 'active',
        agreed_price = v_sub.proposed_price,
        commission_amount = v_commission,
        payout_status = 'pending_first_half',
        cycle_count = 1,
        started_at = now(),
        expires_at = now() + interval '30 days',
        updated_at = now()
    where id = p_subscription_id
    returning * into v_sub;

  insert into public.captain_subscription_messages (subscription_id, sender_id, sender_role, body)
    values (p_subscription_id, auth.uid(), 'captain', 'تم قبول الاشتراك وتفعيله لمدة 30 يوماً.');

  return v_sub;
end;
$$;

-- Every due time-based transition for every subscription, in one
-- deterministic, idempotent pass - see the migration header for why this
-- replaces a cron job. Safe (and cheap - every branch is an indexed/small
-- WHERE match) to call as often as any client likes.
create or replace function public.run_subscription_housekeeping()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sub record;
  v_wallet public.wallets;
  v_net numeric;
  v_half numeric;
  v_before numeric;
  v_after numeric;
begin
  -- Day 15: release the first half of the captain's held net share.
  for v_sub in
    select * from public.captain_subscriptions
    where status = 'active'
      and payout_status = 'pending_first_half'
      and started_at is not null
      and started_at <= now() - interval '15 days'
    for update
  loop
    v_net := v_sub.agreed_price - v_sub.commission_amount;
    v_half := round(v_net / 2.0, 2);

    select * into v_wallet from public.wallets where user_id = v_sub.captain_id for update;
    if found then
      update public.wallets set balance = balance + v_half where id = v_wallet.id;
      insert into public.wallet_transactions (
        wallet_id, user_id, type, amount, balance_before, balance_after,
        is_credit, reference_type, reference_id, description
      ) values (
        v_wallet.id, v_sub.captain_id, 'adjustment', v_half, v_wallet.balance, v_wallet.balance + v_half,
        true, 'captain_subscription_payout', v_sub.id, 'الدفعة الأولى من اشتراك شهري (يوم 15)'
      );
    end if;

    update public.captain_subscriptions
      set payout_status = 'pending_second_half', first_half_paid_at = now(), updated_at = now()
      where id = v_sub.id;
  end loop;

  -- Day 30: release the remainder, and decide what happens to the cycle.
  for v_sub in
    select * from public.captain_subscriptions
    where status = 'active'
      and payout_status = 'pending_second_half'
      and started_at is not null
      and started_at <= now() - interval '30 days'
    for update
  loop
    v_net := v_sub.agreed_price - v_sub.commission_amount;
    v_half := v_net - round(v_net / 2.0, 2);

    select * into v_wallet from public.wallets where user_id = v_sub.captain_id for update;
    if found then
      update public.wallets set balance = balance + v_half where id = v_wallet.id;
      insert into public.wallet_transactions (
        wallet_id, user_id, type, amount, balance_before, balance_after,
        is_credit, reference_type, reference_id, description
      ) values (
        v_wallet.id, v_sub.captain_id, 'adjustment', v_half, v_wallet.balance, v_wallet.balance + v_half,
        true, 'captain_subscription_payout', v_sub.id, 'الدفعة الثانية من اشتراك شهري (اكتمال الشهر)'
      );
    end if;

    update public.captain_subscriptions
      set payout_status = 'fully_paid_out', second_half_paid_at = now(), updated_at = now()
      where id = v_sub.id;
  end loop;

  -- Renewal, escrow mode: expired cycle, auto-recharge the same
  -- agreed_price from the customer's wallet and start a fresh 30-day/
  -- staged-payout cycle. Silently lapses (stays "active" in name only,
  -- but expires_at is in the past so every eligibility check already
  -- treats it as inactive) if the balance isn't there - not a dispute,
  -- just a normal non-renewal.
  for v_sub in
    select * from public.captain_subscriptions
    where status = 'active'
      and renewal_mode = 'escrow'
      and expires_at is not null
      and expires_at <= now()
      and not payment_dispute
    for update
  loop
    select * into v_wallet from public.wallets where user_id = v_sub.customer_id for update;
    if found and v_wallet.balance >= v_sub.agreed_price then
      v_before := v_wallet.balance;
      v_after := v_before - v_sub.agreed_price;

      update public.wallets set balance = v_after where id = v_wallet.id;
      insert into public.wallet_transactions (
        wallet_id, user_id, type, amount, balance_before, balance_after,
        is_credit, reference_type, reference_id, description
      ) values (
        v_wallet.id, v_sub.customer_id, 'payment', v_sub.agreed_price, v_before, v_after,
        false, 'captain_subscription', v_sub.id, 'تجديد اشتراك شهري مع كابتن'
      );

      update public.captain_subscriptions
        set payout_status = 'pending_first_half',
            first_half_paid_at = null,
            second_half_paid_at = null,
            cycle_count = v_sub.cycle_count + 1,
            started_at = now(),
            expires_at = now() + interval '30 days',
            updated_at = now()
        where id = v_sub.id;
    end if;
  end loop;

  -- Renewal, trusted mode: open the confirmation window once the cycle
  -- expires (customer_confirm_subscription_payment/
  -- captain_confirm_subscription_payment below apply the renewal the
  -- moment both sides have confirmed - this loop only ever opens the
  -- window, it never itself extends anything).
  update public.captain_subscriptions
    set renewal_window_opened_at = now(), updated_at = now()
    where status = 'active'
      and renewal_mode = 'trusted'
      and expires_at is not null
      and expires_at <= now()
      and renewal_window_opened_at is null
      and not payment_dispute;

  -- Trusted mode, unconfirmed after 5 days: flag for admin rather than
  -- guess who's telling the truth.
  update public.captain_subscriptions
    set payment_dispute = true,
        dispute_reason = 'لم يتم تأكيد دفع تجديد الاشتراك المباشر من الطرفين خلال 5 أيام',
        updated_at = now()
    where status = 'active'
      and renewal_mode = 'trusted'
      and renewal_window_opened_at is not null
      and renewal_window_opened_at <= now() - interval '5 days'
      and not (customer_confirmed_renewal_at is not null and captain_confirmed_renewal_at is not null)
      and not payment_dispute;
end;
$$;

-- Customer confirms they paid this cycle's subscription directly to the
-- captain (trusted mode only). Applies the renewal immediately if the
-- captain had already confirmed first.
create or replace function public.customer_confirm_subscription_payment(p_subscription_id uuid)
returns public.captain_subscriptions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sub public.captain_subscriptions;
begin
  select * into v_sub from public.captain_subscriptions where id = p_subscription_id for update;
  if not found then
    raise exception 'Subscription thread not found';
  end if;
  if v_sub.customer_id <> auth.uid() then
    raise exception 'Not authorized';
  end if;
  if v_sub.status <> 'active' or v_sub.renewal_mode <> 'trusted' then
    raise exception 'SUBSCRIPTION_NOT_AWAITING_CONFIRMATION';
  end if;

  update public.captain_subscriptions
    set customer_confirmed_renewal_at = now(), updated_at = now()
    where id = p_subscription_id
    returning * into v_sub;

  if v_sub.captain_confirmed_renewal_at is not null then
    v_sub := public.apply_subscription_renewal(p_subscription_id);
  end if;

  return v_sub;
end;
$$;

-- Captain confirms the customer paid them directly this cycle (trusted
-- mode only). Applies the renewal immediately if the customer had already
-- confirmed first.
create or replace function public.captain_confirm_subscription_payment(p_subscription_id uuid)
returns public.captain_subscriptions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sub public.captain_subscriptions;
begin
  select * into v_sub from public.captain_subscriptions where id = p_subscription_id for update;
  if not found then
    raise exception 'Subscription thread not found';
  end if;
  if v_sub.captain_id <> auth.uid() then
    raise exception 'Not authorized';
  end if;
  if v_sub.status <> 'active' or v_sub.renewal_mode <> 'trusted' then
    raise exception 'SUBSCRIPTION_NOT_AWAITING_CONFIRMATION';
  end if;

  update public.captain_subscriptions
    set captain_confirmed_renewal_at = now(), updated_at = now()
    where id = p_subscription_id
    returning * into v_sub;

  if v_sub.customer_confirmed_renewal_at is not null then
    v_sub := public.apply_subscription_renewal(p_subscription_id);
  end if;

  return v_sub;
end;
$$;

-- Shared by both confirm functions above: once both sides have confirmed
-- a trusted-mode renewal, pull the platform's flat commission from the
-- CAPTAIN's wallet (the rest changed hands directly, off-platform) and
-- extend the cycle. Supabase exposes every public-schema function as a
-- callable RPC regardless of intent, so this re-checks both confirmations
-- itself (rather than trusting its two callers to have already checked) -
-- calling it directly can never apply a renewal nobody actually confirmed.
create or replace function public.apply_subscription_renewal(p_subscription_id uuid)
returns public.captain_subscriptions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sub public.captain_subscriptions;
  v_wallet public.wallets;
begin
  select * into v_sub from public.captain_subscriptions where id = p_subscription_id for update;
  if not found
    or v_sub.status <> 'active'
    or v_sub.renewal_mode <> 'trusted'
    or v_sub.customer_confirmed_renewal_at is null
    or v_sub.captain_confirmed_renewal_at is null
  then
    return v_sub;
  end if;

  select * into v_wallet from public.wallets where user_id = v_sub.captain_id for update;
  if found and v_wallet.balance >= v_sub.commission_amount then
    update public.wallets set balance = balance - v_sub.commission_amount where id = v_wallet.id;
    insert into public.wallet_transactions (
      wallet_id, user_id, type, amount, balance_before, balance_after,
      is_credit, reference_type, reference_id, description
    ) values (
      v_wallet.id, v_sub.captain_id, 'commission', v_sub.commission_amount,
      v_wallet.balance, v_wallet.balance - v_sub.commission_amount,
      false, 'captain_subscription_renewal', v_sub.id, 'عمولة تجديد اشتراك شهري (دفع مباشر)'
    );
  end if;

  update public.captain_subscriptions
    set cycle_count = v_sub.cycle_count + 1,
        started_at = now(),
        expires_at = now() + interval '30 days',
        renewal_window_opened_at = null,
        customer_confirmed_renewal_at = null,
        captain_confirmed_renewal_at = null,
        updated_at = now()
    where id = p_subscription_id
    returning * into v_sub;

  return v_sub;
end;
$$;

-- Customer opts a currently-active subscription into direct/"موثوق"
-- renewal from its next cycle onward (or back into the default escrow
-- flow) - takes effect at the next expiry, never touches the cycle
-- already in progress.
create or replace function public.customer_set_subscription_renewal_mode(
  p_subscription_id uuid,
  p_mode text
)
returns public.captain_subscriptions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sub public.captain_subscriptions;
begin
  if p_mode not in ('escrow', 'trusted') then
    raise exception 'Invalid renewal mode: %', p_mode;
  end if;

  select * into v_sub from public.captain_subscriptions where id = p_subscription_id for update;
  if not found then
    raise exception 'Subscription thread not found';
  end if;
  if v_sub.customer_id <> auth.uid() then
    raise exception 'Not authorized';
  end if;
  if v_sub.status <> 'active' then
    raise exception 'SUBSCRIPTION_NOT_ACTIVE';
  end if;

  update public.captain_subscriptions
    set renewal_mode = p_mode, updated_at = now()
    where id = p_subscription_id
    returning * into v_sub;

  return v_sub;
end;
$$;

-- Shared by the two cancel-an-active-subscription wrappers below: ends the
-- subscription, and if the captain's escrowed net share isn't fully paid
-- out yet, flags the held amount for admin review rather than guessing
-- who it belongs to (see migration header). p_cancelled_by only affects
-- the recorded reason text. Ownership is verified by each wrapper before
-- calling this, same defense-in-depth reasoning as
-- apply_subscription_renewal above.
create or replace function public.cancel_active_subscription(
  p_subscription_id uuid,
  p_cancelled_by text
)
returns public.captain_subscriptions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sub public.captain_subscriptions;
  v_net numeric;
  v_remaining numeric;
begin
  select * into v_sub from public.captain_subscriptions where id = p_subscription_id for update;
  if not found or v_sub.status <> 'active' then
    return v_sub;
  end if;

  if v_sub.payout_status is not null and v_sub.payout_status <> 'fully_paid_out' then
    v_net := v_sub.agreed_price - v_sub.commission_amount;
    v_remaining := case
      when v_sub.payout_status = 'pending_first_half' then v_net
      else v_net - round(v_net / 2.0, 2)
    end;
    update public.captain_subscriptions
      set status = 'cancelled',
          payment_dispute = true,
          dispute_reason = case p_cancelled_by
            when 'captain' then 'ألغى الكابتن الاشتراك قبل صرف كامل مستحقاته'
            else 'ألغى الزبون الاشتراك قبل صرف كامل مستحقات الكابتن'
          end,
          dispute_amount = v_remaining,
          updated_at = now()
      where id = p_subscription_id
      returning * into v_sub;
  else
    update public.captain_subscriptions
      set status = 'cancelled', updated_at = now()
      where id = p_subscription_id
      returning * into v_sub;
  end if;

  return v_sub;
end;
$$;

-- Ends an ACTIVE subscription early (there was previously no way to
-- cancel one at all - customer_cancel_subscription only ever covered the
-- pre-payment 'negotiating' stage).
create or replace function public.customer_cancel_active_subscription(p_subscription_id uuid)
returns public.captain_subscriptions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sub public.captain_subscriptions;
begin
  select * into v_sub from public.captain_subscriptions where id = p_subscription_id;
  if not found then
    raise exception 'Subscription thread not found';
  end if;
  if v_sub.customer_id <> auth.uid() then
    raise exception 'Not authorized';
  end if;
  if v_sub.status <> 'active' then
    raise exception 'SUBSCRIPTION_NOT_ACTIVE';
  end if;

  return public.cancel_active_subscription(p_subscription_id, 'customer');
end;
$$;

-- Captain-side counterpart of customer_cancel_active_subscription - for
-- the captain app (a separate codebase) to let a captain end an active
-- subscription too, same dispute-flagging behavior either way.
create or replace function public.captain_cancel_active_subscription(p_subscription_id uuid)
returns public.captain_subscriptions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sub public.captain_subscriptions;
begin
  select * into v_sub from public.captain_subscriptions where id = p_subscription_id;
  if not found then
    raise exception 'Subscription thread not found';
  end if;
  if v_sub.captain_id <> auth.uid() then
    raise exception 'Not authorized';
  end if;
  if v_sub.status <> 'active' then
    raise exception 'SUBSCRIPTION_NOT_ACTIVE';
  end if;

  return public.cancel_active_subscription(p_subscription_id, 'captain');
end;
$$;

-- Admin marks a flagged dispute as resolved after making whatever wallet
-- correction they decided on via the existing Finance > Wallets screen
-- (admin_adjust_wallet_balance, 20260712000028_admin_functions.sql) - this
-- function only clears the flag and records why, it never moves money
-- itself.
create or replace function public.admin_dismiss_subscription_dispute(
  p_subscription_id uuid,
  p_notes text
)
returns public.captain_subscriptions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sub public.captain_subscriptions;
begin
  if not public.has_admin_role('finance_admin') then
    raise exception 'Only finance_admin or super_admin may resolve subscription disputes';
  end if;
  if p_notes is null or btrim(p_notes) = '' then
    raise exception 'A resolution note is required';
  end if;

  update public.captain_subscriptions
    set payment_dispute = false, admin_dispute_notes = p_notes, updated_at = now()
    where id = p_subscription_id
    returning * into v_sub;

  if not found then
    raise exception 'Subscription thread not found';
  end if;

  perform public.log_admin_action(
    'subscription_dispute_resolved', 'captain_subscription', p_subscription_id::text,
    null, null, p_notes
  );

  return v_sub;
end;
$$;

-- customer_subscription_status: identical to
-- 20260812000056_captain_subscriptions.sql plus the new staged-payout/
-- renewal-mode/dispute fields the customer app's UI needs (progress
-- toward the "موثوق" toggle, a pending renewal-confirmation prompt, a
-- dispute-under-review banner).
create or replace function public.customer_subscription_status()
returns table (
  id uuid,
  captain_id uuid,
  captain_name text,
  captain_avatar_url text,
  captain_phone text,
  vehicle_brand text,
  vehicle_model text,
  vehicle_color text,
  status text,
  proposed_price numeric,
  proposed_by text,
  agreed_price numeric,
  started_at timestamptz,
  expires_at timestamptz,
  payout_status text,
  renewal_mode text,
  cycle_count integer,
  renewal_window_opened_at timestamptz,
  customer_confirmed_renewal_at timestamptz,
  captain_confirmed_renewal_at timestamptz,
  payment_dispute boolean,
  dispute_reason text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    s.id, s.captain_id, p.full_name, c.avatar_url, p.phone,
    c.vehicle_brand, c.vehicle_model, c.vehicle_color,
    s.status, s.proposed_price, s.proposed_by, s.agreed_price,
    s.started_at, s.expires_at,
    s.payout_status, s.renewal_mode, s.cycle_count,
    s.renewal_window_opened_at, s.customer_confirmed_renewal_at, s.captain_confirmed_renewal_at,
    s.payment_dispute, s.dispute_reason
  from public.captain_subscriptions s
  join public.captains c on c.id = s.captain_id
  join public.profiles p on p.id = s.captain_id
  where s.customer_id = auth.uid()
    and (
      (s.status = 'active' and s.expires_at > now())
      -- Still 'active' but past expires_at, awaiting both sides'
      -- trusted-mode renewal confirmation (see run_subscription_
      -- housekeeping) - must still surface here, or the customer would
      -- have no way to discover the confirmation prompt is waiting.
      or (s.status = 'active' and s.renewal_window_opened_at is not null)
      or s.status = 'negotiating'
      or s.payment_dispute
    )
  order by (s.status = 'active') desc, s.updated_at desc
  limit 1;
$$;

-- Admin-facing read of every flagged subscription, enriched enough to act
-- on (who to credit/debit and by how much) without a second round trip.
create or replace function public.admin_list_subscription_disputes()
returns table (
  id uuid,
  customer_id uuid,
  customer_name text,
  captain_id uuid,
  captain_name text,
  dispute_reason text,
  dispute_amount numeric,
  agreed_price numeric,
  cycle_count integer,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    s.id, s.customer_id, cp.full_name, s.captain_id, kp.full_name,
    s.dispute_reason, s.dispute_amount, s.agreed_price, s.cycle_count, s.updated_at
  from public.captain_subscriptions s
  join public.profiles cp on cp.id = s.customer_id
  join public.profiles kp on kp.id = s.captain_id
  where s.payment_dispute = true and public.has_admin_role('finance_admin')
  order by s.updated_at desc;
$$;
