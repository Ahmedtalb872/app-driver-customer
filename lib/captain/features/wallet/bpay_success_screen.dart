import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../../core/supabase/wallet_repository.dart';

/// Shown right after any Bpay recharge attempt (success, failure, or
/// still-pending) instead of a SnackBar - each outcome gets a clear
/// screen carrying the amount and the bank's own message so the
/// captain sees exactly what happened. Success flow ends with a "back
/// to home" button that pops all the way to CaptainHomeScreen.
class BpaySuccessScreen extends StatelessWidget {
  final double amount;
  final BpayRechargeStatus status;
  final String bankMessage;

  const BpaySuccessScreen({
    super.key,
    required this.amount,
    this.status = BpayRechargeStatus.success,
    this.bankMessage = '',
  });

  bool get _isSuccess => status == BpayRechargeStatus.success;
  bool get _isFailure => status == BpayRechargeStatus.failed;
  bool get _isPending => status == BpayRechargeStatus.pending;

  Color get _accent {
    if (_isSuccess) return AppColors.success;
    if (_isFailure) return AppColors.error;
    return AppColors.warning;
  }

  IconData get _icon {
    if (_isSuccess) return Icons.check_rounded;
    if (_isFailure) return Icons.close_rounded;
    return Icons.hourglass_bottom_rounded;
  }

  String get _title {
    if (_isSuccess) return 'تمت العملية بنجاح';
    if (_isFailure) return 'فشلت العملية';
    return 'قيد التأكد من البنك';
  }

  String get _tagline {
    if (_isSuccess) return 'تم إضافة الرصيد إلى محفظتك.';
    if (_isFailure) return 'لم يتم خصم أي مبلغ من حسابك.';
    return 'سيتم إضافة الرصيد فور تأكيد البنك للعملية.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon, color: _accent, size: 64),
                ),
                const SizedBox(height: 24),
                Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                    fontFamily: 'Cairo',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _tagline,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'Cairo',
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 20),

                // Amount block - shown for every outcome so the captain
                // sees exactly which amount the bank confirmed/rejected.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _accent.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'مبلغ العملية',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_isSuccess ? '+' : ''}${amount.toStringAsFixed(0)} أوقية',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: _accent,
                          fontFamily: 'Cairo',
                        ),
                      ),
                    ],
                  ),
                ),

                if (bankMessage.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'رسالة البنك',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          bankMessage.trim(),
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 14,
                            color: AppColors.darkText,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                if (_isFailure)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة المحاولة'),
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.of(context).popUntil(
                        (route) => route.isFirst,
                      ),
                      icon: const Icon(Icons.home_rounded),
                      label: const Text('العودة للصفحة الرئيسية'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
