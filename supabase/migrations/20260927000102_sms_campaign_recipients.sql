-- Per-recipient tracking for SMS campaigns, so a large batch (e.g.
-- recruiting ~170 prospective captains) shows a real per-number result
-- instead of just one aggregate count, and can be resumed safely if a
-- single Edge Function call runs out of execution time partway through -
-- see send-sms-campaign, which now sends sequentially (with an
-- admin-configurable delay between each, to avoid tripping Chinguisoft's
-- own rate limiting) instead of all at once in parallel, and writes each
-- recipient's outcome immediately rather than only at the very end.
create table if not exists public.sms_campaign_recipients (
  id uuid primary key default gen_random_uuid(),
  campaign_id uuid not null references public.sms_campaign_broadcasts (id) on delete cascade,
  phone text not null,
  status text not null default 'pending'
    check (status in ('pending', 'sent', 'failed')),
  http_status integer,
  error_message text,
  sent_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists sms_campaign_recipients_campaign_id_idx
  on public.sms_campaign_recipients (campaign_id, status);

alter table public.sms_campaign_recipients enable row level security;

drop policy if exists "Admins can read sms campaign recipients" on public.sms_campaign_recipients;
create policy "Admins can read sms campaign recipients"
  on public.sms_campaign_recipients for select
  to authenticated
  using (public.is_admin());
