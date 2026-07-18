import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

class AdminAuditRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<List<Map<String, dynamic>>> loadLogs({
    String? entityTypeFilter,
    int limit = 50,
    int offset = 0,
  }) async {
    var query = _client.from('audit_logs').select();
    if (entityTypeFilter != null && entityTypeFilter.isNotEmpty) {
      query = query.eq('entity_type', entityTypeFilter);
    }
    final rows = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(rows);
  }
}
