import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../models/models.dart';

/// Shown once [TripTrackingScreen] sees a trip reach [TripStatus.completed]
/// - a simple fare/route recap with a way back to the home screen. No
/// rating step: the `trips` schema has no rating columns yet.
class TripSummaryScreen extends StatelessWidget {
  const TripSummaryScreen({super.key, required this.trip});

  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                'وصلت بسلام!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'شكراً لاستخدامك الهدهد.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.secondaryText,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 28),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildRow('من', trip.pickupLocation),
                      const Divider(height: 24),
                      _buildRow(
                        'إلى',
                        trip.isOpenTrip
                            ? 'الوجهة النهائية'
                            : trip.destinationLocation,
                      ),
                      const Divider(height: 24),
                      _buildRow('المسافة', '${trip.distance.toStringAsFixed(1)} كم'),
                      const Divider(height: 24),
                      _buildRow('طريقة الدفع', trip.paymentMethod),
                      const Divider(height: 24),
                      _buildRow(
                        'المبلغ الإجمالي',
                        '${trip.price.toStringAsFixed(0)} أوقية',
                        emphasize: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text('العودة إلى الرئيسية'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool emphasize = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 13,
            color: AppColors.secondaryText,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            fontSize: emphasize ? 18 : 14,
            color: emphasize ? AppColors.accent : AppColors.darkText,
          ),
        ),
      ],
    );
  }
}
