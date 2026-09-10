-- Real account deletion. The settings screen already had a "حذف الحساب
-- نهائياً" button promising "هذا الإجراء نهائي ولا يمكن الرجوع عنه وستفقد
-- جميع بياناتك" - but it only called _handleLogout(), so the account and
-- every row of its data stayed in the database and the customer could
-- simply log back in. Besides being a plain correctness bug (the dialog
-- lied), App Store guideline 5.1.1(v) requires any app offering account
-- creation to also offer in-app account deletion, so a reviewer testing
-- that button would have found the account intact and rejected the app.
--
-- trips.customer_id was `not null` with no ON DELETE action, which would
-- have made any real delete fail on a foreign key violation. Trips are
-- retained (customer link nulled) rather than deleted, because they carry
-- the captain's completed-work and earnings history - deleting them would
-- silently rewrite other people's financial records. Everything that is
-- actually personal (profile, wallet, saved places, ratings, device
-- token) is hard-deleted via the existing ON DELETE CASCADE chain
-- auth.users -> profiles -> customers.
--
-- Already null-safe for this change: captain_end_trip and
-- notify_new_trip_request both guard `customer_id is not null`, the Dart
-- Trip model has no customerId field at all, and the two admin screens
-- that show a trip's customer read it with `?.` optional chaining.
alter table public.trips
  alter column customer_id drop not null;

alter table public.trips
  drop constraint if exists trips_customer_id_fkey;

alter table public.trips
  add constraint trips_customer_id_fkey
  foreign key (customer_id) references public.customers (id)
  on delete set null;

create or replace function public.customer_delete_account()
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  -- Refuse while a trip is still running: a captain may be driving toward
  -- them right now, and the trip needs a customer to complete against.
  if exists (
    select 1 from public.trips
    where customer_id = v_uid
      and status in ('searching', 'accepted', 'arrived', 'boarded', 'in_progress')
  ) then
    raise exception 'ACTIVE_TRIP';
  end if;

  -- Refuse while Selefli money is still owed - deleting the account would
  -- otherwise be a way to walk away from an unpaid balance.
  if exists (
    select 1 from public.selefli_debts
    where customer_id = v_uid and status = 'outstanding'
  ) then
    raise exception 'OUTSTANDING_DEBT';
  end if;

  -- Cascades: auth.users -> profiles -> customers -> wallets,
  -- saved_places, selefli_debts, captain_subscriptions. trips survive
  -- with customer_id set to null (see the FK change above).
  delete from auth.users where id = v_uid;
end;
$$;

revoke all on function public.customer_delete_account() from public;
grant execute on function public.customer_delete_account() to authenticated;
