-- URGENT HOTFIX: login (and anything else that reads captains/profiles
-- under RLS) is currently broken with Postgres error 42P17 "infinite
-- recursion detected in policy for relation \"trips\"".
--
-- Root cause: the two new policies added in
-- 20260812000056_captain_subscriptions.sql ("Captains viewable by a
-- related customer", "Profiles viewable by a related customer") embed a
-- raw `exists (select 1 from public.trips where ...)` subquery directly in
-- their USING clause. But public.trips already has a SELECT policy
-- ("Open trip requests are visible to active captains",
-- 20260801000046_delivery_service.sql) that itself embeds a subquery
-- against public.captains (`exists (select 1 from public.captains c where
-- c.id = auth.uid() ...)`). Evaluating one policy now requires evaluating
-- the other, which requires evaluating the first again - an infinite
-- cycle Postgres detects and refuses to run.
--
-- The fix: move the trips/captain_subscriptions relationship check into a
-- SECURITY DEFINER function. Like every other SECURITY DEFINER function in
-- this project, it runs with the function owner's privileges and so does
-- not re-trigger RLS on the tables it queries internally - calling it from
-- a policy's USING clause can never recurse back into that same policy,
-- unlike an inline subquery.
create or replace function public.customer_related_to_captain(p_captain_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.trips
    where trips.captain_id = p_captain_id and trips.customer_id = auth.uid()
  ) or exists (
    select 1 from public.captain_subscriptions
    where captain_subscriptions.captain_id = p_captain_id
      and captain_subscriptions.customer_id = auth.uid()
  );
$$;

drop policy if exists "Captains viewable by a related customer" on public.captains;
create policy "Captains viewable by a related customer"
  on public.captains for select
  to authenticated
  using (public.customer_related_to_captain(captains.id));

drop policy if exists "Profiles viewable by a related customer" on public.profiles;
create policy "Profiles viewable by a related customer"
  on public.profiles for select
  to authenticated
  using (public.customer_related_to_captain(profiles.id));
