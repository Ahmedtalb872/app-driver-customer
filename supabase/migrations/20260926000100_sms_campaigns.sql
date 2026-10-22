-- Real backing for the admin dashboard's "حملات SMS" section: sends a
-- promotional SMS (a link + discount code - Chinguisoft's fixed "SMS
-- Campaign" template, see chinguisoft.com/sn) to every customer and/or
-- captain with a phone number. Mirrors
-- 20260817000080_customer_push_broadcasts.sql's push-broadcast history
-- shape exactly (notification_broadcasts -> sms_campaign_broadcasts) -
-- only the admin-facing history log; the actual send happens in the
-- send-sms-campaign Edge Function (service role, bypasses RLS to insert
-- here).

create table if not exists public.sms_campaign_broadcasts (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  promo_url text not null,
  promo_code text not null,
  audience text not null default 'customers'
    check (audience in ('customers', 'captains', 'both')),
  recipient_count integer not null default 0,
  sent_by uuid references auth.users (id),
  sent_at timestamptz not null default now()
);

alter table public.sms_campaign_broadcasts enable row level security;

drop policy if exists "Admins can read sms campaign history" on public.sms_campaign_broadcasts;
create policy "Admins can read sms campaign history"
  on public.sms_campaign_broadcasts for select
  to authenticated
  using (public.is_admin());
