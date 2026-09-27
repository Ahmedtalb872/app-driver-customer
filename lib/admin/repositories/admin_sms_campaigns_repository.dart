import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

class AdminSmsCampaignsRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  /// Sends an SMS campaign to a target audience and returns how many were
  /// actually sent (see supabase/functions/send-sms-campaign). [audience] is
  /// one of 'customers', 'captains', 'both' (all three read phone numbers
  /// from registered profiles), or 'custom' (default - the actual primary
  /// use case: recruiting people who've never signed up), in which case
  /// [phones] must be a non-empty list of admin-supplied phone numbers.
  /// [url]/[code] are optional - this Chinguisoft campaign account's actual
  /// message text is fixed on Chinguisoft's own side, not composed here.
  Future<int> sendCampaign({
    required String title,
    String? url,
    String? code,
    String audience = 'custom',
    List<String>? phones,
  }) async {
    final response = await _client.functions.invoke(
      'send-sms-campaign',
      body: {
        'title': title,
        'url': url ?? '',
        'code': code ?? '',
        'audience': audience,
        if (phones != null) 'phones': phones,
      },
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
