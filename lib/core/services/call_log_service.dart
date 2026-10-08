import '../config/supabase_config.dart';

/// Writes one row per call attempt to `call_logs` - a reviewable history
/// (who called whom, answered or not, how long) separate from
/// `call_signals`' raw WebRTC offer/answer/ICE rows, which have no single
/// row representing "one call" or its outcome. Used only by [CallScreen],
/// which is the one place that already lives through every transition
/// (ringing, answered, ended) for every kind of call in this app.
///
/// Every method is best-effort: a logging failure must never affect the
/// call itself, so nothing here ever throws - it just silently returns
/// null/does nothing.
class CallLogService {
  /// Call this once, right as a call starts ringing (either side), and
  /// keep the returned id for [logAnswered]/[logEnded]. Null means logging
  /// failed - callers just pass it straight through, since both other
  /// methods are themselves no-ops on a null id.
  Future<int?> logStarted({
    required String tripId,
    required String callerRole,
    required String calleeRole,
  }) async {
    try {
      final row = await SupabaseConfig.client
          .from('call_logs')
          .insert({
            'trip_id': tripId,
            'caller_role': callerRole,
            'callee_role': calleeRole,
          })
          .select('id')
          .single();
      return (row['id'] as num).toInt();
    } catch (_) {
      return null;
    }
  }

  Future<void> logAnswered(int? logId) async {
    if (logId == null) return;
    try {
      await SupabaseConfig.client
          .from('call_logs')
          .update({'answered_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', logId);
    } catch (_) {
      // Best effort - a missing answered_at just means the review screen
      // can't show when the call connected, nothing worse.
    }
  }

  Future<void> logEnded(
    int? logId, {
    required String outcome,
    int? durationSeconds,
  }) async {
    if (logId == null) return;
    try {
      await SupabaseConfig.client
          .from('call_logs')
          .update({
            'ended_at': DateTime.now().toUtc().toIso8601String(),
            'outcome': outcome,
            if (durationSeconds != null) 'duration_seconds': durationSeconds,
          })
          .eq('id', logId);
    } catch (_) {
      // Best effort - see logAnswered.
    }
  }
}
