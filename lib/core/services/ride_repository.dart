import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../config/supabase_config.dart';

/// Thin Supabase data layer for the real (backend-backed) trip lifecycle:
/// request -> broadcast to captains -> accept/ignore -> arrive -> passenger
/// boards ("ركبت") -> live tracking -> end -> summary.
///
/// Everything here maps to/from the existing [Trip] display model (see
/// `Trip.fromTripRow`) so every screen that already renders a [Trip] keeps
/// working unchanged - this class only owns *how a Trip gets populated*,
/// never a parallel model.
///
/// Every mutating call goes through a `SECURITY DEFINER` RPC (see migration
/// `20260713000029_open_trip_lifecycle.sql`) so the server - not the client -
/// is the source of truth for who is allowed to do what.
class RideRepository {
  RideRepository._();

  static final RideRepository instance = RideRepository._();

  SupabaseClient get _client => SupabaseConfig.client;

  // `customers(...)` (not `customers!inner(...)`) is deliberate: a
  // dispatched trip with no registered customer account has
  // `customer_id is null` (see admin_dispatch_trip,
  // 20260718000040_guest_dispatch_trip.sql). An inner-join embed would
  // exclude such a trip from every query that uses this select entirely -
  // `.single()` would throw "no rows", and watchIncomingRequests would
  // silently never surface it to any captain.
  static const String _fullJoin =
      '*, '
      'customers(avatar_url, rating, ratings_count, completed_trips_count, is_verified, profiles(full_name, phone)), '
      'captains(avatar_url, vehicle_brand, vehicle_model, vehicle_plate, profiles(full_name, phone))';

  Trip _rowToTrip(Map<String, dynamic> row) {
    final customer = row['customers'] as Map<String, dynamic>?;
    final customerProfile = customer?['profiles'] as Map<String, dynamic>?;
    final captain = row['captains'] as Map<String, dynamic>?;
    final captainProfile = captain?['profiles'] as Map<String, dynamic>?;
    return Trip.fromTripRow(
      row,
      customerProfile: {
        if (customerProfile != null) ...customerProfile,
        if (customer != null) ...customer,
        // Guest trip (no `customers` row at all) - fall back to the phone
        // number the dispatch operator typed, so the captain still has a
        // way to identify/call whoever requested the ride.
        if (customer == null && row['guest_customer_phone'] != null)
          'phone': row['guest_customer_phone'],
      },
      captainProfile: captain == null
          ? null
          : {if (captainProfile != null) ...captainProfile, ...captain},
    );
  }

  Future<Trip> _fetchEnrichedTrip(String tripId) async {
    final row = await _client
        .from('trips')
        .select(_fullJoin)
        .eq('id', tripId)
        .single();
    return _rowToTrip(row);
  }

  // -------------------------------------------------------------------
  // Customer: request a trip (normal or Open Trip).
  // -------------------------------------------------------------------
  Future<Trip> requestTrip({
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required TripType tripType,
    String? destinationAddress,
    double? destinationLat,
    double? destinationLng,
    required VehicleType vehicleType,
    required String paymentMethod,
    String? customerNote,
    int timeoutSeconds = 300,
    int passengerCount = 1,
    String serviceType = 'ride',
    String? recipientName,
    String? recipientPhone,
    String? packageDescription,
    /// The backend payment_method code ('cash'/'wallet'/'selefli') to send
    /// as-is, bypassing [paymentMethod]'s loose Arabic-label matching below
    /// - needed for 'selefli', which has no display-label call site to
    /// match against. Existing callers that only ever pass 'نقداً' don't
    /// need this; it's for RequestRideScreen's Selefli opt-in.
    String? paymentMethodCode,
    /// Required (and validated server-side) when [paymentMethodCode] is
    /// 'selefli' - the client-side price estimate the request is checked
    /// against that tier's cap. Ignored for cash/wallet.
    double? estimatedPrice,
  }) async {
    final row = await _client.rpc(
      'customer_request_trip',
      params: {
        'p_pickup_address': pickupAddress,
        'p_pickup_lat': pickupLat,
        'p_pickup_lng': pickupLng,
        'p_trip_type': tripType == TripType.open ? 'open' : 'normal',
        'p_destination_address': destinationAddress,
        'p_destination_lat': destinationLat,
        'p_destination_lng': destinationLng,
        'p_vehicle_type': vehicleType.name,
        'p_payment_method':
            paymentMethodCode ??
            (paymentMethod == 'المحفظة' ? 'wallet' : 'cash'),
        'p_customer_note': customerNote,
        'p_timeout_seconds': timeoutSeconds,
        'p_passenger_count': passengerCount,
        'p_service_type': serviceType,
        'p_recipient_name': recipientName,
        'p_recipient_phone': recipientPhone,
        'p_package_description': packageDescription,
        'p_estimated_price': estimatedPrice,
      },
    );
    final tripId = (row as Map<String, dynamic>)['id'] as String;
    return _fetchEnrichedTrip(tripId);
  }

