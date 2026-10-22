-- Requested: a quick "المنزل / العمل / خيار آخر" (Home / Work / Other) pick
-- on the trip-request screen (trip_planner_screen.dart) to instantly fill
-- the destination from one of the customer's saved places, instead of
-- typing/searching it again. The existing third saved-places slot was
-- 'school' (محدد لمدرسة فقط) - renamed to a generic 'other' so it fits any
-- third place the customer wants to save, matching what was actually asked
-- for on both this screen and the post-trip save prompt (trip_summary_screen.dart).
update public.saved_places set label = 'other' where label = 'school';

alter table public.saved_places drop constraint if exists saved_places_label_check;
alter table public.saved_places
  add constraint saved_places_label_check
  check (label in ('home', 'work', 'other'));
