import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import '../../models/models.dart';
import '../../core/widgets/real_map_widget.dart';
import '../support/chat_screen.dart';
import 'trip_completed_screen.dart';

class TripInProgressScreen extends StatelessWidget {
  const TripInProgressScreen({super.key});

  void _showSOSDialog(BuildContext context, Trip trip) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: const [
              Icon(Icons.warning_rounded, color: AppColors.error, size: 24),
              SizedBox(width: 8),
              Text(
                'نداء استغاثة طارئ (SOS)',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.error, fontSize: 16),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'هل تشعر بعدم الأمان أو تواجه حالة طارئة؟ اضغط أدناه للاتصال الفوري بفرق الطوارئ ومشاركة موقعك الحالي وتفاصيل السيارة مع العائلة والجهات المعنية.',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Text('السيارة: ${trip.vehicleName ?? "تويوتا كورولا"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('اللوحة: ${trip.vehiclePlate ?? "4567 AA 00"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    Text('الكابتن: ${trip.captainName ?? "سيد محمد"}', style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم إرسال بلاغ الطوارئ ومشاركة الموقع بنجاح.', style: TextStyle(fontFamily: 'Cairo')),
                    backgroundColor: AppColors.error,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('إرسال نداء استغاثة'),
            ),
          ],
        );
      },
    );
  }

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

    // Auto navigate to completed screen once status changes
    if (trip.status == TripStatus.completed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const TripCompletedScreen()),
        );
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Map viewport
            Expanded(
              child: Stack(
                children: [
                  RealMapWidget(
                    showRoute: true,
                    status: TripStatus.started,
                    pickupLat: provider.activeTrip?.pickupLat,
                    pickupLng: provider.activeTrip?.pickupLng,
                    destLat: provider.activeTrip?.destLat,
                    destLng: provider.activeTrip?.destLng,
                    animateCar: true,
                  ),
                  
                  // ETA Overlay card
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.navigation_rounded, color: Colors.white, size: 22),
                              SizedBox(width: 10),
                              Text(
                                'الرحلة جارية الآن نحو الوجهة',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo'),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: const Text(
                              'تبقي 8 دقائق',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // SOS Float button
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: FloatingActionButton(
                      onPressed: () => _showSOSDialog(context, trip),
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      tooltip: 'نداء استغاثة طارئ',
                      child: const Icon(Icons.warning_rounded, size: 28),
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
                  // Destination text
                  Row(
                    children: [
                      const Icon(Icons.flag_rounded, color: AppColors.error, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'الوجهة المحددة',
                              style: TextStyle(fontSize: 10, color: AppColors.secondaryText, fontFamily: 'Cairo'),
                            ),
                            Text(
                              trip.destinationLocation,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkText, fontFamily: 'Cairo'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  
                  // Fare and payment Details
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('تكلفة الرحلة المقدرة', style: TextStyle(fontSize: 10, color: AppColors.secondaryText, fontFamily: 'Cairo')),
                          Text('${trip.price} أوقية', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary, fontFamily: 'Cairo')),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('وسيلة الدفع', style: TextStyle(fontSize: 10, color: AppColors.secondaryText, fontFamily: 'Cairo')),
                          Text(trip.paymentMethod, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo')),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  
                  // Driver details with quick actions
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
                  
                  // Simulator complete button (For front-end testing)
                  ElevatedButton(
                    onPressed: () {
                      provider.customerCompleteTrip();
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text('محاكاة إنهاء الرحلة (الوصول للوجهة)'),
                        SizedBox(width: 8),
                        Icon(Icons.flag_rounded),
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
