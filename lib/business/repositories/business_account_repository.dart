import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/business_account.dart';

class BusinessAccountRepository {
  BusinessAccountRepository._();

  static final BusinessAccountRepository instance =
      BusinessAccountRepository._();

  SupabaseClient get _client => SupabaseConfig.client;

  /// Null means the signed-in user has no business_accounts row yet (a
  /// mid-registration state: the auth account exists but
  /// [createMyAccount] hasn't run/finished - see business_register_screen).
  Future<BusinessAccount?> fetchMyAccount() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _client
        .from('business_accounts')
        .select()
        .eq('id', uid)
        .maybeSingle();
    return row == null ? null : BusinessAccount.fromJson(row);
  }

  /// Creates the signed-in user's own business_accounts row right after
  /// [BusinessAuthService.signUp] - always lands as 'pending' regardless of
  /// what's sent (see the migration's protect_business_account_status
  /// trigger), awaiting admin review.
  Future<void> createMyAccount({
    required String businessName,
    required String businessType,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in.');
    await _client.from('business_accounts').insert({
      'id': uid,
      'business_name': businessName,
      'business_type': businessType,
    });
  }

  Future<void> updateDefaultPickup({
    required String address,
    required double lat,
    required double lng,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in.');
    await _client
        .from('business_accounts')
        .update({
          'default_pickup_address': address,
          'default_pickup_lat': lat,
          'default_pickup_lng': lng,
        })
        .eq('id', uid);
  }
}
