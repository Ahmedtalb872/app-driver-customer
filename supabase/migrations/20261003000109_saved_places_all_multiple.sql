-- Requested: not just "المنزل" (home) - "العمل" (work) and "مكان آخر"
-- (other) should also let a customer save more than one, each named, with
-- a pick-list shown before auto-filling when there's more than one saved
-- under that label (trip_planner_screen.dart). The previous migration
-- (20261003000108) only lifted the one-per-label limit for 'home'; this
-- drops the remaining partial unique index so none of the three labels are
-- single-slot anymore - SavedPlacesRepository.savePlace now always just
-- inserts a new row for every label.
drop index if exists public.saved_places_single_slot_idx;
