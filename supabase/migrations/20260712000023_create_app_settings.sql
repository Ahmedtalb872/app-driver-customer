-- Single-row global app configuration (section 19 of the admin dashboard
-- spec). The `id boolean primary key check (id)` trick is a standard
-- Postgres pattern for enforcing "exactly one row" without extra triggers.

create table if not exists public.app_settings (
  id boolean primary key default true check (id),
  app_name text not null default 'الهدهد',
  logo_url text,
  support_phone text,
  support_email text,
  privacy_policy_url text,
  terms_url text,
  maintenance_mode boolean not null default false,
  min_supported_version text,
  force_update boolean not null default false,
  customer_registration_enabled boolean not null default true,
  captain_registration_enabled boolean not null default true,
  default_language text not null default 'ar',
  default_map_lat double precision not null default 18.0858,
  default_map_lng double precision not null default -15.9785,
  default_map_zoom double precision not null default 13,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id)
);

insert into public.app_settings (id) values (true) on conflict (id) do nothing;

drop trigger if exists app_settings_set_updated_at on public.app_settings;
create trigger app_settings_set_updated_at
before update on public.app_settings
for each row execute function public.set_updated_at();
