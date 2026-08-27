import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import '../../core/constants/colors.dart';
import '../../providers/app_state_provider.dart';
import '../../core/widgets/real_map_widget.dart';
import '../../core/widgets/call_options_sheet.dart';
import '../../core/widgets/route_row.dart';
import '../../core/services/call_signaling_service.dart';
import '../../models/models.dart';
import '../calls/call_screen.dart';
import '../support/chat_screen.dart';
import 'cancel_trip_dialog.dart';
import 'collect_payment_dialog.dart';

/// Shown once a captain is driving an open ride (no known destination): a
/// live map, a running fare meter, and a manual "end trip" action instead of
/// the fixed-destination flow in CaptainActiveTripScreen.
class OpenRideActiveScreen extends StatefulWidget {
  const OpenRideActiveScreen({super.key});

  @override
  State<OpenRideActiveScreen> createState() => _OpenRideActiveScreenState();
}

class _OpenRideActiveScreenState extends State<OpenRideActiveScreen> {
  StreamSubscription<Position>? _positionSub;
  double _distanceKm = 0.0;
  double? _lastLat;
  double? _lastLng;
  double? _carLat;
  double? _carLng;
  // Counts every GPS fix the stream actually delivers, shown next to the
  // "كم" chip - tells a captain (and us, from a screenshot) whether GPS
  // fixes are arriving at all versus arriving but not adding up to any
  // distance, which are two very different problems to chase.
  int _gpsFixCount = 0;

  // Owns its own call-signaling subscription, independent from
  // CaptainActiveTripScreen's - the two screens are never both the active
  // trip's rendered UI at once (that screen delegates to this one entirely
  // once an open ride starts), so each just subscribes to the same
  // call_trip_<id> channel while it's the one on screen. See
  // CaptainActiveTripScreen._ensureCallSignaling for why this is lazy.
  CallSignalingService? _callSignaling;
  String? _callSignalingTripId;
  StreamSubscription<CallSignal>? _incomingCallSub;
  bool _callScreenOpen = false;

  void _ensureCallSignaling(String tripId) {
    if (_callSignalingTripId == tripId) return;
    _incomingCallSub?.cancel();
    _callSignaling?.dispose();
    final signaling = CallSignalingService(tripId: tripId, selfRole: 'captain')..start();
    _callSignaling = signaling;
    _callSignalingTripId = tripId;
    _incomingCallSub = signaling.onOffer.listen(_onIncomingCallOffer);
  }

  void _onIncomingCallOffer(CallSignal signal) {
    if (!mounted || _callScreenOpen || signal.sdp == null) return;
    final trip = Provider.of<AppStateProvider>(context, listen: false).activeTrip;
    if (trip == null) return;
    _openCallScreen(trip, incomingOfferSdp: signal.sdp);
  }

