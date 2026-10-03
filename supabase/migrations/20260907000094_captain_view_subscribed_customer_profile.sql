-- Symmetric to "Profiles viewable by a related customer"
-- (20260812000056/customer_related_to_captain, 20260812000059) - lets a
-- customer read the profile of a captain they're negotiating/subscribed
-- with, but nothing let the reverse happen, so the captain app's new
-- incoming-subscription-offers list/chat (previously missing entirely)
-- had no way to show who the customer even was.
--
-- Uses a SECURITY DEFINER helper rather than an inline subquery in the
-- policy, same reasoning as customer_related_to_captain
-- (20260812000059): a function runs with its owner's privileges and so
-- never re-triggers RLS on the tables it queries internally, which rules
-- out the same class of "infinite recursion detected in policy" bug that
-- migration fixed - even though this particular case (captain_subscriptions'
-- own SELECT policy touches no other RLS-protected table) doesn't appear to
-- actually cycle, keeping every cross-role profile-visibility check on the
-- same safe pattern is worth the one extra function.
create or replace function public.captain_related_to_customer(p_customer_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.captain_subscriptions
    where captain_subscriptions.customer_id = p_customer_id
      and captain_subscriptions.captain_id = auth.uid()
  );
$$;

drop policy if exists "Profiles viewable by a related captain via subscription" on public.profiles;
create policy "Profiles viewable by a related captain via subscription"
  on public.profiles for select
  to authenticated
  using (public.captain_related_to_customer(profiles.id));
