-- Requested: a customer can save MULTIPLE homes (e.g. "بيت الوالد" و"بيت
-- الزوجة"), not just one that gets overwritten every time - shown as a
-- pick-list when tapping "المنزل" on the trip planner screen if there's
-- more than one, and the customer is asked to name it when saving a new
-- one from the post-trip "احفظ هذا الموقع" prompt. 'work'/'other' stay
-- single-slot as before.
alter table public.saved_places
  add column if not exists custom_name text;

-- Drop the old "exactly one row per (customer, label)" constraint...
alter table public.saved_places
  drop constraint if exists saved_places_customer_id_label_key;

-- ...and replace it with a partial index that only enforces that for
-- 'work'/'other' - a 'home' row never matches this index's predicate, so
-- inserting any number of them never conflicts. SavedPlacesRepository
-- keeps using upsert(onConflict: 'customer_id,label') for work/other
-- (still governed by this index) and a plain insert for home (ungoverned,
-- so it always adds a new row).
create unique index if not exists saved_places_single_slot_idx
  on public.saved_places (customer_id, label)
  where label in ('work', 'other');
