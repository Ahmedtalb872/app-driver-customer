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
