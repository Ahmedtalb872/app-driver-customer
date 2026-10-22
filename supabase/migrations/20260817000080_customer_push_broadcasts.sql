-- Lets the admin dashboard broadcast a push notification to every customer
-- (see send-broadcast-push Edge Function) - fills the "لا يوجد جدول
-- notifications" gap the /admin/notifications placeholder called out.
--
-- customers.fcm_token mirrors captains.fcm_token
-- (0017_trip_push_notifications.sql in the aihoudhoud repo) - same shared
-- Firebase project, a customer-app Android app just needs registering
-- under it (see lib/core/services/push_notifications.dart for the client
-- side); the existing FIREBASE_SERVICE_ACCOUNT_JSON Edge Function secret
-- that send-trip-push already relies on works for any app in that same
-- Firebase project, so no new secret is needed for this.
alter table public.customers
  add column if not exists fcm_token text;

-- public.is_admin() (20260712000006_rls_policies.sql) always checks
-- auth.uid(), which is empty when called by a service-role client with no
-- user session - send-broadcast-push authenticates the caller itself
-- (verifies their JWT) and needs to check *that* uid's admin status
-- explicitly instead.
create or replace function public.is_admin_uid(p_uid uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = p_uid and role = 'admin'
  );
$$;

create table if not exists public.notification_broadcasts (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  recipient_count integer not null default 0,
  sent_by uuid references auth.users (id),
  sent_at timestamptz not null default now()
);

alter table public.notification_broadcasts enable row level security;

drop policy if exists "Admins can read notification broadcast history" on public.notification_broadcasts;
create policy "Admins can read notification broadcast history"
  on public.notification_broadcasts for select
  to authenticated
  using (public.is_admin());

-- No insert policy for the authenticated role - the Edge Function writes
-- this log using the service-role key (bypasses RLS entirely), same as
-- every other server-side-only write in this project.
