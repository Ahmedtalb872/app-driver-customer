import '../config/supabase_config.dart';

/// Fetches short-lived Cloudflare Realtime TURN credentials from the
/// `turn-credentials` edge function - see [CallService]'s only caller.
/// Never throws: a failure (not configured, network error, Cloudflare
/// down) returns null exactly like "no TURN available", so a call still
/// goes through on STUN alone, same as before this existed.
class TurnCredentialsService {
  TurnCredentialsService._();
  static final instance = TurnCredentialsService._();

  Future<List<Map<String, dynamic>>?> fetchIceServers() async {
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'turn-credentials',
      );
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
