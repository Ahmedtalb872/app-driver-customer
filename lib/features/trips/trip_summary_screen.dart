import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/services/ride_repository.dart';
import '../../models/models.dart';

/// Shown once [TripTrackingScreen] sees a trip reach [TripStatus.completed]
/// - a fare/route recap, then a 1-5 star rating for the captain with an
/// optional written note before returning to the home screen (see
/// [RideRepository.rateTrip]).
class TripSummaryScreen extends StatefulWidget {
  const TripSummaryScreen({super.key, required this.trip});

  final Trip trip;

  @override
  State<TripSummaryScreen> createState() => _TripSummaryScreenState();
}

class _TripSummaryScreenState extends State<TripSummaryScreen> {
  final _noteController = TextEditingController();
  int _rating = 0;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _submitRating() async {
    if (_rating == 0) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await RideRepository.instance.rateTrip(
        widget.trip.id,
        rating: _rating,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );
      if (!mounted) return;
      _goHome();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = 'تعذر إرسال التقييم الآن، تحقق من الاتصال وحاول مرة أخرى.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
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
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.captainName != null && trip.captainName!.isNotEmpty
                            ? 'قيّم رحلتك مع ${trip.captainName}'
                            : 'قيّم رحلتك مع الكابتن',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildStarRow(),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _noteController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظة (اختياري)',
                          hintText: 'اكتب ملاحظتك عن الكابتن أو الرحلة...',
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error!,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            color: AppColors.error,
                            fontSize: 12,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_rating == 0 || _isSubmitting)
                              ? null
                              : _submitRating,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.darkText,
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('إرسال التقييم'),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Center(
                        child: TextButton(
                          onPressed: _isSubmitting ? null : _goHome,
                          child: const Text('تخطي'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStarRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final filled = starValue <= _rating;
        return IconButton(
          onPressed: () => setState(() => _rating = starValue),
          icon: Icon(
            filled ? Icons.star_rounded : Icons.star_border_rounded,
            color: AppColors.accent,
            size: 34,
          ),
        );
      }),
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
