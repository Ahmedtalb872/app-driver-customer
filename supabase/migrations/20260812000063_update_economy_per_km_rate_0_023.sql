-- Revises the rate from 20260812000062 (0.23 UM/meter) down to 0.023
-- UM/meter (= 23 UM/km) for a normal (economy) ride - confirmed with the
-- customer as an intentional new, much lower rate, not a typo of the
-- previous 0.23. minimum_fare stays 100 UM, unchanged. Only 'economy' is
-- touched - see 000061 for why.
update public.pricing_config
set price_per_km = 23
where vehicle_type = 'economy';
