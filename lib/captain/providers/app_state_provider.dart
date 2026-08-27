import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../core/supabase/auth_repository.dart';
import '../core/supabase/auth_exception.dart';
import '../core/services/new_trip_alert.dart';
import '../core/services/push_notifications.dart';

class AppStateProvider extends ChangeNotifier {
  // Auth state
  bool _isLoggedIn = false;
  String? _userId;
  String _captainEmail = '';

  // Captain state
  bool _isCaptainOnline = false;
  // Filled in from the profiles row at login - kept empty pre-login so a
  // fresh install never shows the DummyData placeholder identity to a real
  // captain.
  String _captainName = '';
  String _captainPhone = '';
  // 'car' or 'motorcycle' - derived from captains.vehicle_type at login
  // (motorcycle is just another value of that same column, not a separate
  // one). Only motorcycle captains can see/toggle delivery requests.
  String _vehicleCategory = 'car';
  // Vehicle details written into every accepted trip so the customer sees
  // the real car/plate to look for at pickup - filled in from the captains
  // row at login. Blank until then; a captain with no vehicle recorded
  // just gets an empty vehicleName rather than the DummyData placeholder.
  String _captainVehicleBrand = '';
  String _captainVehicleModel = '';
  int? _captainVehicleYear;
  String _captainVehiclePlate = '';
  bool _deliveryModeEnabled = false;

  String get _captainVehicleName {
    final parts = <String>[
      _captainVehicleBrand,
      _captainVehicleModel,
      if (_captainVehicleYear != null) _captainVehicleYear.toString(),
    ].where((p) => p.trim().isNotEmpty).toList();
    return parts.join(' ');
  }
  // A brand-new captain starts at 0 on every field - the dummy 1250/425
  // wallet+earnings from the design mock made it look like their account
  // was pre-funded, and let them go online (and try to accept trips) with
  // no real balance behind them.
  double _captainWalletBalance = 0.0;
  double _captainTodayEarnings = 0.0;
  int _captainTripsCount = 0;
  final List<WalletTransaction> _captainTransactions = [];

  // Active Trip states
  Trip? _activeTrip;
  Timer? _countdownTimer;
  int _countdownSeconds = 45;
  bool _isSearching = false;

  // Open ride live meter, two independent components:
  // - Distance: the whole trip bills at 0.023 MRU/meter, continuously (not
  //   rounded up to the next whole km), with a 100 MRU minimum fare for
  //   the trip regardless of how short it is.
  // - Waiting time: bills 5 MRU/minute, but only while the captain is
  //   actually stationary (no GPS movement) beyond a 3-minute grace period
  //   per stop, pausing the instant they're moving again.
  static const double openRideMinimumFare = 100.0;
  static const double openRidePerMeterRate = 0.023;
  static const double openRidePerMinuteRate = 5.0;
  static const Duration openRideIdleThreshold = Duration(minutes: 3);
  DateTime? _openRideStartTime;
  DateTime? _openRideLastMovementTime;
  // Billable idle seconds already banked from earlier stops this trip -
  // the current stop's contribution is computed live on top of this, see
  // _currentBillableIdleSeconds().
  double _openRideAccumulatedIdleSeconds = 0.0;
  double _openRideDistanceKm = 0.0;
  // Last known GPS point, persisted alongside the distance so a resumed
  // session (after the app was killed/relaunched mid-outage) can measure
  // the gap it missed instead of silently dropping that stretch of driving.
  double? _openRideLastLat;
  double? _openRideLastLng;
  Timer? _openRideTicker;

  // Keeps the app alive (via an Android foreground-service notification,
  // same mechanism as the open-ride meter) for as long as the captain is
  // online and waiting for a request - otherwise Android kills the
  // backgrounded app between requests, and the captain loses their online
  // status (and misses requests) without noticing until they reopen the
  // app. Paused while an active trip is in progress so it doesn't run
  // alongside OpenRideActiveScreen's own tracking stream.
  StreamSubscription<Position>? _onlinePresenceSub;

  // Nudges the captain every couple of minutes to complete whatever step of
  // the active trip they're currently on, so a step doesn't get forgotten.
  Timer? _stepReminderTicker;
  DateTime? _tripStepStartedAt;

  // Chat state - empty for a real account; a message appears here only
  // once one comes in through the messages table.
  final List<Message> _chatMessages = [];

  // Trip history - accumulates from actually-completed trips only; the
  // dummy pre-populated list made a brand-new captain look like they
  // already had a busy history behind them.
  final List<Trip> _captainTripHistory = [];

  // Captain incoming request state: sourced live from the `trips` table
  // (real requests created by the customer app), while the captain is online.
  Trip? _incomingRequest;
  StreamSubscription<List<Map<String, dynamic>>>? _pendingRidesSubscription;
  List<Map<String, dynamic>> _lastPendingRides = [];
  final Set<String> _ignoredRideIds = {};

  // Latest fix from the online-presence tracking stream (see
  // _startOnlinePresenceTracking) - kept locally too, not just upserted to
  // captain_locations, so _maybeShowNextPendingRide can filter pending
  // rides by distance without an extra DB round-trip.
  double? _myLat;
  double? _myLng;

  // A pending ride farther than this from the captain's last known
  // position is never surfaced to them - matches the same radius the
  // send-trip-push Edge Function applies for background/killed-app pushes.
  static const double _pendingRideRadiusMeters = 2000.0;

  // Getters
  bool get isLoggedIn => _isLoggedIn;
  String? get userId => _userId;
  String get captainEmail => _captainEmail;

  bool get isCaptainOnline => _isCaptainOnline;
  String get captainName => _captainName;
  String get captainPhone => _captainPhone;
  String get vehicleCategory => _vehicleCategory;
  bool get isMotorcycleCaptain => _vehicleCategory == 'motorcycle';
  bool get deliveryModeEnabled => _deliveryModeEnabled;
  double get captainWalletBalance => _captainWalletBalance;
  double get captainTodayEarnings => _captainTodayEarnings;
  int get captainTripsCount => _captainTripsCount;
  List<WalletTransaction> get captainTransactions => _captainTransactions;

  Trip? get activeTrip => _activeTrip;
  int get countdownSeconds => _countdownSeconds;
  bool get isSearching => _isSearching;
  List<Message> get chatMessages => _chatMessages;

  List<Trip> get captainTripHistory => _captainTripHistory;

  Trip? get incomingRequest => _incomingRequest;

  Duration get openRideElapsed => _openRideStartTime == null
      ? Duration.zero
      : DateTime.now().difference(_openRideStartTime!);

  double get openRideDistanceKm => _openRideDistanceKm;
  double? get openRideLastLat => _openRideLastLat;
  double? get openRideLastLng => _openRideLastLng;

  bool get isOpenRideMeterActive => openRideMeterElapsed > Duration.zero;

