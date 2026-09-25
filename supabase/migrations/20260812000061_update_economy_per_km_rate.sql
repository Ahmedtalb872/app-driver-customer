-- Requested pricing change: 0.26 UM per meter (= 260 UM per km) for a
-- normal (economy) ride, with a 100 UM minimum fare per trip. The minimum
-- was already 100 by default (20260712000024_create_pricing_config.sql),
-- restated here so this migration is a complete, self-contained record of
-- the intended rate rather than relying on that default having survived
-- untouched. Only 'economy' is touched - it's the only tier the customer
-- app actually charges through (RequestRideScreen hardcodes
-- VehicleType.economy; 'comfort'/'family' rows exist in pricing_config but
-- nothing in the app currently requests either).
update public.pricing_config
set price_per_km = 260, minimum_fare = 100
where vehicle_type = 'economy';
