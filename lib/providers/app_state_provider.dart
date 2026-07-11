import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../dummy_data/dummy_data.dart';

class AppStateProvider extends ChangeNotifier {
  // Auth state
  UserType _userType = UserType.customer;
  bool _isLoggedIn = false;
  
  // Profile stats
  String _customerName = DummyData.dummyCustomer.name;
  String _customerPhone = DummyData.dummyCustomer.phone;
  double _customerWalletBalance = 750.0;
  List<WalletTransaction> _customerTransactions = List.from(DummyData.dummyCustomerTransactions);
  List<NotificationModel> _customerNotifications = List.from(DummyData.dummyCustomerNotifications);
  
  // Captain state
  bool _isCaptainOnline = false;
  String _captainName = DummyData.dummyCaptain.user.name;
  String _captainPhone = DummyData.dummyCaptain.user.phone;
  double _captainWalletBalance = 1250.0;
  double _captainTodayEarnings = 425.0;
  int _captainTripsCount = DummyData.dummyCaptain.user.tripsCount;
  List<WalletTransaction> _captainTransactions = List.from(DummyData.dummyCaptainTransactions);
  Map<String, String> _captainDocsStatus = Map.from(DummyData.dummyCaptain.documentsStatus);
  
  // Active Trip states
  Trip? _activeTrip;
  Timer? _countdownTimer;
  int _countdownSeconds = 45;
  bool _isSearching = false;
  
  // Chat state
  List<Message> _chatMessages = List.from(DummyData.dummyMessages);
  
  // Lists of trips
  List<Trip> _customerTripHistory = List.from(DummyData.dummyCustomerTrips);
  List<Trip> _captainTripHistory = List.from(DummyData.dummyCaptainTrips);
  
  // Captain incoming request state (when captain is online, show mock incoming requests)
  Trip? _incomingRequest;
  Timer? _incomingRequestTimer;
  
  // Getters
  UserType get userType => _userType;
  bool get isLoggedIn => _isLoggedIn;
  
  String get customerName => _customerName;
  String get customerPhone => _customerPhone;
  double get customerWalletBalance => _customerWalletBalance;
  List<WalletTransaction> get customerTransactions => _customerTransactions;
  List<NotificationModel> get customerNotifications => _customerNotifications;
  
  bool get isCaptainOnline => _isCaptainOnline;
  String get captainName => _captainName;
  String get captainPhone => _captainPhone;
  double get captainWalletBalance => _captainWalletBalance;
  double get captainTodayEarnings => _captainTodayEarnings;
  int get captainTripsCount => _captainTripsCount;
  List<WalletTransaction> get captainTransactions => _captainTransactions;
  Map<String, String> get captainDocsStatus => _captainDocsStatus;
  
  Trip? get activeTrip => _activeTrip;
  int get countdownSeconds => _countdownSeconds;
  bool get isSearching => _isSearching;
  List<Message> get chatMessages => _chatMessages;
  
  List<Trip> get customerTripHistory => _customerTripHistory;
  List<Trip> get captainTripHistory => _captainTripHistory;
  
  Trip? get incomingRequest => _incomingRequest;

  // Setters & Actions
  void setUserType(UserType type) {
    _userType = type;
    notifyListeners();
  }

  void login(String phone, UserType type) {
    _isLoggedIn = true;
    _userType = type;
    if (type == UserType.customer) {
      _customerPhone = phone;
    } else {
      _captainPhone = phone;
    }
    notifyListeners();
  }

  void registerCustomer(String name, String phone) {
    _customerName = name;
    _customerPhone = phone;
    _isLoggedIn = true;
    _userType = UserType.customer;
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
    _isSearching = false;
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

  // Customer Trip Booking Lifecycle
  void requestTrip({
    required String pickup,
    required String destination,
    required double pickupLat,
    required double pickupLng,
    required double destLat,
    required double destLng,
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
    
    // Create new Trip
    _activeTrip = Trip(
      id: 'trip_${DateTime.now().millisecondsSinceEpoch}',
      customerName: _customerName,
      customerPhone: _customerPhone,
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
        if (_activeTrip != null && _activeTrip!.status == TripStatus.searching) {
          _activeTrip!.status = TripStatus.pending; // Expired/Pending
        }
        notifyListeners();
      }
    });
  }

