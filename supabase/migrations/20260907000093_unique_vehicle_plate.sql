-- Prevents the same vehicle plate from being registered on more than one
-- captain account. vehicle_plate (20260712000027) was a plain text column
-- with no uniqueness at all - nothing stopped a second captain from typing
-- in a plate already claimed by someone else, whether by mistake or to
-- impersonate/hide behind another driver's known vehicle.
--
-- Normalized (uppercased, all whitespace stripped) before comparing so
-- "1234 AB" / "1234ab" / "1234  AB" are all treated as the same plate
-- rather than three different strings that happen to collide only when
-- typed identically. NULL/blank plates are excluded - a plate not filled
-- in yet (or never applicable) isn't a real collision.
create unique index if not exists captains_vehicle_plate_unique
  on public.captains (upper(regexp_replace(vehicle_plate, '\s+', '', 'g')))
  where vehicle_plate is not null and btrim(vehicle_plate) <> '';
