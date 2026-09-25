-- Security fix: "Trip owner, assigned captain, or admin can update" let any
-- authenticated customer or captain party to a trip UPDATE that row
-- directly via PostgREST (RLS gates rows, not columns, and there is no
-- column-level GRANT restricting this) - including final_price,
-- commission_amount, captain_net_earnings, status, and payment_method,
-- completely bypassing customer_request_trip()/captain_end_trip()'s
-- server-computed pricing and validation. A customer could e.g. PATCH
-- their own trip to status = 'completed', final_price = 0 directly.
--
-- No current feature actually needs that: the only direct
-- `.from('trips').update(...)` calls anywhere in the Dart codebase are in
-- lib/admin/repositories/admin_trips_repository.dart (updateAdminNotes,
-- updateRoute) - both admin-only actions, already covered by
-- public.is_admin() below. Every customer/captain-side trip mutation goes
-- through a SECURITY DEFINER RPC (customer_request_trip, captain_end_trip,
-- customer_cancel_trip, etc.), none of which need this policy at all since
-- they run as the function owner, not through RLS. Dropping the
-- customer_id/captain_id branches entirely removes the exposure with no
-- loss of functionality.
drop policy if exists "Trip owner, assigned captain, or admin can update" on public.trips;
create policy "Admin can update"
  on public.trips for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());
