import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// One signaling message exchanged over a trip's call channel. [from] is
/// always the *other* party's role by the time a listener sees it - see
/// [CallSignalingService.start], which drops anything tagged with our own
/// [CallSignalingService.selfRole] (Realtime broadcasts echo back to the
/// sender too).
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

/// Carries WebRTC offer/answer/ICE/hangup messages for one trip's call over
/// a Supabase Realtime broadcast channel - no persisted table, since a
/// signaling message is only ever useful to a peer that's live on the
/// channel right now, and a trip's UUID (unguessable, one call at a time)
/// is a good enough channel key for this app's threat model.
///
/// Owned by the trip-tracking screen for the screen's whole lifetime (not
/// by [CallScreen] itself), so the same subscription keeps listening for
/// the *next* incoming call after one ends - see
/// `TripTrackingScreen._callSignaling`.
class CallSignalingService {
  CallSignalingService({required this.tripId, required this.selfRole});

  final String tripId;

  /// 'customer' or 'captain' - tags every message we send, and lets us
  /// ignore the echo of our own broadcasts (Realtime delivers a broadcast
  /// to every subscriber on the channel, sender included).
  final String selfRole;

  RealtimeChannel? _channel;
  final _offers = StreamController<CallSignal>.broadcast();
  final _answers = StreamController<CallSignal>.broadcast();
  final _iceCandidates = StreamController<CallSignal>.broadcast();
  final _hangups = StreamController<CallSignal>.broadcast();

  Stream<CallSignal> get onOffer => _offers.stream;
  Stream<CallSignal> get onAnswer => _answers.stream;
  Stream<CallSignal> get onIceCandidate => _iceCandidates.stream;
  Stream<CallSignal> get onHangup => _hangups.stream;

  void start() {
    _channel = SupabaseConfig.client.channel('call_trip_$tripId')
      ..onBroadcast(
        event: 'signal',
        callback: (payload) {
          final from = payload['from'] as String?;
          if (from == null || from == selfRole) return;
          final signal = CallSignal(
            type: payload['type'] as String? ?? '',
            from: from,
            sdp: payload['sdp'] as String?,
            candidate: payload['candidate'] as String?,
            sdpMid: payload['sdpMid'] as String?,
            sdpMLineIndex: payload['sdpMLineIndex'] as int?,
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
        },
      )
      ..subscribe();
  }

  Future<void> sendOffer(String sdp) => _send({'type': 'offer', 'sdp': sdp});

  Future<void> sendAnswer(String sdp) => _send({'type': 'answer', 'sdp': sdp});

  Future<void> sendIceCandidate({
    required String candidate,
    String? sdpMid,
    int? sdpMLineIndex,
  }) => _send({
    'type': 'ice',
    'candidate': candidate,
    'sdpMid': sdpMid,
    'sdpMLineIndex': sdpMLineIndex,
  });

  Future<void> sendHangup() => _send({'type': 'hangup'});

  Future<void> _send(Map<String, dynamic> payload) async {
    final channel = _channel;
    if (channel == null) return;
    await channel.sendBroadcastMessage(
      event: 'signal',
      payload: {...payload, 'from': selfRole},
    );
  }

  void dispose() {
    _channel?.unsubscribe();
    _offers.close();
    _answers.close();
    _iceCandidates.close();
    _hangups.close();
  }
}
