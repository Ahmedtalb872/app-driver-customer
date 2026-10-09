import 'dart:async';

import '../config/supabase_config.dart';

/// Fetches short-lived Cloudflare Realtime TURN credentials from the
/// `turn-credentials` edge function - see [CallService]'s only caller.
/// Never throws: a failure (not configured, network error, Cloudflare
/// down) returns null exactly like "no TURN available", so a call still
/// goes through on STUN alone, same as before this existed.
class TurnCredentialsService {
  TurnCredentialsService._();
  static final instance = TurnCredentialsService._();

  /// Bounds how long a call's setup can possibly be held up by this - a
  /// slow or hanging request here (a flaky mobile connection reaching the
  /// edge function, which itself calls out to Cloudflare) would otherwise
  /// freeze the whole call indefinitely before createPeerConnection is
  /// even reached, since CallService awaits this before building its ICE
  /// config. "Best effort, never blocks the call" was always the intent
  /// (see the class doc above) but was never actually enforced - this is
  /// that enforcement.
  static const _timeout = Duration(seconds: 4);

  Future<List<Map<String, dynamic>>?> fetchIceServers() async {
    try {
      final response = await SupabaseConfig.client.functions
          .invoke('turn-credentials')
          .timeout(_timeout);
      final data = response.data;
      if (data is! Map) return null;
      final iceServers = data['iceServers'];
      if (iceServers is! List) return null;
      return iceServers.cast<Map<String, dynamic>>();
    } catch (_) {
      return null;
    }
  }
}
