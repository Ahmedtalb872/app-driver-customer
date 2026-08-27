import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Fetches a real, road-following route between two points from Google's
/// Directions API - RealMapWidget falls back to a straight line between
/// pickup/destination when this returns null (no network, API error, or
/// the API key doesn't have Directions API enabled yet).
class DirectionsService {
  // Deliberately a separate, unrestricted key from the Maps SDK one used in
  // AndroidManifest.xml/Info.plist/web/index.html - Google's "Android apps"
  // key restriction only works for the native Maps SDK, not REST calls like
  // this one, so this key must stay unrestricted (or IP-restricted) rather
  // than sharing the Android-app-restricted key.
  static const _apiKey = 'AIzaSyCxcJ5UKVOiRyIL3Ra4n2upXE0e9dWvdUM';

  static Future<List<LatLng>?> fetchRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/directions/json', {
      'origin': '$originLat,$originLng',
      'destination': '$destLat,$destLng',
      'mode': 'driving',
      'key': _apiKey,
    });
    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['status'] != 'OK') return null;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;
      final overview = routes.first['overview_polyline'] as Map?;
      final encoded = overview?['points'] as String?;
      if (encoded == null) return null;
      return _decodePolyline(encoded);
    } catch (_) {
      return null;
    }
  }

  // Standard Google encoded-polyline decoding algorithm.
  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    final len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
