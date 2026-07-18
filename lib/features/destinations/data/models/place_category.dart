class PlaceCategory {
  final String id;
  final String code;
  final String nameAr;
  final String? nameFr;
  final String? iconName;
  final int sortOrder;
  final bool isActive;

  /// Populated by repositories that also fetch [getCategoryPlaceCounts] -
  /// not a database column, defaults to 0 when unknown.
  final int placeCount;

  const PlaceCategory({
    required this.id,
    required this.code,
    required this.nameAr,
    this.nameFr,
    this.iconName,
    this.sortOrder = 0,
    this.isActive = true,
    this.placeCount = 0,
  });

  factory PlaceCategory.fromJson(Map<String, dynamic> json) {
    return PlaceCategory(
      id: json['id'] as String,
      code: json['code'] as String,
      nameAr: json['name_ar'] as String,
      nameFr: json['name_fr'] as String?,
      iconName: json['icon_name'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name_ar': nameAr,
      'name_fr': nameFr,
      'icon_name': iconName,
      'sort_order': sortOrder,
      'is_active': isActive,
    };
  }

  PlaceCategory copyWithPlaceCount(int count) {
    return PlaceCategory(
      id: id,
      code: code,
      nameAr: nameAr,
      nameFr: nameFr,
      iconName: iconName,
      sortOrder: sortOrder,
      isActive: isActive,
      placeCount: count,
    );
  }
}
