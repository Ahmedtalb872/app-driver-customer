-- Regression fix: captain_end_trip got redefined twice after Selefli
-- shipped (20260813000070_normal_trip_price_ignores_time.sql, then
-- 20260815000071_normal_trip_flat_base_distance.sql) for unrelated pricing
-- changes, and both redefinitions carried forward the pricing logic but
-- dropped the customers.completed_trips_count increment and the
-- selefli_debts insert that 20260812000055_selefli_credit.sql had added.
-- Since 2026-08-13, every completed trip has silently stopped counting
-- toward Selefli eligibility (customer report: "أكمل 11 مشوار إضافي" never
-- decreases) and stopped creating a debt row for selefli-paid trips.
-- Restores both, on top of the current (20260815000071) pricing formula -
-- no pricing behavior changes here.
create or replace function public.captain_end_trip(
  p_trip_id uuid,
  p_final_distance_km numeric
)
returns public.trips
language plpgsql
security definer
set search_path = public
as $$
declare
  v_trip public.trips;
  v_pricing public.pricing_config;
  v_duration_minutes numeric;
  v_subtotal numeric;
  v_final_fare numeric;
  v_commission numeric;
  v_net numeric;
  v_wallet public.wallets;
  v_extra_km numeric;
  v_extra_minutes numeric;
begin
  select * into v_trip from public.trips
    where id = p_trip_id and captain_id = auth.uid() and status = 'in_progress'
    for update;

  if not found then
    raise exception 'TRIP_INVALID_STATE';
  end if;

  select * into v_pricing from public.pricing_config
    where vehicle_type = coalesce(v_trip.vehicle_type, 'economy');
  if not found then
    raise exception 'No pricing configuration for vehicle type %', v_trip.vehicle_type;
  end if;

  v_duration_minutes := greatest(
    extract(epoch from (now() - v_trip.started_at)) / 60.0, 0
  );

  if v_trip.trip_type = 'open' then
    v_extra_km := greatest(p_final_distance_km - v_pricing.open_trip_base_distance_km, 0);
    v_extra_minutes := greatest(v_duration_minutes - v_pricing.open_trip_base_minutes, 0);
    v_subtotal := v_pricing.open_trip_base_fare
      + (v_extra_km * v_pricing.price_per_km)
      + (v_extra_minutes * v_pricing.price_per_minute);
  else
    v_subtotal := v_pricing.base_fare
      + (greatest(p_final_distance_km - v_pricing.base_distance_km, 0) * v_pricing.price_per_km);
  end if;

  v_subtotal := v_subtotal * coalesce(v_pricing.surge_multiplier, 1.0);
  v_final_fare := greatest(v_subtotal, v_pricing.minimum_fare);
  v_commission := round(v_final_fare * coalesce(v_pricing.commission_percentage, 0) / 100.0, 2);
  v_net := round(v_final_fare - v_commission, 2);

  update public.trips
    set status = 'completed',
        completed_at = now(),
        distance_km = greatest(p_final_distance_km, 0),
        traveled_distance_km = greatest(p_final_distance_km, 0),
        actual_duration_minutes = round(v_duration_minutes)::integer,
        final_price = v_final_fare,
        commission_amount = v_commission,
        captain_net_earnings = v_net
    where id = p_trip_id
    returning * into v_trip;

  select * into v_wallet from public.wallets where user_id = v_trip.captain_id for update;
  if found then
    update public.wallets set balance = balance + v_net where id = v_wallet.id;
    insert into public.wallet_transactions (
      wallet_id, user_id, type, amount, balance_before, balance_after,
      is_credit, reference_type, reference_id, description
    ) values (
      v_wallet.id, v_trip.captain_id, 'adjustment', v_net,
      v_wallet.balance, v_wallet.balance + v_net,
      true, 'trip', v_trip.id, 'صافي أرباح مشوار مفتوح'
    );
  end if;

  if v_trip.customer_id is not null then
    update public.customers
      set completed_trips_count = completed_trips_count + 1
      where id = v_trip.customer_id;

    if v_trip.payment_method = 'selefli' then
      insert into public.selefli_debts (customer_id, trip_id, amount)
        values (v_trip.customer_id, v_trip.id, v_final_fare)
      on conflict (trip_id) do nothing;
    end if;
  end if;

  return v_trip;
end;
$$;

-- Backfill: recompute completed_trips_count for every customer from their
-- actual completed-trip history, since the count has been stuck since
-- 2026-08-13 regardless of how many trips customers finished in that
-- window - a plain re-increment from here on would leave everyone
-- permanently short by however many trips they completed while it was
-- broken.
update public.customers c
set completed_trips_count = coalesce((
  select count(*) from public.trips t
  where t.customer_id = c.id and t.status = 'completed'
), 0);
