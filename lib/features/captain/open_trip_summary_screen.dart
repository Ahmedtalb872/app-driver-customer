import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/utils/format_utils.dart';
import '../../providers/app_state_provider.dart';

class OpenTripSummaryScreen extends StatelessWidget {
  const OpenTripSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
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

    final movingDuration = Duration(seconds: trip.movingSeconds ?? 0);
    final waitingDuration = Duration(seconds: trip.waitingSeconds ?? 0);
    final totalDuration = movingDuration + waitingDuration;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
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
                'تم إنهاء المشوار المفتوح!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                  fontFamily: 'Cairo',
                ),
              ),
              const Text(
                'راجع تفاصيل الرحلة والأجرة النهائية أدناه.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 28),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'مسار الرحلة',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'Cairo',
                          color: AppColors.darkText,
                        ),
                      ),
                      const Divider(height: 24),
                      _row('نقطة الانطلاق', trip.pickupLocation),
                      const SizedBox(height: 10),
                      _row(
                        'الموقع النهائي المكتشف',
                        trip.destinationLocation.isNotEmpty
                            ? trip.destinationLocation
                            : 'غير محدد',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'الوقت والمسافة',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'Cairo',
                          color: AppColors.darkText,
                        ),
                      ),
                      const Divider(height: 24),
                      _row(
                        'المدة الإجمالية',
                        FormatUtils.duration(totalDuration),
                      ),
                      const SizedBox(height: 10),
                      _row('وقت السير', FormatUtils.duration(movingDuration)),
                      const SizedBox(height: 10),
                      _row(
                        'وقت الانتظار',
                        FormatUtils.duration(waitingDuration),
                      ),
                      const SizedBox(height: 10),
                      _row(
                        'المسافة الكلية المقطوعة',
                        FormatUtils.km(trip.distance),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تفاصيل الأجرة',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'Cairo',
                          color: AppColors.darkText,
                        ),
                      ),
                      const Divider(height: 24),
                      _row(
                        'الأجرة الأساسية',
                        FormatUtils.fare(trip.baseFareAmount ?? 0),
                      ),
                      const SizedBox(height: 10),
                      _row(
                        'أجرة المسافة',
                        FormatUtils.fare(trip.distanceFareAmount ?? 0),
                      ),
                      const SizedBox(height: 10),
                      _row(
                        'أجرة الوقت',
                        FormatUtils.fare(trip.timeFareAmount ?? 0),
                      ),
                      const SizedBox(height: 10),
                      _row(
                        'أجرة الانتظار',
                        FormatUtils.fare(trip.waitingFareAmount ?? 0),
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'الإجمالي النهائي',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          Text(
                            FormatUtils.fare(trip.price),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.success,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _row('طريقة الدفع', trip.paymentMethod),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: () {
                  provider.confirmCaptainSummary();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('تأكيد استلام الدفع'),
                    SizedBox(width: 8),
                    Icon(Icons.check_circle_rounded),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
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
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
              fontFamily: 'Cairo',
            ),
          ),
        ),
      ],
    );
  }
}
