import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/colors.dart';
import '../../../core/services/wallet_repository.dart';
import 'payment_gateway_service.dart';
import 'payment_provider_config.dart';

enum _PaymentStage { form, processing, success, failure }

/// A single reusable, native (no WebView) payment screen used for Bankily,
/// Masrvi, Sedad and any future provider. Only [provider] changes what's
/// shown (logo, colors, merchant fields, field lengths) — the layout,
/// validation, processing/success/failure states are shared.
///
/// On a successful provider payment, this screen queues a wallet recharge
/// request (see [WalletRepository.submitRechargeRequest]) - the payment
/// itself succeeded, but the wallet balance only actually updates once an
/// admin reviews and approves the request (the same review queue
/// `recharge_requests` was always meant to back), so the success screen
/// says "submitted for review", not "credited".
class PaymentGatewayScreen extends StatefulWidget {
  final PaymentProviderConfig provider;
  final double initialAmount;

  /// Injectable so a real API-backed implementation can replace the mock
  /// later without any change to this screen.
  final PaymentGatewayService? gatewayService;

  const PaymentGatewayScreen({
    super.key,
    required this.provider,
    required this.initialAmount,
    this.gatewayService,
  });

  @override
  State<PaymentGatewayScreen> createState() => _PaymentGatewayScreenState();
}

class _PaymentGatewayScreenState extends State<PaymentGatewayScreen> {
  late final PaymentGatewayService _service =
      widget.gatewayService ?? const MockPaymentGatewayService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  bool _obscurePin = true;

