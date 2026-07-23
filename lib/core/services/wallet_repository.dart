import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../config/supabase_config.dart';

/// Read-only access to the signed-in user's `wallets`/`wallet_transactions`
/// rows (see 20260712000005_create_wallets.sql,
/// 20260712000020_create_wallet_transactions.sql). Balance-changing writes
/// only ever happen through admin-reviewed SECURITY DEFINER functions
/// (`admin_approve_recharge`, ...) - there is no client write path, which is
/// why this repository is fetch-only.
class WalletRepository {
  WalletRepository._();

  static final WalletRepository instance = WalletRepository._();

  SupabaseClient get _client => SupabaseConfig.client;

  Future<double> fetchBalance() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return 0.0;
    final row = await _client
        .from('wallets')
        .select('balance')
        .eq('user_id', uid)
        .maybeSingle();
    return (row?['balance'] as num?)?.toDouble() ?? 0.0;
  }

  Future<List<WalletTransaction>> fetchTransactions({int limit = 50}) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from('wallet_transactions')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(_rowToTransaction)
        .toList();
  }

  WalletTransaction _rowToTransaction(Map<String, dynamic> row) {
    return WalletTransaction(
      id: row['id'] as String,
      amount: (row['amount'] as num).toDouble(),
      type: _typeFromDb(row['type'] as String?),
      title: (row['description'] as String?)?.trim().isNotEmpty == true
          ? row['description'] as String
          : _defaultTitle(row['type'] as String?),
      date: (row['created_at'] as String).substring(0, 16).replaceFirst(
        'T',
        ' ',
      ),
      isCredit: row['is_credit'] as bool? ?? false,
    );
  }

  TransactionType _typeFromDb(String? value) {
    switch (value) {
      case 'recharge':
        return TransactionType.charge;
      case 'payment':
        return TransactionType.payment;
      case 'refund':
        return TransactionType.refund;
      case 'withdraw':
        return TransactionType.withdraw;
      case 'commission':
        return TransactionType.commission;
      case 'transfer':
        return TransactionType.transfer;
      default:
        return TransactionType.reward;
    }
  }

  String _defaultTitle(String? type) {
    switch (type) {
      case 'recharge':
        return 'شحن رصيد المحفظة';
      case 'payment':
        return 'دفع رحلة';
      case 'refund':
        return 'استرجاع مبلغ';
      case 'withdraw':
        return 'سحب رصيد';
      default:
        return 'عملية في المحفظة';
    }
  }
}
