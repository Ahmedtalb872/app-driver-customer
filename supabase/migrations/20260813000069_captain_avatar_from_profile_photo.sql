-- Closes the gap 20260812000054_captain_avatar_url.sql deliberately left
-- open: captains.avatar_url has existed since then, but nothing has ever
-- written to it - a captain's "profile_photo" is really a private
-- captain_documents row (owner-or-admin only RLS, since that table also
-- holds ID/license documents), never copied anywhere customer-readable.
-- A customer's trip-tracking screen has always shown the captain's first
-- initial instead of their actual photo as a result.
--
-- This adds a public 'captain-avatars' Storage bucket (public, same as
-- 20260812000068_customer_avatar_upload.sql's 'customer-avatars' - a
-- customer-facing photo is meant to be freely viewable, unlike the private
-- verification documents) that an admin can copy an approved profile_photo
-- document into from the dashboard (see
-- AdminCaptainsRepository.syncApprovedProfilePhotoToAvatar) - one of the
-- three options 20260812000054 named for populating avatar_url ("an admin
-- action"). "Captains are updatable by admin" (20260712000026_admin_rls.sql)
-- already lets an admin write avatar_url directly once the file is copied -
-- no new RPC needed for that part.

insert into storage.buckets (id, name, public)
values ('captain-avatars', 'captain-avatars', true)
on conflict (id) do nothing;

-- Path convention (enforced by the client, re-checked here via the
-- folder-name check): captains/{captain_id}/{timestamp}.{ext}. Admin-only,
-- unlike customer-avatars (which a customer manages for themselves) -
-- captains don't get a self-serve avatar upload from this dashboard.
drop policy if exists "Admins manage captain avatars" on storage.objects;
create policy "Admins manage captain avatars"
  on storage.objects for all
  to authenticated
  using (bucket_id = 'captain-avatars' and public.is_admin())
  with check (bucket_id = 'captain-avatars' and public.is_admin());
