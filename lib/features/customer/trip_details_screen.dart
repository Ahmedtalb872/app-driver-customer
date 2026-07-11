import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import '../../models/models.dart';
import '../../core/widgets/real_map_widget.dart';
import 'searching_captain_screen.dart';

class TripDetailsScreen extends StatefulWidget {
  final String pickup;
  final String destination;
  final double distance;
  final int duration;
  final double price;
  final double pickupLat;
  final double pickupLng;
  final double destLat;
  final double destLng;

  const TripDetailsScreen({
    super.key,
    required this.pickup,
    required this.destination,
    required this.distance,
    required this.duration,
    required this.price,
    required this.pickupLat,
    required this.pickupLng,
    required this.destLat,
    required this.destLng,
  });

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  VehicleType _selectedCarType = VehicleType.economy;
  bool _isOpenRide = false;
  int _openRideDuration = 45; // 30, 45, 60
  String _paymentMethod = 'نقداً'; // نقداً, المحفظة, Bankily, Masrvi, Sedad

  double _getCalculatedPrice() {
    double factor = 1.0;
    if (_selectedCarType == VehicleType.comfort) {
      factor = 1.4;
    } else if (_selectedCarType == VehicleType.family) {
      factor = 1.8;
    }
    return double.parse((widget.price * factor).toStringAsFixed(0));
  }