  void _openCallScreen(Trip trip, {String? incomingOfferSdp}) {
    final signaling = _callSignaling;
    if (signaling == null) return;
    _callScreenOpen = true;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => CallScreen(
              signaling: signaling,
              peerName: trip.customerName,
              incomingOfferSdp: incomingOfferSdp,
            ),
          ),
        )
        .then((_) => _callScreenOpen = false);
  }

  @override
  void initState() {
    super.initState();
    // Seeds from the provider in case this screen is a fresh instance of an
    // already-in-progress open ride (e.g. restored after the app was killed
    // and relaunched) - otherwise the on-screen distance would start over
    // from zero even though the provider already restored the real total.
    // Seeding _lastLat/_lastLng too means the very next GPS fix measures
    // the actual gap covered while the app was down, instead of silently
    // dropping that stretch of driving.
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    _distanceKm = provider.openRideDistanceKm;
    _lastLat = provider.openRideLastLat;
    _lastLng = provider.openRideLastLng;
    _startTrackingDistance();
  }

  Future<void> _startTrackingDistance() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showLocationWarning('خدمة الموقع (GPS) مُغلقة، فعّلها لتحديث المسافة والأجرة.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showLocationWarning('صلاحية الموقع غير ممنوحة، فعّلها من إعدادات التطبيق لتحديث المسافة والأجرة.');
        return;
      }

      // On Android, run the location updates as a foreground service with a
      // persistent notification for as long as this screen is open -
      // otherwise Android kills the app in the background to save battery,
      // wiping the live fare meter (distance/time) mid-trip.
      final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
      final LocationSettings locationSettings = isAndroid
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 5,
              foregroundNotificationConfig: const ForegroundNotificationConfig(
                notificationTitle: 'الهدهد',
                notificationText: 'مشوار جارٍ الآن',
                enableWakeLock: true,
              ),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 5,
            );

      _positionSub =
          Geolocator.getPositionStream(
            locationSettings: locationSettings,
          ).listen((position) {
            if (!mounted) return;
            double? meters;
            // Only credit distance - and only move the reference point
            // fresh comparisons are measured from - once the car has
            // actually covered real ground since it, not on every GPS fix.
            // A stationary phone's fix still drifts a few meters from pure
            // signal noise, well past the 5m distanceFilter this stream
            // already applies; without this floor that drift kept adding
            // up as "distance" driven while genuinely parked. A fix that
            // doesn't clear it just leaves the reference point where it
            // was, so slow real movement still accumulates correctly
            // across several fixes instead of being silently dropped.
            var realMovement = true;
            if (_lastLat != null && _lastLng != null) {
              meters = Geolocator.distanceBetween(
                _lastLat!,
                _lastLng!,
                position.latitude,
                position.longitude,
              );
              realMovement = meters >= AppStateProvider.idleMovementThresholdMeters;
              if (realMovement) _distanceKm += meters / 1000;
            }
            setState(() {
              if (realMovement) {
                _lastLat = position.latitude;
                _lastLng = position.longitude;
              }
              _carLat = position.latitude;
              _carLng = position.longitude;
              _gpsFixCount++;
            });
            if (mounted) {
              Provider.of<AppStateProvider>(context, listen: false)
                  .updateOpenRideDistance(
                    _distanceKm,
                    lat: position.latitude,
                    lng: position.longitude,
                    distanceMeters: meters,
                  );
            }
          }, onError: (_) {
            // The stream itself can fail mid-trip (GPS turned off, permission
            // revoked, ...) - surface that instead of the meter just
            // silently freezing with no explanation.
            _showLocationWarning('انقطع تتبع الموقع، تحقق من صلاحية GPS.');
          });
    } catch (_) {
      _showLocationWarning('تعذر تفعيل تتبع الموقع، تحقق من صلاحيات GPS.');
    }
  }

  void _showLocationWarning(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
        backgroundColor: AppColors.error,
        duration: const Duration(seconds: 12),
      ),
    );
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _incomingCallSub?.cancel();
    _callSignaling?.dispose();
    super.dispose();
  }

  String _formatElapsed(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // Read (not listen): the live fare/time ticker fires every second, and
    // listening here would rebuild the whole screen - including the map -
    // on every tick, which is what made the map look like it was jittering.
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    final trip = provider.activeTrip;
    if (trip == null) return const SizedBox.shrink();
    _ensureCallSignaling(trip.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  RealMapWidget(
                    pickupLat: trip.pickupLat,
                    pickupLng: trip.pickupLng,
                    carLat: _carLat,
                    carLng: _carLng,
                  ),

                  // Live fare badge - the only part that needs to redraw
                  // every second, so it's isolated from the map above.
                  Positioned(
                    top: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Consumer<AppStateProvider>(
                        builder: (context, provider, _) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 8),
                            ],
                          ),
                          child: Text(
                            '${provider.openRideFare.toStringAsFixed(0)} أوقية',
                            style: const TextStyle(
                              color: AppColors.darkText,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              fontFamily: 'Cairo',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Cancel trip button
                  Positioned(
                    right: 16,
                    top: 16,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 6),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.error,
                        ),
                        onPressed: () => showCancelTripDialog(context),
                      ),
                    ),
                  ),

                  // Live stats stack, grouped on the opposite side from the
                  // map's zoom controls (which sit at left:16). The fare
                  // already shows in the badge above, so it isn't repeated
                  // here - just distance and elapsed time.
                  Positioned(
                    right: 16,
                    top: 72,
                    child: Consumer<AppStateProvider>(
                      builder: (context, provider, _) => Column(
                        children: [
                          _buildStatChip(_distanceKm.toStringAsFixed(1), 'كم'),
                          const SizedBox(height: 4),
                          // Temporary diagnostic: how many GPS fixes have
                          // actually arrived, so a stuck "كم" chip can be
                          // told apart from a genuinely-empty GPS stream.
                          Text(
                            'GPS: $_gpsFixCount',
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.secondaryText,
                              fontFamily: 'Cairo',
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildStatChip(
                            _formatElapsed(provider.openRideMeterElapsed),
                            'الوقت',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom control board
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text(
                          'مشوار مفتوح',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            fontFamily: 'Cairo',
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'كود: ${trip.id.length > 8 ? trip.id.substring(trip.id.length - 8) : trip.id}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  Row(
                    children: [
                      const Icon(
                        Icons.radio_button_checked_rounded,
                        color: AppColors.success,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'من',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.secondaryText,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            Text(
                              RouteRow.shortAddress(trip.pickupLocation),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: AppColors.darkText,
                                fontFamily: 'Cairo',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primary,
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.customerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                fontFamily: 'Cairo',
                              ),
                            ),
                            Text(
                              trip.customerPhone,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ChatScreen(showAppBar: true),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.call_outlined,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        onPressed: () => showCallOptionsSheet(
                          context,
                          phone: trip.customerPhone,
                          onInAppCall: () => _openCallScreen(trip),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () => showCollectPaymentDialog(
                      context,
                      suggestedAmount: provider.openRideFare,
                      onConfirm: (amountPaid) =>
                          provider.captainCompleteOpenRide(
                            distanceKm: _distanceKm,
                            amountPaid: amountPaid,
                          ),
                    ),
                    child: const Text('إنهاء الرحلة'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String value, String label) {
    return Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.darkText,
              fontFamily: 'Cairo',
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.secondaryText,
              fontFamily: 'Cairo',
            ),
          ),
        ],
      ),
    );
  }
}
