import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/services/route_estimator.dart';
import '../../core/services/ride_repository.dart';
import '../../core/widgets/real_map_widget.dart';
import '../../models/models.dart';
import '../../providers/app_state_provider.dart';
import '../destinations/data/models/destination_suggestion.dart';
import 'trip_tracking_screen.dart';

/// Confirm-and-request screen: shown after the customer picks a destination
/// on [DestinationSearchScreen]. Lets them pick a vehicle tier (with a
/// live, client-side fare estimate - see [RideRepository.fetchPricingConfig])
/// and payment method, then calls [RideRepository.requestTrip].
class RequestRideScreen extends StatefulWidget {
  const RequestRideScreen({
    super.key,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    required this.destination,
  });

  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;
  final DestinationSuggestion destination;

  @override
  State<RequestRideScreen> createState() => _RequestRideScreenState();
}

class _RequestRideScreenState extends State<RequestRideScreen> {
  static const _routeEstimator = HaversineRouteEstimator();

  late final RouteEstimate? _route;
  VehicleType _selectedVehicle = VehicleType.economy;
  String _paymentMethod = 'نقداً';
  int _passengerCount = 1;
  final _noteController = TextEditingController();

  bool _loadingPrices = true;
  final Map<VehicleType, double> _estimatedPrices = {};
  bool _isRequesting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _route = _routeEstimator.estimate(
      pickup: LatLng(widget.pickupLat, widget.pickupLng),
      destination: LatLng(widget.destination.latitude, widget.destination.longitude),
    );
    _loadPrices();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadPrices() async {
    for (final vehicle in VehicleType.values) {
      try {
        final config = await RideRepository.instance.fetchPricingConfig(
          vehicle.name,
        );
        if (config == null || _route == null) continue;
        final baseFare = (config['base_fare'] as num).toDouble();
        final pricePerKm = (config['price_per_km'] as num).toDouble();
        final pricePerMinute = (config['price_per_minute'] as num).toDouble();
        final minimumFare = (config['minimum_fare'] as num).toDouble();
        final surge = (config['surge_multiplier'] as num?)?.toDouble() ?? 1.0;
        final raw =
            (baseFare +
                _route.distanceKm * pricePerKm +
                _route.durationMinutes * pricePerMinute) *
            surge;
        _estimatedPrices[vehicle] = raw < minimumFare ? minimumFare : raw;
      } catch (_) {
        // Best effort - the vehicle card falls back to "غير متوفر" below.
      }
    }
    if (mounted) setState(() => _loadingPrices = false);
  }

  Future<void> _handleRequest() async {
    setState(() {
      _isRequesting = true;
      _error = null;
    });
    try {
      final trip = await RideRepository.instance.requestTrip(
        pickupAddress: widget.pickupAddress,
        pickupLat: widget.pickupLat,
        pickupLng: widget.pickupLng,
        tripType: TripType.normal,
        destinationAddress: widget.destination.title,
        destinationLat: widget.destination.latitude,
        destinationLng: widget.destination.longitude,
        vehicleType: _selectedVehicle,
        paymentMethod: _paymentMethod,
        customerNote: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        passengerCount: _passengerCount,
      );
      if (!mounted) return;
      context.read<AppStateProvider>().setActiveTripFromBackend(trip);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => TripTrackingScreen(tripId: trip.id),
        ),
        (route) => route.isFirst,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isRequesting = false;
        _error = 'تعذر إرسال طلب المشوار الآن. تحقق من الاتصال وحاول مرة أخرى.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('تأكيد طلب المشوار')),
      body: Column(
        children: [
          SizedBox(
            height: 220,
            child: RealMapWidget(
              interactive: false,
              showRoute: true,
              pickupLat: widget.pickupLat,
              pickupLng: widget.pickupLng,
              destLat: widget.destination.latitude,
              destLng: widget.destination.longitude,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRouteSummary(),
                  const SizedBox(height: 20),
                  const Text(
                    'اختر فئة السيارة',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...VehicleType.values.map(_buildVehicleCard),
                  const SizedBox(height: 20),
                  const Text(
                    'طريقة الدفع',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildPaymentSelector(),
                  const SizedBox(height: 20),
                  const Text(
                    'عدد الركاب',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildPassengerStepper(),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظة للكابتن (اختياري)',
                      hintText: 'مثال: أنا أمام البوابة الرئيسية',
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        color: AppColors.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomBar(),
    );
  }

  Widget _buildRouteSummary() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLocationRow(
            Icons.radio_button_checked_rounded,
            AppColors.success,
            widget.pickupAddress,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6, horizontal: 9),
            child: SizedBox(
              height: 16,
              child: VerticalDivider(width: 2, thickness: 2),
            ),
          ),
          _buildLocationRow(
            Icons.location_on_rounded,
            AppColors.error,
            widget.destination.displayLabel,
          ),
          if (_route != null) ...[
            const Divider(height: 24),
            Text(
              'المسافة التقريبية ${_route.distanceKm.toStringAsFixed(1)} كم - '
              'حوالي ${_route.durationMinutes} دقيقة',
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationRow(IconData icon, Color color, String label) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleCard(VehicleType vehicle) {
    final selected = _selectedVehicle == vehicle;
    final price = _estimatedPrices[vehicle];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _selectedVehicle = vehicle),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withOpacity(0.06) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.directions_car_filled_rounded,
                color: selected ? AppColors.primary : AppColors.secondaryText,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.typeArabic,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      vehicle.description,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              _loadingPrices
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      price != null
                          ? '${price.toStringAsFixed(0)} أوقية'
                          : 'غير متوفر',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: selected ? AppColors.primary : AppColors.darkText,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildPaymentChip('نقداً', Icons.payments_outlined),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildPaymentChip('المحفظة', Icons.wallet_rounded),
        ),
      ],
    );
  }

  Widget _buildPaymentChip(String value, IconData icon) {
    final selected = _paymentMethod == value;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _paymentMethod = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: selected ? AppColors.primary : AppColors.secondaryText,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: selected ? AppColors.primary : AppColors.darkText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassengerStepper() {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: _passengerCount > 1
              ? () => setState(() => _passengerCount--)
              : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            '$_passengerCount',
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        IconButton.filledTonal(
          onPressed: _passengerCount < 6
              ? () => setState(() => _passengerCount++)
              : null,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final price = _estimatedPrices[_selectedVehicle];
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: SafeArea(
        top: false,
        child: ElevatedButton(
          onPressed: _isRequesting ? null : _handleRequest,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
          ),
          child: _isRequesting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  price != null
                      ? 'اطلب الآن - ${price.toStringAsFixed(0)} أوقية'
                      : 'اطلب الآن',
                ),
        ),
      ),
    );
  }
}