  void _showPaymentMethodSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'اختر طريقة الدفع',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Cairo', color: AppColors.darkText),
                  ),
                  const SizedBox(height: 16),
                  
                  // Payment methods list
                  ...['نقداً', 'المحفظة', 'Bankily', 'Masrvi', 'Sedad'].map((method) {
                    IconData icon = Icons.money_rounded;
                    if (method == 'المحفظة') icon = Icons.account_balance_wallet_rounded;
                    if (method == 'Bankily') icon = Icons.mobile_screen_share_rounded;
                    if (method == 'Masrvi' || method == 'Sedad') icon = Icons.phonelink_ring_rounded;

                    return RadioListTile<String>(
                      value: method,
                      groupValue: _paymentMethod,
                      activeColor: AppColors.primary,
                      title: Row(
                        children: [
                          Icon(icon, color: AppColors.primary, size: 20),
                          const SizedBox(width: 12),
                          Text(method, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                        ],
                      ),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _paymentMethod = val;
                          });
                          setSheetState(() {
                            _paymentMethod = val;
                          });
                          Navigator.of(context).pop();
                        }
                      },
                    );
                  }).toList(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _handleConfirmTrip() {
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    
    // Check wallet balance
    if (_paymentMethod == 'المحفظة' && provider.customerWalletBalance < _getCalculatedPrice()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('رصيد المحفظة غير كافٍ للرحلة، يرجى اختيار وسيلة دفع أخرى أو شحن الرصيد.', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Call Provider to create trip request
    provider.requestTrip(
      pickup: widget.pickup,
      destination: widget.destination,
      pickupLat: widget.pickupLat,
      pickupLng: widget.pickupLng,
      destLat: widget.destLat,
      destLng: widget.destLng,
      distance: widget.distance,
      duration: widget.duration,
      price: _getCalculatedPrice(),
      carType: _selectedCarType,
      isOpenRide: _isOpenRide,
      timeoutSeconds: _openRideDuration,
      paymentMethod: _paymentMethod,
    );

    // Navigate to searching screen
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const SearchingCaptainScreen()),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    double finalPrice = _getCalculatedPrice();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('تفاصيل وتأكيد المشوار'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Map preview segment
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  RealMapWidget(
                    showRoute: true,
                    pickupLat: widget.pickupLat,
                    pickupLng: widget.pickupLng,
                    destLat: widget.destLat,
                    destLng: widget.destLng,
                  ),
                  
                  // Float duration card
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
                            '${widget.distance} كم',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                          ),
                          Text(
                            '${widget.duration} دقيقة',
                            style: const TextStyle(fontSize: 11, color: AppColors.secondaryText, fontFamily: 'Cairo'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Interaction Sheet segment
            Expanded(
              flex: 5,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 1)],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Car Selection Cards
                      const Text(
                        'نوع السيارة',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo', color: AppColors.darkText),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildCarCard(
                            VehicleType.economy,
                            'إقتصادية',
                            '1-4 ركاب',
                            widget.price,
                            Icons.directions_car_filled_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildCarCard(
                            VehicleType.comfort,
                            'مريحة',
                            '1-4 ركاب',
                            widget.price * 1.4,
                            Icons.local_taxi_rounded,
                          ),
                          const SizedBox(width: 8),
                          _buildCarCard(
                            VehicleType.family,
                            'عائلية',
                            '1-6 ركاب',
                            widget.price * 1.8,
                            Icons.airport_shuttle_rounded,
                          ),
                        ],
                      ),
                      const Divider(height: 28),
                      
                      // Open Ride options (مشوار مفتوح)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'مشوار مفتوح للكباتن',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'Cairo', color: AppColors.darkText),
                              ),
                              Text(
                                'إتاحة المشوار لجميع الكباتن القريبين فوراً.',
                                style: TextStyle(fontSize: 11, color: AppColors.secondaryText, fontFamily: 'Cairo'),
                              ),
                            ],
                          ),
                          Switch(
                            value: _isOpenRide,
                            activeColor: AppColors.primary,
                            onChanged: (val) {
                              setState(() {
                                _isOpenRide = val;
                              });
                            },
                          ),
                        ],
                      ),
                      
                      if (_isOpenRide) ...[
                        const SizedBox(height: 12),
                        // Duration picker
                        const Text(
                          'مدة ظهور المشوار للكابتن:',
                          style: TextStyle(fontSize: 12, fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [30, 45, 60].map((sec) {
                            return Expanded(
                              child: RadioListTile<int>(
                                value: sec,
                                groupValue: _openRideDuration,
                                contentPadding: EdgeInsets.zero,
                                activeColor: AppColors.primary,
                                title: Text('$sec ثانية', style: const TextStyle(fontSize: 12, fontFamily: 'Cairo')),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _openRideDuration = val;
                                    });
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                        
                        // Alert banner
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.warning.withOpacity(0.2)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'تنبيـه: سيختفي المشوار تلقائياً من شاشة الكابتن بعد انتهاء المدة المحددة إذا لم يتم قبوله.',
                                  style: TextStyle(fontSize: 11, color: AppColors.warning, fontFamily: 'Cairo', height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const Divider(height: 28),
                      
                      // Payment selection
                      InkWell(
                        onTap: _showPaymentMethodSheet,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.payment_rounded, color: AppColors.primary, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                'طريقة الدفع: $_paymentMethod',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Cairo', color: AppColors.darkText),
                              ),
                              const Spacer(),
                              const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppColors.secondaryText),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Confirm trip action
                      ElevatedButton(
                        onPressed: _handleConfirmTrip,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('تأكيد طلب المشوار ($finalPrice أوقية)'),
                            const SizedBox(width: 8),
                            const Icon(Icons.check, size: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarCard(
    VehicleType type,
    String label,
    String seats,
    double rawPrice,
    IconData icon,
  ) {
    bool isSel = _selectedCarType == type;
    double cardPrice = double.parse(rawPrice.toStringAsFixed(0));
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCarType = type;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: isSel ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSel ? AppColors.primary : AppColors.border,
              width: 1.5,
            ),
            boxShadow: isSel ? [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 6)] : null,
          ),
          child: Column(
            children: [
              Icon(icon, color: isSel ? Colors.white : AppColors.secondaryText, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSel ? Colors.white : AppColors.darkText,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Cairo',
                  fontSize: 12,
                ),
              ),
              Text(
                seats,
                style: TextStyle(
                  color: isSel ? Colors.white70 : AppColors.secondaryText,
                  fontSize: 10,
                  fontFamily: 'Cairo',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$cardPrice و.م',
                style: TextStyle(
                  color: isSel ? Colors.white : AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  fontFamily: 'Cairo',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
