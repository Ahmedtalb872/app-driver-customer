import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

/// Backs the Operator Dispatch page: looks up a calling customer by phone,
/// reads live pricing to show an estimated fare, and creates the trip via
/// the `admin_dispatch_trip` RPC (20260713000030_operator_dispatch.sql).
class AdminDispatchRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  /// Finds an existing customer account by phone number. Returns null if no
  /// registered customer has that number - manual dispatch requires the
  /// caller to already have the app (this app has no service-role-backed
  /// account-creation path available to the client, by design - see
  /// docs/admin_web_deployment.md section 3).
  Future<Map<String, dynamic>?> findCustomerByPhone(String phone) async {
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return null;
    return _client
        .from('customers')
        .select('id, status, profiles!inner(full_name, phone)')
        .eq('profiles.phone', trimmed)
        .maybeSingle();
  }

  Future<Map<String, dynamic>?> fetchPricingConfig(String vehicleType) async {
    return _client
        .from('pricing_config')
        .select()
        .eq('vehicle_type', vehicleType)
        .maybeSingle();
  }

  Future<Map<String, dynamic>> dispatchTrip({
    required String customerPhone,
    required String pickupAddress,
    required double pickupLat,
    required double pickupLng,
    required String tripType, // 'normal' | 'open'
    String? destinationAddress,
    double? destinationLat,
    double? destinationLng,
    required String vehicleType,
    required String paymentMethod,
    double? estimatedPrice,
    int? estimatedDurationMinutes,
    double? distanceKm,
    String? customerNote,
    int timeoutSeconds = 300,
    // 'ride' | 'delivery' - see 20260802000048_admin_dispatch_delivery.sql.
    // Only relevant when 'delivery': recipientName/recipientPhone are then
    // required server-side and vehicleType is forced to 'motorcycle'
    // regardless of what's passed above, mirroring
    // customer_request_trip's own delivery branch.
    String serviceType = 'ride',
    String? recipientName,
    String? recipientPhone,
    String? packageDescription,
  }) async {
    // Customer registration is optional (20260718000040_guest_dispatch_trip.sql):
    // if `customerPhone` doesn't match any registered account, the RPC still
    // creates the trip - with no customer_id - and broadcasts it exactly
    // like any other open trip. No CUSTOMER_NOT_FOUND case to special-case
    // here anymore.
    final row = await _client.rpc(
      'admin_dispatch_trip',
      params: {
        'p_customer_phone': customerPhone,
        'p_pickup_address': pickupAddress,
        'p_pickup_lat': pickupLat,
        'p_pickup_lng': pickupLng,
        'p_trip_type': tripType,
        'p_destination_address': destinationAddress,
        'p_destination_lat': destinationLat,
        'p_destination_lng': destinationLng,
        'p_vehicle_type': vehicleType,
        'p_payment_method': paymentMethod,
        'p_estimated_price': estimatedPrice,
        'p_estimated_duration_minutes': estimatedDurationMinutes,
        'p_distance_km': distanceKm,
        'p_customer_note': customerNote,
        'p_timeout_seconds': timeoutSeconds,
        'p_service_type': serviceType,
        'p_recipient_name': recipientName,
        'p_recipient_phone': recipientPhone,
        'p_package_description': packageDescription,
      },
    );
    return Map<String, dynamic>.from(row as Map);
  }
}
