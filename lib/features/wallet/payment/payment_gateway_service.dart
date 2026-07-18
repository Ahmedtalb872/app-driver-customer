import 'payment_provider_config.dart';

/// Outcome of a single payment attempt, provider-agnostic.
class PaymentResult {
  final bool isSuccess;
  final String? transactionReference;
  final String? failureReason;

  const PaymentResult.success(this.transactionReference)
    : isSuccess = true,
      failureReason = null;

  const PaymentResult.failure(this.failureReason)
    : isSuccess = false,
      transactionReference = null;
}

/// Abstraction over "actually talk to the payment provider". [PaymentGatewayScreen]
/// only ever calls [pay] — swapping [MockPaymentGatewayService] for a real
/// Bankily/Masrvi/Sedad API client later is a one-line change with no UI impact.
abstract class PaymentGatewayService {
  Future<PaymentResult> pay({
    required PaymentProviderConfig provider,
    required double amount,
    required String phoneNumber,
    required String pin,
  });
}

/// Local, network-free simulation used until a real backend/API integration
/// is available. Deterministic edge cases (rather than pure randomness) keep
/// the failure path reachable and demoable: PIN "0000" or amounts above
/// 50,000 always fail with a specific reason; everything else succeeds.
class MockPaymentGatewayService implements PaymentGatewayService {
  const MockPaymentGatewayService();

  @override
  Future<PaymentResult> pay({
    required PaymentProviderConfig provider,
    required double amount,
    required String phoneNumber,
    required String pin,
  }) async {
    await Future.delayed(const Duration(seconds: 2));

    if (pin == '0000') {
      return const PaymentResult.failure(
        'رمز PIN غير صحيح. الرجاء التحقق والمحاولة مجدداً.',
      );
    }
    if (amount > 50000) {
      return PaymentResult.failure(
        'تم تجاوز الحد الأقصى المسموح به لعملية واحدة عبر ${provider.displayName}.',
      );
    }
    if (amount <= 0) {
      return const PaymentResult.failure('قيمة العملية غير صالحة.');
    }

    return PaymentResult.success(
      'TXN-${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}
