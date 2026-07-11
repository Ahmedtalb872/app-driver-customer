import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import '../../models/models.dart';


class OpenTripsScreen extends StatefulWidget {
  final bool showAppBar;
  const OpenTripsScreen({super.key, this.showAppBar = false});

  @override
  State<OpenTripsScreen> createState() => _OpenTripsScreenState();
}

class _OpenTripsScreenState extends State<OpenTripsScreen> {
  // Local list of active open rides
  List<Map<String, dynamic>> _openRides = [];
  Timer? _tickerTimer;

  @override
  void initState() {
    super.initState();
    // Initialize with 2 dummy open rides
    _openRides = [
      {
        'id': 'open_t1',
        'customerName': 'سيدي ولد المختار',
        'pickup': 'لكصر (كارفور ولد أماه)',
        'destination': 'تفرغ زينة (سوق طيبة)',
        'distance': 4.5,
        'duration': 12,
        'price': 180.0,
        'payment': 'نقداً',
        'timeLeft': 38,
      },
      {
        'id': 'open_t2',
        'customerName': 'زينب منت اعل',
        'pickup': 'عرفات (كارفور مدريد)',
        'destination': 'دار النعيم (شينقيط)',
        'distance': 9.2,
        'duration': 22,
        'price': 350.0,
        'payment': 'Bankily',
        'timeLeft': 52,
      },
    ];

    // Start local timer to tick down durations
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          for (var ride in _openRides) {
            if (ride['timeLeft'] > 0) {
              ride['timeLeft']--;
            }
          }
          // Remove rides that expired (0 seconds)
          _openRides.removeWhere((r) => r['timeLeft'] <= 0);
        });
      }
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  void _acceptOpenTrip(Map<String, dynamic> rideData) {
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    
    // Simulate accepting the open ride
    provider.requestTrip(
      pickup: rideData['pickup'],
      destination: rideData['destination'],
      pickupLat: 18.0982, // لكصر
      pickupLng: -15.9592,
      destLat: 18.1065, // تفرغ زينة
      destLng: -15.9664,
      distance: rideData['distance'],
      duration: rideData['duration'],
      price: rideData['price'],
      carType: VehicleType.economy,
      isOpenRide: true,
      timeoutSeconds: 45,
      paymentMethod: rideData['payment'],
    );
    
    // Switch state from customer searching to accepted immediately
    provider.acceptIncomingRequest();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم قبول المشوار بنجاح! جاري التوجه إلى الزبون: ${rideData['customerName']}', style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('المشاوير المفتوحة للجميع'),
            )
          : AppBar(
              title: const Text('المشاوير المفتوحة'),
              automaticallyImplyLeading: false,
            ),
      body: _openRides.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.hourglass_empty_rounded,
                      color: AppColors.primary,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'لا توجد مشاوير مفتوحة حالياً',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'انتظر، ستظهر الطلبات الجديدة هنا فوراً.',
                    style: TextStyle(fontSize: 12, color: AppColors.secondaryText, fontFamily: 'Cairo'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24.0),
              itemCount: _openRides.length,
              itemBuilder: (context, index) {
                final ride = _openRides[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header metadata (customer name and time left)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'الزبون: ${ride['customerName']}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkText, fontFamily: 'Cairo'),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.timer_outlined, color: AppColors.error, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    'تبقي ${ride['timeLeft']} ثانية',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        
                        // Route details
                        Row(
                          children: [
                            Column(
                              children: [
                                const Icon(Icons.radio_button_checked_rounded, color: AppColors.success, size: 16),
                                Container(width: 1, height: 20, color: AppColors.border),
                                const Icon(Icons.location_on_rounded, color: AppColors.error, size: 16),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ride['pickup'],
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.darkText, fontFamily: 'Cairo'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    ride['destination'],
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
                        
                        // Pricing & distance info
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('الأرباح الإجمالية', style: TextStyle(fontSize: 10, color: AppColors.secondaryText, fontFamily: 'Cairo')),
                                Text('${ride['price']} أوقية', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary, fontFamily: 'Cairo')),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text('المسافة', style: TextStyle(fontSize: 10, color: AppColors.secondaryText, fontFamily: 'Cairo')),
                                Text('${ride['distance']} كم', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo')),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('الدفع', style: TextStyle(fontSize: 10, color: AppColors.secondaryText, fontFamily: 'Cairo')),
                                Text(ride['payment'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.darkText, fontFamily: 'Cairo')),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        
                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('تفاصيل الرحلة: مسار من ${ride['pickup']} إلى ${ride['destination']} بمسافة ${ride['distance']} كم.', style: const TextStyle(fontFamily: 'Cairo')),
                                      backgroundColor: AppColors.primary,
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 40),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('عرض التفاصيل', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _acceptOpenTrip(ride),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.success,
                                  minimumSize: const Size(double.infinity, 40),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('قبول المشوار', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