  void resetSearchTimer(int newTimeout) {
    _isSearching = true;
    _countdownSeconds = newTimeout;
    if (_activeTrip != null) {
      _activeTrip!.status = TripStatus.searching;
    }
    notifyListeners();

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 0) {
        _countdownSeconds--;
        notifyListeners();
        
        // Auto-accept simulation at 5 seconds after reset
        if (newTimeout - _countdownSeconds == 6) {
          _simulateCaptainAccepted();
        }
      } else {
        timer.cancel();
        _isSearching = false;
        if (_activeTrip != null && _activeTrip!.status == TripStatus.searching) {
          _activeTrip!.status = TripStatus.pending;
        }
        notifyListeners();
      }
    });
  }

  void cancelActiveTrip() {
    _countdownTimer?.cancel();
    _isSearching = false;
    if (_activeTrip != null) {
      _activeTrip!.status = TripStatus.cancelled;
      _customerTripHistory.insert(0, _activeTrip!);
      _addCustomerNotification('تم إلغاء الرحلة', 'تم إلغاء طلب رحلتك بنجاح.');
    }
    _activeTrip = null;
    notifyListeners();
  }

  // Simulator helper: Captain accepts ride
  void _simulateCaptainAccepted() {
    _countdownTimer?.cancel();
    _isSearching = false;
    if (_activeTrip != null) {
      _activeTrip = Trip(
        id: _activeTrip!.id,
        customerName: _activeTrip!.customerName,
        customerPhone: _activeTrip!.customerPhone,
        captainName: DummyData.dummyCaptain.user.name,
        captainPhone: DummyData.dummyCaptain.user.phone,
        captainAvatar: DummyData.dummyCaptain.user.avatar,
        vehicleName: '${DummyData.dummyCaptain.vehicle.brand} ${DummyData.dummyCaptain.vehicle.model} ${DummyData.dummyCaptain.vehicle.year}',
        vehiclePlate: DummyData.dummyCaptain.vehicle.plate,
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
      
      _addCustomerNotification('تم قبول رحلتك', 'الكابتن ${_activeTrip!.captainName} في الطريق إليك.');
      notifyListeners();

      // Simulate Captain En Route steps:
      // accepted -> enRoute (after 5s) -> arrived (after 10s) -> started (after 15s)
      Timer(const Duration(seconds: 4), () {
        if (_activeTrip != null && _activeTrip!.status == TripStatus.accepted) {
          _activeTrip!.status = TripStatus.enRoute;
          _addCustomerNotification('الكابتن في الطريق', 'الكابتن ${_activeTrip!.captainName} يقترب من موقعك.');
          notifyListeners();
        }
      });

      Timer(const Duration(seconds: 9), () {
        if (_activeTrip != null && _activeTrip!.status == TripStatus.enRoute) {
          _activeTrip!.status = TripStatus.arrived;
          _addCustomerNotification('وصل الكابتن', 'وصل الكابتن ${_activeTrip!.captainName} إلى موقع الانطلاق.');
          notifyListeners();
        }
      });
    }
  }

  // Customer triggers to advance simulator once captain has arrived
  void customerStartTrip() {
    if (_activeTrip != null && _activeTrip!.status == TripStatus.arrived) {
      _activeTrip!.status = TripStatus.started;
      _addCustomerNotification('تم بدء الرحلة', 'رحلتك إلى ${_activeTrip!.destinationLocation} بدأت الآن. نتمنى لك مشواراً ممتعاً.');
      notifyListeners();
    }
  }

  void customerCompleteTrip() {
    if (_activeTrip != null && _activeTrip!.status == TripStatus.started) {
      _activeTrip!.status = TripStatus.completed;
      _customerTripHistory.insert(0, _activeTrip!);
      
      // Deduct from wallet if wallet payment
      if (_activeTrip!.paymentMethod == 'المحفظة') {
        _customerWalletBalance -= _activeTrip!.price;
        _customerTransactions.insert(
          0,
          WalletTransaction(
            id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
            amount: _activeTrip!.price,
            type: TransactionType.payment,
            title: 'دفع قيمة رحلة إلى ${_activeTrip!.destinationLocation}',
            date: DateTime.now().toString().substring(0, 16),
            isCredit: false,
          ),
        );
      }
      
      _addCustomerNotification('تم إنهاء الرحلة', 'تم الوصول بنجاح. تكلفة الرحلة: ${_activeTrip!.price} أوقية.');
      notifyListeners();
    }
  }

  void submitRating(double stars, String comment, double tip) {
    if (_activeTrip != null) {
      // Add tip if positive
      if (tip > 0) {
        _customerWalletBalance -= tip;
        _customerTransactions.insert(
          0,
          WalletTransaction(
            id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
            amount: tip,
            type: TransactionType.payment,
            title: 'إكرامية للكابتن ${_activeTrip!.captainName}',
            date: DateTime.now().toString().substring(0, 16),
            isCredit: false,
          ),
        );
      }
      _activeTrip = null; // Close active trip flow
      notifyListeners();
    }
  }

  // Captain Trip Booking Lifecycle (When logged in as Captain)
  void _startSimulatedIncomingRequest() {
    _incomingRequestTimer?.cancel();
    _incomingRequestTimer = Timer(const Duration(seconds: 4), () {
      if (_isCaptainOnline && _activeTrip == null && _incomingRequest == null) {
        _countdownSeconds = 45;
        _incomingRequest = Trip(
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
        );
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

  void acceptIncomingRequest() {
    _countdownTimer?.cancel();
    if (_incomingRequest != null) {
      _activeTrip = Trip(
        id: _incomingRequest!.id,
        customerName: _incomingRequest!.customerName,
        customerPhone: _incomingRequest!.customerPhone,
        pickupLocation: _incomingRequest!.pickupLocation,
        destinationLocation: _incomingRequest!.destinationLocation,
        pickupLat: _incomingRequest!.pickupLat,
        pickupLng: _incomingRequest!.pickupLng,
        destLat: _incomingRequest!.destLat,
        destLng: _incomingRequest!.destLng,
        distance: _incomingRequest!.distance,
        duration: _incomingRequest!.duration,
        price: _incomingRequest!.price,
        paymentMethod: _incomingRequest!.paymentMethod,
        status: TripStatus.accepted,
        carType: _incomingRequest!.carType,
        isOpenRide: _incomingRequest!.isOpenRide,
        openRideTimeout: _incomingRequest!.openRideTimeout,
        date: _incomingRequest!.date,
      );
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
    if (_userType == UserType.customer) {
      _customerWalletBalance += amount;
      _customerTransactions.insert(
        0,
        WalletTransaction(
          id: 'tx_rch_${DateTime.now().millisecondsSinceEpoch}',
          amount: amount,
          type: TransactionType.charge,
          title: 'شحن رصيد بواسطة $method',
          date: DateTime.now().toString().substring(0, 16),
          isCredit: true,
        ),
      );
      _addCustomerNotification('تم شحن الرصيد', 'لقد تم إضافة $amount أوقية إلى محفظتك بنجاح عبر $method.');
    } else {
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
    }
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

  void transferBalance(double amount, String phone) {
    if (_userType == UserType.customer) {
      if (_customerWalletBalance >= amount) {
        _customerWalletBalance -= amount;
        _customerTransactions.insert(
          0,
          WalletTransaction(
            id: 'tx_trf_${DateTime.now().millisecondsSinceEpoch}',
            amount: amount,
            type: TransactionType.transfer,
            title: 'تحويل رصيد إلى $phone',
            date: DateTime.now().toString().substring(0, 16),
            isCredit: false,
          ),
        );
        _addCustomerNotification('تم تحويل الرصيد', 'لقد قمت بتحويل $amount أوقية إلى $phone.');
        notifyListeners();
      }
    }
  }

  // Messaging / Chatting
  void sendChatMessage(String content) {
    final newMessage = Message(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: _userType == UserType.customer ? 'cust_1' : 'cap_1',
      senderName: _userType == UserType.customer ? _customerName : _captainName,
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
        senderId: _userType == UserType.customer ? 'cap_1' : 'cust_1',
        senderName: _userType == UserType.customer ? 'سيد محمد ولد بونا' : 'أحمد سالم ولد محمد',
        content: _userType == UserType.customer 
            ? 'تمام يا طيب، أنا متابع معك على الخريطة.'
            : 'بإذن الله، أنا في مكان الاتفاق.',
        time: 'الآن',
        isMe: false,
      );
      _chatMessages.add(replyMessage);
      notifyListeners();
    });
  }

  // Update Captain doc status
  void updateCaptainDoc(String docKey, String newStatus) {
    _captainDocsStatus[docKey] = newStatus;
    notifyListeners();
  }

  // Helper
  void _addCustomerNotification(String title, String body) {
    _customerNotifications.insert(
      0,
      NotificationModel(
        id: 'notif_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        body: body,
        time: 'الآن',
      ),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _incomingRequestTimer?.cancel();
    super.dispose();
  }
}
