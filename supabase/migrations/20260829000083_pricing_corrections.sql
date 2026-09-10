-- Pricing correction requested by the operator, three fixes to
-- public.pricing_config:
--
-- 1. The family tier's price_per_km got stuck at 230 (ten times the
--    intended rate) by an incident on 2026-08-12: a rate change was
--    applied to both economy and family as a temporary revert
--    (20260812000065_revert_to_0_23_rate.sql), then only economy was
--    brought back down (20260812000066_economy_rate_0_023_confirmed.sql)
--    - family was left behind at the reverted value. Corrected here to
--    match economy's 23.
--
-- 2. Platform commission lowered from 15% to 10% across every vehicle
--    type (economy, comfort, family, motorcycle/delivery) - a straight
--    business-rate change, not a bug fix.
--
-- 3. minimum_fare (100) and base_distance_km (3) reset explicitly on
--    every row. Both were already 100/3 for every tier per the migration
--    history, but are reasserted here in case any of the four rows drift
--    from a direct edit through the admin dashboard's pricing screen
--    (which writes straight to this table, leaving no migration trail).
--
-- No function change needed for the "no increase before 3km" rule: both
-- captain_end_trip's normal-trip branch and the open-trip branch already
-- read base_distance_km from this same table per vehicle_type
-- (20260816000077_restore_completed_trips_count.sql) -
--   greatest(final_distance_km - base_distance_km, 0) * price_per_km
-- - so a trip of base_distance_km or less has zero distance-based charge
-- for every vehicle type already, and this migration only has to make
-- sure that column reads 3 everywhere.

update public.pricing_config
set price_per_km = 23
where vehicle_type = 'family';

update public.pricing_config
set commission_percentage = 10;

update public.pricing_config
set minimum_fare = 100,
    base_distance_km = 3;
