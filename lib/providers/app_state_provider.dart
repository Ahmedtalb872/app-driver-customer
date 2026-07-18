import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../dummy_data/dummy_data.dart';
import '../core/services/fare_calculator.dart';

class AppStateProvider extends ChangeNotifier {
  // Auth state
  UserType _userType = UserType.captain;
  bool _isLoggedIn = false;

  // Captain state
  bool _isCaptainOnline = false;
  String _captainName = DummyData.dummyCaptain.user.name;
  String _captainPhone = DummyData.dummyCaptain.user.phone;
  double _captainWalletBalance = 1250.0;
  double _captainTodayEarnings = 425.0;
  int _captainTripsCount = DummyData.dummyCaptain.user.tripsCount;
  List<WalletTransaction> _captainTransactions = List.from(
    DummyData.dummyCaptainTransactions,
  );

  // Active Trip states
  Trip? _activeTrip;
  Timer? _countdownTimer;
  int _countdownSeconds = 45;

  // Chat state
  List<Message> _chatMessages = List.from(DummyData.dummyMessages);

  // Lists of trips
  List<Trip> _captainTripHistory = List.from(DummyData.dummyCaptainTrips);

  // Captain incoming request state (when captain is online, show mock incoming requests)
  Trip? _incomingRequest;
  Timer? _incomingRequestTimer;
  int _incomingRequestCounter = 0;

  // Getters
  UserType get userType => _userType;
  bool get isLoggedIn => _isLoggedIn;

  bool get isCaptainOnline => _isCaptainOnline;
  String get captainName => _captainName;
  String get captainPhone => _captainPhone;
  double get captainWalletBalance => _captainWalletBalance;
  double get captainTodayEarnings => _captainTodayEarnings;
  int get captainTripsCount => _captainTripsCount;
  List<WalletTransaction> get captainTransactions => _captainTransactions;

  Trip? get activeTrip => _activeTrip;
  int get countdownSeconds => _countdownSeconds;
  List<Message> get chatMessages => _chatMessages;

  List<Trip> get captainTripHistory => _captainTripHistory;

  Trip? get incomingRequest => _incomingRequest;

  // ---------------------------------------------------------------------
  // Real-backend bridge methods. `captain_home_screen.dart` now sources
  // incoming requests from `RideRepository` (real Supabase data) instead of
  // the `_startSimulatedIncomingRequest` timers above. These two setters let
  // that real flow populate the same `_activeTrip` slot every existing
  // screen (CaptainActiveTripScreen, OpenTripActiveScreen, summary screens,
  // ...) already reads, without duplicating any of their rendering logic.
  // ---------------------------------------------------------------------

  /// Populates [activeTrip] from a just-accepted real trip. Deliberately
  /// does none of the wallet/timer bookkeeping the simulated methods below
  /// do - a real trip's lifecycle is driven by `RideRepository`/backend RPCs
  /// from here on.
  void setActiveTripFromBackend(Trip trip) {
    _activeTrip = trip;
    notifyListeners();
  }

  /// Records a real Open Trip's server-computed completion (final fare,
  /// commission, net earnings already authoritative from `captain_end_trip`)
  /// into the same trip history / wallet-display fields the simulated flow
  /// already maintains, so the existing wallet/history screens keep working
  /// unchanged for real trips too.
  void applyBackendTripCompletion(Trip completedTrip) {
    _captainTripHistory.insert(0, completedTrip);
    _activeTrip = completedTrip;

    final net = completedTrip.netEarnings ?? 0;
    final commission = completedTrip.commission ?? 0;
    _captainWalletBalance += net;
    _captainTodayEarnings += net;
    _captainTripsCount += 1;

    _captainTransactions.insert(
      0,
      WalletTransaction(
        id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        amount: net,
        type: TransactionType.charge,
        title: 'صافي أرباح مشوار مفتوح من ${completedTrip.pickupLocation}',
        date: DateTime.now().toString().substring(0, 16),
        isCredit: true,
      ),
    );
    _captainTransactions.insert(
      0,
      WalletTransaction(
        id: 'tx_comm_${DateTime.now().millisecondsSinceEpoch}',
        amount: commission,
        type: TransactionType.commission,
        title: 'عمولة مشوار مفتوح من ${completedTrip.pickupLocation}',
        date: DateTime.now().toString().substring(0, 16),
        isCredit: false,
      ),
    );

    notifyListeners();
  }

  // Setters & Actions
  void setUserType(UserType type) {
    _userType = type;
    notifyListeners();
  }

  void login(String phone, UserType type) {
    _isLoggedIn = true;
    _userType = type;
    _captainPhone = phone;
    notifyListeners();
  }

  void registerCaptain(String name, String phone) {
    _captainName = name;
    _captainPhone = phone;
    _isLoggedIn = true;
    _userType = UserType.captain;
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    _activeTrip = null;
    _countdownTimer?.cancel();
    _incomingRequestTimer?.cancel();
    notifyListeners();
  }

