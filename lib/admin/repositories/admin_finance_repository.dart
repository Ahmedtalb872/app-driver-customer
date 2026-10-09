import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

class AdminFinanceRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<List<Map<String, dynamic>>> loadWallets({
    String? searchQuery,
    int limit = 25,
    int offset = 0,
  }) async {
    var query = _client.from('wallets').select('*, profiles!inner(*)');
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim();
      query = query.or(
        'full_name.ilike.%$q%,phone.ilike.%$q%',
        referencedTable: 'profiles',
      );
    }
    final rows = await query
        .order('updated_at', ascending: false)
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> loadTransactions({
    String? typeFilter,
    int limit = 50,
    int offset = 0,
  }) async {
    var query = _client.from('wallet_transactions').select();
    if (typeFilter != null && typeFilter.isNotEmpty) {
      query = query.eq('type', typeFilter);
    }
    final rows = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> loadRechargeRequests({
    String? statusFilter,
    int limit = 25,
    int offset = 0,
  }) async {
    var query = _client.from('recharge_requests').select();
    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.eq('status', statusFilter);
    }
    final rows = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> loadWithdrawalRequests({
    String? statusFilter,
    int limit = 25,
    int offset = 0,
  }) async {
    var query = _client.from('withdrawal_requests').select();
    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.eq('status', statusFilter);
    }
    final rows = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> approveRecharge(String requestId, {String? notes}) async {
    await _client.rpc(
      'admin_approve_recharge',
      params: {'p_request_id': requestId, 'p_notes': notes},
    );
  }

  Future<void> rejectRecharge(String requestId, String reason) async {
    await _client.rpc(
      'admin_reject_recharge',
      params: {'p_request_id': requestId, 'p_reason': reason},
    );
  }

  Future<void> approveWithdrawal(String requestId, {String? notes}) async {
    await _client.rpc(
      'admin_approve_withdrawal',
      params: {'p_request_id': requestId, 'p_notes': notes},
    );
  }

  Future<void> rejectWithdrawal(String requestId, String reason) async {
    await _client.rpc(
      'admin_reject_withdrawal',
      params: {'p_request_id': requestId, 'p_reason': reason},
    );
  }

  Future<void> adjustWalletBalance(
    String userId,
    double amount,
    bool isCredit,
    String reason,
  ) async {
    await _client.rpc(
      'admin_adjust_wallet_balance',
      params: {
        'p_user_id': userId,
        'p_amount': amount,
        'p_is_credit': isCredit,
        'p_reason': reason,
      },
    );
  }

  /// Captain-subscription cycles flagged for manual review (an early
  /// cancellation before the captain's escrowed share was fully paid out,
  /// or a trusted-mode renewal neither side confirmed in time) - see
  /// admin_list_subscription_disputes(),
  /// 20260812000057_subscription_staged_payout.sql. The actual wallet fix
  /// is made separately via [adjustWalletBalance]; this dispute row just
  /// tracks that something needs a human decision.
  Future<List<Map<String, dynamic>>> loadSubscriptionDisputes() async {
    final rows = await _client.rpc('admin_list_subscription_disputes');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> dismissSubscriptionDispute(
    String subscriptionId,
    String notes,
  ) async {
    await _client.rpc(
      'admin_dismiss_subscription_dispute',
      params: {'p_subscription_id': subscriptionId, 'p_notes': notes},
    );
  }
}
