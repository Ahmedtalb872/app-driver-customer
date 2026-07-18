-- Captain document management: upload from the mobile app, review from the
-- admin dashboard. Nothing here weakens any existing RLS policy or exposes
-- the service_role key - every write goes through a SECURITY DEFINER RPC
-- that re-validates the caller server-side, exactly matching the pattern
-- already used throughout 20260712000028_admin_functions.sql and
-- 20260713000029/30_*.sql. Client code never gets direct INSERT/UPDATE on
-- public.captain_documents; it only gets SELECT of its own (or, for admins,
-- all) rows via RLS.

-- ---------------------------------------------------------------------
-- 1. Table
-- ---------------------------------------------------------------------
create table if not exists public.captain_documents (
  id uuid primary key default gen_random_uuid(),
  captain_id uuid not null references public.captains (id) on delete cascade,
  document_type text not null check (document_type in (
    'profile_photo',
    'national_id_front',
    'national_id_back',
    'driving_license_front',
    'driving_license_back',
    'vehicle_registration_front',
    'vehicle_registration_back',
    'vehicle_photo',
    'vehicle_insurance',
    'additional_document'
  )),
  file_path text not null,
  file_name text not null,
  mime_type text not null,
  file_size bigint not null,
  uploaded_at timestamptz not null default now(),
  expires_at timestamptz,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected', 'expired')),
  rejection_reason text,
  reviewed_by uuid references auth.users (id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- One current row per document type per captain - re-upload replaces the
  -- pointer via UPSERT (see captain_upload_document below), the storage
  -- path itself always gets a fresh {timestamp} so old files are never
  -- overwritten in Storage, only superseded.
  unique (captain_id, document_type)
);

create index if not exists captain_documents_captain_id_idx
  on public.captain_documents (captain_id);
create index if not exists captain_documents_status_idx
  on public.captain_documents (status);

drop trigger if exists captain_documents_set_updated_at on public.captain_documents;
create trigger captain_documents_set_updated_at
before update on public.captain_documents
for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------
-- 2. RLS - read-only from the client. No insert/update policy at all:
-- every write goes through the SECURITY DEFINER RPCs below, which
-- bypass RLS the same way every other sensitive write in this project
-- does (admin_approve_captain, customer_request_trip, ...).
-- ---------------------------------------------------------------------
alter table public.captain_documents enable row level security;

drop policy if exists "Captain documents viewable by owner or admin" on public.captain_documents;
create policy "Captain documents viewable by owner or admin"
  on public.captain_documents for select
  to authenticated
  using (auth.uid() = captain_id or public.is_admin());

-- ---------------------------------------------------------------------
-- 3. Storage bucket + storage.objects RLS
-- ---------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('captain-documents', 'captain-documents', false)
on conflict (id) do nothing;

-- Path convention (enforced by the client, and re-checked here via the
-- folder-name check): captains/{captain_id}/{document_type}/{timestamp}_{filename}
drop policy if exists "Captains can upload their own documents" on storage.objects;
create policy "Captains can upload their own documents"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'captain-documents'
    and (storage.foldername(name))[1] = 'captains'
    and (storage.foldername(name))[2] = auth.uid()::text
  );

drop policy if exists "Captains view own documents, admins view all" on storage.objects;
create policy "Captains view own documents, admins view all"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'captain-documents'
    and (
      (storage.foldername(name))[1] = 'captains'
      and (storage.foldername(name))[2] = auth.uid()::text
    )
    or (bucket_id = 'captain-documents' and public.is_admin())
  );

-- Intentionally no update/delete policy for anyone via the client - files
-- are superseded (new timestamped path), never overwritten or removed, and
-- the service_role key (which would bypass RLS entirely) is never used
-- client-side anywhere in this project.

-- ---------------------------------------------------------------------
-- 4. RPCs
-- ---------------------------------------------------------------------

-- Captain uploads (or replaces) one document. The client must have already
-- uploaded the file bytes to Storage at p_file_path via the Storage API
-- (gated by the "Captains can upload their own documents" policy above)
-- before calling this - this RPC only registers/updates the metadata row,
-- atomically resetting review state so a replaced document always goes
-- back to 'pending' rather than keeping a stale approval/rejection.
create or replace function public.captain_upload_document(
  p_document_type text,
  p_file_path text,
  p_file_name text,
  p_mime_type text,
  p_file_size bigint,
  p_expires_at timestamptz default null
)
returns public.captain_documents
language plpgsql
security definer
set search_path = public
as $$
declare
  v_captain_id uuid := auth.uid();
  v_row public.captain_documents;
