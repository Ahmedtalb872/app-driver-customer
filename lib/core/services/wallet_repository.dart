import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../config/supabase_config.dart';

/// Outcome of a live Bpay recharge call - mirrors the three statuses the
/// customer-bpay-payment Edge Function can resolve to (see
/// checkTransaction's TS/TF/TA in Bankily's B-PAY spec): success credits
/// the wallet immediately, pending means the bank is still confirming and
/// the wallet will be credited automatically once it does, failed means
/// it didn't go through at all.
enum BpayRechargeStatus { success, pending, failed }

class BpayRechargeResult {
  final BpayRechargeStatus status;
  final String message;
  const BpayRechargeResult(this.status, this.message);
}

/// Access to the signed-in user's `wallets`/`wallet_transactions` rows (see
/// 20260712000005_create_wallets.sql,
/// 20260712000020_create_wallet_transactions.sql). Balance-changing writes
/// only ever happen through SECURITY DEFINER functions: either an admin
/// reviewing a queued request (`admin_approve_recharge`, ...) - the
/// client's only direct write for that path is [submitRechargeRequest], a
/// plain `recharge_requests` insert RLS already allows for the row's own
/// owner (`auth.uid() = user_id`, 20260712000026_admin_rls.sql) - or a
/// live Bpay payment confirmed by the bank, credited immediately with no
/// admin review via [submitBpayRecharge].
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

  /// Queues a wallet top-up for admin review - does not credit the wallet
  /// itself (see the class doc). [method] is the payment provider's
  /// display name (Bankily/Masrvi/Sedad), stored as free text for the
  /// admin's own reference.
  Future<void> submitRechargeRequest({
    required double amount,
    required String method,
  }) async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) throw StateError('Not signed in');
    final wallet = await _client
        .from('wallets')
        .select('id')
        .eq('user_id', uid)
        .single();
    await _client.from('recharge_requests').insert({
      'user_id': uid,
      'wallet_id': wallet['id'],
      'amount': amount,
      'payment_method': method,
    });
  }

  /// Live wallet recharge via Bankily's Bpay - calls the
  /// customer-bpay-payment Edge Function (the customer-app counterpart of
  /// aihoudhoud/captain app's own bpay-payment), which credits the wallet
  /// automatically the moment the bank confirms the payment, no admin
  /// review involved (unlike [submitRechargeRequest] above).
  Future<BpayRechargeResult> submitBpayRecharge({
    required double amount,
    required String payerPhone,
    required String verificationCode,
  }) async {
    if (_client.auth.currentUser == null) {
      throw StateError('Not signed in');
    }
    try {
      final response = await _client.functions.invoke(
        'customer-bpay-payment',
        body: {
          'amount': amount,
          'payerPhone': payerPhone,
          'passcode': verificationCode,
        },
      );
      return _parseBpayResult(response.data);
    } on FunctionException catch (e) {
      return _parseBpayResult(e.details);
    } catch (_) {
      return const BpayRechargeResult(
        BpayRechargeStatus.failed,
        'تعذر الاتصال بخدمة الدفع، حاول مرة أخرى.',
      );
    }
  }

  BpayRechargeResult _parseBpayResult(dynamic data) {
    if (data is! Map) {
      return const BpayRechargeResult(
        BpayRechargeStatus.failed,
        'تعذر الاتصال بخدمة الدفع، حاول مرة أخرى.',
      );
    }
    final status = BpayRechargeStatus.values.firstWhere(
      (s) => s.name == data['status'],
      orElse: () => BpayRechargeStatus.failed,
    );
    final message =
        data['message'] as String? ?? 'تعذر إتمام عملية الدفع، حاول مرة أخرى.';
    return BpayRechargeResult(status, message);
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
