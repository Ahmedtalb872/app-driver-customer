import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

class AdminPricingRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<List<Map<String, dynamic>>> loadAll() async {
    final rows = await _client
        .from('pricing_config')
        .select()
        .order('vehicle_type');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> update(
    String id,
    Map<String, dynamic> before,
    Map<String, dynamic> payload,
  ) async {
    await _client
        .from('pricing_config')
        .update({...payload, 'updated_by': _client.auth.currentUser?.id})
        .eq('id', id);

    await _client.rpc(
      'log_admin_action',
      params: {
        'p_action': 'pricing_updated',
        'p_entity_type': 'pricing_config',
        'p_entity_id': id,
        'p_before_value': before,
        'p_after_value': payload,
      },
    );
  }
}
