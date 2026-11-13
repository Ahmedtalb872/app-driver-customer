-- New regulated fare structure for the economy tier, matching the pricing
-- competing ride-hailing apps (e.g. ClassRide) are rolling out under the
-- same regulatory mandate: 90 MRU flat for the first 2.5km (was 100 for
-- the first 3km), then 27 MRU/km beyond that (was 23).
--
-- Only 'economy' is touched here - comfort/family/motorcycle keep their
-- current pricing untouched.
update public.pricing_config
set base_fare = 90,
    minimum_fare = 90,
    price_per_km = 27,
    base_distance_km = 2.5
where vehicle_type = 'economy';
