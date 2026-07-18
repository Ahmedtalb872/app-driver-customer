import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../core/services/fare_calculator.dart';
import '../../core/services/gps_jump_filter.dart';
import '../../core/services/ride_repository.dart';
import '../../models/models.dart';

/// Granular lifecycle of a single open (destination-unknown) trip, owned and
/// driven entirely by [OpenTripController]. This is intentionally separate
/// from the coarser [TripStatus] used elsewhere so the rest of the app
/// (trip history, customer screens) doesn't need to know about it.
enum OpenTripStage {
  accepted,
  arrived,
  onboard,
  running,
  waiting,
  completed,
  cancelled,
}

/// Drives a single open trip: state machine, live GPS distance tracking with
/// jump/accuracy filtering, and moving/waiting timers used for the fare meter.
///
/// Lives for the lifetime of the active-trip screen (created once in
/// `initState`, disposed in `dispose`) so its state survives widget rebuilds.
///
/// GPS/meter plumbing stays local/in-memory exactly as before. On top of
/// that, when [trip] is backed by a real Supabase row (real UUID id, not the
/// legacy `trip_...`/`trip_incoming_...` synthetic ids still used by the
/// still-simulated `open_trips_screen.dart` browsing flow), this controller
/// additionally: listens for the passenger's real "ركبت" event instead of
/// ever starting the meter from a captain self-report, and periodically
/// persists a live-tracking snapshot (never on every raw GPS fix - see
/// `_maybeSyncLiveTracking`).
class OpenTripController extends ChangeNotifier {
  final Trip trip;

  OpenTripController({required this.trip})
    : _stage = _initialStageFor(trip.status);

  /// A real Supabase trip id is a UUID and never starts with `trip_` (the
  /// prefix every locally-synthesized/dummy Trip id uses) - see
  /// `AppStateProvider`'s dummy-request builders and `requestTrip`.
  bool get isRealTrip => !trip.id.startsWith('trip_');

  static OpenTripStage _initialStageFor(TripStatus status) {
    switch (status) {
      case TripStatus.arrived:
        return OpenTripStage.arrived;
      case TripStatus.started:
        return OpenTripStage.running;
      default:
        return OpenTripStage.accepted;
    }
  }

  OpenTripStage _stage;
  OpenTripStage get stage => _stage;

  final Stopwatch _movingStopwatch = Stopwatch();
  final Stopwatch _waitingStopwatch = Stopwatch();
  Duration get movingDuration => _movingStopwatch.elapsed;
  Duration get waitingDuration => _waitingStopwatch.elapsed;
  Duration get totalDuration => movingDuration + waitingDuration;

  double _distanceKm = 0.0;
  double get distanceKm => _distanceKm;

  final List<LatLng> _tracePoints = [];
  List<LatLng> get tracePoints => List.unmodifiable(_tracePoints);

  Position? _currentPosition;
  Position? get currentPosition => _currentPosition;
  Position? _lastAcceptedPosition;

  DateTime? tripStartTime;
  DateTime? tripEndTime;

  bool _gpsAvailable = true;
  bool get gpsAvailable => _gpsAvailable;

  String? _locationError;
  String? get locationError => _locationError;

  StreamSubscription<Position>? _positionSub;
  Timer? _tickTimer;
  bool _disposed = false;

  StreamSubscription<Trip?>? _remoteSub;
  DateTime? _lastTrackingSyncAt;

  FareBreakdown get fareBreakdown => FareCalculator.calculate(
    distanceKm: _distanceKm,
    movingDuration: movingDuration,
    waitingDuration: waitingDuration,
  );

  // ---------------------------------------------------------------------
  // State transitions. Every method validates the current stage before
  // acting so calls arriving out of order (double taps, stale callbacks)
  // are safely ignored instead of corrupting the meter.
  // ---------------------------------------------------------------------

  bool markArrived() {
    if (_stage != OpenTripStage.accepted) return false;
    _stage = OpenTripStage.arrived;
    notifyListeners();
    return true;
  }

  bool markPassengerOnboard() {
    if (_stage != OpenTripStage.arrived) return false;
    _stage = OpenTripStage.onboard;
    notifyListeners();
    return true;
  }

  /// For a real trip only: starts listening for the passenger's "ركبت"
  /// action (the trip row's status flipping to in_progress). This is the
  /// *only* way a real Open Trip's meter starts - there is deliberately no
  /// captain self-report path anymore, per spec section 12 ("Only the trip
  /// passenger can press ركبت").
  void listenForRemoteBoarding() {
    if (!isRealTrip || _remoteSub != null || _disposed) return;
    _remoteSub = RideRepository.instance.watchTrip(trip.id).listen((remote) {
      if (_disposed || remote == null) return;
      if (remote.status == TripStatus.started &&
          _stage == OpenTripStage.arrived) {
        markPassengerOnboard();
        startTrip();
      }
    });
  }

  /// Prevents starting the trip before the passenger is confirmed onboard.
  Future<bool> startTrip() async {
    if (_stage != OpenTripStage.onboard) return false;
    _stage = OpenTripStage.running;
    tripStartTime = DateTime.now();
    _movingStopwatch
      ..reset()
      ..start();
    _startTicker();
    await _startTracking();
    notifyListeners();
    return true;
  }

