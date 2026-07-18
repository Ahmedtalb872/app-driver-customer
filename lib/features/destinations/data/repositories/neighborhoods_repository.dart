import '../datasources/destinations_remote_datasource.dart';
import '../models/neighborhood.dart';

class NeighborhoodsRepository {
  NeighborhoodsRepository({DestinationsRemoteDataSource? dataSource})
    : _dataSource = dataSource ?? DestinationsRemoteDataSource();

  final DestinationsRemoteDataSource _dataSource;

  Future<List<Neighborhood>> loadByDistrict(String districtId) async {
    final rows = await _dataSource.fetchNeighborhoodsByDistrict(districtId);
    return rows.map(Neighborhood.fromJson).toList();
  }

  // --- Admin preparation (no UI in Phase 2) --------------------------

  Future<List<Neighborhood>> adminListAllNeighborhoods() async {
    final rows = await _dataSource.fetchAllNeighborhoods();
    return rows.map(Neighborhood.fromJson).toList();
  }

  Future<Neighborhood> adminAddNeighborhood({
    required String districtId,
    required String nameAr,
    String? nameFr,
    double? latitude,
    double? longitude,
  }) async {
    final row = await _dataSource.insertNeighborhood({
      'district_id': districtId,
      'name_ar': nameAr,
      'name_fr': nameFr,
      'latitude': latitude,
      'longitude': longitude,
    });
    return Neighborhood.fromJson(row);
  }

  Future<Neighborhood> adminUpdateNeighborhood(
    String id, {
    String? nameAr,
    String? nameFr,
    double? latitude,
    double? longitude,
    bool? isActive,
  }) async {
    final payload = <String, dynamic>{
      if (nameAr != null) 'name_ar': nameAr,
      if (nameFr != null) 'name_fr': nameFr,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (isActive != null) 'is_active': isActive,
    };
    final row = await _dataSource.updateNeighborhood(id, payload);
    return Neighborhood.fromJson(row);
  }
}
