import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import '../../models/models.dart';
import '../../core/widgets/real_map_widget.dart';
import '../support/chat_screen.dart';
import 'captain_trip_summary_screen.dart';

class CaptainActiveTripScreen extends StatelessWidget {
  const CaptainActiveTripScreen({super.key});

  void _simulateCall(BuildContext context, String name) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text('اتصال هاتفي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          content: Text('جاري الاتصال بـ $name...\n(+222 44444444)', style: const TextStyle(fontFamily: 'Cairo', fontSize: 14), textAlign: TextAlign.center),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_rounded, size: 48, color: AppColors.success),
              const SizedBox(height: 16),
              const Text('تم إكمال المشوار بنجاح!', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('الرجوع للرئيسية'),
              ),
            ],
          ),
        ),
      );
    }

    // Auto transition to Trip Summary screen once completed
    if (trip.status == TripStatus.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const CaptainTripSummaryScreen()),
        );
      });
    }

    // Determine state visual details
    String statusTitle = 'توجه إلى نقطة الانطلاق';
    String addressLabel = 'موقع العميل (الالتقاء)';
    String addressValue = trip.pickupLocation;
    String actionLabel = 'وصلت للزبون';
    Color actionColor = AppColors.primary;
    IconData actionIcon = Icons.sports_motorsports_rounded;
    VoidCallback onAction = () => provider.captainArriveAtPickup();

    if (trip.status == TripStatus.arrived) {
      statusTitle = 'وصلت لموقع العميل';
      addressLabel = 'موقع العميل (الانتظار)';
      actionLabel = 'بدء الرحلة الجارية';
      actionColor = AppColors.success;
      actionIcon = Icons.play_arrow_rounded;
      onAction = () => provider.captainStartActiveTrip();
    } else if (trip.status == TripStatus.started) {
      statusTitle = 'مشوار جاري الآن نحو الوجهة';
      addressLabel = 'الوجهة المحددة للرحلة';
      addressValue = trip.destinationLocation;
      actionLabel = 'إنهاء الرحلة بنجاح';
      actionColor = AppColors.error;
      actionIcon = Icons.flag_rounded;
      onAction = () => provider.captainCompleteActiveTrip();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(statusTitle),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Map viewport
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
                  
                  // Float ETA indicator
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${trip.distance} كم',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                          ),
                          const Text(
                            'المسافة الكلية',
                            style: TextStyle(fontSize: 10, color: AppColors.secondaryText, fontFamily: 'Cairo'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Bottom Sheet control board
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
                  // Address text box
                  Row(
                    children: [
                      Icon(
                        trip.status == TripStatus.started ? Icons.flag_rounded : Icons.radio_button_checked_rounded,
                        color: trip.status == TripStatus.started ? AppColors.error : AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              addressLabel,
                              style: const TextStyle(fontSize: 10, color: AppColors.secondaryText, fontFamily: 'Cairo'),
                            ),
                            Text(
                              addressValue,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkText, fontFamily: 'Cairo'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  
                  // Customer details and actions row
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary,
                        child: Icon(Icons.person, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.customerName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo'),
                            ),
                            Text(
                              trip.customerPhone,
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
                        onPressed: () => _simulateCall(context, trip.customerName),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Status change confirm action button
                  ElevatedButton(
                    onPressed: onAction,
                    style: ElevatedButton.styleFrom(backgroundColor: actionColor),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(actionLabel),
                        const SizedBox(width: 8),
                        Icon(actionIcon),
                      ],
                    ),
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
