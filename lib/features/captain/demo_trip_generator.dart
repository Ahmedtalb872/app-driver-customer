import '../../models/models.dart';

/// Builds locally-generated trial ride requests for the captain to test the
/// incoming-request flow (ringtone/vibration/countdown/accept/reject) without
/// a real passenger or backend trip row. Only ever surfaced behind
/// `DemoModeConfig.isEnabled` (see the developer menu in
/// `CaptainHomeScreen._buildDrawer`) - never reachable in a release build.
///
/// Every [Trip] here carries [Trip.isDemoTrip] = true and a `trip_demo_...`
/// id, so `CaptainHomeScreen` knows to skip the real `RideRepository`
/// accept/ignore/expire RPCs, and `OpenTripController.isRealTrip` (which only
/// checks for the `trip_` id prefix) treats the metered one exactly like the
/// legacy simulated open-trip flow it already supports.
class DemoTripGenerator {
  DemoTripGenerator._();

  /// How long the captain has to accept before the request auto-expires.
  static const int acceptTimeoutSeconds = 45;

  /// A normal trial ride with a known destination and a fixed upfront price.
  static Trip fixedPriceTrip() {
    final now = DateTime.now();
    return Trip(
      id: 'trip_demo_fixed_${now.millisecondsSinceEpoch}',
      customerName: 'زبون تجريبي',
      customerPhone: '+22200000001',
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
      isOpenRide: false,
      openRideTimeout: acceptTimeoutSeconds,
      date: now.toIso8601String(),
      tripType: TripType.normal,
      requestExpiresAt: now.add(const Duration(seconds: acceptTimeoutSeconds)),
      isDemoTrip: true,
    );
  }

  /// A trial "بالعداد" ride: only a pickup point, no destination - the fare
  /// is metered live once the captain marks the passenger onboard.
  static Trip meterTrip() {
    final now = DateTime.now();
    return Trip(
      id: 'trip_demo_meter_${now.millisecondsSinceEpoch}',
      customerName: 'زبون تجريبي (بالعداد)',
      customerPhone: '+22200000002',
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
      openRideTimeout: acceptTimeoutSeconds,
      date: now.toIso8601String(),
      tripType: TripType.open,
      driverDistanceToPickupKm: 1.8,
      driverEtaToPickupMinutes: 5,
      requestExpiresAt: now.add(const Duration(seconds: acceptTimeoutSeconds)),
      isDemoTrip: true,
    );
  }
}
