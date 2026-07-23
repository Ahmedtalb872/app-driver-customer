import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

class AdminTripsRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<List<Map<String, dynamic>>> loadTrips({
    String? statusFilter,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 25,
    int offset = 0,
  }) async {
    var query = _client.from('trips').select();

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.eq('status', statusFilter);
    }
    if (fromDate != null) {
      query = query.gte('requested_at', fromDate.toIso8601String());
    }
    if (toDate != null) {
      query = query.lte('requested_at', toDate.toIso8601String());
    }

    final rows = await query
        .order('requested_at', ascending: false)
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>?> loadTripById(String id) async {
    return await _client.from('trips').select().eq('id', id).maybeSingle();
  }

  static const activeStatuses = [
    'searching',
    'accepted',
    'arrived',
    'in_progress',
  ];

  /// Live Operations feed: currently active trips with customer/captain
  /// names embedded via the existing FK relationships (trips -> customers
  /// -> profiles, trips -> captains -> profiles) - no new columns/tables.
  Future<List<Map<String, dynamic>>> loadActiveTrips() async {
    final rows = await _client
        .from('trips')
        .select(
          '*, customers(profiles(full_name, phone)), '
          'captains(profiles(full_name, phone))',
        )
        .inFilter('status', activeStatuses)
        .order('requested_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> updateAdminNotes(String tripId, String notes) async {
    await _client.from('trips').update({'admin_notes': notes}).eq('id', tripId);
  }

  /// Corrects a trip's pickup and/or destination (address + coordinates)
  /// after the fact - e.g. the customer's app dropped the pin in the wrong
  /// spot, or picked the wrong place from search. A plain owner-or-admin
  /// update (RLS: `Trip owner, assigned captain, or admin can update`,
  /// 20260712000026_admin_rls.sql) - no RPC needed, same as
  /// [updateAdminNotes]. [destinationAddress]/[destinationLat]/
  /// [destinationLng] are only sent when non-null, so calling this for an
  /// Open Trip (no destination yet) only ever touches the pickup fields.
  Future<void> updateRoute(
    String tripId, {
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    String? destinationAddress,
    double? destinationLat,
    double? destinationLng,
  }) async {
    await _client
        .from('trips')
        .update({
          'pickup_address': pickupAddress,
          'pickup_lat': pickupLat,
          'pickup_lng': pickupLng,
          if (destinationAddress != null)
            'destination_address': destinationAddress,
          if (destinationLat != null) 'destination_lat': destinationLat,
          if (destinationLng != null) 'destination_lng': destinationLng,
        })
        .eq('id', tripId);
  }

  Future<void> cancel(String tripId, String reason) async {
    await _client.rpc(
      'admin_cancel_trip',
      params: {'p_trip_id': tripId, 'p_reason': reason},
    );
  }

  /// Marks a trip boarded/started (status 'arrived' -> 'in_progress'). The
  /// customer-facing "ركبت" flow (`passenger_board_trip`) requires the
  /// passenger to be signed in and call it themselves - this project's
  /// admin-dispatched trips are placed on behalf of phone-in customers who
  /// never sign into any app, so this is the only way those trips can ever
  /// start (see `admin_board_trip`, 20260718000038_admin_board_trip.sql).
  Future<void> boardTrip(String tripId) async {
    await _client.rpc('admin_board_trip', params: {'p_trip_id': tripId});
  }

  Future<void> assignCaptain(
    String tripId,
    String captainId, {
    String? reason,
  }) async {
    await _client.rpc(
      'admin_assign_captain',
      params: {
        'p_trip_id': tripId,
        'p_captain_id': captainId,
        'p_reason': reason,
      },
    );
  }

  /// Captain ids currently holding an active trip - used by the captain
  /// picker to exclude captains who are already busy elsewhere.
  Future<Set<String>> loadBusyCaptainIds() async {
    final rows = await _client
        .from('trips')
        .select('captain_id')
        .inFilter('status', activeStatuses)
        .not('captain_id', 'is', null);
    return List<Map<String, dynamic>>.from(
      rows,
    ).map((r) => r['captain_id'] as String).toSet();
  }

  /// Live version of [loadActiveTrips]: emits the enriched active-trips list
  /// immediately, then again every time any row in `trips` changes
  /// (debounced so a burst of updates only triggers one re-fetch). Reuses
  /// [loadActiveTrips] rather than hydrating the raw realtime rows itself,
  /// so the join logic only lives in one place.
  Stream<List<Map<String, dynamic>>> watchActiveTrips() {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    Timer? debounce;

    Future<void> refresh() async {
      try {
        controller.add(await loadActiveTrips());
      } catch (_) {
        // Transient fetch failure: keep showing the last emitted list.
      }
    }

    final sub = _client.from('trips').stream(primaryKey: ['id']).listen((_) {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 300), refresh);
    });

    refresh();

    controller.onCancel = () async {
      debounce?.cancel();
      await sub.cancel();
    };

    return controller.stream;
  }

  /// Exports the given rows as CSV text (section 7: "Export filtered trip
  /// data to CSV"). Kept simple/dependency-light rather than pulling the
  /// `csv` package's full writer for a handful of known columns.
  String toCsv(List<Map<String, dynamic>> trips) {
    final header = [
      'id',
      'status',
      'pickup_address',
      'destination_address',
      'distance_km',
      'estimated_price',
      'final_price',
      'payment_method',
      'commission_amount',
      'captain_net_earnings',
      'requested_at',
      'completed_at',
      'cancellation_reason',
    ];
    final buffer = StringBuffer(header.join(','));
    buffer.writeln();
    for (final trip in trips) {
      final values = header.map((key) {
        final value = trip[key];
        if (value == null) return '';
        final text = value.toString().replaceAll('"', '""');
        return text.contains(',') ? '"$text"' : text;
      });
      buffer.writeln(values.join(','));
    }
    return buffer.toString();
  }
}
