import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/supabase/auth_exception.dart';
import '../../core/supabase/wallet_repository.dart';
import '../../providers/app_state_provider.dart';
import 'bpay_success_screen.dart';

/// Our merchant identification code with Bankily's Bpay service (BPM),
/// shown to the captain so they can pay it directly from their Bankily app.
const String _kBpayMerchantCode = '027575';

/// Wallet recharge via Bankily's Bpay: the captain enters the amount, the
/// Bankily number to charge, and the passcode Bankily gave them, and
/// WalletRepository submits it to the live bpay-payment Edge Function -
/// the wallet is credited automatically the moment the bank confirms it,
/// no admin review involved.
class BpayRechargeScreen extends StatefulWidget {
  const BpayRechargeScreen({super.key});

  @override
  State<BpayRechargeScreen> createState() => _BpayRechargeScreenState();
}

class _BpayRechargeScreenState extends State<BpayRechargeScreen> {
  final _repository = WalletRepository();
  final _amountController = TextEditingController();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _copyMerchantCode() {
    Clipboard.setData(const ClipboardData(text: _kBpayMerchantCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ الكود', style: TextStyle(fontFamily: 'Cairo')),
      ),
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    final phone = _phoneController.text.trim();
    final code = _codeController.text.trim();

    if (amount == null || amount <= 0) {
      _showError('أدخل مبلغًا صحيحًا.');
      return;
    }
    if (phone.isEmpty) {
      _showError('أدخل رقم Bankily الذي دفعت منه.');
      return;
    }
    if (code.isEmpty) {
      _showError('أدخل رمز التحقق الذي وصلك من Bankily.');
      return;
    }
    if (code.length != 4 || int.tryParse(code) == null) {
      _showError('رمز التحقق يجب أن يكون 4 أرقام بالضبط.');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result = await _repository.submitRechargeRequest(
        amount: amount,
        payerPhone: phone,
        verificationCode: code,
      );
      if (!mounted) return;

      if (result.status == BpayRechargeStatus.success) {
        Provider.of<AppStateProvider>(
          context,
          listen: false,
        ).creditWalletFromBpayRecharge(amount);
      }

      // Every outcome (success / failure / pending) now lands on the
      // result screen, so the captain sees the bank's own message and
      // the amount instead of a red toast that disappears in 4 seconds.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => BpaySuccessScreen(
            amount: amount,
            status: result.status,
            bankMessage: result.message,
          ),
        ),
      );
    } on AppAuthException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('دفع BPAY'),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.darkText,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Image.asset(
                  'assets/images/bankily_logo_transparent.png',
                  height: 110,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ادفع كود Bpay من تطبيق Bankily، ثم أدخل تفاصيل الدفع أدناه.',
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'Cairo',
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text(
                          'كود Bpay الهدهد: ',
                          style: TextStyle(
                            fontSize: 15,
                            fontFamily: 'Cairo',
                            color: AppColors.darkText,
                          ),
                        ),
                        Text(
                          _kBpayMerchantCode,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                            fontFamily: 'Cairo',
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          onPressed: _copyMerchantCode,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'أدخل تفاصيل الدفع',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'أدخل المبلغ ورقم Bankily ورمز الدفع.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'المبلغ (MRU)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم Bankily'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'رمز التحقق (4 أرقام)',
                  counterText: '',
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('ادفع الآن'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
