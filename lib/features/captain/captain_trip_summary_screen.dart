import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';

class CaptainTripSummaryScreen extends StatelessWidget {
  const CaptainTripSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    // Get last trip from history (which is the one just completed)
    final trip = provider.captainTripHistory.isNotEmpty
        ? provider.captainTripHistory.first
        : null;

    if (trip == null) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('العودة للرئيسية'),
          ),
        ),
      );
    }

    final grossFare = trip.price;
    final commission =
        trip.commission ?? double.parse((grossFare * 0.15).toStringAsFixed(1));
    final netEarnings = trip.netEarnings ?? (grossFare - commission);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 30),

              // Success badge
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: AppColors.success,
                  size: 64,
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'عمل رائع يا كابتن!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                  fontFamily: 'Cairo',
                ),
              ),
              const Text(
                'تم تسجيل المشوار وإضافة الأرباح لمحفظتك بنجاح.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 32),

              // Financial Invoice Ledger card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'كشف أرباح الرحلة',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'Cairo',
                          color: AppColors.darkText,
                        ),
                      ),
                      const Divider(height: 24),

                      // Gross Fare
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'إجمالي قيمة الرحلة (المستلم)',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          Text(
                            '$grossFare أوقية',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.darkText,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Commission Deduction
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'عمولة الهدهد المستقطعة (15%)',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.error,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          Text(
                            '-$commission أوقية',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Net Earnings
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'صافي أرباحك من المشوار',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          Text(
                            '+$netEarnings أوقية',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),

                      // Route info
                      _buildSummaryRow('اسم العميل للرحلة', trip.customerName),
                      _buildSummaryRow(
                        'طريقة الدفع للمشوار',
                        trip.paymentMethod,
                      ),
                      _buildSummaryRow(
                        'المسافة والمدة',
                        '${trip.distance} كم (${trip.duration} دقيقة)',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Action buttons
              ElevatedButton(
                onPressed: () {
                  provider.confirmCaptainSummary();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('تأكيد العودة للوحة التحكم'),
                    SizedBox(width: 8),
                    Icon(Icons.dashboard_rounded),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'تم إرسال بلاغك للدعم للمراجعة المالية.',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.secondaryText,
                ),
                child: const Text('أواجه مشكلة في مستحقات الرحلة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.secondaryText,
              fontFamily: 'Cairo',
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}
