import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

class AdminSmsCampaignsRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  /// Sends a promotional SMS (a link + discount code - Chinguisoft's fixed
  /// campaign template) to every customer and/or captain with a phone
  /// number (see supabase/functions/send-sms-campaign) and returns how many
  /// were actually sent. [audience] is one of 'customers' (default),
  /// 'captains', or 'both'.
  Future<int> sendCampaign({
    required String title,
    required String url,
    required String code,
    String audience = 'customers',
  }) async {
    final response = await _client.functions.invoke(
      'send-sms-campaign',
      body: {'title': title, 'url': url, 'code': code, 'audience': audience},
    );
    final data = response.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
    return (data is Map ? data['sent'] as num? : null)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> loadHistory() async {
    final rows = await _client
        .from('sms_campaign_broadcasts')
        .select()
        .order('sent_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(rows);
  }
}
