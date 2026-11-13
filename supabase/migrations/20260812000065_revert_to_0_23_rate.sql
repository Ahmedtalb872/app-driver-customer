-- Customer rejected the 0.023 UM/meter rate (20260812000063/000064) right
-- after asking for it, and asked to keep "the same price" instead - the
-- last rate actually confirmed before that was 0.23 UM/meter
-- (= 230 UM/km, 20260812000062). Reverts both 'economy' and 'family' (which
-- had also picked up 0.023 via 000064) back to 230. minimum_fare stays
-- 100 UM, unchanged throughout.
update public.pricing_config
set price_per_km = 230
where vehicle_type in ('economy', 'family');
