class Place {
  final String id;
  final String districtId;
  final String? neighborhoodId;
  final String categoryId;
  final String nameAr;
  final String? nameFr;
  final String? addressAr;
  final String? addressFr;
  final double latitude;
  final double longitude;
  final String? googlePlaceId;
  final String? phone;
  final String? descriptionAr;
  final bool isPopular;
  final bool isVerified;
  final bool isActive;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Place({
    required this.id,
    required this.districtId,
    this.neighborhoodId,
    required this.categoryId,
    required this.nameAr,
    this.nameFr,
    this.addressAr,
    this.addressFr,
    required this.latitude,
    required this.longitude,
    this.googlePlaceId,
    this.phone,
    this.descriptionAr,
    this.isPopular = false,
    this.isVerified = false,
    this.isActive = true,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'] as String,
      districtId: json['district_id'] as String,
      neighborhoodId: json['neighborhood_id'] as String?,
      categoryId: json['category_id'] as String,
      nameAr: json['name_ar'] as String,
      nameFr: json['name_fr'] as String?,
      addressAr: json['address_ar'] as String?,
      addressFr: json['address_fr'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      googlePlaceId: json['google_place_id'] as String?,
      phone: json['phone'] as String?,
      descriptionAr: json['description_ar'] as String?,
      isPopular: json['is_popular'] as bool? ?? false,
      isVerified: json['is_verified'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'district_id': districtId,
      'neighborhood_id': neighborhoodId,
      'category_id': categoryId,
      'name_ar': nameAr,
      'name_fr': nameFr,
      'address_ar': addressAr,
      'address_fr': addressFr,
      'latitude': latitude,
      'longitude': longitude,
      'google_place_id': googlePlaceId,
      'phone': phone,
      'description_ar': descriptionAr,
      'is_popular': isPopular,
      'is_verified': isVerified,
      'is_active': isActive,
      'created_by': createdBy,
    };
  }

  /// Best-effort display name/address, preferring Arabic (this app's
  /// primary locale) and falling back to French when Arabic is missing.
  String get displayName => nameAr.isNotEmpty ? nameAr : (nameFr ?? '');
  String? get displayAddress =>
      (addressAr != null && addressAr!.isNotEmpty) ? addressAr : addressFr;
}
