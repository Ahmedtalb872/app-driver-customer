-- Confirmed with the customer: apply the same 0.023 UM/meter (23 UM/km)
-- rate set for 'economy' (20260812000063) to the 'family' ("عائلية" -
-- bigger car, 1-6 passengers) tier as well. minimum_fare is untouched here -
-- it's already 100 UM by default for every tier
-- (20260712000024_create_pricing_config.sql).
update public.pricing_config
set price_per_km = 23
where vehicle_type = 'family';
