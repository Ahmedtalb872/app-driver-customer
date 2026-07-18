import 'package:geolocator/geolocator.dart';

import '../datasources/destinations_remote_datasource.dart';
import '../models/district.dart';

/// Loads/manages [District] rows. Never touched directly by UI widgets -
/// screens depend on this repository, not on Supabase.
class DistrictsRepository {
  DistrictsRepository({DestinationsRemoteDataSource? dataSource})
    : _dataSource = dataSource ?? DestinationsRemoteDataSource();

  final DestinationsRemoteDataSource _dataSource;

  Future<List<District>> loadActiveDistricts() async {
    final rows = await _dataSource.fetchActiveDistricts();
    return rows.map(District.fromJson).toList();
  }

  /// Picks the closest district to [latitude]/[longitude] out of the
  /// currently active ones, or null if no district has coordinates yet.
  /// Used to pre-select a sensible district when the customer drops a pin
  /// on the map before explicitly choosing one.
  District? resolveDistrictFromCoordinates(
    List<District> districts,
    double latitude,
    double longitude,
  ) {
    District? closest;
    double? closestDistanceMeters;

    for (final district in districts) {
      final districtLat = district.latitude;
      final districtLng = district.longitude;
      if (districtLat == null || districtLng == null) continue;

      final distance = Geolocator.distanceBetween(
        latitude,
        longitude,
        districtLat,
        districtLng,
      );

      if (closestDistanceMeters == null || distance < closestDistanceMeters) {
        closest = district;
        closestDistanceMeters = distance;
      }
    }

    return closest;
  }

  // --- Admin preparation (no UI in Phase 2) --------------------------

  Future<List<District>> adminListAllDistricts() async {
    final rows = await _dataSource.fetchAllDistricts();
    return rows.map(District.fromJson).toList();
  }

  Future<District> adminAddDistrict({
    required String nameAr,
    String? nameFr,
    required String code,
    double? latitude,
    double? longitude,
    double mapZoom = 13,
  }) async {
    final row = await _dataSource.insertDistrict({
      'name_ar': nameAr,
      'name_fr': nameFr,
      'code': code,
      'latitude': latitude,
      'longitude': longitude,
      'map_zoom': mapZoom,
    });
    return District.fromJson(row);
  }

  Future<District> adminUpdateDistrict(
    String id, {
    String? nameAr,
    String? nameFr,
    double? latitude,
    double? longitude,
    double? mapZoom,
  }) async {
    final payload = <String, dynamic>{
      if (nameAr != null) 'name_ar': nameAr,
      if (nameFr != null) 'name_fr': nameFr,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (mapZoom != null) 'map_zoom': mapZoom,
    };
    final row = await _dataSource.updateDistrict(id, payload);
    return District.fromJson(row);
  }

  Future<District> adminDeactivateDistrict(String id) async {
    final row = await _dataSource.updateDistrict(id, {'is_active': false});
    return District.fromJson(row);
  }

  Future<District> adminActivateDistrict(String id) async {
    final row = await _dataSource.updateDistrict(id, {'is_active': true});
    return District.fromJson(row);
  }
}