begin
  if not exists (select 1 from public.captains where id = v_captain_id) then
    raise exception 'Only a captain account may upload documents';
  end if;

  if p_document_type not in (
    'profile_photo', 'national_id_front', 'national_id_back',
    'driving_license_front', 'driving_license_back',
    'vehicle_registration_front', 'vehicle_registration_back',
    'vehicle_photo', 'vehicle_insurance', 'additional_document'
  ) then
    raise exception 'Invalid document type: %', p_document_type;
  end if;

  if p_mime_type not in ('image/jpeg', 'image/jpg', 'image/png', 'application/pdf') then
    raise exception 'Unsupported file type: %', p_mime_type;
  end if;

  if p_file_size is null or p_file_size <= 0 or p_file_size > 10485760 then
    raise exception 'File size must be between 1 byte and 10MB';
  end if;

  insert into public.captain_documents (
    captain_id, document_type, file_path, file_name, mime_type, file_size,
    uploaded_at, expires_at, status, rejection_reason, reviewed_by, reviewed_at
  ) values (
    v_captain_id, p_document_type, p_file_path, p_file_name, p_mime_type, p_file_size,
    now(), p_expires_at, 'pending', null, null, null
  )
  on conflict (captain_id, document_type) do update
    set file_path = excluded.file_path,
        file_name = excluded.file_name,
        mime_type = excluded.mime_type,
        file_size = excluded.file_size,
        uploaded_at = now(),
        expires_at = excluded.expires_at,
        status = 'pending',
        rejection_reason = null,
        reviewed_by = null,
        reviewed_at = null
  returning * into v_row;

  return v_row;
end;
$$;

-- Admin approves one document.
create or replace function public.admin_approve_document(p_document_id uuid)
returns public.captain_documents
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.captain_documents;
begin
  if not public.has_admin_role('operations_admin') then
    raise exception 'Only operations_admin or super_admin may approve documents';
  end if;

  update public.captain_documents
    set status = 'approved',
        rejection_reason = null,
        reviewed_by = auth.uid(),
        reviewed_at = now()
    where id = p_document_id
    returning * into v_row;

  if not found then
    raise exception 'Document % not found', p_document_id;
  end if;

  perform public.log_admin_action(
    'document_approved', 'captain_document', p_document_id::text, null,
    jsonb_build_object('document_type', v_row.document_type, 'captain_id', v_row.captain_id),
    null
  );

  return v_row;
end;
$$;

-- Admin rejects one document (also used for the dashboard's "request
-- replacement" action - both are a reject with a reason, just different
-- dialog copy client-side; there is no separate stored status for it).
create or replace function public.admin_reject_document(p_document_id uuid, p_reason text)
returns public.captain_documents
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.captain_documents;
begin
  if not public.has_admin_role('operations_admin') then
    raise exception 'Only operations_admin or super_admin may reject documents';
  end if;
  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'A reason is required to reject a document';
  end if;

  update public.captain_documents
    set status = 'rejected',
        rejection_reason = p_reason,
        reviewed_by = auth.uid(),
        reviewed_at = now()
    where id = p_document_id
    returning * into v_row;

  if not found then
    raise exception 'Document % not found', p_document_id;
  end if;

  perform public.log_admin_action(
    'document_rejected', 'captain_document', p_document_id::text, null,
    jsonb_build_object('document_type', v_row.document_type, 'captain_id', v_row.captain_id),
    p_reason
  );

  return v_row;
end;
$$;

-- ---------------------------------------------------------------------
-- 5. Gate captain approval on document completeness. This re-implements
-- admin_approve_captain from 20260712000028_admin_functions.sql with one
-- added guard - a client-side-only check could be bypassed by calling the
-- RPC directly, so the guard has to live here, server-side, to actually
-- "prevent captain approval until all mandatory documents are approved".
-- ---------------------------------------------------------------------
create or replace function public.admin_approve_captain(p_captain_id uuid)
returns public.captains
language plpgsql
security definer
set search_path = public
as $$
declare
  v_captain public.captains;
  v_missing_count integer;
begin
  if not public.has_admin_role('operations_admin') then
    raise exception 'Only operations_admin or super_admin may approve captains';
  end if;

  select count(*) into v_missing_count
  from unnest(array[
    'profile_photo', 'national_id_front', 'national_id_back',
    'driving_license_front', 'driving_license_back',
    'vehicle_registration_front', 'vehicle_registration_back',
    'vehicle_photo', 'vehicle_insurance'
  ]) as required_type
  where not exists (
    select 1 from public.captain_documents cd
    where cd.captain_id = p_captain_id
      and cd.document_type = required_type
      and cd.status = 'approved'
  );

  if v_missing_count > 0 then
    raise exception 'CAPTAIN_DOCUMENTS_INCOMPLETE: % of 9 mandatory documents are not yet approved', v_missing_count;
  end if;

  update public.captains
    set status = 'approved', rejection_reason = null
    where id = p_captain_id
    returning * into v_captain;

  if not found then
    raise exception 'Captain % not found', p_captain_id;
  end if;

  perform public.log_admin_action('captain_approved', 'captain', p_captain_id::text, null, null, null);

  return v_captain;
end;
$$;
