import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import '../../models/models.dart';
import '../../core/widgets/real_map_widget.dart';
import '../support/chat_screen.dart';
import 'captain_en_route_screen.dart';

class CaptainAcceptedScreen extends StatefulWidget {
  const CaptainAcceptedScreen({super.key});

  @override
  State<CaptainAcceptedScreen> createState() => _CaptainAcceptedScreenState();
}

class _MockPhoto extends StatelessWidget {
  final String url;
  const _MockPhoto({required this.url});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 30,
      backgroundImage: NetworkImage(url),
      backgroundColor: AppColors.background,
    );
  }
}

class _CaptainAcceptedScreenState extends State<CaptainAcceptedScreen> {
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    // Auto-navigate to En-Route screen after 4 seconds to simulate real-time updates
    _navigationTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const CaptainEnRouteScreen()),
        );
      }
    });
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  void _simulateCall(String name) {
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

  void _shareRideInfo(Trip trip) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ رابط تتبع الرحلة لمشاركته مع أصدقائك.', style: TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.success,
      ),
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
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              const Text('لم يتم العثور على مشوار نشط.', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('العودة للرئيسية'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('تم قبول طلبك'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Map viewport
            Expanded(
              flex: 4,
              child: RealMapWidget(
                showRoute: true,
                status: TripStatus.accepted,
                pickupLat: trip.pickupLat,
                pickupLng: trip.pickupLng,
                destLat: trip.destLat,
                destLng: trip.destLng,
                animateCar: false,
              ),
            ),
            
            // Captain Details Sheet
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
                  // Header Info
                  Row(
                    children: [
                      _MockPhoto(url: trip.captainAvatar ?? 'https://api.dicebear.com/7.x/adventurer/svg?seed=Sidi'),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.captainName ?? 'كابتن الهدهد',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo'),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, color: AppColors.accent, size: 16),
                                const SizedBox(width: 4),
                                const Text('4.9', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 12),
                                Text('${trip.carTypeNameArabic} • ${trip.vehiclePlate ?? "4567 AA 00"}', style: const TextStyle(fontSize: 12, color: AppColors.secondaryText, fontFamily: 'Cairo')),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: const [
                            Text('الوصول خلال', style: TextStyle(fontSize: 9, color: AppColors.secondaryText, fontFamily: 'Cairo')),
                            Text('3 دقائق', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary, fontFamily: 'Cairo')),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  
                  // Car Info banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_car_filled_rounded, color: AppColors.primary, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trip.vehicleName ?? 'تويوتا كورولا 2018',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo'),
                              ),
                              const Text(
                                'اللون: فضي ميتاليك',
                                style: TextStyle(fontSize: 11, color: AppColors.secondaryText, fontFamily: 'Cairo'),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.darkText, width: 1.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            trip.vehiclePlate ?? '4567 AA 00',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.0),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Quick actions Row
                  Row(
                    children: [
                      _buildQuickAction(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'محادثة',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const ChatScreen(showAppBar: true)),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      _buildQuickAction(
                        icon: Icons.call_outlined,
                        label: 'اتصال',
                        onTap: () => _simulateCall(trip.captainName ?? 'الكابتن'),
                      ),
                      const SizedBox(width: 12),
                      _buildQuickAction(
                        icon: Icons.share_location_rounded,
                        label: 'مشاركة',
                        onTap: () => _shareRideInfo(trip),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Track / Cancel Button
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            provider.cancelActiveTrip();
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                          ),
                          child: const Text('إلغاء الرحلة'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _navigationTimer?.cancel();
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(builder: (context) => const CaptainEnRouteScreen()),
                            );
                          },
                          child: const Text('متابعة الكابتن'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 44),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
