-- Revises the rate from 20260812000061 (0.26 UM/meter) down to 0.23
-- UM/meter (= 230 UM/km) for a normal (economy) ride. minimum_fare stays
-- 100 UM, unchanged. Only 'economy' is touched - see 000061 for why.
update public.pricing_config
set price_per_km = 230
where vehicle_type = 'economy';
