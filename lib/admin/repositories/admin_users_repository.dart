import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

class AdminUsersRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<List<Map<String, dynamic>>> loadAdmins() async {
    final rows = await _client
        .from('admin_users')
        .select('*, profiles!inner(*)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Promotes an *existing* authenticated user (found by their profile id)
  /// to admin. Creating a brand-new login from scratch needs the Supabase
  /// service-role key, which must never live in Flutter Web - see the
  /// admin_promote_to_admin() migration comment.
  Future<void> promoteToAdmin({
    required String targetUserId,
    required String adminRole,
    String? fullName,
  }) async {
    await _client.rpc(
      'admin_promote_to_admin',
      params: {
        'p_target_user_id': targetUserId,
        'p_admin_role': adminRole,
        'p_full_name': fullName,
      },
    );
  }

  Future<void> setActive(String adminId, bool isActive) async {
    await _client.rpc(
      'admin_set_admin_active',
      params: {'p_target_admin_id': adminId, 'p_is_active': isActive},
    );
  }

  /// Looks up a profile by phone so "Add Admin" can resolve a target user
  /// without needing to know their raw UUID.
  Future<Map<String, dynamic>?> findProfileByPhone(String phone) async {
    return await _client
        .from('profiles')
        .select()
        .eq('phone', phone)
        .maybeSingle();
  }
}
