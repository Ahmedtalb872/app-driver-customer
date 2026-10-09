import 'package:flutter/material.dart';
import '../models/models.dart';

/// Customer-facing app state: session, active trip, wallet display data.
/// The real trip lifecycle (request/accept/arrive/board/end) is driven by
/// [RideRepository] talking to Supabase - this provider only ever mirrors
/// the latest known state for the widgets that render it, following the
/// same `setActiveTripFromBackend`/`applyBackendTripCompletion` bridge
/// pattern the rest of the app already uses for backend-sourced data.
class AppStateProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String _customerName = '';
  String _customerPhone = '';

  double _walletBalance = 0.0;
  List<WalletTransaction> _walletTransactions = [];

  Trip? _activeTrip;
  List<Trip> _tripHistory = [];

  bool get isLoggedIn => _isLoggedIn;
  String get customerName => _customerName;
  String get customerPhone => _customerPhone;

  double get walletBalance => _walletBalance;
  List<WalletTransaction> get walletTransactions => _walletTransactions;

  Trip? get activeTrip => _activeTrip;
  List<Trip> get tripHistory => _tripHistory;

  void login(String phone, {String? fullName}) {
    _isLoggedIn = true;
    _customerPhone = phone;
    if (fullName != null && fullName.trim().isNotEmpty) {
      _customerName = fullName.trim();
    }
    notifyListeners();
  }

  void setCustomerName(String name) {
    _customerName = name;
    notifyListeners();
  }

  void logout() {
    _isLoggedIn = false;
    _customerName = '';
    _customerPhone = '';
    _activeTrip = null;
    _tripHistory = [];
    _walletBalance = 0.0;
    _walletTransactions = [];
    notifyListeners();
  }

  /// Populates [activeTrip] from a just-requested or updated real trip -
  /// used every time [RideRepository.requestTrip]/`watchTrip` produces a
  /// new snapshot, so every screen reading [activeTrip] stays in sync.
  void setActiveTripFromBackend(Trip? trip) {
    _activeTrip = trip;
    notifyListeners();
  }

  /// Moves a just-completed/cancelled trip out of [activeTrip] and into
  /// [tripHistory] for the trips list to show immediately, without waiting
  /// for the next [setTripHistory] refresh from the backend.
  void archiveActiveTrip() {
    if (_activeTrip == null) return;
    _tripHistory = [_activeTrip!, ..._tripHistory];
    _activeTrip = null;
    notifyListeners();
  }

  void setTripHistory(List<Trip> trips) {
    _tripHistory = trips;
    notifyListeners();
  }

  void setWallet({
    required double balance,
    required List<WalletTransaction> transactions,
  }) {
    _walletBalance = balance;
    _walletTransactions = transactions;
    notifyListeners();
  }
}