  // -------------------------------------------------------------------
  // Captain: broadcasting incoming requests (realtime).
  // -------------------------------------------------------------------

  /// Emits the single request currently offered to this captain - the
  /// earliest still-broadcasting, non-expired, non-ignored-by-this-captain
  /// request - or `null` when there is none. Only one incoming-ride dialog
  /// is ever shown at a time, matching the spec.
  Stream<Trip?> watchIncomingRequests(String captainId) {
    final controller = StreamController<Trip?>.broadcast();
    final Map<String, Trip> lastKnown = {};

    final sub = _client
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('status', 'searching')
        .order('requested_at')
        .listen((rows) async {
          final candidates = rows.where((r) {
            final ignoredBy =
                (r['ignored_by'] as List?)?.cast<String>() ?? const [];
            final expiresAt = r['expires_at'] as String?;
            final notExpired =
                expiresAt == null ||
                DateTime.parse(expiresAt).toLocal().isAfter(DateTime.now());
            return r['captain_id'] == null &&
                !ignoredBy.contains(captainId) &&
                notExpired;
          }).toList();

          if (candidates.isEmpty) {
            controller.add(null);
            return;
          }

          final chosen = candidates.first;
          final tripId = chosen['id'] as String;

          // The raw realtime row has no joined customer/profile columns -
          // enrich once per newly-seen trip id and cache it so a stream of
          // unrelated column updates on the same row doesn't refetch.
          if (!lastKnown.containsKey(tripId)) {
            try {
              lastKnown[tripId] = await _fetchEnrichedTrip(tripId);
            } catch (_) {
              return;
            }
          }
          controller.add(lastKnown[tripId]);
        });

    controller.onCancel = () async {
      lastKnown.clear();
      await sub.cancel();
    };

    return controller.stream;
  }

  /// Live updates for a single trip both sides watch after acceptance -
  /// captain sees customer cancel/status changes, customer sees captain
  /// arrive/board/live-tracking/completion.
  Stream<Trip?> watchTrip(String tripId) {
    final controller = StreamController<Trip?>.broadcast();
    Trip? lastKnown;

    final sub = _client
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('id', tripId)
        .listen((rows) async {
          if (rows.isEmpty) {
            controller.add(null);
            return;
          }
          try {
            lastKnown = await _fetchEnrichedTrip(tripId);
            controller.add(lastKnown);
          } catch (_) {
            // Transient fetch failure: keep showing the last known state
            // rather than surfacing a raw error to the UI.
            controller.add(lastKnown);
          }
        });

    controller.onCancel = () => sub.cancel();
    return controller.stream;
  }

  // -------------------------------------------------------------------
  // Actions.
  // -------------------------------------------------------------------

