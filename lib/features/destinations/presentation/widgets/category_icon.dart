import 'package:flutter/material.dart';

/// Maps a `place_categories.icon_name` value (see the Phase 2 seed file)
/// to a concrete Material icon. Centralized here so the seed data and the
/// UI agree on the same fixed vocabulary of icon names.
IconData iconForCategory(String? iconName) {
  switch (iconName) {
    case 'restaurant':
      return Icons.restaurant_rounded;
    case 'local_cafe':
      return Icons.local_cafe_rounded;
    case 'local_hospital':
      return Icons.local_hospital_rounded;
    case 'medical_services':
      return Icons.medical_services_rounded;
    case 'local_pharmacy':
      return Icons.local_pharmacy_rounded;
    case 'storefront':
      return Icons.storefront_rounded;
    case 'shopping_bag':
      return Icons.shopping_bag_rounded;
    case 'account_balance':
      return Icons.account_balance_rounded;
    case 'school':
      return Icons.school_rounded;
    case 'mosque':
      return Icons.mosque_rounded;
    case 'hotel':
      return Icons.hotel_rounded;
    case 'apartment':
      return Icons.apartment_rounded;
    case 'location_city':
      return Icons.location_city_rounded;
    case 'route':
      return Icons.route_rounded;
    case 'tour':
      return Icons.tour_rounded;
    case 'flight':
      return Icons.flight_rounded;
    case 'directions_boat':
      return Icons.directions_boat_rounded;
    case 'sports_soccer':
      return Icons.sports_soccer_rounded;
    case 'local_gas_station':
      return Icons.local_gas_station_rounded;
    case 'star':
      return Icons.star_rounded;
    case 'holiday_village':
      return Icons.holiday_village_rounded;
    case 'more_horiz':
      return Icons.more_horiz_rounded;
    default:
      return Icons.place_rounded;
  }
}
