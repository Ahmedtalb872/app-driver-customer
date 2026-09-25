import 'place.dart';

/// A single row from the unified `search_destinations` RPC
/// (20260717000035_destination_search.sql). Unlike [Place], this can
/// represent a place, a district, or a neighborhood - [resultType]
/// discriminates which.
enum DestinationResultType { place, district, neighborhood }

class DestinationSuggestion {
  final DestinationResultType resultType;
  final String id;
  final String title;
  final String? subtitle;
  final String? districtId;
  final String? categoryCode;
  final bool isVerified;
  final bool isPopular;
  final double latitude;
  final double longitude;

  const DestinationSuggestion({
    required this.resultType,
    required this.id,
    required this.title,
    this.subtitle,
    this.districtId,
    this.categoryCode,
    this.isVerified = false,
    this.isPopular = false,
    required this.latitude,
    required this.longitude,
  });

  factory DestinationSuggestion.fromJson(Map<String, dynamic> json) {
    return DestinationSuggestion(
      resultType: _typeFromDb(json['result_type'] as String?),
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '',
      subtitle: json['subtitle'] as String?,
      districtId: json['district_id'] as String?,
      categoryCode: json['category_code'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      isPopular: json['is_popular'] as bool? ?? false,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  /// From a [Place] returned by a category-scoped search (search_places) -
  /// used for the "browse by category" fallback when a text/voice search
  /// misses, so both paths return the same suggestion type to the caller.
  /// [categoryCode] isn't on [Place] itself (only categoryId, an internal
  /// uuid) - pass the code of whichever category was actually searched,
  /// since the caller already knows it.
  factory DestinationSuggestion.fromPlace(Place place, {String? categoryCode}) {
    return DestinationSuggestion(
      resultType: DestinationResultType.place,
      id: place.id,
      title: place.displayName,
      subtitle: place.displayAddress,
      districtId: place.districtId,
      categoryCode: categoryCode,
      isVerified: place.isVerified,
      isPopular: place.isPopular,
      latitude: place.latitude,
      longitude: place.longitude,
    );
  }

  /// From a `recent_places` row (fetch_recent_places) - a customer's own
  /// previously-requested destination, shown before they type anything.
  factory DestinationSuggestion.fromRecentPlaceJson(Map<String, dynamic> json) {
    return DestinationSuggestion(
      resultType: DestinationResultType.place,
      id: (json['place_id'] as String?) ?? (json['id'] as String),
      title: json['address'] as String,
      districtId: json['district_id'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  static DestinationResultType _typeFromDb(String? value) {
    switch (value) {
      case 'district':
        return DestinationResultType.district;
      case 'neighborhood':
        return DestinationResultType.neighborhood;
      case 'place':
      default:
        return DestinationResultType.place;
    }
  }

  /// One-line label for a suggestions dropdown row, e.g. "مطعم الوفاء -
  /// تفرغ زينة" for a place or just the name for a district/neighborhood.
  String get displayLabel {
    if (subtitle == null || subtitle!.isEmpty) return title;
    return '$title - $subtitle';
  }
}
