class District {
  final String id;
  final String nameAr;
  final String? nameFr;
  final String code;
  final double? latitude;
  final double? longitude;
  final double mapZoom;
  final bool isActive;

  const District({
    required this.id,
    required this.nameAr,
    this.nameFr,
    required this.code,
    this.latitude,
    this.longitude,
    this.mapZoom = 13,
    this.isActive = true,
  });

  factory District.fromJson(Map<String, dynamic> json) {
    return District(
      id: json['id'] as String,
      nameAr: json['name_ar'] as String,
      nameFr: json['name_fr'] as String?,
      code: json['code'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      mapZoom: (json['map_zoom'] as num?)?.toDouble() ?? 13,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_ar': nameAr,
      'name_fr': nameFr,
      'code': code,
      'latitude': latitude,
      'longitude': longitude,
      'map_zoom': mapZoom,
      'is_active': isActive,
    };
  }
}
