import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

class AdminSmsCampaignsRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<Map<String, dynamic>> _invokeOnce({
    required String title,
    required String url,
    required String code,
    required String audience,
    List<String>? phones,
    String? campaignId,
    required double delaySeconds,
  }) async {
    final response = await _client.functions.invoke(
      'send-sms-campaign',
      body: {
        'title': title,
        'url': url,
        'code': code,
        'audience': audience,
        if (phones != null) 'phones': phones,
        if (campaignId != null) 'campaignId': campaignId,
        'delaySeconds': delaySeconds,
      },
    );
    final data = response.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
    return Map<String, dynamic>.from(data as Map);
  }

  /// Sends an SMS campaign to a target audience, looping the Edge Function
  /// call as many times as needed until every recipient has a final result
  /// (see supabase/functions/send-sms-campaign - a single call only
  /// processes a bounded chunk, to stay safely inside the function's
  /// execution time limit even with a real per-message delay). [audience]
  /// is one of 'customers', 'captains', 'both' (all three read phone
  /// numbers from registered profiles), or 'custom' (default - the actual
  /// primary use case: recruiting people who've never signed up), in which
  /// case [phones] must be a non-empty list of admin-supplied phone
  /// numbers. [url]/[code] are optional - this Chinguisoft campaign
  /// account's actual message text is fixed on Chinguisoft's own side, not
  /// composed here. [delaySeconds] paces the sends (capped at 3s
  /// server-side) so as not to trip Chinguisoft's own rate limiting.
  /// [onProgress] is called after every chunk with (sentSoFar, remaining).
  /// Returns the final total sent.
  Future<int> sendCampaign({
    required String title,
    String? url,
    String? code,
    String audience = 'custom',
    List<String>? phones,
    double delaySeconds = 0.5,
    void Function(int sentSoFar, int remaining)? onProgress,
  }) async {
    String? campaignId;
    int sentTotal = 0;
    int remaining = 1; // force at least one call

    while (remaining > 0) {
      final data = await _invokeOnce(
        title: title,
        url: url ?? '',
        code: code ?? '',
        audience: audience,
        phones: campaignId == null ? phones : null,
        campaignId: campaignId,
        delaySeconds: delaySeconds,
      );
      campaignId = data['campaignId'] as String?;
      sentTotal = (data['sent'] as num?)?.toInt() ?? sentTotal;
      remaining = (data['remaining'] as num?)?.toInt() ?? 0;
      onProgress?.call(sentTotal, remaining);
    }
    return sentTotal;
  }

  Future<List<Map<String, dynamic>>> loadHistory() async {
    final rows = await _client
        .from('sms_campaign_broadcasts')
        .select()
        .order('sent_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Per-number results for one campaign (phone + status + any error) -
  /// see public.sms_campaign_recipients, written to incrementally by
  /// send-sms-campaign as each send completes.
  Future<List<Map<String, dynamic>>> loadRecipients(String campaignId) async {
    final rows = await _client
        .from('sms_campaign_recipients')
        .select()
        .eq('campaign_id', campaignId)
        .order('created_at');
    return List<Map<String, dynamic>>.from(rows);
  }
}