  _PaymentStage _stage = _PaymentStage.form;
  String? _failureReason;
  String? _transactionReference;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.initialAmount.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_amountController.text) ?? 0.0;

  void _copyMerchantId() {
    Clipboard.setData(ClipboardData(text: widget.provider.merchantId));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'تم نسخ رقم التاجر',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _handleConfirm() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _stage = _PaymentStage.processing);

    final result = await _service.pay(
      provider: widget.provider,
      amount: _amount,
      phoneNumber: _phoneController.text,
      pin: _pinController.text,
    );

    if (!mounted) return;

    if (result.isSuccess) {
      try {
        await WalletRepository.instance.submitRechargeRequest(
          amount: _amount,
          method: widget.provider.displayName,
        );
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _stage = _PaymentStage.failure;
          _failureReason =
              'تم الدفع لكن تعذر إرسال طلب الشحن الآن. تواصل مع الدعم مع رقم العملية.';
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _stage = _PaymentStage.success;
        _transactionReference = result.transactionReference;
      });
    } else {
      setState(() {
        _stage = _PaymentStage.failure;
        _failureReason = result.failureReason;
      });
    }
  }

  void _retry() {
    setState(() => _stage = _PaymentStage.form);
  }

  @override
  Widget build(BuildContext context) {
    final provider = widget.provider;
    return PopScope(
      canPop: _stage != _PaymentStage.processing,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: switch (_stage) {
            _PaymentStage.form => _buildForm(provider),
            _PaymentStage.processing => _buildProcessing(provider),
            _PaymentStage.success => _buildSuccess(provider),
            _PaymentStage.failure => _buildFailure(provider),
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Form stage
  // ---------------------------------------------------------------------

  Widget _buildForm(PaymentProviderConfig provider) {
    return Column(
      children: [
        _buildHeader(provider),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMerchantCard(provider),
                  const SizedBox(height: 20),

                  _buildFieldLabel('رقم هاتف ${provider.displayName} الخاص بك'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    maxLength: provider.phoneDigits,
                    decoration: const InputDecoration(
                      counterText: '',
                      hintText: 'أدخل رقم الهاتف',
                      prefixIcon: Icon(
                        Icons.phone_iphone_rounded,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'الرجاء إدخال رقم الهاتف';
                      }
                      if (value.length != provider.phoneDigits) {
                        return 'رقم الهاتف يجب أن يتكون من ${provider.phoneDigits} أرقام';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  _buildFieldLabel('رمز ${provider.displayName} السري (PIN)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _pinController,
                    obscureText: _obscurePin,
                    keyboardType: TextInputType.number,
                    maxLength: provider.pinDigits,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '•' * provider.pinDigits,
                      prefixIcon: const Icon(
                        Icons.lock_outline_rounded,
                        color: AppColors.secondaryText,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePin
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.secondaryText,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePin = !_obscurePin),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'الرجاء إدخال رمز PIN';
                      }
                      if (value.length != provider.pinDigits) {
                        return 'رمز PIN يجب أن يتكون من ${provider.pinDigits} أرقام';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  _buildFieldLabel('المبلغ (أوقية)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(
                        Icons.payments_outlined,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      final amt = double.tryParse(value ?? '');
                      if (amt == null || amt <= 0) {
                        return 'الرجاء إدخال مبلغ صحيح';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  _buildSummaryCard(provider),
                  const SizedBox(height: 28),

                  ElevatedButton(
                    onPressed: _handleConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: provider.primaryColor,
                    ),
                    child: const Text('تأكيد الدفع'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.secondaryText,
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: const Text('إلغاء'),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(PaymentProviderConfig provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 28),
      decoration: BoxDecoration(
        color: provider.primaryColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(false),
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: provider.onPrimaryColor,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: provider.onPrimaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      color: provider.onPrimaryColor,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'دفع آمن',
                      style: TextStyle(
                        color: provider.onPrimaryColor,
                        fontSize: 11,
                        fontFamily: 'Cairo',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: provider.onPrimaryColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    provider.logoIcon,
                    color: provider.onPrimaryColor,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الدفع عبر ${provider.displayName}',
                        style: TextStyle(
                          color: provider.onPrimaryColor,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          fontFamily: 'Cairo',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        provider.legalName,
                        style: TextStyle(
                          color: provider.onPrimaryColor.withOpacity(0.85),
                          fontSize: 12,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMerchantCard(PaymentProviderConfig provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow(
            'رقم التاجر (Merchant ID)',
            provider.merchantId,
            copyable: true,
          ),
          const Divider(height: 24),
          _buildInfoRow('اسم التاجر', provider.merchantName),
          const Divider(height: 24),
          _buildInfoRow(provider.accountLabel, provider.merchantAccountNumber),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool copyable = false}) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.secondaryText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ),
        if (copyable)
          IconButton(
            icon: const Icon(
              Icons.copy_rounded,
              size: 18,
              color: AppColors.primary,
            ),
            onPressed: _copyMerchantId,
          ),
      ],
    );
  }

  Widget _buildSummaryCard(PaymentProviderConfig provider) {
    const fee = 0.0;
    final total = _amount + fee;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: provider.primaryColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: provider.primaryColor.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ملخص العملية',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              fontFamily: 'Cairo',
              color: AppColors.darkText,
            ),
          ),
          const Divider(height: 24),
          _buildSummaryLine('المبلغ', '${_amount.toStringAsFixed(0)} أوقية'),
          const SizedBox(height: 8),
          _buildSummaryLine('رسوم الخدمة', '${fee.toStringAsFixed(0)} أوقية'),
          const Divider(height: 24),
          _buildSummaryLine(
            'الإجمالي المستحق',
            '${total.toStringAsFixed(0)} أوقية',
            emphasize: true,
            color: provider.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(
    String label,
    String value, {
    bool emphasize = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.secondaryText,
            fontFamily: 'Cairo',
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: emphasize ? 16 : 13,
            fontWeight: FontWeight.bold,
            color: color ?? AppColors.darkText,
            fontFamily: 'Cairo',
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: AppColors.darkText,
        fontFamily: 'Cairo',
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Processing / success / failure stages
  // ---------------------------------------------------------------------

  Widget _buildProcessing(PaymentProviderConfig provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              valueColor: AlwaysStoppedAnimation<Color>(provider.primaryColor),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'جارٍ معالجة الدفع عبر ${provider.displayName}...',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
              fontFamily: 'Cairo',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'الرجاء الانتظار، لا تغلق التطبيق.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.secondaryText,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess(PaymentProviderConfig provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 64,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'تم إرسال طلب الشحن',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'تم الدفع بنجاح عبر ${provider.displayName}، وأُرسل طلب شحن بمبلغ '
              '${_amount.toStringAsFixed(0)} أوقية للمراجعة. ستُضاف إلى '
              'محفظتك بعد موافقة الإدارة.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
                fontFamily: 'Cairo',
              ),
            ),
            if (_transactionReference != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  'رقم العملية: $_transactionReference',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                    fontFamily: 'Cairo',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                ),
                child: const Text('تم'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailure(PaymentProviderConfig provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 64,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'فشلت عملية الدفع',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _failureReason ?? 'حدث خطأ غير متوقع أثناء تنفيذ العملية.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.secondaryText,
                fontFamily: 'Cairo',
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _retry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: provider.primaryColor,
                ),
                child: const Text('إعادة المحاولة'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('إلغاء'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