  bool toggleWaiting() {
    if (_stage == OpenTripStage.running) {
      _stage = OpenTripStage.waiting;
      _movingStopwatch.stop();
      _waitingStopwatch.start();
      notifyListeners();
      return true;
    }
    if (_stage == OpenTripStage.waiting) {
      _stage = OpenTripStage.running;
      _waitingStopwatch.stop();
      _movingStopwatch.start();
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Prevents ending a trip that has not started.
  bool completeTrip() {
    if (_stage != OpenTripStage.running && _stage != OpenTripStage.waiting) {
      return false;
    }
    _movingStopwatch.stop();
    _waitingStopwatch.stop();
    tripEndTime = DateTime.now();
    _stage = OpenTripStage.completed;
    _stopTicker();
    _stopTracking();
    notifyListeners();
    return true;
  }

  bool cancelTrip() {
    if (_stage == OpenTripStage.completed ||
        _stage == OpenTripStage.cancelled) {
      return false;
    }
    _movingStopwatch.stop();
    _waitingStopwatch.stop();
    _stage = OpenTripStage.cancelled;
    _stopTicker();
    _stopTracking();
    notifyListeners();
    return true;
  }

  // ---------------------------------------------------------------------
  // UI ticker: only responsible for refreshing the displayed meter every
  // second (elapsed time / distance / fare all read live off the stopwatches
  // and distance accumulator, avoiding drift).
  // ---------------------------------------------------------------------

  void _startTicker() {
    if (_tickTimer != null) return; // Prevent duplicate timers.
    _tickTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => notifyListeners(),
    );
  }

  void _stopTicker() {
    _tickTimer?.cancel();
    _tickTimer = null;
  }

  // ---------------------------------------------------------------------
  // GPS tracking.
  // ---------------------------------------------------------------------

  Future<void> _startTracking() async {
    if (_positionSub != null) return; // Prevent duplicate stream subscriptions.

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _gpsAvailable = false;
      _locationError = 'خدمة الموقع الجغرافي غير مفعّلة على الجهاز.';
      notifyListeners();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _gpsAvailable = false;
      _locationError =
          'تم رفض إذن الوصول للموقع، لا يمكن تتبع المسافة المقطوعة تلقائياً.';
      notifyListeners();
      return;
    }

    _gpsAvailable = true;
    _locationError = null;

    try {
      final initial = await Geolocator.getCurrentPosition();
      _handlePosition(initial);
    } catch (_) {
      // The stream below will keep trying; a single failed initial fix is not fatal.
    }

    _positionSub =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen(
          _handlePosition,
          onError: (_) {
            if (_disposed) return;
            _gpsAvailable = false;
            _locationError =
                'تعذر الحصول على إشارة GPS مؤقتاً، تم إيقاف حساب المسافة حتى تعود الإشارة.';
            notifyListeners();
          },
        );
  }

  void _handlePosition(Position position) {
    if (_disposed) return;
    _currentPosition = position;
    _gpsAvailable = true;
    _locationError = null;

    final previous = _lastAcceptedPosition;
    if (previous == null) {
      _lastAcceptedPosition = position;
      _tracePoints.add(LatLng(position.latitude, position.longitude));
      notifyListeners();
      return;
    }

    final result = GpsJumpFilter.evaluate(
      previous: previous,
      current: position,
    );
    if (!result.accepted) {
      // Poor accuracy or an unrealistic jump: keep the old reference point so
      // the next reading is still compared fairly, and don't touch distance.
      notifyListeners();
      return;
    }

    _lastAcceptedPosition = position;
    if (result.distanceDeltaMeters > 0) {
      _tracePoints.add(LatLng(position.latitude, position.longitude));
      // Only accumulate distance while actively running — never while
      // waiting and never before the trip has officially started.
      if (_stage == OpenTripStage.running) {
        _distanceKm += result.distanceDeltaMeters / 1000.0;
      }
    }
    _maybeSyncLiveTracking(position);
    notifyListeners();
  }

  /// Persists a live-tracking snapshot for a real trip at most once every
  /// 15 seconds (never on every raw GPS fix), matching spec section 16's
  /// "update the displayed fare smoothly without excessive backend writes".
  /// Fire-and-forget: a transient network failure never interrupts the
  /// local meter, which remains the source of truth for the live UI.
  void _maybeSyncLiveTracking(Position position) {
    if (!isRealTrip || _stage != OpenTripStage.running) return;
    final now = DateTime.now();
    if (_lastTrackingSyncAt != null &&
        now.difference(_lastTrackingSyncAt!) < const Duration(seconds: 15)) {
      return;
    }
    _lastTrackingSyncAt = now;
    RideRepository.instance
        .updateLiveTracking(
          tripId: trip.id,
          lat: position.latitude,
          lng: position.longitude,
          traveledDistanceKm: _distanceKm,
        )
        .catchError((_) {});
  }

  void _stopTracking() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTicker();
    _stopTracking();
    _remoteSub?.cancel();
    super.dispose();
  }
}
