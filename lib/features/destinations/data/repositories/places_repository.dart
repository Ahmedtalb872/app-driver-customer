import '../datasources/destinations_remote_datasource.dart';
import '../models/place.dart';

class PlacesRepository {
  PlacesRepository({DestinationsRemoteDataSource? dataSource})
    : _dataSource = dataSource ?? DestinationsRemoteDataSource();

  final DestinationsRemoteDataSource _dataSource;

  Future<List<Place>> loadByDistrictAndCategory({
    required String districtId,
    required String categoryId,
    int limit = 50,
    int offset = 0,
  }) async {
    final rows = await _dataSource.fetchPlacesByDistrictCategory(
      districtId: districtId,
      categoryId: categoryId,
      limit: limit,
      offset: offset,
    );
    return rows.map(Place.fromJson).toList();
  }

  Future<List<Place>> loadPopularByDistrict({
    required String districtId,
    int limit = 10,
  }) async {
    final rows = await _dataSource.fetchPopularPlacesByDistrict(
      districtId: districtId,
      limit: limit,
    );
    return rows.map(Place.fromJson).toList();
  }

  /// Searches by Arabic/French name or address, optionally scoped to a
  /// district and/or category, with exact/prefix/popular/district ranking
  /// handled server-side by search_places(). [query] may be empty to just
  /// list places matching the filters.
  Future<List<Place>> search({
    required String query,
    String? districtId,
    String? categoryId,
    int limit = 20,
    int offset = 0,
  }) async {
    final rows = await _dataSource.searchPlaces(
      query: query,
      districtId: districtId,
      categoryId: categoryId,
      limit: limit,
      offset: offset,
    );
    return rows.map(Place.fromJson).toList();
  }

  // --- Admin preparation (no UI in Phase 2) --------------------------

  Future<List<Place>> adminListPlaces({
    String? districtId,
    String? categoryId,
  }) async {
    final rows = await _dataSource.fetchAllPlaces(
      districtId: districtId,
      categoryId: categoryId,
    );
    return rows.map(Place.fromJson).toList();
  }

  Future<List<Place>> adminSearchPlaces({
    required String query,
    String? districtId,
    String? categoryId,
  }) {
    return search(
      query: query,
      districtId: districtId,
      categoryId: categoryId,
      limit: 100,
    );
  }

  Future<Place> adminAddOfficialPlace({
    required String districtId,
    String? neighborhoodId,
    required String categoryId,
    required String nameAr,
    String? nameFr,
    String? addressAr,
    String? addressFr,
    required double latitude,
    required double longitude,
    String? googlePlaceId,
    String? phone,
    String? descriptionAr,
    bool isPopular = false,
    String? createdBy,
  }) async {
    final row = await _dataSource.insertPlace({
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
      'created_by': createdBy,
    });
    return Place.fromJson(row);
  }

  Future<Place> adminUpdateOfficialPlace(
    String id, {
    String? nameAr,
    String? nameFr,
    String? addressAr,
    String? addressFr,
    double? latitude,
    double? longitude,
    String? phone,
    String? descriptionAr,
    bool? isPopular,
    String? categoryId,
    String? neighborhoodId,
  }) async {
    final payload = <String, dynamic>{
      if (nameAr != null) 'name_ar': nameAr,
      if (nameFr != null) 'name_fr': nameFr,
      if (addressAr != null) 'address_ar': addressAr,
      if (addressFr != null) 'address_fr': addressFr,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (phone != null) 'phone': phone,
      if (descriptionAr != null) 'description_ar': descriptionAr,
      if (isPopular != null) 'is_popular': isPopular,
      if (categoryId != null) 'category_id': categoryId,
      if (neighborhoodId != null) 'neighborhood_id': neighborhoodId,
    };
    final row = await _dataSource.updatePlace(id, payload);
    return Place.fromJson(row);
  }

  Future<Place> adminVerifyPlace(String id) async {
    final row = await _dataSource.updatePlace(id, {'is_verified': true});
    return Place.fromJson(row);
  }

  Future<Place> adminDeactivatePlace(String id) async {
    final row = await _dataSource.updatePlace(id, {'is_active': false});
    return Place.fromJson(row);
  }

  Future<Place> adminActivatePlace(String id) async {
    final row = await _dataSource.updatePlace(id, {'is_active': true});
    return Place.fromJson(row);
  }

  Future<Map<String, int>> adminGetPlaceUsageStats(String placeId) {
    return _dataSource.fetchPlaceUsageStats(placeId);
  }
}
