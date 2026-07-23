-- Lets an admin put a captain document back on hold ("pending") with a
-- mandatory reason, distinct from a hard rejection - e.g. "the photo is
-- blurry, please re-upload" without counting as a rejection against the
-- captain. `status` already allows 'pending' (it's every document's
-- initial, never-reviewed state), so no schema/constraint change is
-- needed - this just adds the missing RPC to *set* it deliberately,
-- mirroring admin_reject_document exactly except for the target status.
-- Reuses `rejection_reason` to store the hold reason too, same as reject -
-- it's really "why this document isn't currently approved", not
-- specifically "why it was rejected".

create or replace function public.admin_set_document_pending(
  p_document_id uuid,
  p_reason text
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
    raise exception 'Only operations_admin or super_admin may set a document to pending';
  end if;
  if p_reason is null or btrim(p_reason) = '' then
    raise exception 'A reason is required to put a document on hold';
  end if;

  update public.captain_documents
    set status = 'pending',
        rejection_reason = p_reason,
        reviewed_by = auth.uid(),
        reviewed_at = now()
    where id = p_document_id
    returning * into v_row;

  if not found then
    raise exception 'Document % not found', p_document_id;
  end if;

  perform public.log_admin_action(
    'document_set_pending', 'captain_document', p_document_id::text, null,
    jsonb_build_object('document_type', v_row.document_type, 'captain_id', v_row.captain_id),
    p_reason
  );

  return v_row;
end;
$$;
