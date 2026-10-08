import 'dart:async';

import '../../core/config/supabase_config.dart';

/// A brand new voice-call offer from a customer, picked up by
/// [AdminIncomingCallListener] - carries just enough to start answering it
/// (see `AdminShell._onIncomingOffer`).
class AdminIncomingOffer {
  const AdminIncomingOffer({
    required this.tripId,
    required this.offerSdp,
    required this.createdAt,
  });

  final String tripId;
  final String offerSdp;
  final DateTime createdAt;
}

/// Watches for a new voice-call offer from any customer, across every trip
/// at once - unlike [CallSignalingService] (scoped to one trip_id, used
/// once the admin is already dealing with a specific call), this is what
/// lets the admin dashboard ring no matter which screen is currently open,
/// not just while a trip's detail panel happens to be on screen.
///
/// Poll-only, deliberately not the realtime `.stream()` other admin
/// listeners use (e.g. `AdminTripsRepository.watchActiveTrips`) - unlike
/// `trips`, `call_signals` rows are never deleted and every single ICE
/// candidate for every call ever placed is its own row, so an unfiltered
/// live stream would have to hydrate that whole, ever-growing table on
/// every dashboard load and would only get slower as the system grows -
/// exactly what a "make it fast" ask shouldn't do. A tightly filtered poll
/// (`type = 'offer' and from_role = 'customer'`, backed by the partial
/// index in 20261008000113_call_signals_customer_offer_index.sql) stays
/// cheap and fast regardless of table size, and 1s is fast enough to feel
/// like a real incoming call ringing.
class AdminIncomingCallListener {
  Timer? _pollTimer;
  DateTime? _startedAt;
  final _seenIds = <int>{};

  final _offers = StreamController<AdminIncomingOffer>.broadcast();
  Stream<AdminIncomingOffer> get onOffer => _offers.stream;

  void start() {
    _startedAt = DateTime.now().toUtc();
    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final rows = await SupabaseConfig.client
          .from('call_signals')
          .select('id, trip_id, payload, created_at')
          .eq('type', 'offer')
          .eq('from_role', 'customer')
          .gte('created_at', _startedAt!.toIso8601String())
          .order('id');
      for (final row in List<Map<String, dynamic>>.from(rows)) {
        final id = (row['id'] as num).toInt();
        if (!_seenIds.add(id)) continue;

        final tripId = row['trip_id'] as String?;
        final payload =
            (row['payload'] as Map?)?.cast<String, dynamic>() ?? const {};
        final sdp = payload['sdp'] as String?;
        final createdAtRaw = row['created_at'] as String?;
        final createdAt = createdAtRaw != null
            ? DateTime.tryParse(createdAtRaw)
            : null;
        if (tripId == null || sdp == null || createdAt == null) continue;

        _offers.add(
          AdminIncomingOffer(
            tripId: tripId,
            offerSdp: sdp,
            createdAt: createdAt,
          ),
        );
      }
    } catch (_) {
      // Best effort - the next tick tries again regardless.
    }
  }

  void dispose() {
    _pollTimer?.cancel();
    _offers.close();
  }
}
