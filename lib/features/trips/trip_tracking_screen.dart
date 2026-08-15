import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/services/call_signaling_service.dart';
import '../../core/services/ride_repository.dart';
import '../../core/services/route_estimator.dart';
import '../../core/services/trip_foreground_service.dart';
import '../../core/widgets/real_map_widget.dart';
import '../../models/models.dart';
import '../../providers/app_state_provider.dart';
import '../calls/call_screen.dart';
import 'trip_summary_screen.dart';

/// Watches a single trip (see [RideRepository.watchTrip]) from the moment a
/// customer requests it through to completion or cancellation, rendering
/// the matching UI for each [TripStatus] along the way.
class TripTrackingScreen extends StatefulWidget {
  const TripTrackingScreen({super.key, required this.tripId});

  final String tripId;

  @override
  State<TripTrackingScreen> createState() => _TripTrackingScreenState();
}

class _TripTrackingScreenState extends State<TripTrackingScreen> {
  static const _routeEstimator = HaversineRouteEstimator();

  StreamSubscription<Trip?>? _sub;
  Trip? _trip;
  RouteEstimate? _liveEstimate;
  bool _handledTerminal = false;
  bool _isCancelling = false;

  /// Owns the trip's call-signaling channel for this screen's whole
  /// lifetime (not just while a call is on screen), so an incoming call can
  /// be caught and surfaced at any point while the trip is open - see
  /// [_onIncomingCallOffer].
  late final CallSignalingService _callSignaling;
  StreamSubscription<CallSignal>? _incomingCallSub;
  bool _callScreenOpen = false;

  @override
  void initState() {
    super.initState();
    _sub = RideRepository.instance.watchTrip(widget.tripId).listen(_onTrip);
    // Keeps the app process alive in the background for as long as this
    // screen represents a real, non-terminal trip (stopped the moment
    // _onTrip below sees it end) - see TripForegroundService for why.
    TripForegroundService.start();

    _callSignaling = CallSignalingService(
      tripId: widget.tripId,
      selfRole: 'customer',
    )..start();
    _incomingCallSub = _callSignaling.onOffer.listen(_onIncomingCallOffer);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _incomingCallSub?.cancel();
    _callSignaling.dispose();
    TripForegroundService.stop();
    super.dispose();
  }

  /// Only ever reacts while no call screen is already open on top of this
  /// one - a second offer while a call is already in progress is either a
  /// stray retransmit or something to handle inside that call screen, not
  /// a new incoming call to prompt for.
  void _onIncomingCallOffer(CallSignal signal) {
    if (!mounted || _callScreenOpen || signal.sdp == null) return;
    _openCallScreen(incomingOfferSdp: signal.sdp);
  }

