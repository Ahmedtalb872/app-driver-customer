import 'dart:async';

import '../config/supabase_config.dart';

/// One signaling message exchanged over a trip's call. [from] is always
/// the *other* party's role by the time a listener sees it - see
/// [CallSignalingService.start], which drops anything tagged with our own
/// [CallSignalingService.selfRole].
class CallSignal {
  const CallSignal({
    required this.type,
    required this.from,
    this.sdp,
    this.candidate,
    this.sdpMid,
    this.sdpMLineIndex,
  });

  final String type;
  final String from;
  final String? sdp;
  final String? candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;
}

/// Carries WebRTC offer/answer/ICE/hangup messages for one trip's call
/// through the `call_signals` table (RLS: only that trip's own customer/
/// captain can read or insert its rows), watched via the same
/// `.stream()` realtime mechanism [RideRepository.watchTrip] already
/// relies on for live trip updates - not Realtime Broadcast, which this
/// app had no other proven usage of and turned out not to reliably
/// deliver messages between the two apps (see
/// 20260816000075_call_signals_table.sql for the full story).
///
/// Owned by the trip-tracking screen for the screen's whole lifetime (not
/// by [CallScreen] itself), so the same subscription keeps listening for
/// the *next* incoming call after one ends - see
/// `TripTrackingScreen._callSignaling`.
class CallSignalingService {
  CallSignalingService({required this.tripId, required this.selfRole});

  final String tripId;

  /// 'customer' or 'captain' - tags every message we send, and lets us
  /// ignore our own inserts (the stream delivers every matching row,
  /// sender included).
  final String selfRole;

  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  final _seenIds = <int>{};

  /// Signals inserted before this service started are from a previous call
  /// attempt on the same trip (rows are never deleted) - skipped so a new
  /// call doesn't immediately "receive" a stale offer/answer left over from
  /// an earlier one.
  DateTime? _startedAt;

  final _offers = StreamController<CallSignal>.broadcast();
  final _answers = StreamController<CallSignal>.broadcast();
  final _iceCandidates = StreamController<CallSignal>.broadcast();
  final _hangups = StreamController<CallSignal>.broadcast();

  Stream<CallSignal> get onOffer => _offers.stream;
  Stream<CallSignal> get onAnswer => _answers.stream;
  Stream<CallSignal> get onIceCandidate => _iceCandidates.stream;
  Stream<CallSignal> get onHangup => _hangups.stream;

  void start() {
    _startedAt = DateTime.now().toUtc();
    _sub = SupabaseConfig.client
        .from('call_signals')
        .stream(primaryKey: ['id'])
        .eq('trip_id', tripId)
        .listen((rows) {
          for (final row in rows) {
            final id = (row['id'] as num).toInt();
            if (!_seenIds.add(id)) continue;

            final createdAtRaw = row['created_at'] as String?;
            final createdAt = createdAtRaw != null
                ? DateTime.tryParse(createdAtRaw)
                : null;
            if (createdAt != null &&
                _startedAt != null &&
                createdAt.isBefore(_startedAt!)) {
              continue;
            }

            final from = row['from_role'] as String?;
            if (from == null || from == selfRole) continue;

            final payload = (row['payload'] as Map?)?.cast<String, dynamic>() ?? const {};
            final signal = CallSignal(
              type: row['type'] as String? ?? '',
              from: from,
              sdp: payload['sdp'] as String?,
              candidate: payload['candidate'] as String?,
              sdpMid: payload['sdpMid'] as String?,
              sdpMLineIndex: (payload['sdpMLineIndex'] as num?)?.toInt(),
            );
            switch (signal.type) {
              case 'offer':
                _offers.add(signal);
              case 'answer':
                _answers.add(signal);
              case 'ice':
                _iceCandidates.add(signal);
              case 'hangup':
                _hangups.add(signal);
            }
          }
        });
  }

  Future<void> sendOffer(String sdp) => _send('offer', {'sdp': sdp});

  Future<void> sendAnswer(String sdp) => _send('answer', {'sdp': sdp});

  Future<void> sendIceCandidate({
    required String candidate,
    String? sdpMid,
    int? sdpMLineIndex,
  }) => _send('ice', {
    'candidate': candidate,
    'sdpMid': sdpMid,
    'sdpMLineIndex': sdpMLineIndex,
  });

  Future<void> sendHangup() => _send('hangup', const {});

  Future<void> _send(String type, Map<String, dynamic> payload) async {
    await SupabaseConfig.client.from('call_signals').insert({
      'trip_id': tripId,
      'from_role': selfRole,
      'type': type,
      'payload': payload,
    });
  }

  void dispose() {
    _sub?.cancel();
    _offers.close();
    _answers.close();
    _iceCandidates.close();
    _hangups.close();
  }
}
