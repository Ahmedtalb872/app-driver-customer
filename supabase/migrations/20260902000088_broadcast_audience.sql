-- Lets the admin dashboard's broadcast notification (send-broadcast-push)
-- target captains as well as customers - previously it only ever queried
-- public.customers, even though public.captains.fcm_token has existed all
-- along (mirrored by customers.fcm_token, see
-- 20260817000080_customer_push_broadcasts.sql's own comment) and this same
-- dashboard already manages captains (admin_captains_screen.dart) just as
-- much as customers.
alter table public.notification_broadcasts
  add column if not exists audience text not null default 'customers'
    check (audience in ('customers', 'captains', 'both'));