  void _openCallScreen({String? incomingOfferSdp}) {
    final trip = _trip;
    if (trip == null) return;
    _callScreenOpen = true;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => CallScreen(
              signaling: _callSignaling,
              peerName: trip.captainName ?? 'الكابتن',
              peerAvatarUrl: trip.captainAvatar,
              incomingOfferSdp: incomingOfferSdp,
            ),
          ),
        )
        .then((_) => _callScreenOpen = false);
  }

  /// Straight-line ETA/remaining-distance from the captain's last known
  /// position to whatever point is currently relevant: the pickup while the
  /// captain is still on the way, or the destination once the ride is under
  /// way - except for an open trip, which has no fixed destination, so
  /// there is nothing to estimate toward once it starts (the bottom card
  /// falls back to elapsed time / distance traveled so far instead).
  RouteEstimate? _computeLiveEstimate(Trip trip) {
    final captainLat = trip.captainLat;
    final captainLng = trip.captainLng;
    if (captainLat == null || captainLng == null) return null;

    final targetingPickup =
        trip.status == TripStatus.accepted ||
        trip.status == TripStatus.enRoute ||
        trip.status == TripStatus.arrived;
    final targetingDestination = trip.status == TripStatus.started && !trip.isOpenTrip;
    if (!targetingPickup && !targetingDestination) return null;

    final target = targetingPickup
        ? LatLng(trip.pickupLat, trip.pickupLng)
        : LatLng(trip.destLat, trip.destLng);
    return _routeEstimator.estimate(
      pickup: LatLng(captainLat, captainLng),
      destination: target,
    );
  }

  void _onTrip(Trip? trip) {
    if (!mounted) return;
    setState(() {
      _trip = trip;
      _liveEstimate = trip != null ? _computeLiveEstimate(trip) : null;
    });
    if (trip == null || _handledTerminal) return;

    context.read<AppStateProvider>().setActiveTripFromBackend(trip);

    if (trip.status == TripStatus.completed) {
      _handledTerminal = true;
      TripForegroundService.stop();
      context.read<AppStateProvider>().archiveActiveTrip();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => TripSummaryScreen(trip: trip)),
        );
      });
    } else if (trip.status == TripStatus.cancelled) {
      _handledTerminal = true;
      TripForegroundService.stop();
      context.read<AppStateProvider>()
        ..archiveActiveTrip()
        ..setActiveTripFromBackend(null);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم إلغاء المشوار.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
  }

  Future<void> _cancelTrip() async {
    setState(() => _isCancelling = true);
    try {
      await RideRepository.instance.cancelTrip(
        widget.tripId,
        cancelledBy: 'customer',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر إلغاء المشوار الآن، حاول مرة أخرى.',
              style: TextStyle(fontFamily: 'Cairo'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = _trip;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: trip == null
          ? const Center(child: CircularProgressIndicator())
          : trip.status == TripStatus.searching
          ? _buildSearchingView()
          : Stack(
              children: [
                Positioned.fill(child: _buildLiveMap(trip)),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: _buildTopBanner(trip),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(top: false, child: _buildBottomCard(trip)),
                ),
              ],
            ),
    );
  }

  /// Full-screen view for [TripStatus.searching]: a pulsing radar animation
  /// around a car icon, standing in for the map (there is nothing to show
  /// on it yet - no captain is assigned) while the request broadcasts.
  Widget _buildSearchingView() {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _SearchingPulse(),
                  const SizedBox(height: 28),
                  const Text(
                    'جاري البحث عن كابتن قريب منك...',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'سيصلك إشعار فور قبول أحد الكباتن لطلبك.',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isCancelling ? null : _cancelTrip,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
                child: _isCancelling
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('إلغاء الطلب'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The real map behind the status banner/bottom card, from the moment a
  /// captain is assigned onward - pickup pin always shown, destination pin
  /// added once there is a real one (never for an open trip - it has no
  /// destination yet by definition), and the captain's actual live
  /// position (see [Trip.captainLat]/[captainLng], pushed by the captain
  /// app) when known. Falls back to [RealMapWidget]'s own simulated
  /// pickup<->destination animation only when no real position has arrived
  /// yet, rather than showing nothing.
  Widget _buildLiveMap(Trip trip) {
    final hasDestination = !trip.isOpenTrip;
    return RealMapWidget(
      status: trip.status,
      showRoute: true,
      animateCar: trip.captainLat == null,
      pickupLat: trip.pickupLat,
      pickupLng: trip.pickupLng,
      destLat: hasDestination ? trip.destLat : null,
      destLng: hasDestination ? trip.destLng : null,
      carLat: trip.captainLat,
      carLng: trip.captainLng,
    );
  }

  Widget _buildTopBanner(Trip trip) {
    final (text, color) = switch (trip.status) {
      TripStatus.accepted => ('الكابتن في الطريق إليك', AppColors.accent),
      TripStatus.enRoute => ('الكابتن في الطريق إليك', AppColors.accent),
      TripStatus.arrived => ('وصل الكابتن إلى موقعك', AppColors.success),
      TripStatus.started => ('الرحلة جارية الآن', AppColors.accent),
      _ => (trip.statusArabic, AppColors.secondaryText),
    };
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(30),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_taxi_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                fontFamily: 'Cairo',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomCard(Trip trip) {
    final canCancel = trip.status == TripStatus.accepted;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.accent, width: 4)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 14)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (trip.captainName != null && trip.captainName!.isNotEmpty)
            _buildCaptainCard(trip)
          else
            Text(
              trip.isOpenTrip ? 'مشوار مفتوح' : trip.destinationLocation,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          const SizedBox(height: 16),
          if (canCancel)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isCancelling ? null : _cancelTrip,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
                child: _isCancelling
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('إلغاء المشوار'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCaptainCard(Trip trip) {
    final avatarUrl = trip.captainAvatar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (trip.price > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${trip.price.toStringAsFixed(0)} أوقية',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            const Spacer(),
            IconButton.filledTonal(
              onPressed: () => _openCallScreen(),
              icon: const Icon(Icons.call_rounded),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: AppColors.accent, width: 2.5),
                ),
              ),
              child: CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? NetworkImage(avatarUrl)
                    : null,
                child: (avatarUrl != null && avatarUrl.isNotEmpty)
                    ? null
                    : Text(
                        trip.captainName!.isNotEmpty
                            ? trip.captainName!.substring(0, 1)
                            : '؟',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.primary,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    trip.captainName!,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  if (trip.vehicleName != null && trip.vehicleName!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        trip.vehicleName!,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (trip.vehiclePlate != null && trip.vehiclePlate!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accent, width: 1.5),
            ),
            child: Column(
              children: [
                const Text(
                  'رقم اللوحة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  trip.vehiclePlate!,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: AppColors.darkText,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (trip.captainPhone != null && trip.captainPhone!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.phone_rounded,
                  size: 14,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(width: 6),
                Text(
                  trip.captainPhone!,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Divider(height: 1),
        ),
        _buildStatTileRow(trip),
      ],
    );
  }

  /// Three fixed-width tiles: captain rating (always shown, sourced from
  /// [Trip.captainRating] regardless of trip type/phase), then ETA and
  /// remaining distance while there is a fixed point to head toward
  /// (pickup before the ride starts, destination during a normal ride) -
  /// or, once an open trip (no fixed destination) is under way, elapsed
  /// time and distance traveled so far instead.
  Widget _buildStatTileRow(Trip trip) {
    final estimate = _liveEstimate;
    final isOpenInProgress = trip.status == TripStatus.started && trip.isOpenTrip;

    String etaLabel = 'الوصول';
    String etaValue = '—';
    String distanceLabel = 'المسافة المتبقية';
    String distanceValue = '—';

    if (estimate != null) {
      etaValue = '${estimate.durationMinutes} د';
      distanceValue = '${estimate.distanceKm.toStringAsFixed(1)} كم';
    } else if (isOpenInProgress) {
      etaLabel = 'مدة المشوار';
      final startedAt = trip.startedAt;
      if (startedAt != null) {
        final minutes = DateTime.now().difference(startedAt).inMinutes;
        etaValue = '$minutes د';
      }
      distanceLabel = 'المسافة المقطوعة';
      final traveled = trip.liveTraveledDistanceKm;
      if (traveled != null) {
        distanceValue = '${traveled.toStringAsFixed(1)} كم';
      }
    }

    return Row(
      children: [
        Expanded(
          child: _buildStatTile(
            Icons.star_rounded,
            'تقييم الكابتن',
            trip.captainRating != null
                ? trip.captainRating!.toStringAsFixed(1)
                : '—',
          ),
        ),
        Expanded(child: _buildStatTile(Icons.schedule_rounded, etaLabel, etaValue)),
        Expanded(
          child: _buildStatTile(
            Icons.directions_car_rounded,
            distanceLabel,
            distanceValue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatTile(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppColors.accent),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppColors.darkText,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 10,
            color: AppColors.secondaryText,
          ),
        ),
      ],
    );
  }
}

/// A car icon inside a filled circle, with three expanding-and-fading rings
/// radiating outward on a loop - a "radar ping" standing in for an actual
/// map while [TripTrackingScreen] has nothing to show a captain on yet.
class _SearchingPulse extends StatefulWidget {
  const _SearchingPulse();

  @override
  State<_SearchingPulse> createState() => _SearchingPulseState();
}

class _SearchingPulseState extends State<_SearchingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++) _buildRing(i),
              child!,
            ],
          ),
        );
      },
      child: Container(
        width: 68,
        height: 68,
        decoration: const BoxDecoration(
          color: AppColors.accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: const Icon(
          Icons.local_taxi_rounded,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }

  /// [index] staggers each of the 3 rings a third of a cycle apart, so a new
  /// ring starts just as the previous one is fading out - a continuous
  /// pulse rather than three rings ticking in lockstep.
  Widget _buildRing(int index) {
    final phase = (_controller.value + index / 3) % 1.0;
    final scale = 0.35 + phase * 1.1;
    final opacity = (1 - phase).clamp(0.0, 1.0) * 0.45;
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accent, width: 2),
          ),
        ),
      ),
    );
  }
}
