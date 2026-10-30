-- Lets a customer set their own profile photo. public.customers.avatar_url
-- has existed since 20260713000029_open_trip_lifecycle.sql (added for the
-- captain-facing incoming-ride dialog) but nothing has ever let a customer
-- actually set it - ProfileScreen has only ever shown the first letter of
-- their name. Every other avatar_url in this project (captains.avatar_url)
-- is consumed as a plain, directly-renderable URL (NetworkImage(avatarUrl),
-- no signed-URL step) - this bucket follows that same convention: public,
-- not the private/signed-URL pattern captain-documents uses for sensitive
-- verification files.
--
-- "Customers updatable by owner" (20260712000006_rls_policies.sql,
-- auth.uid() = id, no column restriction) already lets a customer write
-- avatar_url directly via a normal table update once the file itself is in
-- Storage - no new RPC needed for that part.

insert into storage.buckets (id, name, public)
values ('customer-avatars', 'customer-avatars', true)
on conflict (id) do nothing;

-- Path convention (enforced by the client, re-checked here via the
-- folder-name check): customers/{customer_id}/{timestamp}.{ext}. The
-- bucket itself is public, so reads never need a policy at all - "for all"
-- here only ever governs insert (a fresh upload) and, incidentally,
-- replacing/removing a customer's own previously-uploaded file.
drop policy if exists "Customers manage their own avatar" on storage.objects;
create policy "Customers manage their own avatar"
  on storage.objects for all
  to authenticated
  using (
    bucket_id = 'customer-avatars'
    and (storage.foldername(name))[1] = 'customers'
    and (storage.foldername(name))[2] = auth.uid()::text
  )
  with check (
    bucket_id = 'customer-avatars'
    and (storage.foldername(name))[1] = 'customers'
    and (storage.foldername(name))[2] = auth.uid()::text
  );
