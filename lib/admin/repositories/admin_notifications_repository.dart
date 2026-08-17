import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

class AdminNotificationsRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  /// Sends a push notification to every customer with a registered device
  /// (see supabase/functions/send-broadcast-push) and returns how many
  /// were actually reached.
  Future<int> sendBroadcast({required String title, required String body}) async {
    final response = await _client.functions.invoke(
      'send-broadcast-push',
      body: {'title': title, 'body': body},
    );
    final data = response.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
    return (data is Map ? data['sent'] as num? : null)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> loadHistory() async {
    final rows = await _client
        .from('notification_broadcasts')
        .select()
        .order('sent_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(rows);
  }
}