  // Billable seconds of the *current* stop only - 0 while moving, and 0
  // for the first 4 minutes of any stop (the free grace period), only
  // counting up past that.
  double _currentBillableIdleSeconds() {
    if (_openRideLastMovementTime == null) return 0;
    final idleSeconds = DateTime.now()
        .difference(_openRideLastMovementTime!)
        .inSeconds
        .toDouble();
    final graceSeconds = openRideIdleThreshold.inSeconds.toDouble();
    return idleSeconds > graceSeconds ? idleSeconds - graceSeconds : 0;
  }

  // Time shown on the live "الوقت" stat: total billable waiting time so
  // far - banked time from earlier stops plus whatever the current stop
  // (if any) is accruing right now. Stays at zero while moving.
  Duration get openRideMeterElapsed => Duration(
    seconds: (_openRideAccumulatedIdleSeconds + _currentBillableIdleSeconds())
        .round(),
  );

  // The 100 MRU minimum applies to the *combined* distance+waiting total,
  // not to the distance portion alone with waiting always stacked on top -
  // otherwise a short ride with a long wait could be overcharged (e.g. 30
  // MRU of distance + 90 MRU of waiting is a fair 120, not 100+90=190).
  // Once the natural total reaches 100, the fare keeps climbing past it.
  double get openRideFare {
    final distanceMeters = _openRideDistanceKm * 1000;
    final distanceFare = distanceMeters * openRidePerMeterRate;
    final billableMinutes = openRideMeterElapsed.inSeconds / 60.0;
    final waitingFare = billableMinutes * openRidePerMinuteRate;
    final total = distanceFare + waitingFare;
    return total < openRideMinimumFare ? openRideMinimumFare : total;
  }

  // A stationary phone's GPS fix still drifts by several meters between
  // readings from pure signal noise - well past the 5m distanceFilter the
  // position stream is already set to. Without this, every jittery fix
  // reset the idle clock, so a captain genuinely stopped for many minutes
  // never crossed the grace period: openRideMeterElapsed stayed at 0
  // forever. Only a fix that moved the car by more than this counts as
  // real movement for idle-tracking purposes (still fine for a slow crawl
  // in traffic - it just takes one more fix to register). Public because
  // OpenRideActiveScreen applies the exact same floor before crediting
  // distance too - otherwise the same GPS noise this exists to filter out
  // of the idle clock was still quietly adding "distance driven" while
  // the car sat parked.
  static const double idleMovementThresholdMeters = 20.0;

  // Reported by OpenRideActiveScreen on every real GPS position update -
  // movement, so bank whatever billable idle time the stop that just ended
  // accrued before resetting the idle clock for this new movement. Also
  // tracks the current point so a killed-and-relaunched session can measure
  // the gap it missed instead of dropping that stretch of driving.
  //
  // [distanceMeters] is the raw distance covered since the previous fix
  // (null for the very first fix) - used only to decide whether this
  // update counts as real movement for the idle clock; [totalDistanceKm]
  // is still the running total shown to the captain regardless.
  void updateOpenRideDistance(
    double totalDistanceKm, {
    double? lat,
    double? lng,
    double? distanceMeters,
  }) {
    final isRealMovement =
        distanceMeters == null || distanceMeters >= idleMovementThresholdMeters;
    if (isRealMovement) {
      _openRideAccumulatedIdleSeconds += _currentBillableIdleSeconds();
      _openRideLastMovementTime = DateTime.now();
    }
    _openRideDistanceKm = totalDistanceKm;
    if (lat != null && lng != null) {
      _openRideLastLat = lat;
      _openRideLastLng = lng;
    }
    _persistOpenRideProgress();
    notifyListeners();
  }

  DateTime? _openRideProgressLastPersisted;

  // Saves the live meter (distance + idle time) to the trip row so it
  // survives the app being killed and relaunched (e.g. after a network
  // drop) - without this, restoreActiveTripIfAny() would bring the trip
  // back but the meter would restart from zero. Throttled to avoid writing
  // on every single GPS ping while driving.
  //
  // Idle time is saved as _openRideAccumulatedIdleSeconds (already-banked
  // stops) *plus* _currentBillableIdleSeconds() (whatever the captain's
  // current stop, if any, has racked up so far) - the banked total alone
  // only grows when a real movement event closes out a stop, so a captain
  // who'd been waiting continuously (no movement in between) had that
  // entire wait vanish if the app got killed mid-stop: distance survived
  // (it's just a running total) but the time counter reset to whatever it
  // was at the *start* of the current stop, not its actual value.
  void _persistOpenRideProgress({bool force = false}) {
    final trip = _activeTrip;
    if (trip == null || !trip.isOpenRide || !trip.isRemote) return;
    final now = DateTime.now();
    if (!force &&
        _openRideProgressLastPersisted != null &&
        now.difference(_openRideProgressLastPersisted!) <
            const Duration(seconds: 15)) {
      return;
    }
    _openRideProgressLastPersisted = now;
    Supabase.instance.client
        .from('trips')
        .update({
          'live_distance_km': _openRideDistanceKm,
          'live_idle_seconds':
              _openRideAccumulatedIdleSeconds + _currentBillableIdleSeconds(),
          if (_openRideLastLat != null) 'live_last_lat': _openRideLastLat,
          if (_openRideLastLng != null) 'live_last_lng': _openRideLastLng,
        })
        .eq('id', trip.id)
        .catchError((_) {});
  }

  // Hydrate state from a Supabase `profiles` row after a real sign-in/sign-up.
  // Callers are responsible for verifying profile['role'] == 'captain'
  // before calling this, since this app only serves captains.
  void loginFromProfile(
    Map<String, dynamic> profile,
    String email, {
    Map<String, dynamic>? captain,
  }) {
    _isLoggedIn = true;
    _userId = profile['id'] as String?;
    final String? fullName = profile['full_name'] as String?;
    final String? phone = profile['phone'] as String?;
    if (fullName != null && fullName.isNotEmpty) _captainName = fullName;
    if (phone != null && phone.isNotEmpty) _captainPhone = phone;
    _captainEmail = email;
    if (captain != null) {
      // Motorcycle isn't a separate column - it's just another value of
      // captains.vehicle_type (alongside economy/comfort/family for cars).
      _vehicleCategory = captain['vehicle_type'] == 'motorcycle'
          ? 'motorcycle'
          : 'car';
      _deliveryModeEnabled = captain['accepts_delivery'] as bool? ?? false;
      _captainVehicleBrand = (captain['vehicle_brand'] as String?) ?? '';
      _captainVehicleModel = (captain['vehicle_model'] as String?) ?? '';
      _captainVehicleYear = captain['vehicle_year'] as int?;
      _captainVehiclePlate = (captain['vehicle_plate'] as String?) ?? '';
      // Server-side truth wins over the local 0 default so refunds/
      // recharges/commissions credited on other devices (or by admin)
      // survive a re-login here.
      final serverBalance = captain['wallet_balance'];
      if (serverBalance != null) {
        _captainWalletBalance = (serverBalance as num).toDouble();
      }
      // Restores online status across an app relaunch too - otherwise a
      // captain silently drops offline (and stops receiving requests)
      // every time Android kills the backgrounded app, with no visible
      // sign anything changed until they happen to check.
      _isCaptainOnline = captain['is_online'] as bool? ?? false;
      // A zero-balance captain can't accept trips at all (see
      // toggleCaptainOnline), so don't leave them silently online in that
      // state - flip them offline and let them come back after a recharge.
      if (_isCaptainOnline && _captainWalletBalance <= 0) {
        _isCaptainOnline = false;
        if (_userId != null) {
          AuthRepository().setCaptainOnline(_userId!, false);
        }
      }
      if (_isCaptainOnline) _subscribeToPendingRides();
    }
    _syncOnlinePresenceTracking();
    // Registers this device for new-trip push alerts (rings/full-screens
    // even if the app is backgrounded or killed) - fire-and-forget, a
    // failure here shouldn't block login.
    PushNotifications.syncToken();
    notifyListeners();
  }