  /// Throws [TripUnavailableException] when another captain already
  /// accepted (or the request expired) - callers should show the canned
  /// "تم قبول هذا المشوار من طرف كابتن آخر" message, never the raw error.
  Future<Trip> acceptTrip(String tripId) async {
    try {
      // The RPC returns the bare trips row (no customer join) - re-fetch
      // enriched so the caller gets full passenger display info.
      await _client.rpc('captain_accept_trip', params: {'p_trip_id': tripId});
      return _fetchEnrichedTrip(tripId);
    } on PostgrestException catch (e) {
      if (e.message.contains('TRIP_UNAVAILABLE')) {
        throw TripUnavailableException();
      }
      rethrow;
    }
  }

  Future<void> ignoreTrip(String tripId) async {
    await _client.rpc('captain_ignore_trip', params: {'p_trip_id': tripId});
  }

  Future<Trip> arriveTrip(String tripId) async {
    await _client.rpc('captain_arrive_trip', params: {'p_trip_id': tripId});
    return _fetchEnrichedTrip(tripId);
  }

  Future<Trip> boardTrip(String tripId) async {
    await _client.rpc('passenger_board_trip', params: {'p_trip_id': tripId});
    return _fetchEnrichedTrip(tripId);
  }

  Future<void> updateLiveTracking({
    required String tripId,
    required double lat,
    required double lng,
    required double traveledDistanceKm,
  }) async {
    await _client.rpc(
      'update_trip_live_tracking',
      params: {
        'p_trip_id': tripId,
        'p_lat': lat,
        'p_lng': lng,
        'p_traveled_distance_km': traveledDistanceKm,
      },
    );
  }

  Future<Trip> endTrip({
    required String tripId,
    required double finalDistanceKm,
  }) async {
    await _client.rpc(
      'captain_end_trip',
      params: {'p_trip_id': tripId, 'p_final_distance_km': finalDistanceKm},
    );
    return _fetchEnrichedTrip(tripId);
  }

  /// Customer- or captain-initiated cancellation before a trip completes.
  /// Uses a direct table update rather than a new RPC: the existing owner
  /// update policy from `20260712000026_admin_rls.sql`
  /// (`auth.uid() = customer_id or auth.uid() = captain_id or is_admin()`)
  /// already permits this, so no schema/RLS change was needed for it.
  Future<void> cancelTrip(String tripId, {required String cancelledBy}) async {
    await _client
        .from('trips')
        .update({
          'status': 'cancelled',
          'cancelled_at': DateTime.now().toUtc().toIso8601String(),
          'cancelled_by': cancelledBy,
        })
        .eq('id', tripId);
  }

  Future<void> setCaptainOnline(bool isOnline) async {
    await _client.rpc('captain_set_online', params: {'p_is_online': isOnline});
  }

  Future<void> expireTrip(String tripId) async {
    await _client.rpc('expire_trip', params: {'p_trip_id': tripId});
  }

  /// Latest `pricing_config` row for a vehicle type - used client-side only
  /// for showing a live *estimate* while a trip runs; the authoritative
  /// final fare is always computed server-side in `captain_end_trip`.
  Future<Map<String, dynamic>?> fetchPricingConfig(String vehicleType) async {
    return _client
        .from('pricing_config')
        .select()
        .eq('vehicle_type', vehicleType)
        .maybeSingle();
  }

  // -------------------------------------------------------------------
  // Customer: trip history.
  // -------------------------------------------------------------------

  /// The signed-in customer's past trips (most recent first), enriched the
  /// same way [watchTrip]/[acceptTrip] already are so [MyTripsScreen] can
  /// render them with [Trip] unchanged.
  Future<List<Trip>> fetchCustomerTrips() async {
    final customerId = _client.auth.currentUser?.id;
    if (customerId == null) return [];
    final rows = await _client
        .from('trips')
        .select(_fullJoin)
        .eq('customer_id', customerId)
        .order('requested_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(_rowToTrip)
        .toList();
  }
}

/// Thrown when a captain tries to accept a request that's no longer
/// available (already accepted by someone else, or expired).
class TripUnavailableException implements Exception {}
