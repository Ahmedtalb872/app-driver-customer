-- Adds OCR extraction state to captain_documents so the admin dashboard can
-- show the text machine-read off a document (national ID, driving license,
-- vehicle registration, insurance...) right next to its thumbnail, instead
-- of the reviewer having to zoom into every photographed document by hand
-- to read small print. Populated by the extract-document-text Edge
-- Function - called best-effort right after a captain uploads
-- (CaptainDocumentsRepository.uploadDocument) and lazily by the admin
-- dashboard for any older row still 'not_attempted' when a captain's
-- document list loads (AdminCaptainsRepository.loadDocuments).
--
-- This is read-only assistance for the human reviewer, not an
-- auto-approval mechanism - admin_approve_document/admin_approve_captain
-- (20260717000034_captain_documents.sql) are completely untouched, so a
-- document still only gets approved by an operations_admin actually
-- clicking approve.
alter table public.captain_documents
  add column if not exists extracted_text text,
  add column if not exists extracted_at timestamptz,
  add column if not exists extraction_status text not null default 'not_attempted'
    check (extraction_status in ('not_attempted', 'pending', 'done', 'failed', 'skipped'));
