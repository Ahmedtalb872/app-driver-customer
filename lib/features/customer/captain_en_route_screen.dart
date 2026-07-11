import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import '../../models/models.dart';
import '../../core/widgets/real_map_widget.dart';
import '../support/chat_screen.dart';
import 'trip_in_progress_screen.dart';

class CaptainEnRouteScreen extends StatelessWidget {
  const CaptainEnRouteScreen({super.key});

  void _simulateCall(BuildContext context, String name) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text('اتصال هاتفي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          content: Text('جاري الاتصال بـ $name...\n(+222 33333333)', style: const TextStyle(fontFamily: 'Cairo', fontSize: 14), textAlign: TextAlign.center),
          actions: [
            Center(
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                icon: const Icon(Icons.call_end_rounded),
                label: const Text('إنهاء المكالمة'),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final trip = provider.activeTrip;

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

    // Auto navigate to active trip in progress once trip starts
    if (trip.status == TripStatus.started) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const TripInProgressScreen()),
        );
      });
    }

    // Determine sub-states of en-route for visual text helper
    String statusTitle = 'الكابتن في الطريق إليك';
    String statusSubtitle = 'يمكنك تتبع مسار الكابتن مباشرة على الخريطة.';
    Color statusBg = AppColors.primary;
    IconData statusIcon = Icons.directions_car_filled_rounded;

    if (trip.status == TripStatus.enRoute) {
      statusTitle = 'الكابتن قريب منك';
      statusSubtitle = 'الكابتن يبتعد مسافة قصيرة جداً عن موقعك الآن.';
      statusBg = AppColors.warning;
      statusIcon = Icons.near_me_rounded;
    } else if (trip.status == TripStatus.arrived) {
      statusTitle = 'وصل الكابتن إلى موقعك!';
      statusSubtitle = 'يرجى التوجه إلى السيارة ولقاء الكابتن لبدء المشوار.';
      statusBg = AppColors.success;
      statusIcon = Icons.sports_motorsports_rounded;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Map viewport showing animated route and marker movement
            Expanded(
              child: Stack(
                children: [
                  RealMapWidget(
                    showRoute: true,
                    status: trip.status,
                    pickupLat: trip.pickupLat,
                    pickupLng: trip.pickupLng,
                    destLat: trip.destLat,
                    destLng: trip.destLng,
                    animateCar: true,
                  ),
                  
                  // Status Banner overlay
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                      ),
                      child: Row(
                        children: [
                          Icon(statusIcon, color: Colors.white, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  statusTitle,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo'),
                                ),
                                Text(
                                  statusSubtitle,
                                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontFamily: 'Cairo'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Bottom Sheet Info Panel
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
                  // Ride route info card
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
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.darkText, fontFamily: 'Cairo'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              trip.destinationLocation,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.darkText, fontFamily: 'Cairo'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  
                  // Captain and Vehicle Row
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundImage: NetworkImage(trip.captainAvatar ?? 'https://api.dicebear.com/7.x/adventurer/svg?seed=Sidi'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.captainName ?? 'كابتن الهدهد',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo'),
                            ),
                            Text(
                              '${trip.vehicleName ?? "تويوتا كورولا"} • ${trip.vehiclePlate ?? "4567 AA 00"}',
                              style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primary, size: 20),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const ChatScreen(showAppBar: true)),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.call_outlined, color: AppColors.primary, size: 20),
                        onPressed: () => _simulateCall(context, trip.captainName ?? 'الكابتن'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Action button depending on status
                  if (trip.status == TripStatus.arrived)
                    ElevatedButton(
                      onPressed: () {
                        // Simulate starting the trip
                        provider.customerStartTrip();
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text('بدء الرحلة (محاكاة الصعود للسيارة)'),
                          SizedBox(width: 8),
                          Icon(Icons.play_arrow_rounded),
                        ],
                      ),
                    )
                  else
                    OutlinedButton(
                      onPressed: () {
                        provider.cancelActiveTrip();
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                      child: const Text('إلغاء طلب المشوار'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
