-- Requested: a normal ride's price should be distance-based only (plus the
-- flat base fare) - time spent should never factor in. Only touches the
-- non-open branch of captain_end_trip (trip_type <> 'open', which also
-- covers deliveries - they're always trip_type = 'normal' too, see
-- customer_request_trip); the open-trip flat-fare/threshold formula
-- (20260729000042_open_trip_base_fare.sql) is untouched.
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
    -- Flat open_trip_base_fare covers up to open_trip_base_distance_km AND
    -- up to open_trip_base_minutes; only whichever portion exceeds its own
    -- threshold is charged extra, so a trip that stays within both is
    -- exactly the flat fare regardless of how it split between the two.
    v_extra_km := greatest(p_final_distance_km - v_pricing.open_trip_base_distance_km, 0);
    v_extra_minutes := greatest(v_duration_minutes - v_pricing.open_trip_base_minutes, 0);
    v_subtotal := v_pricing.open_trip_base_fare
      + (v_extra_km * v_pricing.price_per_km)
      + (v_extra_minutes * v_pricing.price_per_minute);
  else
    -- Normal ride (and delivery, also trip_type = 'normal'): distance-based
    -- only, no time component - requested explicitly, "الوقت لا يحسب في
    -- المشوار العادي".
    v_subtotal := v_pricing.base_fare
      + (greatest(p_final_distance_km, 0) * v_pricing.price_per_km);
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

  return v_trip;
end;
$$;
