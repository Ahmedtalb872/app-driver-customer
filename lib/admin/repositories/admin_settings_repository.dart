import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

class AdminSettingsRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<Map<String, dynamic>> load() async {
    final row = await _client
        .from('app_settings')
        .select()
        .eq('id', true)
        .single();
    return row;
  }

  Future<void> update(
    Map<String, dynamic> before,
    Map<String, dynamic> payload,
  ) async {
    await _client
        .from('app_settings')
        .update({...payload, 'updated_by': _client.auth.currentUser?.id})
        .eq('id', true);

    await _client.rpc(
      'log_admin_action',
      params: {
        'p_action': 'settings_updated',
        'p_entity_type': 'app_settings',
        'p_entity_id': 'app_settings',
        'p_before_value': before,
        'p_after_value': payload,
      },
    );
  }
}