  // Re-hydrates an in-progress trip after the app process was killed and
  // relaunched mid-trip - active-trip state otherwise only lives here in
  // memory, so without this the captain would land back on the dashboard
  // with no sign their trip still exists, even though nothing changed
  // server-side. Call after loginFromProfile for an approved captain.
  Future<void> restoreActiveTripIfAny() async {
    final uid = _userId;
    if (uid == null || _activeTrip != null) return;
    try {
      final row = await AuthRepository().getActiveTripForCaptain(uid);
      if (row == null) return;
      await _hydrateActiveTripFromRow(row);
    } catch (_) {
      // Best-effort - worst case the captain has to be told to check their
      // trips manually; nothing here should block app startup.
    }
  }

  Future<void> _hydrateActiveTripFromRow(Map<String, dynamic> row) async {
    final tripId = row['id'] as String;
    String customerName = 'الزبون';
    String customerPhone = '';
    if (row['customer_id'] != null) {
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('full_name, phone')
            .eq('id', row['customer_id'])
            .single();
        final name = profile['full_name'] as String?;
        final phone = profile['phone'] as String?;
        if (name != null && name.isNotEmpty) customerName = name;
        if (phone != null && phone.isNotEmpty) customerPhone = phone;
      } catch (_) {
        // Fall back to the generic label if the profile can't be read.
      }
    }
    if (customerPhone.isEmpty) {
      final guestPhone = row['guest_customer_phone'] as String?;
      if (guestPhone != null && guestPhone.isNotEmpty) {
        customerPhone = guestPhone;
      }
    }

    final serviceType = row['service_type'] as String? ?? 'ride';
    final isDelivery = serviceType == 'delivery';
    String? packageDescription;
    if (isDelivery) {
      final recipientName = row['recipient_name'] as String?;
      final recipientPhone = row['recipient_phone'] as String?;
      if (recipientName != null && recipientName.isNotEmpty) {
        customerName = recipientName;
      }
      if (recipientPhone != null && recipientPhone.isNotEmpty) {
        customerPhone = recipientPhone;
      }
      packageDescription = row['package_description'] as String?;
    }

    final pickupLat = (row['pickup_lat'] as num).toDouble();
    final pickupLng = (row['pickup_lng'] as num).toDouble();
    final destLat = (row['destination_lat'] as num?)?.toDouble();
    final destLng = (row['destination_lng'] as num?)?.toDouble();
    final isOpenRide = row['trip_type'] == 'open';

    final distanceKm = (row['distance_km'] as num?)?.toDouble() ?? 0.0;
    final durationMin =
        (row['estimated_duration_minutes'] as num?)?.toInt() ?? 0;
    final price = (row['estimated_price'] as num?)?.toDouble() ?? 0.0;
    final paymentMethod = row['payment_method'] == 'wallet'
        ? 'محفظة الهدهد'
        : 'نقداً';
    final vehicleType = switch (row['vehicle_type']) {
      'comfort' => VehicleType.comfort,
      'family' => VehicleType.family,
      _ => VehicleType.economy,
    };

