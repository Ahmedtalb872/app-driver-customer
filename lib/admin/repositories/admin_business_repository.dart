import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

class AdminBusinessRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<List<Map<String, dynamic>>> loadBusinessAccounts({
    String? statusFilter,
  }) async {
    var query = _client.from('business_accounts').select('*, profiles(full_name, phone)');
    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.eq('status', statusFilter);
    }
    final rows = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> approve(String businessId) async {
    await _client
        .from('business_accounts')
        .update({'status': 'approved', 'rejection_reason': null})
        .eq('id', businessId);
  }

  Future<void> reject(String businessId, String reason) async {
    await _client
        .from('business_accounts')
        .update({'status': 'rejected', 'rejection_reason': reason})
        .eq('id', businessId);
  }

  Future<void> setSuspended(String businessId, bool suspended) async {
    await _client
        .from('business_accounts')
        .update({'status': suspended ? 'suspended' : 'approved'})
        .eq('id', businessId);
  }
}
