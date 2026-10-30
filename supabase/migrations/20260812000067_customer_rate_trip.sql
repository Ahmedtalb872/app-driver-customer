-- Lets a customer rate their captain (1-5 stars, optional written note)
-- right after a trip completes - TripSummaryScreen currently ends with a
-- plain "back to home" button and no way to leave feedback at all.
--
-- public.captains.rating/ratings_count have existed since
-- 20260812000056_captain_subscriptions.sql (added for browsable_captains'
-- directory listing) but nothing has ever actually written to them - every
-- captain has shown up with a null rating. customer_rate_trip below is the
-- first and only writer, keeping a running average.

alter table public.trips
  add column if not exists customer_rating integer
    check (customer_rating between 1 and 5);

alter table public.trips
  add column if not exists customer_rating_note text;

alter table public.trips
  add column if not exists customer_rated_at timestamptz;

create or replace function public.customer_rate_trip(
  p_trip_id uuid,
  p_rating integer,
  p_note text default null
)
returns public.trips
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.trips;
begin
  if p_rating is null or p_rating < 1 or p_rating > 5 then
    raise exception 'RATING_OUT_OF_RANGE';
  end if;

  -- The `customer_rating is null` guard is what makes this idempotent -
  -- exactly like captain_end_trip's `status = 'in_progress'` guard - so a
  -- retried call (or a double-tap) can never double-count the same trip
  -- into the captain's aggregate rating below.
  update public.trips
    set customer_rating = p_rating,
        customer_rating_note = nullif(btrim(coalesce(p_note, '')), ''),
        customer_rated_at = now()
    where id = p_trip_id
      and customer_id = auth.uid()
      and status = 'completed'
      and customer_rating is null
    returning * into v_row;

  if not found then
    raise exception 'TRIP_ALREADY_RATED_OR_INVALID';
  end if;

  if v_row.captain_id is not null then
    update public.captains
      set ratings_count = ratings_count + 1,
          rating = round(
            (coalesce(rating, 0) * ratings_count + p_rating)
              / (ratings_count + 1)::numeric,
            1
          )
      where id = v_row.captain_id;
  end if;

  return v_row;
end;
$$;