  // Captain Switch Online/Offline
  void toggleCaptainOnline() {
    _isCaptainOnline = !_isCaptainOnline;
    if (!_isCaptainOnline) {
      _incomingRequest = null;
      _incomingRequestTimer?.cancel();
    } else {
      // Simulate an incoming request after 5 seconds if online
      _startSimulatedIncomingRequest();
    }
    notifyListeners();
  }

  // Captain Trip Booking Lifecycle (When logged in as Captain)
  void _startSimulatedIncomingRequest() {
    _incomingRequestTimer?.cancel();
    _incomingRequestTimer = Timer(const Duration(seconds: 4), () {
      if (_isCaptainOnline && _activeTrip == null && _incomingRequest == null) {
        _countdownSeconds = 45;
        _incomingRequestCounter++;
        // Alternate between a normal (fixed destination) and an open
        // (destination-unknown) trip so both flows are reachable locally.
        _incomingRequest = _incomingRequestCounter.isOdd
            ? _buildDummyNormalRequest()
            : _buildDummyOpenRequest();
        notifyListeners();

        // Count down for captain accept
        _countdownTimer?.cancel();
        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (_countdownSeconds > 0) {
            _countdownSeconds--;
            notifyListeners();
          } else {
            timer.cancel();
            _incomingRequest = null;
            notifyListeners();
          }
        });
      }
    });
  }

  Trip _buildDummyNormalRequest() {
    return Trip(
      id: 'trip_incoming_${DateTime.now().millisecondsSinceEpoch}',
      customerName: 'فاطمة منت محمد',
      customerPhone: '+22247777777',
      pickupLocation: 'تفرغ زينة (سوبرماركت النخيل)',
      destinationLocation: 'تيارت (كارفور عين الطلح)',
      pickupLat: 18.1065,
      pickupLng: -15.9664,
      destLat: 18.1255,
      destLng: -15.9288,
      distance: 6.8,
      duration: 15,
      price: 220.0,
      paymentMethod: 'نقداً',
      status: TripStatus.searching,
      carType: VehicleType.economy,
      isOpenRide: true,
      openRideTimeout: 45,
      date: DateTime.now().toString().substring(0, 16),
      tripType: TripType.normal,
    );
  }

  Trip _buildDummyOpenRequest() {
    return Trip(
      id: 'trip_incoming_${DateTime.now().millisecondsSinceEpoch}',
      customerName: 'محمد الأمين ولد الشيخ',
      customerPhone: '+22246222222',
      pickupLocation: 'لكصر (كارفور ولد أماه)',
      destinationLocation: '',
      pickupLat: 18.0982,
      pickupLng: -15.9592,
      destLat: 18.0982,
      destLng: -15.9592,
      distance: 0,
      duration: 0,
      price: 0,
      paymentMethod: 'نقداً',
      status: TripStatus.searching,
      carType: VehicleType.economy,
      isOpenRide: false,
      openRideTimeout: 45,
      date: DateTime.now().toString().substring(0, 16),
      tripType: TripType.open,
      driverDistanceToPickupKm: 1.8,
      driverEtaToPickupMinutes: 5,
    );
  }

  void acceptIncomingRequest() {
    _countdownTimer?.cancel();
    if (_incomingRequest != null) {
      _activeTrip = _incomingRequest!.copyWith(status: TripStatus.accepted);
      _incomingRequest = null;
      notifyListeners();
    }
  }

  void ignoreIncomingRequest() {
    _countdownTimer?.cancel();
    _incomingRequest = null;
    notifyListeners();
    // Simulate another request later
    _startSimulatedIncomingRequest();
  }

  void captainArriveAtPickup() {
    if (_activeTrip != null && _activeTrip!.status == TripStatus.accepted) {
      _activeTrip!.status = TripStatus.arrived;
      notifyListeners();
    }
  }

  void captainStartActiveTrip() {
    if (_activeTrip != null && _activeTrip!.status == TripStatus.arrived) {
      _activeTrip!.status = TripStatus.started;
      notifyListeners();
    }
  }

  void captainCompleteActiveTrip() {
    if (_activeTrip != null && _activeTrip!.status == TripStatus.started) {
      _activeTrip!.status = TripStatus.completed;

      // Calculate earnings (85% net, 15% commission)
      double price = _activeTrip!.price;
      double commission = double.parse((price * 0.15).toStringAsFixed(1));
      double net = price - commission;

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
      );

      _captainTripHistory.insert(0, finishedTrip);

      // Update wallet if paid online, or charge commission
      _captainWalletBalance += net;
      _captainTodayEarnings += net;
      _captainTripsCount += 1;

      _captainTransactions.insert(
        0,
        WalletTransaction(
          id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
          amount: net,
          type: TransactionType.charge,
          title: 'صافي أرباح رحلة إلى ${_activeTrip!.destinationLocation}',
          date: DateTime.now().toString().substring(0, 16),
          isCredit: true,
        ),
      );

      _captainTransactions.insert(
        0,
        WalletTransaction(
          id: 'tx_comm_${DateTime.now().millisecondsSinceEpoch}',
          amount: commission,
          type: TransactionType.commission,
          title: 'عمولة رحلة إلى ${_activeTrip!.destinationLocation}',
          date: DateTime.now().toString().substring(0, 16),
          isCredit: false,
        ),
      );

      notifyListeners();
    }
  }

  /// Finalizes an open (destination-unknown) trip using the live meter
  /// numbers computed by [OpenTripController], mirroring the earnings split
  /// used for normal trips. Keeps [_activeTrip] populated (status completed)
  /// so the summary screen can read it, same pattern as [captainCompleteActiveTrip];
  /// it is cleared afterwards by [confirmCaptainSummary].
  void captainCompleteOpenTrip({
    required double distanceKm,
    required Duration movingDuration,
    required Duration waitingDuration,
    required FareBreakdown fare,
    double? finalLat,
    double? finalLng,
  }) {
    if (_activeTrip == null || _activeTrip!.status != TripStatus.started) {
      return;
    }

    final totalMinutes = (movingDuration + waitingDuration).inMinutes;
    final commission = double.parse((fare.total * 0.15).toStringAsFixed(1));
    final net = double.parse((fare.total - commission).toStringAsFixed(1));

    final finishedTrip = _activeTrip!.copyWith(
      status: TripStatus.completed,
      distance: double.parse(distanceKm.toStringAsFixed(2)),
      duration: totalMinutes,
      price: fare.total,
      destinationLocation: (finalLat != null && finalLng != null)
          ? 'الموقع النهائي (${finalLat.toStringAsFixed(4)}, ${finalLng.toStringAsFixed(4)})'
          : 'الموقع النهائي غير محدد',
      netEarnings: net,
      commission: commission,
      baseFareAmount: fare.baseFare,
      distanceFareAmount: fare.distanceFare,
      timeFareAmount: fare.timeFare,
      waitingFareAmount: fare.waitingFare,
      movingSeconds: movingDuration.inSeconds,
      waitingSeconds: waitingDuration.inSeconds,
      finalLat: finalLat,
      finalLng: finalLng,
    );

    _captainTripHistory.insert(0, finishedTrip);
    _activeTrip = finishedTrip;

    _captainWalletBalance += net;
    _captainTodayEarnings += net;
    _captainTripsCount += 1;

    _captainTransactions.insert(
      0,
      WalletTransaction(
        id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        amount: net,
        type: TransactionType.charge,
        title: 'صافي أرباح مشوار مفتوح من ${finishedTrip.pickupLocation}',
        date: DateTime.now().toString().substring(0, 16),
        isCredit: true,
      ),
    );

    _captainTransactions.insert(
      0,
      WalletTransaction(
        id: 'tx_comm_${DateTime.now().millisecondsSinceEpoch}',
        amount: commission,
        type: TransactionType.commission,
        title: 'عمولة مشوار مفتوح من ${finishedTrip.pickupLocation}',
        date: DateTime.now().toString().substring(0, 16),
        isCredit: false,
      ),
    );

    notifyListeners();
  }

  /// Captain-initiated cancellation of the current active trip (normal or
  /// open), used before the trip is completed. Logs it into history as
  /// cancelled and immediately frees the captain up for new requests.
  void captainCancelActiveTrip() {
    if (_activeTrip == null) return;
    final cancelled = _activeTrip!.copyWith(status: TripStatus.cancelled);
    _captainTripHistory.insert(0, cancelled);
    _activeTrip = null;
    notifyListeners();
    if (_isCaptainOnline) {
      _startSimulatedIncomingRequest();
    }
  }

  void confirmCaptainSummary() {
    _activeTrip = null;
    notifyListeners();
    // Ready for next request if online
    if (_isCaptainOnline) {
      _startSimulatedIncomingRequest();
    }
  }

  // Wallet operations
  void rechargeWallet(double amount, String method) {
    _captainWalletBalance += amount;
    _captainTransactions.insert(
      0,
      WalletTransaction(
        id: 'tx_rch_${DateTime.now().millisecondsSinceEpoch}',
        amount: amount,
        type: TransactionType.charge,
        title: 'شحن رصيد الكابتن بواسطة $method',
        date: DateTime.now().toString().substring(0, 16),
        isCredit: true,
      ),
    );
    notifyListeners();
  }

  void withdrawCaptainEarnings(double amount) {
    if (amount <= _captainWalletBalance) {
      _captainWalletBalance -= amount;
      _captainTransactions.insert(
        0,
        WalletTransaction(
          id: 'tx_wdr_${DateTime.now().millisecondsSinceEpoch}',
          amount: amount,
          type: TransactionType.withdraw,
          title: 'سحب رصيد الأرباح إلى Bankily',
          date: DateTime.now().toString().substring(0, 16),
          isCredit: false,
        ),
      );
      notifyListeners();
    }
  }

  // Messaging / Chatting
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

    // Mock an automatic reply from the other side after 2 seconds
    Timer(const Duration(seconds: 2), () {
      final replyMessage = Message(
        id: 'msg_rep_${DateTime.now().millisecondsSinceEpoch}',
        senderId: 'cust_1',
        senderName: 'أحمد سالم ولد محمد',
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
    _incomingRequestTimer?.cancel();
    super.dispose();
  }
}
