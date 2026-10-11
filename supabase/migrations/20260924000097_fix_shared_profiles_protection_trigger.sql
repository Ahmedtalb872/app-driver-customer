-- Root cause of the "تعذر حفظ كلمة السر الآن" signup/login failures
-- (PostgrestException 42703, "record \"new\" has no field ...") that showed
-- up one column at a time as trips_count, then rating, then is_admin:
--
-- This app and the sibling captain app (aihoudhoud) share one Supabase
-- project/database. public.profiles is the SAME physical table for both
-- apps - this app's own migration only ever added id/full_name/phone/role
-- (20260712000001_create_profiles.sql), but aihoudhoud's
-- 0029_lock_down_self_update_columns.sql installed a `before update on
-- public.profiles` trigger, public.reject_protected_column_self_edit(),
-- that unconditionally reads new.wallet_balance/new.is_admin/new.rating/
-- new.trips_count/new.acceptance_rate/new.cancellation_rate - columns that
-- only ever existed on aihoudhoud's own captain-oriented profiles shape.
-- Any UPDATE to a customer's profiles row (e.g. saving full_name right
-- after choosing a password) fires that same trigger and 42703s on
-- whichever of those columns is still missing. Manually ALTER TABLE-ing
-- each missing column in the SQL editor (as done so far) only shifts which
-- column fails next - it doesn't fix the trigger itself, and the very next
-- new captain-side column this trigger starts protecting would reproduce
-- the exact same failure again.
--
-- Real fix: make the shared trigger function tolerant of either app's
-- profiles shape by checking column presence via to_jsonb(...) ? '<col>'
-- before comparing, instead of assuming every listed column always
-- exists. Behavior for rows/columns that *do* exist (this is still the
-- correct place to guard trips_count/rating/is_admin/wallet_balance/
-- acceptance_rate/cancellation_rate against a captain or customer editing
-- their own row directly via the REST API - see aihoudhoud's
-- 0029_lock_down_self_update_columns.sql for the full threat model) is
-- unchanged; a column that's simply absent on a given table's current
-- shape is now treated as "not editable, so not a protected-column edit"
-- instead of crashing the entire update.
create or replace function public.reject_protected_column_self_edit()
returns trigger
language plpgsql
as $$
declare
  new_j jsonb;
  old_j jsonb;
begin
  if current_user = 'authenticated' then
    if tg_table_name = 'profiles' then
      new_j := to_jsonb(new);
      old_j := to_jsonb(old);
      if (new_j ? 'wallet_balance' and old_j ? 'wallet_balance'
            and new_j -> 'wallet_balance' is distinct from old_j -> 'wallet_balance')
        or (new_j ? 'is_admin' and old_j ? 'is_admin'
            and new_j -> 'is_admin' is distinct from old_j -> 'is_admin')
        or (new_j ? 'rating' and old_j ? 'rating'
            and new_j -> 'rating' is distinct from old_j -> 'rating')
        or (new_j ? 'trips_count' and old_j ? 'trips_count'
            and new_j -> 'trips_count' is distinct from old_j -> 'trips_count')
        or (new_j ? 'acceptance_rate' and old_j ? 'acceptance_rate'
            and new_j -> 'acceptance_rate' is distinct from old_j -> 'acceptance_rate')
        or (new_j ? 'cancellation_rate' and old_j ? 'cancellation_rate'
            and new_j -> 'cancellation_rate' is distinct from old_j -> 'cancellation_rate')
      then
        raise exception 'protected_column_self_edit: profiles';
      end if;
    elsif tg_table_name = 'captains' then
      if new.status is distinct from old.status then
        raise exception 'protected_column_self_edit: captains';
      end if;
    end if;
  end if;
  return new;
end;
$$;
