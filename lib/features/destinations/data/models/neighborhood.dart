class Neighborhood {
  final String id;
  final String districtId;
  final String nameAr;
  final String? nameFr;
  final double? latitude;
  final double? longitude;
  final bool isActive;

  const Neighborhood({
    required this.id,
    required this.districtId,
    required this.nameAr,
    this.nameFr,
    this.latitude,
    this.longitude,
    this.isActive = true,
  });

  factory Neighborhood.fromJson(Map<String, dynamic> json) {
    return Neighborhood(
      id: json['id'] as String,
      districtId: json['district_id'] as String,
      nameAr: json['name_ar'] as String,
      nameFr: json['name_fr'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'district_id': districtId,
      'name_ar': nameAr,
      'name_fr': nameFr,
      'latitude': latitude,
      'longitude': longitude,
      'is_active': isActive,
    };
  }
}
