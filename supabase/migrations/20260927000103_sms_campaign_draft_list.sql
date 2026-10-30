-- The "أرقام الهواتف" textarea on the SMS campaigns screen only lived in
-- Flutter's in-memory TextEditingController - a page refresh reset it back
-- to the hardcoded first recruitment batch, silently dropping any numbers
-- the admin typed in afterward via "إضافة رقم واحد" or pasted in. This
-- single-row table gives that textarea's raw text a durable home so it
-- survives refreshes (and works the same from any browser/device the admin
-- opens the dashboard from, unlike browser localStorage).
create table if not exists public.sms_campaign_draft_list (
  id text primary key default 'default',
  phones_text text not null default '',
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id)
);

alter table public.sms_campaign_draft_list enable row level security;

drop policy if exists "Admins can read sms campaign draft list" on public.sms_campaign_draft_list;
create policy "Admins can read sms campaign draft list"
  on public.sms_campaign_draft_list for select
  to authenticated
  using (public.is_admin());

drop policy if exists "Admins can write sms campaign draft list" on public.sms_campaign_draft_list;
create policy "Admins can write sms campaign draft list"
  on public.sms_campaign_draft_list for insert
  to authenticated
  with check (public.is_admin());

drop policy if exists "Admins can update sms campaign draft list" on public.sms_campaign_draft_list;
create policy "Admins can update sms campaign draft list"
  on public.sms_campaign_draft_list for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());
