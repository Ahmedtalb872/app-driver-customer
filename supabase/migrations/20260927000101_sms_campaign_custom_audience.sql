-- The actual primary use case for "حملات SMS" turned out to be recruiting
-- captains who have never signed up at all - a plain admin-pasted phone
-- list, not anyone already in public.profiles. Widens the audience check
-- constraint to accept 'custom' alongside the existing
-- customers/captains/both (see send-sms-campaign, which now accepts a
-- `phones: string[]` array directly in the request body when
-- audience = 'custom' instead of querying profiles for it).
alter table public.sms_campaign_broadcasts drop constraint if exists sms_campaign_broadcasts_audience_check;
alter table public.sms_campaign_broadcasts
  add constraint sms_campaign_broadcasts_audience_check
  check (audience in ('customers', 'captains', 'both', 'custom'));
