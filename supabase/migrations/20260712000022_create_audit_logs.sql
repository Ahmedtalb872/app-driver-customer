-- Append-only record of every sensitive admin action. There is
-- deliberately no client-facing insert policy anywhere for this table
-- (see 20260712000026_admin_rls.sql) - the only way a row is ever created
-- is via public.log_admin_action(), called from inside the SECURITY
-- DEFINER functions that perform the sensitive action itself, so the log
-- entry and the action it describes are always written atomically.

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid references auth.users (id),
  admin_name text,
  admin_role text,
  action text not null,
  entity_type text,
  entity_id text,
  before_value jsonb,
  after_value jsonb,
  reason text,
  created_at timestamptz not null default now()
);
