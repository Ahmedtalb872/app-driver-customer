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

/// Confirm-and-request screen: shown either after the customer picks a
/// destination on [DestinationSearchScreen] (a [TripType.normal] trip), or
/// directly from the home screen with no destination at all for a
/// [TripType.open] trip - its whole point is that the destination is
/// discovered as the ride happens rather than picked up front. Every ride
/// requests the single standard ([VehicleType.economy]) tier - there is no
/// vehicle-class picker - with a live, client-side fare estimate (see
/// [RideRepository.fetchPricingConfig]) when a destination is known, and a
/// payment method, then calls [RideRepository.requestTrip].
class RequestRideScreen extends StatefulWidget {
  const RequestRideScreen({
    super.key,
    required this.pickupLat,
    required this.pickupLng,
    required this.pickupAddress,
    this.destination,
    this.tripType = TripType.normal,
  });

  final double pickupLat;
  final double pickupLng;
  final String pickupAddress;

  /// Null for a trip started as [TripType.open] straight from the home
  /// screen's trip-type selector, with no destination search step at all.
  final DestinationSuggestion? destination;

  /// Initial trip type. Forced to [TripType.open] whenever [destination] is
  /// null, since there's nothing to switch back to [TripType.normal] with.
  final TripType tripType;

  @override
  State<RequestRideScreen> createState() => _RequestRideScreenState();
}

class _RequestRideScreenState extends State<RequestRideScreen> {
  static const _routeEstimator = HaversineRouteEstimator();
  static const _vehicleType = VehicleType.economy;

  late final RouteEstimate? _route;
  late TripType _tripType;
  String _paymentMethod = 'نقداً';
  int _passengerCount = 1;
  final _noteController = TextEditingController();

  bool _loadingPrice = true;
  double? _estimatedPrice;
  Map<String, dynamic>? _pricingConfig;
  bool _isRequesting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final destination = widget.destination;
    _tripType = destination == null ? TripType.open : widget.tripType;
    _route = destination == null
        ? null
        : _routeEstimator.estimate(
            pickup: LatLng(widget.pickupLat, widget.pickupLng),
            destination: LatLng(destination.latitude, destination.longitude),
          );
    _loadPrice();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadPrice() async {
    try {
      final config = await RideRepository.instance.fetchPricingConfig(
        _vehicleType.name,
      );
      _pricingConfig = config;
      if (config != null && _route != null) {
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
        _estimatedPrice = raw < minimumFare ? minimumFare : raw;
      }
    } catch (_) {
      // Best effort - the bottom bar falls back to a price-less button.
    }
    if (mounted) setState(() => _loadingPrice = false);
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
        tripType: _tripType,
        destinationAddress: widget.destination?.title,
        destinationLat: widget.destination?.latitude,
        destinationLng: widget.destination?.longitude,
        vehicleType: _vehicleType,
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
              destLat: widget.destination?.latitude,
              destLng: widget.destination?.longitude,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRouteSummary(),
                  if (widget.destination != null) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'نوع المشوار',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildTripTypeSelector(),
                  ],
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
    final destination = widget.destination;
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
          if (destination != null) ...[
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
              destination.displayLabel,
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
          ] else ...[
            const Divider(height: 24),
            Text(
              _openTripStartingRateText(),
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

  /// Describes the open-trip flat starting rate from `pricing_config`
  /// (`open_trip_base_fare` only - the distance/time thresholds it covers
  /// are metering mechanics for the captain app to reason about, not shown
  /// here), falling back to a generic message while it's still loading or
  /// if it couldn't be fetched.
  String _openTripStartingRateText() {
    final baseFare = (_pricingConfig?['open_trip_base_fare'] as num?)
        ?.toDouble();
    if (baseFare == null) {
      return 'مشوار مفتوح - بدون وجهة محددة، سيتم تحديد المسار مع الكابتن '
          'أثناء الرحلة والسعر يُحسب حسب المسافة والوقت الفعلي.';
    }
    return 'مشوار مفتوح - بدون وجهة محددة. يبدأ بـ ${baseFare.toStringAsFixed(0)} '
        'أوقية، ثم يُحسب الإضافي حسب المسافة والوقت الفعلي.';
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

  Widget _buildTripTypeSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildTripTypeChip(
            type: TripType.normal,
            icon: Icons.route_rounded,
            label: 'عادي',
            subtitle: 'وجهة محددة وسعر ثابت',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildTripTypeChip(
            type: TripType.open,
            icon: Icons.timelapse_rounded,
            label: 'مفتوح',
            subtitle: 'السعر يُحسب حسب المسافة والوقت الفعلي',
          ),
        ),
      ],
    );
  }

  Widget _buildTripTypeChip({
    required TripType type,
    required IconData icon,
    required String label,
    required String subtitle,
  }) {
    final selected = _tripType == type;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _tripType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
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
              label,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: selected ? AppColors.primary : AppColors.darkText,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 9.5,
                color: AppColors.secondaryText,
              ),
            ),
          ],
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

  String _openTripButtonLabel() {
    final config = _pricingConfig;
    if (config == null) return 'اطلب الآن - السعر يُحسب حسب المسافة والوقت الفعلي';
    final baseFare = (config['open_trip_base_fare'] as num).toDouble();
    return 'اطلب الآن - يبدأ بـ ${baseFare.toStringAsFixed(0)} أوقية';
  }

  Widget _buildBottomBar() {
    final price = _estimatedPrice;
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
                      ? _tripType == TripType.open
                            ? 'اطلب الآن - بداية من ${price.toStringAsFixed(0)} أوقية تقريباً'
                            : 'اطلب الآن - ${price.toStringAsFixed(0)} أوقية'
                      : _loadingPrice
                      ? 'جارٍ حساب السعر...'
                      : widget.destination == null
                      ? _openTripButtonLabel()
                      : 'اطلب الآن',
                ),
        ),
      ),
    );
  }
}
