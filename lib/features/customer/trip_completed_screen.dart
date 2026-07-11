import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import 'rate_captain_screen.dart';

class TripCompletedScreen extends StatelessWidget {
  const TripCompletedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final trip = provider.customerTripHistory.isNotEmpty 
        ? provider.customerTripHistory.first 
        : provider.activeTrip;

    if (trip == null) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            child: const Text('العودة للرئيسية'),
          ),
        ),
      );
    }

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
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 64,
                ),
              ),
              const SizedBox(height: 20),
              
              const Text(
                'تمت الرحلة بنجاح!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                  fontFamily: 'Cairo',
                ),
              ),
              const Text(
                'شكراً لاستخدامك تطبيق الهدهد لنقل الركاب.',
                style: TextStyle(fontSize: 12, color: AppColors.secondaryText, fontFamily: 'Cairo'),
              ),
              const SizedBox(height: 32),
              
              // Invoice details card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تفاصيل الفاتورة والرحلة',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo', color: AppColors.darkText),
                      ),
                      const Divider(height: 24),
                      
                      // Price row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('السعر النهائي للرحلة', style: TextStyle(fontSize: 13, fontFamily: 'Cairo', color: AppColors.secondaryText)),
                          Text(
                            '${trip.price} أوقية',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary, fontFamily: 'Cairo'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Details rows
                      _buildInvoiceRow('المسافة المقطوعة', '${trip.distance} كم'),
                      _buildInvoiceRow('مدة الرحلة الفعلية', '${trip.duration} دقيقة'),
                      _buildInvoiceRow('وسيلة الدفع المستخدمة', trip.paymentMethod),
                      const Divider(height: 24),
                      
                      // Route
                      Row(
                        children: [
                          Column(
                            children: [
                              const Icon(Icons.radio_button_checked_rounded, color: AppColors.success, size: 16),
                              Container(width: 1, height: 16, color: AppColors.border),
                              const Icon(Icons.location_on_rounded, color: AppColors.error, size: 16),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trip.pickupLocation,
                                  style: const TextStyle(fontSize: 12, color: AppColors.darkText, fontFamily: 'Cairo'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  trip.destinationLocation,
                                  style: const TextStyle(fontSize: 12, color: AppColors.darkText, fontFamily: 'Cairo'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              // Proceed button to Rating
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const RateCaptainScreen()),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text('تقييم الكابتن والمتابعة'),
                    SizedBox(width: 8),
                    Icon(Icons.star_half_rounded),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.secondaryText, fontFamily: 'Cairo')),
          Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo')),
        ],
      ),
    );
  }
}
