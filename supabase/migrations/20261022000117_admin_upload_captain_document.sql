-- Lets an admin upload a document on a captain's behalf (e.g. the captain
-- sent their ID/license photos over WhatsApp instead of using the app) -
-- previously the only way in was the captain's own
-- captain_upload_document RPC, keyed to auth.uid(), so there was no path
-- for an admin to register a document under a *different* captain_id.
-- Mirrors that RPC's validation and upsert shape exactly, just with an
-- admin-role check instead of a captains-table membership check, and
-- p_captain_id taken as a parameter instead of read from auth.uid().

create or replace function public.admin_upload_captain_document(
  p_captain_id uuid,
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
  v_row public.captain_documents;
begin
  if not public.has_admin_role('operations_admin') then
    raise exception 'Only operations_admin or super_admin may upload a document for a captain';
  end if;

  if not exists (select 1 from public.captains where id = p_captain_id) then
    raise exception 'Captain % not found', p_captain_id;
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
    p_captain_id, p_document_type, p_file_path, p_file_name, p_mime_type, p_file_size,
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

  perform public.log_admin_action(
    'document_uploaded_by_admin', 'captain_document', v_row.id::text, null,
    jsonb_build_object('document_type', p_document_type, 'captain_id', p_captain_id),
    null
  );

  return v_row;
end;
$$;

-- storage.objects insert: the existing "Captains can upload their own
-- documents" policy only allows writing under the signed-in captain's own
-- folder (storage.foldername(name)[2] = auth.uid()::text), which an admin
-- uploading for someone else can never satisfy. This adds a parallel
-- admin-only insert policy instead of widening that one.
drop policy if exists "Admins can upload documents for any captain" on storage.objects;
create policy "Admins can upload documents for any captain"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'captain-documents'
    and (storage.foldername(name))[1] = 'captains'
    and public.is_admin()
  );
