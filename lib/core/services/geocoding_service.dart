import 'dart:convert';

import 'package:http/http.dart' as http;

/// Free, keyless reverse geocoding via OpenStreetMap's public Nominatim
/// API - the same OSM ecosystem this app's map tiles already use (see
/// `map_tile_provider.dart`). Nominatim's usage policy caps public use at
/// roughly 1 request/second and discourages heavy production traffic; this
/// is only ever called on an explicit marker drop/drag, debounced, never
/// per-frame - see `OperatorDispatchScreen._setPickup`/`_setDestination`.
/// If usage ever scales up meaningfully, self-hosting Nominatim (or
/// switching providers) should be reconsidered.
class GeocodingService {
  GeocodingService._();

  static final GeocodingService instance = GeocodingService._();

  static const String _userAgent =
      'HudhudAdminDashboard/1.0 (+https://alhodhod.example)';

  /// Best-effort - returns null on any failure (network, rate limit,
  /// unparseable response) rather than throwing, since this only ever
  /// backs an optional address auto-fill the operator can freely overwrite.
  Future<String?> reverseGeocode(double lat, double lng) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'lat': '$lat',
      'lon': '$lng',
      'zoom': '18',
      'addressdetails': '1',
    });
    try {
      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final displayName = body['display_name'] as String?;
      return (displayName != null && displayName.isNotEmpty)
          ? displayName
          : null;
    } catch (_) {
      return null;
    }
  }
}
