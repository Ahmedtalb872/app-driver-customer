-- The splash screen's new force-update check (VersionGateService) needs to
-- read app_settings.min_supported_version/force_update before a user signs
-- in - not just once already authenticated, since an old install stuck on
-- the auth welcome screen is exactly the case "force update" is for. The
-- existing policy from 20260712000026_admin_rls.sql only allowed the
-- `authenticated` role; this widens read-only access to `anon` too. Nothing
-- in this table is sensitive (app name, support contact, default map
-- center, the force-update fields themselves).

drop policy if exists "App settings are readable by authenticated users" on public.app_settings;
create policy "App settings are readable by anyone"
  on public.app_settings for select
  to anon, authenticated
  using (true);
