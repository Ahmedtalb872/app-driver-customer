import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/services/google_directions_route_estimator.dart';
import '../../core/services/route_estimator.dart';
import '../../core/services/ride_repository.dart';
import '../../models/models.dart';
import '../../providers/app_state_provider.dart';
import '../destinations/data/models/destination_suggestion.dart';
import '../destinations/data/repositories/recent_places_repository.dart';
import 'trip_tracking_screen.dart';

/// Confirm-and-request screen for a parcel delivery - the same broadcast/
/// accept/tracking pipeline as [RequestRideScreen], just with a recipient
/// and package instead of a passenger count, and always priced/broadcast
/// as a motorcycle job (`customer_request_trip` forces this server-side
/// regardless of what's sent - see `20260801000046_delivery_service.sql`).
/// Only an approved captain who rides a motorcycle *and* opted into
/// delivery ever sees the resulting request.
class DeliveryRequestScreen extends StatefulWidget {
  const DeliveryRequestScreen({
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
  State<DeliveryRequestScreen> createState() => _DeliveryRequestScreenState();
}

class _DeliveryRequestScreenState extends State<DeliveryRequestScreen> {
  static const _vehicleType = VehicleType.economy; // ignored server-side
  static const _paymentMethod = 'نقداً';
  static const _routeEstimator = HaversineRouteEstimator();
  static final _directionsEstimator = GoogleDirectionsRouteEstimator(
    apiKey: dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '',
  );

  final _recentPlacesRepository = RecentPlacesRepository();

  final _formKey = GlobalKey<FormState>();
  final _recipientNameController = TextEditingController();
  final _recipientPhoneController = TextEditingController();
  final _packageController = TextEditingController();

  late RouteEstimate _route;

  bool _loadingPrice = true;
  double? _estimatedPrice;
  bool _isRequesting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // estimate() only ever returns null when destination is null (see
    // HaversineRouteEstimator.estimate) - widget.destination is required and
    // non-nullable here, unlike RequestRideScreen's optional one, so this is
    // always non-null.
    _route = _routeEstimator.estimate(
      pickup: LatLng(widget.pickupLat, widget.pickupLng),
      destination: LatLng(
        widget.destination.latitude,
        widget.destination.longitude,
      ),
    )!;
    _loadPrice();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    final roadRoute = await _directionsEstimator.estimate(
      pickup: LatLng(widget.pickupLat, widget.pickupLng),
      destination: LatLng(
        widget.destination.latitude,
        widget.destination.longitude,
      ),
    );
    if (roadRoute == null || !mounted) return;
    setState(() => _route = roadRoute);
    _loadPrice();
  }

  @override
  void dispose() {
    _recipientNameController.dispose();
    _recipientPhoneController.dispose();
    _packageController.dispose();
    super.dispose();
  }

  Future<void> _loadPrice() async {
    try {
      final config = await RideRepository.instance.fetchPricingConfig(
        'motorcycle',
      );
      if (config != null) {
        final baseFare = (config['base_fare'] as num).toDouble();
        final baseDistanceKm = (config['base_distance_km'] as num?)?.toDouble() ?? 0;
        final pricePerKm = (config['price_per_km'] as num).toDouble();
        final minimumFare = (config['minimum_fare'] as num).toDouble();
        final surge = (config['surge_multiplier'] as num?)?.toDouble() ?? 1.0;
        // Distance-based only, no time component, and base_fare is a flat
        // rate covering up to base_distance_km outright - a delivery is
        // always trip_type = 'normal' server-side too, see
        // 20260815000071_normal_trip_flat_base_distance.sql, so this
        // estimate is never higher than what actually gets charged.
        final extraKm = (_route.distanceKm - baseDistanceKm).clamp(0, double.infinity);
        final raw = (baseFare + extraKm * pricePerKm) * surge;
        _estimatedPrice = raw < minimumFare ? minimumFare : raw;
      }
    } catch (_) {
      // Best effort - the bottom bar falls back to a price-less button.
    }
    if (mounted) setState(() => _loadingPrice = false);
  }

  Future<void> _handleRequest() async {
    if (!_formKey.currentState!.validate()) return;
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
        vehicleType: _vehicleType,
        paymentMethod: _paymentMethod,
        serviceType: 'delivery',
        recipientName: _recipientNameController.text.trim(),
        recipientPhone: '+222${_recipientPhoneController.text.trim()}',
        packageDescription: _packageController.text.trim().isEmpty
            ? null
            : _packageController.text.trim(),
        // The only source of trips.estimated_price, which the captain app
        // shows before deciding whether to accept a request - previously
        // never sent at all, so every delivery left that column null.
        estimatedPrice: _estimatedPrice,
      );
      if (!mounted) return;
      // Fire-and-forget - never blocks the trip flow over this bookkeeping
      // call (see RecentPlacesRepository.recordVisit's own doc comment).
      unawaited(_recentPlacesRepository.recordVisit(widget.destination));
      context.read<AppStateProvider>().setActiveTripFromBackend(trip);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => TripTrackingScreen(tripId: trip.id),
        ),
        (route) => route.isFirst,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRequesting = false;
        _error = 'تعذر إرسال طلب التوصيل الآن. تحقق من الاتصال وحاول مرة أخرى.\n$e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('تأكيد طلب التوصيل')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRouteSummary(),
                    const SizedBox(height: 20),
                    const Text(
                      'بيانات المستلم',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _recipientNameController,
                      decoration: const InputDecoration(
                        labelText: 'اسم المستلم',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'مطلوب'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _recipientPhoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'رقم هاتف المستلم',
                        prefixText: '+222 ',
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'مطلوب';
                        if (v.length != 8) return 'يجب أن يتكون من 8 أرقام';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'وصف الطرد (اختياري)',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _packageController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'مثال: ظرف مستندات، طرد صغير...',
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
            'استلام: ${widget.pickupAddress}',
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
            'تسليم: ${widget.destination.displayLabel}',
          ),
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
                      ? 'اطلب التوصيل الآن - ${price.toStringAsFixed(0)} أوقية'
                      : _loadingPrice
                      ? 'جارٍ حساب السعر...'
                      : 'اطلب التوصيل الآن',
                ),
        ),
      ),
    );
  }
}
