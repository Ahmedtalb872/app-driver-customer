-- Extends the ClassRide-matching regulated fare structure
-- (20260830000084_economy_regulated_pricing.sql, economy only) to every
-- car tier: 90 MRU flat for the first 2.5km, then 27 MRU/km beyond that.
--
-- motorcycle (delivery) is deliberately excluded - see
-- 20260801000046_delivery_service.sql's comment: delivery must always
-- price lower than any car trip, which this same rate would break.
update public.pricing_config
set base_fare = 90,
    minimum_fare = 90,
    price_per_km = 27,
    base_distance_km = 2.5
where vehicle_type in ('economy', 'comfort', 'family');
