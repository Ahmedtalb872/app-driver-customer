-- Customer confirmed explicitly (pasted this exact statement back) after
-- the back-and-forth in 000063-000065: 'economy' should be 0.023 UM/meter
-- (23 UM/km) after all. 'family' stays at 230 (000065) - only economy was
-- reconfirmed here.
update public.pricing_config
set price_per_km = 23
where vehicle_type = 'economy';
