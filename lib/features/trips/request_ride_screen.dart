import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/services/google_directions_route_estimator.dart';
import '../../core/services/route_estimator.dart';
import '../../core/services/captain_subscription_repository.dart';
import '../../core/services/ride_repository.dart';
import '../../core/services/selefli_repository.dart';
import '../../models/models.dart';
import '../../providers/app_state_provider.dart';
import '../destinations/data/models/destination_suggestion.dart';
import '../destinations/data/repositories/recent_places_repository.dart';
import 'trip_tracking_screen.dart';

/// Confirm-and-request screen: shown either after the customer picks a
/// destination on [DestinationSearchScreen] (a [TripType.normal] trip), or
/// directly from the home screen with no destination at all for a
/// [TripType.open] trip - its whole point is that the destination is
/// discovered as the ride happens rather than picked up front. Every ride
/// requests the single standard ([VehicleType.economy]) tier - there is no
/// vehicle-class picker - with a live, client-side fare estimate (see
/// [RideRepository.fetchPricingConfig]) when a destination is known. Payment
/// is cash by default (no picker for that, to keep this screen to as few
/// steps as possible); a normal ride optionally offers a loyal customer's
/// "سلفلي" (Selefli) pay-later credit line instead (see
/// [_buildSelefliOption]/[SelefliRepository]), or - when the customer has
/// an active monthly subscription with a captain - a free ride under that
/// subscription instead (see [_buildSubscriptionOption]/
/// [CaptainSubscriptionRepository]), then calls [RideRepository.requestTrip].
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
  static final _directionsEstimator = GoogleDirectionsRouteEstimator(
    apiKey: dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '',
  );
  static const _vehicleType = VehicleType.economy;

  static const _paymentMethod = 'نقداً';

  final _recentPlacesRepository = RecentPlacesRepository();
  final _selefliRepository = SelefliRepository.instance;
  final _captainSubscriptionRepository = CaptainSubscriptionRepository.instance;

  RouteEstimate? _route;
  late final TripType _tripType;
  int _passengerCount = 1;
  final _noteController = TextEditingController();

  bool _loadingPrice = true;
  double? _estimatedPrice;
  Map<String, dynamic>? _pricingConfig;
  bool _isRequesting = false;
  String? _error;

  /// Only ever non-null for a normal ride with a known destination -
  /// Selefli needs an estimated price to check against a cap, which an
  /// open trip (destination discovered mid-ride) doesn't have, and the
  /// backend restricts it to service_type 'ride' + trip_type 'normal'
  /// anyway (SELEFLI_REQUIRES_NORMAL_RIDE).
  SelefliStatus? _selefliStatus;
  bool _useSelefli = false;

  /// Only ever non-null for a normal ride - a monthly subscription is
  /// pinned to one specific captain and only covers ordinary rides (backend
  /// restricts it to service_type 'ride' + trip_type 'normal', same as
  /// Selefli: SUBSCRIPTION_REQUIRES_NORMAL_RIDE). Unlike Selefli there's no
  /// price cap to check - every ride with the subscribed captain is free
  /// for the whole active window.
  CaptainSubscription? _subscriptionStatus;
  bool _useSubscription = false;

  @override
  void initState() {
    super.initState();
    final destination = widget.destination;
    _tripType = destination == null ? TripType.open : widget.tripType;
    if (destination != null) {
      // Straight-line estimate first so the screen has a distance/price to
      // show immediately, then upgraded in place to real road distance/
      // duration once the Directions API responds (see _loadRoute) - never
      // block the initial render on a network round trip.
      _route = _routeEstimator.estimate(
        pickup: LatLng(widget.pickupLat, widget.pickupLng),
        destination: LatLng(destination.latitude, destination.longitude),
      );
      _loadRoute(destination);
      if (_tripType == TripType.normal) {
        _loadSelefliStatus();
        _loadSubscriptionStatus();
      }
    }
    _loadPrice();
  }

  Future<void> _loadSelefliStatus() async {
    try {
      final status = await _selefliRepository.fetchStatus();
      if (mounted) setState(() => _selefliStatus = status);
    } catch (_) {
      // Best effort - the Selefli option just stays hidden if this fails.
    }
  }

  Future<void> _loadSubscriptionStatus() async {
    try {
      final status = await _captainSubscriptionRepository.fetchMyStatus();
      if (mounted) setState(() => _subscriptionStatus = status);
    } catch (_) {
      // Best effort - the subscription option just stays hidden if this fails.
    }
  }

  Future<void> _loadRoute(DestinationSuggestion destination) async {
    final roadRoute = await _directionsEstimator.estimate(
      pickup: LatLng(widget.pickupLat, widget.pickupLng),
      destination: LatLng(destination.latitude, destination.longitude),
    );
    if (roadRoute == null || !mounted) return;
    setState(() => _route = roadRoute);
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
      final route = _route;
      if (config != null && route != null) {
        final baseFare = (config['base_fare'] as num).toDouble();
        final baseDistanceKm = (config['base_distance_km'] as num?)?.toDouble() ?? 0;
        final pricePerKm = (config['price_per_km'] as num).toDouble();
        final minimumFare = (config['minimum_fare'] as num).toDouble();
        final surge = (config['surge_multiplier'] as num?)?.toDouble() ?? 1.0;
        // Distance-based only, no time component, and base_fare is a flat
        // rate covering up to base_distance_km outright - matches
        // captain_end_trip's normal-ride formula
        // (20260815000071_normal_trip_flat_base_distance.sql) so this
        // estimate is never higher than what actually gets charged.
        final extraKm = (route.distanceKm - baseDistanceKm).clamp(0, double.infinity);
        final raw = (baseFare + extraKm * pricePerKm) * surge;
        _estimatedPrice = raw < minimumFare ? minimumFare : raw;
      }
    } catch (_) {
      // Best effort - the bottom bar falls back to a price-less button.
    }
    if (mounted) setState(() => _loadingPrice = false);
  }

  bool get _canOfferSelefli {
    final status = _selefliStatus;
    final price = _estimatedPrice;
    return status != null &&
        status.canRequestNow &&
        price != null &&
        price <= status.cap!;
  }

  bool get _canOfferSubscription => _subscriptionStatus?.isActive == true;

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
        paymentMethodCode: _useSubscription && _canOfferSubscription
            ? 'subscription'
            : _useSelefli && _canOfferSelefli
            ? 'selefli'
            : null,
        // Always sent (not just for Selefli, which only needs it for the
        // cap check) - this is also the only source of trips.estimated_price,
        // which the captain app shows before deciding whether to accept a
        // request. Previously only ever sent for a Selefli request, so
        // every ordinary cash/wallet ride left that column null and the
        // captain saw no price at all until after completion.
        estimatedPrice: _estimatedPrice,
        customerNote: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        passengerCount: _passengerCount,
      );
      if (!mounted) return;
      // Fire-and-forget - never blocks the trip flow over this bookkeeping
      // call (see RecentPlacesRepository.recordVisit's own doc comment).
      final destination = widget.destination;
      if (destination != null) {
        unawaited(_recentPlacesRepository.recordVisit(destination));
      }
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
        _error = _friendlyErrorFor(e);
      });
    }
  }

  /// Selefli's server-side checks (SELEFLI_*, see customer_request_trip in
  /// 20260812000055_selefli_credit.sql) are re-validated at request time
  /// even though the UI already gates the toggle on the same conditions -
  /// eligibility/debt/cap can all change between this screen loading and
  /// the request actually landing. Recognized codes get a real Arabic
  /// explanation; anything else falls back to the raw exception (appended,
  /// not just a generic message, so a screenshot of this screen is enough
  /// to diagnose an unexpected failure).
  String _friendlyErrorFor(Object e) {
    final message = e.toString();
    if (message.contains('SELEFLI_DEBT_OUTSTANDING')) {
      return 'لديك دين سلفلي سابق لم يُسدَّد بعد - سدّده أولاً لتتمكن من طلب مشوار جديد بسلفلي.';
    }
    if (message.contains('SELEFLI_OVER_CAP')) {
      return 'سعر هذا المشوار يتجاوز الحد المسموح به لسلفلي حالياً.';
    }
    if (message.contains('SELEFLI_NOT_ELIGIBLE')) {
      return 'لست مؤهلاً لسلفلي بعد.';
    }
    if (message.contains('SELEFLI_REQUIRES_NORMAL_RIDE')) {
      return 'سلفلي متاح فقط لمشوار عادي بوجهة محددة.';
    }
    if (message.contains('NO_ACTIVE_SUBSCRIPTION')) {
      return 'ليس لديك اشتراك شهري نشط حالياً.';
    }
    if (message.contains('SUBSCRIPTION_REQUIRES_NORMAL_RIDE')) {
      return 'الاشتراك الشهري متاح فقط لمشوار عادي بوجهة محددة.';
    }
    return 'تعذر إرسال طلب المشوار الآن. تحقق من الاتصال وحاول مرة أخرى.\n$e';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('تأكيد طلب المشوار')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRouteSummary(),
            if (_canOfferSubscription) ...[
              const SizedBox(height: 16),
              _buildSubscriptionOption(),
            ] else if (_canOfferSelefli) ...[
              const SizedBox(height: 16),
              _buildSelefliOption(),
            ],
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
      bottomSheet: _buildBottomBar(),
    );
  }

  Widget _buildRouteSummary() {
    final destination = widget.destination;
    final route = _route;
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
            if (route != null) ...[
              const Divider(height: 24),
              Text(
                'المسافة التقريبية ${route.distanceKm.toStringAsFixed(1)} كم - '
                'حوالي ${route.durationMinutes} دقيقة',
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

  /// Only ever built while [_canOfferSelefli] is true - see that getter
  /// for the eligibility/debt/cap conditions.
  Widget _buildSelefliOption() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ادفع لاحقاً مع سلفلي',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'اطلب هذا المشوار الآن وسدّد قيمته لاحقاً من محفظتك.',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _useSelefli,
            onChanged: (value) => setState(() => _useSelefli = value),
            activeColor: AppColors.accent,
          ),
        ],
      ),
    );
  }

  /// Only ever built while [_canOfferSubscription] is true, in which case
  /// it's shown instead of the Selefli card (see build()) - a customer
  /// with an active subscription rides free with that captain, which is
  /// strictly better than paying later.
  Widget _buildSubscriptionOption() {
    final captainName = _subscriptionStatus?.captainName ?? 'الكابتن';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'استخدم اشتراكك الشهري',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'هذا المشوار مجاني ضمن اشتراكك مع $captainName.',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _useSubscription,
            onChanged: (value) => setState(() => _useSubscription = value),
            activeColor: AppColors.primary,
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
    final baseFare = (_pricingConfig?['open_trip_base_fare'] as num?)
        ?.toDouble();
    if (baseFare == null) {
      return 'اطلب الآن - السعر يُحسب حسب المسافة والوقت الفعلي';
    }
    return 'اطلب الآن - يبدأ بـ ${baseFare.toStringAsFixed(0)} أوقية';
  }

  /// The amount/status text shown in its own row above the request button -
  /// separated out so the price reads as a prominent figure rather than
  /// being buried inside the button's own label.
  String? _priceRowText(double? price) {
    if (price == null) return null;
    if (_tripType == TripType.open) {
      return 'بداية من ${price.toStringAsFixed(0)} أوقية تقريباً';
    }
    if (_useSubscription && _canOfferSubscription) {
      return 'مجاناً ضمن اشتراكك الشهري';
    }
    if (_useSelefli && _canOfferSelefli) {
      return 'سدّد ${price.toStringAsFixed(0)} أوقية لاحقاً بسلفلي';
    }
    return '${price.toStringAsFixed(0)} أوقية';
  }

  Widget _buildBottomBar() {
    final price = _estimatedPrice;
    final priceRowText = _priceRowText(price);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (priceRowText != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  priceRowText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            ElevatedButton(
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
                          ? 'اطلب الآن'
                          : _loadingPrice
                          ? 'جارٍ حساب السعر...'
                          : widget.destination == null
                          ? _openTripButtonLabel()
                          : 'اطلب الآن',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
