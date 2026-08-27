import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_exception.dart';
import 'supabase_config.dart';

/// Outcome of a live Bpay recharge call - mirrors the three statuses the
/// bpay-payment Edge Function can resolve to (see checkTransaction's
/// TS/TF/TA in Bankily's B-PAY spec): success credits the wallet
/// immediately, pending means the bank is still confirming and the wallet
/// will be credited automatically once it does, failed means it didn't go
/// through at all.
enum BpayRechargeStatus { success, pending, failed }

class BpayRechargeResult {
  final BpayRechargeStatus status;
  final String message;
  const BpayRechargeResult(this.status, this.message);
}

/// Recharging the wallet calls Bankily's live Bpay merchant API through the
/// bpay-payment Edge Function (see supabase/functions/bpay-payment), which
/// holds the merchant credentials server-side - they must never live in the
/// Flutter client. The captain's wallet is credited automatically the
/// moment the bank confirms the payment, no admin review needed.
class WalletRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<BpayRechargeResult> submitRechargeRequest({
    required double amount,
    required String payerPhone,
    required String verificationCode,
  }) async {
    if (_client.auth.currentUser == null) {
      throw AppAuthException('يجب تسجيل الدخول أولاً.');
    }
    try {
      final response = await _client.functions.invoke(
        'bpay-payment',
        body: {
          'amount': amount,
          'payerPhone': payerPhone,
          'passcode': verificationCode,
        },
      );
      return _parseRechargeResult(response.data);
    } on FunctionException catch (e) {
      return _parseRechargeResult(e.details);
    } catch (_) {
      return const BpayRechargeResult(
        BpayRechargeStatus.failed,
        'تعذر الاتصال بخدمة الدفع، حاول مرة أخرى.',
      );
    }
  }

  BpayRechargeResult _parseRechargeResult(dynamic data) {
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
    final message = data['message'] as String? ??
        'تعذر إتمام عملية الدفع، حاول مرة أخرى.';
    return BpayRechargeResult(status, message);
  }

  Future<List<Map<String, dynamic>>> getMyRechargeRequests() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    try {
      return await _client
          .from('wallet_recharge_requests')
          .select()
          .eq('captain_id', userId)
          .order('created_at', ascending: false);
    } on PostgrestException {
      throw AppAuthException('تعذر تحميل طلبات الشحن.');
    }
  }

  /// Sum of the captain's still-valid, unredeemed gift credits (1 MRU
  /// granted per completed trip, each expiring 3 months after it was
  /// earned) - see migration 0011 for the crediting/expiry rules.
  Future<double> getGiftBalance() async {
    try {
      final result = await _client.rpc('get_captain_gift_balance');
      return (result as num).toDouble();
    } on PostgrestException {
      throw AppAuthException('تعذر تحميل رصيد مكافأتي.');
    }
  }

  /// Redeems the captain's entire gift balance into the main wallet - only
  /// succeeds server-side if that balance is already at least 10 MRU.
  /// Returns the redeemed amount.
  Future<double> redeemGiftCredits() async {
    try {
      final result = await _client.rpc('redeem_captain_gift_credits');
      return (result as num).toDouble();
    } on PostgrestException catch (e) {
      throw AppAuthException(
        e.message.contains('10')
            ? 'رصيد الهدايا أقل من 10 أوقية، لا يمكن التحويل بعد.'
            : 'تعذر تحويل رصيد الهدايا، حاول مرة أخرى.',
      );
    }
  }
}
