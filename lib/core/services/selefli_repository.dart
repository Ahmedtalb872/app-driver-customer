import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../config/supabase_config.dart';

/// "سلفلي" (Selefli) - a loyal customer's ride-now-pay-later credit line.
/// See customer_selefli_status/customer_request_trip/captain_end_trip/
/// admin_approve_recharge in 20260812000055_selefli_credit.sql for the
/// full eligibility/debt-creation/auto-repayment logic this only reads or
/// triggers - this repository itself does no balance/debt math client-side.
class SelefliRepository {
  SelefliRepository._();

  static final SelefliRepository instance = SelefliRepository._();

  SupabaseClient get _client => SupabaseConfig.client;

  /// Empty-state default (not eligible, nothing owed) for a signed-out
  /// session, matching how the rest of this app's repositories treat "no
  /// user" as an empty result rather than an error.
  Future<SelefliStatus> fetchStatus() async {
    if (_client.auth.currentUser == null) {
      return const SelefliStatus(
        cap: null,
        outstandingAmount: 0,
        completedTripsCount: 0,
      );
    }
    final row = await _client.rpc('customer_selefli_status');
    final data = row is List
        ? Map<String, dynamic>.from(row.first as Map)
        : Map<String, dynamic>.from(row as Map);
    return SelefliStatus.fromJson(data);
  }
}
