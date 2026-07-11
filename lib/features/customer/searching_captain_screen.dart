import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import '../../models/models.dart';
import '../../core/widgets/real_map_widget.dart';
import 'captain_accepted_screen.dart';

class SearchingCaptainScreen extends StatefulWidget {
  const SearchingCaptainScreen({super.key});

  @override
  State<SearchingCaptainScreen> createState() => _SearchingCaptainScreenState();
}

class _SearchingCaptainScreenState extends State<SearchingCaptainScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _showTimeoutDialog(AppStateProvider provider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text(
            'لم يقبل أي كابتن المشوار',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: const Text(
            'لم يتوفر كابتن مناسب لقبول طلبك حالياً. يمكنك زيادة السعر لجذب الكباتن أو إعادة الإرسال.',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.4),
            textAlign: TextAlign.center,
          ),
          actions: [
            Column(
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Resend request
                    provider.resetSearchTimer(45);
                  },
                  child: const Text('إعادة إرسال المشوار (45 ثانية)'),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Increase price by 50 Ouguiya and resend
                    if (provider.activeTrip != null) {
                      double newPrice = provider.activeTrip!.price + 50;
                      provider.requestTrip(
                        pickup: provider.activeTrip!.pickupLocation,
                        destination: provider.activeTrip!.destinationLocation,
                        pickupLat: provider.activeTrip!.pickupLat,
                        pickupLng: provider.activeTrip!.pickupLng,
                        destLat: provider.activeTrip!.destLat,
                        destLng: provider.activeTrip!.destLng,
                        distance: provider.activeTrip!.distance,
                        duration: provider.activeTrip!.duration,
                        price: newPrice,
                        carType: provider.activeTrip!.carType,
                        isOpenRide: provider.activeTrip!.isOpenRide,
                        timeoutSeconds: 45,
                        paymentMethod: provider.activeTrip!.paymentMethod,
                      );
                    }
                  },
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: const Text('زيادة السعر بمقدار +50 أوقية'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    provider.cancelActiveTrip();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('إلغاء الطلب والرجوع'),
                ),
              ],
            )
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final activeTrip = provider.activeTrip;

    // Automatic transition to Accepted Screen once captain accepts
    if (activeTrip != null && (activeTrip.status == TripStatus.accepted || activeTrip.status == TripStatus.enRoute)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const CaptainAcceptedScreen()),
        );
      });
    }

    // Handle timeout state
    if (provider.countdownSeconds == 0 && activeTrip != null && activeTrip.status == TripStatus.pending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Stop timer check and show dialog
        _showTimeoutDialog(provider);
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Map viewport
            Expanded(
              flex: 4,
              child: Stack(
                children: [
                  RealMapWidget(
                    showRoute: true,
                    pickupLat: provider.activeTrip?.pickupLat,
                    pickupLng: provider.activeTrip?.pickupLng,
                    destLat: provider.activeTrip?.destLat,
                    destLng: provider.activeTrip?.destLng,
                  ),
                  
                  // Pulse radar overlay
                  Center(
                    child: AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Container(
                          width: 140 * _pulseAnimation.value,
                          height: 140 * _pulseAnimation.value,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withOpacity(0.18 * (2 - _pulseAnimation.value)),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.3 * (2 - _pulseAnimation.value)),
                              width: 2,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10)],
                      ),
                      child: const Icon(
                        Icons.local_taxi_rounded,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Search Status Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    activeTrip?.isOpenRide == true
                        ? 'تم فتح المشوار للكباتن القريبين'
                        : 'جاري البحث عن كابتن قريب',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    activeTrip?.isOpenRide == true
                        ? 'المشوار معروض على لوحة كباتن الهدهد حالياً.'
                        : 'نقوم بمطابقة مشوارك مع أقرب سائق متاح.',
                    style: const TextStyle(fontSize: 12, color: AppColors.secondaryText, fontFamily: 'Cairo'),
                  ),
                  const SizedBox(height: 24),
                  
                  // Countdown timer widget
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: CircularProgressIndicator(
                          value: provider.countdownSeconds / (activeTrip?.openRideTimeout ?? 45),
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          strokeWidth: 6,
                        ),
                      ),
                      Text(
                        '00:${provider.countdownSeconds.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  
                  // Trip Summary list
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildSummaryItem('المسافة', '${activeTrip?.distance} كم'),
                      Container(width: 1, height: 24, color: AppColors.border),
                      _buildSummaryItem('التكلفة المقدرة', '${activeTrip?.price} و.م'),
                      Container(width: 1, height: 24, color: AppColors.border),
                      _buildSummaryItem('الدفع', activeTrip?.paymentMethod ?? 'نقداً'),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Cancel button
                  OutlinedButton(
                    onPressed: () {
                      provider.cancelActiveTrip();
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error, width: 1.5),
                    ),
                    child: const Text('إلغاء طلب الرحلة'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.secondaryText, fontFamily: 'Cairo')),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo')),
      ],
    );
  }
}
