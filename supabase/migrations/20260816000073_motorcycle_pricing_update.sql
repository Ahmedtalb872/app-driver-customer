-- Requested: motorcycle delivery pricing - minimum_fare 100 (was 70),
-- price_per_km 22 (0.022/meter, was 15) for distance beyond
-- base_distance_km. base_fare/base_distance_km unchanged (35/3km) - they
-- stay dominated by the higher minimum_fare within that first 3km, same
-- shape as before, just with the new floor/rate values.
update public.pricing_config
set minimum_fare = 100,
    price_per_km = 22
where vehicle_type = 'motorcycle';
