import '../datasources/destinations_remote_datasource.dart';
import '../models/place_category.dart';

class CategoriesRepository {
  CategoriesRepository({DestinationsRemoteDataSource? dataSource})
    : _dataSource = dataSource ?? DestinationsRemoteDataSource();

  final DestinationsRemoteDataSource _dataSource;

  Future<List<PlaceCategory>> loadActiveCategories() async {
    final rows = await _dataSource.fetchActiveCategories();
    return rows.map(PlaceCategory.fromJson).toList();
  }

  /// Active categories for [districtId], each annotated with how many
  /// active places exist in that district - powers the category grid's
  /// "N places available" badge and lets the UI disable empty categories.
  Future<List<PlaceCategory>> loadCategoriesWithPlaceCounts(
    String districtId,
  ) async {
    final categories = await loadActiveCategories();
    final counts = await _dataSource.fetchCategoryPlaceCounts(districtId);
    return categories
        .map(
          (category) => category.copyWithPlaceCount(counts[category.id] ?? 0),
        )
        .toList();
  }

  // --- Admin preparation (no UI in Phase 2) --------------------------

  Future<List<PlaceCategory>> adminListAllCategories() async {
    final rows = await _dataSource.fetchAllCategories();
    return rows.map(PlaceCategory.fromJson).toList();
  }

  Future<PlaceCategory> adminAddCategory({
    required String code,
    required String nameAr,
    String? nameFr,
    String? iconName,
    int sortOrder = 0,
  }) async {
    final row = await _dataSource.insertCategory({
      'code': code,
      'name_ar': nameAr,
      'name_fr': nameFr,
      'icon_name': iconName,
      'sort_order': sortOrder,
    });
    return PlaceCategory.fromJson(row);
  }

  Future<PlaceCategory> adminUpdateCategory(
    String id, {
    String? nameAr,
    String? nameFr,
    String? iconName,
    int? sortOrder,
    bool? isActive,
  }) async {
    final payload = <String, dynamic>{
      if (nameAr != null) 'name_ar': nameAr,
      if (nameFr != null) 'name_fr': nameFr,
      if (iconName != null) 'icon_name': iconName,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isActive != null) 'is_active': isActive,
    };
    final row = await _dataSource.updateCategory(id, payload);
    return PlaceCategory.fromJson(row);
  }
}
