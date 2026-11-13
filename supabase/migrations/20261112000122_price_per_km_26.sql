-- Lowers the per-km rate from 27 to 26 MRU/km for every car tier (same
-- group 20260830000085_classride_pricing_all_cars.sql set to 27) - base
-- fare (90 MRU flat for the first 2.5km) and minimum fare are untouched.
-- motorcycle (delivery) stays excluded, same reasoning as that migration:
-- delivery must always price lower than any car trip.
update public.pricing_config
set price_per_km = 26
where vehicle_type in ('economy', 'comfort', 'family');