    _activeTrip = Trip(
      id: tripId,
      customerName: customerName,
      customerPhone: customerPhone,
      captainName: _captainName,
      captainPhone: _captainPhone,
      pickupLocation: row['pickup_address'] as String? ?? 'موقع الانطلاق',
      destinationLocation: row['destination_address'] as String?,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      destLat: destLat,
      destLng: destLng,
      distance: distanceKm,
      duration: durationMin,
      price: isOpenRide ? openRideMinimumFare : price,
      paymentMethod: paymentMethod,
      status: _mapDbTripStatus(row['status'] as String?),
      carType: vehicleType,
      isOpenRide: isOpenRide,
      openRideTimeout: 45,
      date: DateTime.now().toString().substring(0, 16),
      isRemote: true,
      serviceType: serviceType,
      packageDescription: packageDescription,
    );
    if (isOpenRide && _activeTrip!.status == TripStatus.started) {
      _restoreOpenRideMeter(row);
    }
    _syncOnlinePresenceTracking();
    _startStepReminder();
    notifyListeners();
  }

  // Brings the live fare meter back after the app was killed and relaunched
  // mid open-ride, using whatever progress was last saved by
  // _persistOpenRideProgress() - otherwise the meter would silently restart
  // from zero even though the trip (and its distance so far) is still real.
  void _restoreOpenRideMeter(Map<String, dynamic> row) {
    final boardedAt = row['boarded_at'] as String?;
    _openRideStartTime = boardedAt != null
        ? DateTime.tryParse(boardedAt) ?? DateTime.now()
        : DateTime.now();
    _openRideDistanceKm = (row['live_distance_km'] as num?)?.toDouble() ?? 0.0;
    _openRideAccumulatedIdleSeconds =
        (row['live_idle_seconds'] as num?)?.toDouble() ?? 0.0;
    _openRideLastLat = (row['live_last_lat'] as num?)?.toDouble();
    _openRideLastLng = (row['live_last_lng'] as num?)?.toDouble();
    // Treat the moment the app comes back as "just moved" rather than
    // assuming the whole outage was idle time - a captain who was actually
    // driving with no connection shouldn't get billed as if they'd stopped.
    _openRideLastMovementTime = DateTime.now();
    _openRideTicker?.cancel();
    _openRideTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      _persistOpenRideProgress();
      notifyListeners();
    });
  }

  TripStatus _mapDbTripStatus(String? dbStatus) {
    switch (dbStatus) {
      case 'arrived':
        return TripStatus.arrived;
      case 'in_progress':
      case 'boarded':
        return TripStatus.started;
      default:
        return TripStatus.accepted;
    }
  }

  // Reflects an edit made from CaptainEditInfoScreen locally, without a
  // full re-login: the display name shown in the drawer/profile header.
  void updateCaptainDisplayName(String name) {
    if (name.isEmpty) return;
    _captainName = name;
    notifyListeners();
  }

  // Reflects a vehicle-category change made from CaptainEditInfoScreen
  // locally - both car and motorcycle captains can have delivery mode on,
  // so this no longer needs to reset it.
  void updateVehicleCategoryLocally(String vehicleType) {
    _vehicleCategory = vehicleType == 'motorcycle' ? 'motorcycle' : 'car';
    notifyListeners();
  }

  // Any captain (car or motorcycle) can opt in/out of delivery requests.
  // For a motorcycle captain this is the *only* kind of request they'll
  // ever receive; for a car captain it's on top of their normal passenger
  // rides - see _maybeShowNextPendingRide.
  void toggleDeliveryMode() {
    _deliveryModeEnabled = !_deliveryModeEnabled;
    notifyListeners();
    if (_userId != null) {
      AuthRepository().setAcceptsDelivery(_userId!, _deliveryModeEnabled);
    }
  }

  void logout() {
    _isLoggedIn = false;
    _userId = null;
    _captainEmail = '';
    _vehicleCategory = 'car';
    _deliveryModeEnabled = false;
    _activeTrip = null;
    _isSearching = false;
    _isCaptainOnline = false;
    _countdownTimer?.cancel();
    _unsubscribeFromPendingRides();
    _openRideTicker?.cancel();
    _openRideStartTime = null;
    _openRideLastMovementTime = null;
    _openRideAccumulatedIdleSeconds = 0.0;
    _openRideDistanceKm = 0.0;
    _openRideLastLat = null;
    _openRideLastLng = null;
    _onlinePresenceSub?.cancel();
    _onlinePresenceSub = null;
    notifyListeners();
    AuthRepository().signOut().catchError((_) {});
  }

  // Captain Switch Online/Offline. Returns null on success or an Arabic
  // reason string when the toggle is refused (currently: trying to go
  // online with an empty wallet, since the platform commission would put
  // the wallet into the negative on the very first accepted trip).
  String? toggleCaptainOnline() {
    final goingOnline = !_isCaptainOnline;
    if (goingOnline && _captainWalletBalance <= 0) {
      return 'يجب شحن محفظتك أولًا قبل الاتصال واستقبال الطلبات.';
    }
    _isCaptainOnline = goingOnline;
    if (!_isCaptainOnline) {
      _incomingRequest = null;
      _countdownTimer?.cancel();
      _unsubscribeFromPendingRides();
    } else {
      _subscribeToPendingRides();
    }
    if (_userId != null) {
      AuthRepository().setCaptainOnline(_userId!, _isCaptainOnline);
    }
    _syncOnlinePresenceTracking();
    notifyListeners();
    return null;
  }

  // Starts/stops the online-presence foreground tracking to match the
  // current state: should run only while online with no active trip. Safe
  // to call from anywhere online status or activeTrip might have changed -
  // it's a no-op if already in the right state.
  void _syncOnlinePresenceTracking() {
    final shouldTrack = _isCaptainOnline && _activeTrip == null;
    if (shouldTrack && _onlinePresenceSub == null) {
      _startOnlinePresenceTracking();
    } else if (!shouldTrack && _onlinePresenceSub != null) {
      _onlinePresenceSub?.cancel();
      _onlinePresenceSub = null;
    }
  }

  Future<void> _startOnlinePresenceTracking() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      // A caller may have gone offline (or accepted a trip) while
      // permissions were being requested above.
      if (!_isCaptainOnline || _activeTrip != null) return;

      final isAndroid =
          !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
      final LocationSettings locationSettings = isAndroid
          ? AndroidSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 50,
              foregroundNotificationConfig: const ForegroundNotificationConfig(
                notificationTitle: 'الهدهد',
                notificationText: 'متصل الآن - بانتظار الطلبات',
                enableWakeLock: true,
              ),
            )
          : const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 50);

      _onlinePresenceSub =
          Geolocator.getPositionStream(locationSettings: locationSettings).listen((
            position,
          ) {
            final uid = _userId;
            if (uid == null) return;
            _myLat = position.latitude;
            _myLng = position.longitude;
            Supabase.instance.client
                .from('captain_locations')
                .upsert({
                  'captain_id': uid,
                  'lat': position.latitude,
                  'lng': position.longitude,
                  'heading': position.heading,
                  'updated_at': DateTime.now().toIso8601String(),
                })
                .catchError((_) {});
            // A ride may have been skipped earlier for lacking a location
            // fix to compare against (or the captain has simply moved
            // closer to one since) - re-evaluate now that it's fresh.
            _maybeShowNextPendingRide();
          });
    } catch (_) {
      // No GPS available; presence tracking just doesn't start.
    }
  }

  // Used when a captain accepts a ride browsed from the open trips list.
  // Open rides have no destination: the customer didn't specify one, and the
  // final fare is metered live once the trip starts (see openRideFare).
  void requestTrip({
    required String customerName,
    required String customerPhone,
    required String pickup,
    String? destination,
    required double pickupLat,
    required double pickupLng,
    double? destLat,
    double? destLng,
    required double distance,
    required int duration,
    required double price,
    required VehicleType carType,
    required bool isOpenRide,
    required int timeoutSeconds,
    required String paymentMethod,
  }) {
    _isSearching = true;
    _countdownSeconds = timeoutSeconds;

    _activeTrip = Trip(
      id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
      customerName: customerName,
      customerPhone: customerPhone,
      pickupLocation: pickup,
      destinationLocation: destination,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      destLat: destLat,
      destLng: destLng,
      distance: distance,
      duration: duration,
      price: price,
      paymentMethod: paymentMethod,
      status: TripStatus.searching,
      carType: carType,
      isOpenRide: isOpenRide,
      openRideTimeout: timeoutSeconds,
      date: DateTime.now().toString().substring(0, 16),
    );

    notifyListeners();

    // Start countdown timer
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 0) {
        _countdownSeconds--;
        notifyListeners();

        // Auto-accept trip simulation at 35 seconds (10s passed) if the countdown is running
        if (timeoutSeconds - _countdownSeconds == 8) {
          _simulateCaptainAccepted();
        }
      } else {
        // Countdown expired without acceptance
        timer.cancel();
        _isSearching = false;
        if (_activeTrip != null &&
            _activeTrip!.status == TripStatus.searching) {
          _activeTrip!.status = TripStatus.pending; // Expired/Pending
        }
        notifyListeners();
      }
    });
  }

  // Simulator helper: marks the just-requested open ride as accepted
  void _simulateCaptainAccepted() {
    _countdownTimer?.cancel();
    _isSearching = false;
    if (_activeTrip != null) {
      _activeTrip = Trip(
        id: _activeTrip!.id,
        customerName: _activeTrip!.customerName,
        customerPhone: _activeTrip!.customerPhone,
        captainName: _captainName,
        captainPhone: _captainPhone,
        vehicleName: _captainVehicleName,
        vehiclePlate: _captainVehiclePlate,
        pickupLocation: _activeTrip!.pickupLocation,
        destinationLocation: _activeTrip!.destinationLocation,
        pickupLat: _activeTrip!.pickupLat,
        pickupLng: _activeTrip!.pickupLng,
        destLat: _activeTrip!.destLat,
        destLng: _activeTrip!.destLng,
        distance: _activeTrip!.distance,
        duration: _activeTrip!.duration,
        price: _activeTrip!.price,
        paymentMethod: _activeTrip!.paymentMethod,
        status: TripStatus.accepted,
        carType: _activeTrip!.carType,
        isOpenRide: _activeTrip!.isOpenRide,
        openRideTimeout: _activeTrip!.openRideTimeout,
        date: _activeTrip!.date,
      );
      notifyListeners();

      // Simulate the captain's progress toward pickup:
      // accepted -> enRoute (after 4s) -> arrived (after 9s)
      Timer(const Duration(seconds: 4), () {
        if (_activeTrip != null && _activeTrip!.status == TripStatus.accepted) {
          _activeTrip!.status = TripStatus.enRoute;
          notifyListeners();
        }
      });

      Timer(const Duration(seconds: 9), () {
        if (_activeTrip != null && _activeTrip!.status == TripStatus.enRoute) {
          _activeTrip!.status = TripStatus.arrived;
          notifyListeners();
        }
      });
    }
  }

  // Captain Trip Booking Lifecycle (real incoming requests while online,
  // sourced live from the `trips` table via Supabase Realtime - this is
  // the table the customer app actually writes to; `rides` is unused).
  void _subscribeToPendingRides() {
    _pendingRidesSubscription?.cancel();
    _pendingRidesSubscription = Supabase.instance.client
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('status', 'searching')
        .order('requested_at', ascending: true)
        .listen((rows) {
          _lastPendingRides = rows;
          // The request currently ringing may have just left 'searching'
          // (the customer cancelled it, it expired, or another captain
          // claimed it first) - this stream only ever lists rows still
          // 'searching', so its disappearance is exactly that signal.
          // Without this check the alert would keep ringing indefinitely
          // for a request that no longer exists.
          final incoming = _incomingRequest;
          if (incoming != null &&
              incoming.isRemote &&
              !rows.any((r) => r['id'] == incoming.id)) {
            _countdownTimer?.cancel();
            NewTripAlert.stop();
            _incomingRequest = null;
            notifyListeners();
          }
          _maybeShowNextPendingRide();
        });
  }

  void _unsubscribeFromPendingRides() {
    _pendingRidesSubscription?.cancel();
    _pendingRidesSubscription = null;
    _lastPendingRides = [];
    _ignoredRideIds.clear();
  }

  bool _isIgnoredByMe(Map<String, dynamic> row) {
    final ignoredBy = row['ignored_by'];
    final uid = _userId;
    if (uid == null || ignoredBy is! List) return false;
    return ignoredBy.contains(uid);
  }

  void _maybeShowNextPendingRide() {
    if (!_isCaptainOnline || _activeTrip != null || _incomingRequest != null) {
      return;
    }
    for (final row in _lastPendingRides) {
      final id = row['id'] as String;
      final serviceType = row['service_type'] as String? ?? 'ride';
      final isDelivery = serviceType == 'delivery';
      // A motorcycle captain only ever receives delivery requests, and
      // only once they've opted in - never regular passenger rides. A car
      // captain always receives regular rides, plus delivery requests too
      // once they've opted in via the same toggle.
      if (isMotorcycleCaptain) {
        if (!isDelivery || !_deliveryModeEnabled) continue;
      } else if (isDelivery && !_deliveryModeEnabled) {
        continue;
      }
      // Only surface requests within _pendingRideRadiusMeters of the
      // captain's last known position - without a fix yet to compare
      // against, skip rather than show a request that might actually be
      // far away (a fresh fix re-triggers this check, see
      // _startOnlinePresenceTracking's listener).
      final myLat = _myLat;
      final myLng = _myLng;
      final pickupLat = (row['pickup_lat'] as num?)?.toDouble();
      final pickupLng = (row['pickup_lng'] as num?)?.toDouble();
      if (myLat == null || myLng == null || pickupLat == null || pickupLng == null) {
        continue;
      }
      final distanceMeters = Geolocator.distanceBetween(
        myLat,
        myLng,
        pickupLat,
        pickupLng,
      );
      if (distanceMeters > _pendingRideRadiusMeters) continue;
      if (row['captain_id'] == null &&
          !_ignoredRideIds.contains(id) &&
          !_isIgnoredByMe(row)) {
        _showPendingRide(row);
        return;
      }
    }
  }

  Future<void> _showPendingRide(Map<String, dynamic> row) async {
    final String tripId = row['id'] as String;
    String customerName = 'زبون جديد';
    String customerPhone = '';
    if (row['customer_id'] != null) {
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('full_name, phone')
            .eq('id', row['customer_id'])
            .single();
        final name = profile['full_name'] as String?;
        final phone = profile['phone'] as String?;
        if (name != null && name.isNotEmpty) customerName = name;
        if (phone != null && phone.isNotEmpty) customerPhone = phone;
      } catch (_) {
        // Fall back to the generic label if the profile can't be read.
      }
    }
    // Guest customers (no account) have their number on the trip itself.
    if (customerPhone.isEmpty) {
      final guestPhone = row['guest_customer_phone'] as String?;
      if (guestPhone != null && guestPhone.isNotEmpty) {
        customerPhone = guestPhone;
      }
    }

    final serviceType = row['service_type'] as String? ?? 'ride';
    final isDelivery = serviceType == 'delivery';
    String? packageDescription;
    if (isDelivery) {
      // A delivery's contact is the recipient, not the sender - reuse the
      // same customerName/customerPhone fields the call/chat UI already
      // reads, so nothing downstream needs to know the difference.
      final recipientName = row['recipient_name'] as String?;
      final recipientPhone = row['recipient_phone'] as String?;
      if (recipientName != null && recipientName.isNotEmpty) {
        customerName = recipientName;
      }
      if (recipientPhone != null && recipientPhone.isNotEmpty) {
        customerPhone = recipientPhone;
      }
      packageDescription = row['package_description'] as String?;
    }

    // The captain may have gone offline, or picked up another trip, while
    // the profile lookup above was in flight.
    if (!_isCaptainOnline || _activeTrip != null || _incomingRequest != null) {
      return;
    }

    final pickupLat = (row['pickup_lat'] as num).toDouble();
    final pickupLng = (row['pickup_lng'] as num).toDouble();
    final destLat = (row['destination_lat'] as num?)?.toDouble();
    final destLng = (row['destination_lng'] as num?)?.toDouble();
    final isOpenRide = row['trip_type'] == 'open';

    double distanceKm = (row['distance_km'] as num?)?.toDouble() ?? 0.0;
    if (distanceKm == 0.0 && destLat != null && destLng != null) {
      distanceKm =
          Geolocator.distanceBetween(pickupLat, pickupLng, destLat, destLng) /
          1000;
    }
    int durationMin = (row['estimated_duration_minutes'] as num?)?.toInt() ?? 0;
    if (durationMin == 0) {
      // No routing engine available: roughly estimate 2 minutes per km.
      durationMin = (distanceKm * 2).round().clamp(1, 999);
    }
    final price = (row['estimated_price'] as num?)?.toDouble() ?? 0.0;
    final paymentMethod = row['payment_method'] == 'wallet'
        ? 'محفظة الهدهد'
        : 'نقداً';
    final vehicleType = switch (row['vehicle_type']) {
      'comfort' => VehicleType.comfort,
      'family' => VehicleType.family,
      _ => VehicleType.economy,
    };

    _countdownSeconds = 45;
    _incomingRequest = Trip(
      id: tripId,
      customerName: customerName,
      customerPhone: customerPhone,
      pickupLocation: row['pickup_address'] as String? ?? 'موقع الانطلاق',
      destinationLocation: row['destination_address'] as String?,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      destLat: destLat,
      destLng: destLng,
      distance: distanceKm,
      duration: durationMin,
      price: isOpenRide ? openRideMinimumFare : price,
      paymentMethod: paymentMethod,
      status: TripStatus.searching,
      carType: vehicleType,
      isOpenRide: isOpenRide,
      openRideTimeout: 45,
      date: DateTime.now().toString().substring(0, 16),
      isRemote: true,
      serviceType: serviceType,
      packageDescription: packageDescription,
    );
    notifyListeners();
    NewTripAlert.play(
      customerName: customerName,
      pickup: _incomingRequest!.pickupLocation,
    );

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 0) {
        _countdownSeconds--;
        notifyListeners();
      } else {
        timer.cancel();
        if (_incomingRequest?.id == tripId) {
          NewTripAlert.stop();
          _ignoredRideIds.add(tripId);
          _markIgnoredOnServer(row);
          _incomingRequest = null;
          notifyListeners();
          _maybeShowNextPendingRide();
        }
      }
    });
  }

  // Appends this captain to the trip's `ignored_by` array so it doesn't
  // resurface for them again, without claiming it for anyone else.
  void _markIgnoredOnServer(Map<String, dynamic> row) {
    final uid = _userId;
    if (uid == null) return;
    final current = (row['ignored_by'] as List?)?.cast<String>() ?? [];
    if (current.contains(uid)) return;
    Supabase.instance.client
        .from('trips')
        .update({
          'ignored_by': [...current, uid],
        })
        .eq('id', row['id'])
        .catchError((_) {});
  }

  // Returns an Arabic error message on failure (e.g. someone else claimed
  // the trip first, or the captain went offline in the meantime) so the UI
  // can show it - null means the trip was accepted successfully.
  Future<String?> acceptIncomingRequest() async {
    _countdownTimer?.cancel();
    NewTripAlert.stop();
    final request = _incomingRequest;
    if (request == null) return null;
    _incomingRequest = null;
    notifyListeners();

    if (request.isRemote) {
      final uid = _userId;
      if (uid == null) return null;
      try {
        // Atomic, server-checked claim: captain_accept_trip() re-verifies
        // the captain is approved/online (and, for a delivery, a motorcycle
        // captain with accepts_delivery on) before handing the trip over -
        // it raises if someone else claimed it first or the captain isn't
        // eligible, either of which just means moving on to the next one.
        await AuthRepository().acceptTrip(request.id);
      } on AppAuthException catch (e) {
        _maybeShowNextPendingRide();
        return e.message;
      } catch (_) {
        _maybeShowNextPendingRide();
        return 'تعذر قبول الطلب، حاول مرة أخرى.';
      }
    }

    _activeTrip = Trip(
      id: request.id,
      customerName: request.customerName,
      customerPhone: request.customerPhone,
      captainName: _captainName,
      captainPhone: _captainPhone,
      vehicleName: _captainVehicleName,
      vehiclePlate: _captainVehiclePlate,
      pickupLocation: request.pickupLocation,
      destinationLocation: request.destinationLocation,
      pickupLat: request.pickupLat,
      pickupLng: request.pickupLng,
      destLat: request.destLat,
      destLng: request.destLng,
      distance: request.distance,
      duration: request.duration,
      price: request.price,
      paymentMethod: request.paymentMethod,
      status: TripStatus.accepted,
      carType: request.carType,
      isOpenRide: request.isOpenRide,
      openRideTimeout: request.openRideTimeout,
      date: request.date,
      isRemote: request.isRemote,
      serviceType: request.serviceType,
      packageDescription: request.packageDescription,
    );
    _syncOnlinePresenceTracking();
    _startStepReminder();
    notifyListeners();
    return null;
  }

  void ignoreIncomingRequest() {
    _countdownTimer?.cancel();
    NewTripAlert.stop();
    if (_incomingRequest != null) {
      final id = _incomingRequest!.id;
      _ignoredRideIds.add(id);
      if (_incomingRequest!.isRemote) {
        final row = _lastPendingRides.cast<Map<String, dynamic>?>().firstWhere(
          (r) => r?['id'] == id,
          orElse: () => null,
        );
        if (row != null) _markIgnoredOnServer(row);
      }
    }
    _incomingRequest = null;
    notifyListeners();
    _maybeShowNextPendingRide();
  }

  void captainArriveAtPickup() {
    if (_activeTrip != null && _activeTrip!.status == TripStatus.accepted) {
      _activeTrip!.status = TripStatus.arrived;
      if (_activeTrip!.isRemote) {
        _updateRemoteTripStatus(
          _activeTrip!.id,
          'arrived',
          extra: {'arrived_at': DateTime.now().toIso8601String()},
        );
      }
      _startStepReminder();
      notifyListeners();
    }
  }

  void captainStartActiveTrip() {
    if (_activeTrip != null && _activeTrip!.status == TripStatus.arrived) {
      _activeTrip!.status = TripStatus.started;
      if (_activeTrip!.isRemote) {
        _updateRemoteTripStatus(
          _activeTrip!.id,
          _activeTrip!.isOpenRide ? 'boarded' : 'in_progress',
          extra: {
            if (_activeTrip!.isOpenRide)
              'boarded_at': DateTime.now().toIso8601String()
            else
              'started_at': DateTime.now().toIso8601String(),
          },
        );
      }
      if (_activeTrip!.isOpenRide) {
        _openRideStartTime = DateTime.now();
        _openRideLastMovementTime = DateTime.now();
        _openRideAccumulatedIdleSeconds = 0.0;
        _openRideDistanceKm = 0.0;
        _openRideLastLat = null;
        _openRideLastLng = null;
        _openRideTicker?.cancel();
        // Just ticks notifyListeners() every second so the live fare/time
        // display keeps updating while stationary - openRideFare and
        // openRideMeterElapsed compute their own values from timestamps.
        _openRideTicker = Timer.periodic(const Duration(seconds: 1), (_) {
          _persistOpenRideProgress();
          notifyListeners();
        });
      }
      _startStepReminder();
      notifyListeners();
    }
  }

  // The captain enters what was actually collected from the customer in
  // cash, which may differ from the estimated fare shown during the trip.
  void captainCompleteActiveTrip({required double amountPaid}) {
    if (_activeTrip != null &&
        _activeTrip!.status == TripStatus.started &&
        !_activeTrip!.isOpenRide) {
      if (_activeTrip!.isRemote) {
        _updateRemoteTripStatus(
          _activeTrip!.id,
          'completed',
          extra: {
            'completed_at': DateTime.now().toIso8601String(),
            'final_price': amountPaid,
          },
        );
      }
      _stopStepReminder();
      _finalizeCompletedTrip(amountPaid);
    }
  }

  // Fire-and-forget: keeps the customer app's copy of the trip in sync.
  // Local captain state has already moved on by the time this resolves, so
  // failures here don't need to roll anything back - just log and continue.
  // 'completed'/'cancelled' get a few retries: if that write never lands
  // (e.g. a connectivity drop at the exact moment the captain ends the
  // trip) the row is stuck looking active forever, and restoreActiveTripIfAny()
  // would keep bringing the same already-finished trip back on every future
  // app launch - worth a bit of extra effort to avoid.
  void _updateRemoteTripStatus(
    String tripId,
    String status, {
    Map<String, dynamic>? extra,
    int attempt = 0,
  }) {
    final isTerminal = status == 'completed' || status == 'cancelled';
    Supabase.instance.client
        .from('trips')
        .update({'status': status, ...?extra})
        .eq('id', tripId)
        .catchError((_) {
          if (isTerminal && attempt < 4) {
            Future.delayed(Duration(seconds: 3 * (attempt + 1)), () {
              _updateRemoteTripStatus(
                tripId,
                status,
                extra: extra,
                attempt: attempt + 1,
              );
            });
          }
        });
  }

  void _startStepReminder() {
    _stepReminderTicker?.cancel();
    _tripStepStartedAt = DateTime.now();
    _stepReminderTicker = Timer.periodic(const Duration(minutes: 2), (_) {
      final trip = _activeTrip;
      if (trip == null ||
          trip.status == TripStatus.completed ||
          trip.status == TripStatus.cancelled) {
        _stopStepReminder();
        return;
      }
      // While actually driving to the destination, don't nag to finish the
      // trip before the estimated trip time has even passed - only "did you
      // arrive"/"did the customer board" steps should chase every 2 minutes
      // regardless of estimate, since those should happen quickly.
      if (trip.status == TripStatus.started && !trip.isOpenRide) {
        final elapsed = _tripStepStartedAt == null
            ? Duration.zero
            : DateTime.now().difference(_tripStepStartedAt!);
        if (elapsed < Duration(minutes: trip.duration)) return;
      }
      NewTripAlert.playStepReminder(_stepReminderMessage());
    });
  }

  void _stopStepReminder() {
    _stepReminderTicker?.cancel();
    _stepReminderTicker = null;
    _tripStepStartedAt = null;
  }

  String _stepReminderMessage() {
    final trip = _activeTrip;
    if (trip == null) return 'لا تنسَ إكمال خطوات المشوار الحالي.';
    final isDelivery = trip.isDelivery;
    switch (trip.status) {
      case TripStatus.accepted:
        return isDelivery
            ? 'لا تنسَ التوجه إلى نقطة الاستلام وتحديث حالة الطلب.'
            : 'لا تنسَ التوجه إلى نقطة الانطلاق وتحديث حالة الطلب.';
      case TripStatus.arrived:
        return isDelivery
            ? 'اضغط "تم استلام الطرد" لمتابعة التوصيل.'
            : 'اضغط "بدء الرحلة الجارية" لمتابعة المشوار.';
      case TripStatus.started:
        return isDelivery
            ? 'اضغط "تم التسليم" فور تسليم الطرد للزبون.'
            : 'اضغط "إنهاء الرحلة بنجاح" فور الوصول للوجهة.';
      default:
        return 'لا تنسَ إكمال خطوات المشوار الحالي.';
    }
  }

  // Ends an open ride: there's no destination to arrive at, so the captain
  // decides when it's over and the fare is whatever the live meter shows.
  void captainCompleteOpenRide({
    double distanceKm = 0,
    required double amountPaid,
  }) {
    if (_activeTrip != null &&
        _activeTrip!.status == TripStatus.started &&
        _activeTrip!.isOpenRide) {
      final elapsedMinutes = (openRideElapsed.inSeconds / 60.0).round();
      if (_activeTrip!.isRemote) {
        _updateRemoteTripStatus(
          _activeTrip!.id,
          'completed',
          extra: {
            'completed_at': DateTime.now().toIso8601String(),
            'final_price': amountPaid,
            'traveled_distance_km': distanceKm,
          },
        );
      }
      _activeTrip = Trip(
        id: _activeTrip!.id,
        customerName: _activeTrip!.customerName,
        customerPhone: _activeTrip!.customerPhone,
        captainName: _activeTrip!.captainName,
        captainPhone: _activeTrip!.captainPhone,
        captainAvatar: _activeTrip!.captainAvatar,
        vehicleName: _activeTrip!.vehicleName,
        vehiclePlate: _activeTrip!.vehiclePlate,
        pickupLocation: _activeTrip!.pickupLocation,
        destinationLocation: _activeTrip!.destinationLocation,
        pickupLat: _activeTrip!.pickupLat,
        pickupLng: _activeTrip!.pickupLng,
        destLat: _activeTrip!.destLat,
        destLng: _activeTrip!.destLng,
        distance: distanceKm,
        duration: elapsedMinutes,
        price: _activeTrip!.price,
        paymentMethod: _activeTrip!.paymentMethod,
        status: _activeTrip!.status,
        carType: _activeTrip!.carType,
        isOpenRide: _activeTrip!.isOpenRide,
        openRideTimeout: _activeTrip!.openRideTimeout,
        date: _activeTrip!.date,
        isRemote: _activeTrip!.isRemote,
        serviceType: _activeTrip!.serviceType,
        packageDescription: _activeTrip!.packageDescription,
      );
      _stopStepReminder();
      _finalizeCompletedTrip(amountPaid);
      _openRideTicker?.cancel();
      _openRideTicker = null;
      _openRideStartTime = null;
      _openRideLastMovementTime = null;
      _openRideAccumulatedIdleSeconds = 0.0;
      _openRideDistanceKm = 0.0;
      _openRideLastLat = null;
      _openRideLastLng = null;
    }
  }

  void _finalizeCompletedTrip(double price) {
    _activeTrip!.status = TripStatus.completed;

    // Calculate earnings (90% net, 10% commission)
    double commission = double.parse((price * 0.10).toStringAsFixed(1));
    double net = price - commission;
    String destinationLabel = _activeTrip!.destinationLocation ?? 'مشوار مفتوح';

    Trip finishedTrip = Trip(
      id: _activeTrip!.id,
      customerName: _activeTrip!.customerName,
      customerPhone: _activeTrip!.customerPhone,
      pickupLocation: _activeTrip!.pickupLocation,
      destinationLocation: _activeTrip!.destinationLocation,
      pickupLat: _activeTrip!.pickupLat,
      pickupLng: _activeTrip!.pickupLng,
      destLat: _activeTrip!.destLat,
      destLng: _activeTrip!.destLng,
      distance: _activeTrip!.distance,
      duration: _activeTrip!.duration,
      price: price,
      paymentMethod: _activeTrip!.paymentMethod,
      status: TripStatus.completed,
      carType: _activeTrip!.carType,
      isOpenRide: _activeTrip!.isOpenRide,
      openRideTimeout: _activeTrip!.openRideTimeout,
      date: _activeTrip!.date,
      netEarnings: net,
      commission: commission,
      isRemote: _activeTrip!.isRemote,
      serviceType: _activeTrip!.serviceType,
      packageDescription: _activeTrip!.packageDescription,
    );

    _captainTripHistory.insert(0, finishedTrip);

    // The captain collects the full fare directly (cash, or the customer's
    // own payment method) - the app never holds it. The captain's own
    // الهدهد wallet only tracks what they owe the company, so completing a
    // trip deducts the commission from it rather than crediting anything;
    // "today's earnings" still reflects their real net profit for display.
    _captainWalletBalance -= commission;
    _captainTodayEarnings += net;
    _captainTripsCount += 1;

    _captainTransactions.insert(
      0,
      WalletTransaction(
        id: 'tx_comm_${DateTime.now().millisecondsSinceEpoch}',
        amount: commission,
        type: TransactionType.commission,
        title: 'عمولة رحلة إلى $destinationLabel',
        date: DateTime.now().toString().substring(0, 16),
        isCredit: false,
      ),
    );

    notifyListeners();
  }

  // Captain cancels an already-accepted trip (before or during it), with a
  // reason recorded for the trip history.
  void captainCancelActiveTrip(String reason) {
    if (_activeTrip == null) return;

    if (_activeTrip!.isRemote) {
      _updateRemoteTripStatus(
        _activeTrip!.id,
        'cancelled',
        extra: {
          'cancelled_at': DateTime.now().toIso8601String(),
          'cancelled_by': 'captain',
          'cancellation_reason': reason,
        },
      );
    }

    final cancelledTrip = Trip(
      id: _activeTrip!.id,
      customerName: _activeTrip!.customerName,
      customerPhone: _activeTrip!.customerPhone,
      captainName: _activeTrip!.captainName,
      captainPhone: _activeTrip!.captainPhone,
      captainAvatar: _activeTrip!.captainAvatar,
      vehicleName: _activeTrip!.vehicleName,
      vehiclePlate: _activeTrip!.vehiclePlate,
      pickupLocation: _activeTrip!.pickupLocation,
      destinationLocation: _activeTrip!.destinationLocation,
      pickupLat: _activeTrip!.pickupLat,
      pickupLng: _activeTrip!.pickupLng,
      destLat: _activeTrip!.destLat,
      destLng: _activeTrip!.destLng,
      distance: _activeTrip!.distance,
      duration: _activeTrip!.duration,
      price: _activeTrip!.price,
      paymentMethod: _activeTrip!.paymentMethod,
      status: TripStatus.cancelled,
      carType: _activeTrip!.carType,
      isOpenRide: _activeTrip!.isOpenRide,
      openRideTimeout: _activeTrip!.openRideTimeout,
      date: _activeTrip!.date,
      cancellationReason: reason,
      isRemote: _activeTrip!.isRemote,
      serviceType: _activeTrip!.serviceType,
      packageDescription: _activeTrip!.packageDescription,
    );

    _captainTripHistory.insert(0, cancelledTrip);

    _activeTrip = null;
    _isSearching = false;
    _countdownTimer?.cancel();
    _stopStepReminder();
    _openRideTicker?.cancel();
    _openRideTicker = null;
    _openRideStartTime = null;
    _openRideLastMovementTime = null;
    _openRideAccumulatedIdleSeconds = 0.0;
    _openRideDistanceKm = 0.0;
    _openRideLastLat = null;
    _openRideLastLng = null;
    _syncOnlinePresenceTracking();
    notifyListeners();

    // Ready for the next request if still online
    _maybeShowNextPendingRide();
  }

  void confirmCaptainSummary() {
    _activeTrip = null;
    _syncOnlinePresenceTracking();
    notifyListeners();
    // Ready for next request if online
    _maybeShowNextPendingRide();
  }

  // Reflects a successful WalletRepository.redeemGiftCredits() call: the
  // redemption itself already happened server-side, this just updates the
  // locally-tracked wallet balance/history to match.
  void creditWalletFromGiftRedemption(double amount) {
    _captainWalletBalance += amount;
    _captainTransactions.insert(
      0,
      WalletTransaction(
        id: 'tx_gift_${DateTime.now().millisecondsSinceEpoch}',
        amount: amount,
        type: TransactionType.reward,
        title: 'تحويل من مكافأتي',
        date: DateTime.now().toString().substring(0, 16),
        isCredit: true,
      ),
    );
    notifyListeners();
  }

  // Reflects a successful WalletRepository.submitRechargeRequest() Bpay
  // call: the wallet was already credited server-side (see
  // credit_captain_wallet_from_bpay), this just updates the locally-tracked
  // balance/history to match, the same way gift redemption does above.
  void creditWalletFromBpayRecharge(double amount) {
    _captainWalletBalance += amount;
    _captainTransactions.insert(
      0,
      WalletTransaction(
        id: 'tx_bpay_${DateTime.now().millisecondsSinceEpoch}',
        amount: amount,
        type: TransactionType.charge,
        title: 'شحن رصيد عبر Bpay',
        date: DateTime.now().toString().substring(0, 16),
        isCredit: true,
      ),
    );
    notifyListeners();
  }

  // Messaging / Chatting with the customer on the active trip
  void sendChatMessage(String content) {
    final newMessage = Message(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: 'cap_1',
      senderName: _captainName,
      content: content,
      time: 'الآن',
      isMe: true,
    );
    _chatMessages.add(newMessage);
    notifyListeners();

    // Mock an automatic reply from the customer after 2 seconds
    Timer(const Duration(seconds: 2), () {
      final replyMessage = Message(
        id: 'msg_rep_${DateTime.now().millisecondsSinceEpoch}',
        senderId: 'cust_1',
        senderName: _activeTrip?.customerName ?? 'الزبون',
        content: 'بإذن الله، أنا في مكان الاتفاق.',
        time: 'الآن',
        isMe: false,
      );
      _chatMessages.add(replyMessage);
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pendingRidesSubscription?.cancel();
    _openRideTicker?.cancel();
    _stepReminderTicker?.cancel();
    super.dispose();
  }
}
