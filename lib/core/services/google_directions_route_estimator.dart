import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'route_estimator.dart';

/// Real road-based routing via the Google Directions API - actual distance,
/// duration, and a turn-following polyline instead of
/// [HaversineRouteEstimator]'s straight line. Returns null on any failure
/// (missing/invalid key, no network, no route found, API error) rather than
/// throwing, so callers can fall back to [HaversineRouteEstimator] the same
/// way they already handle a failed price fetch.
///
/// Never attempts the call on web: Google's Directions API doesn't send
/// CORS headers, so a browser-side request would just fail after a real
/// network round trip for nothing - [kIsWeb] short-circuits to null
/// immediately instead.
///
/// Reuses the same Android-restricted Maps SDK key already used natively
/// (see android/app/build.gradle.kts) for this direct REST call too, by
/// attaching the X-Android-Package/X-Android-Cert headers Google's API
/// checks an Android-app-restricted key against - see
/// https://developers.google.com/maps/api-security-best-practices. No
/// separate Directions-specific key or restriction needed, only "Directions
/// API" added to the same key's API restrictions in Google Cloud Console.
class GoogleDirectionsRouteEstimator {
  const GoogleDirectionsRouteEstimator({required this.apiKey});

  final String apiKey;

  // Must match android/app/build.gradle.kts's applicationId and the SHA-1
  // of android/debug.keystore's androiddebugkey (hex, no colons) - both
  // pinned there for the same reason this needs to match them exactly.
  static const _androidPackageName = 'com.alhudhud.customerapp';
  static const _androidCertFingerprint =
      '51506D306A370A799C20DBF26C78D17F291CB7BA';

  Future<RouteEstimate?> estimate({
    required LatLng pickup,
    required LatLng destination,
  }) async {
    if (kIsWeb || apiKey.isEmpty) return null;

    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/directions/json',
        {
          'origin': '${pickup.latitude},${pickup.longitude}',
          'destination': '${destination.latitude},${destination.longitude}',
          'mode': 'driving',
          'key': apiKey,
        },
      );
      final headers = <String, String>{};
      if (Platform.isAndroid) {
        headers['X-Android-Package'] = _androidPackageName;
        headers['X-Android-Cert'] = _androidCertFingerprint;
      }

      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body['status'] != 'OK') return null;

      final routes = body['routes'] as List;
      if (routes.isEmpty) return null;
      final legs = (routes.first as Map<String, dynamic>)['legs'] as List;
      if (legs.isEmpty) return null;
      final leg = legs.first as Map<String, dynamic>;

      final distanceMeters = (leg['distance']['value'] as num).toDouble();
      final durationSeconds = (leg['duration']['value'] as num).toDouble();
      final encodedPolyline =
          (routes.first as Map<String, dynamic>)['overview_polyline']['points']
              as String;

      return RouteEstimate(
        distanceKm: distanceMeters / 1000,
        durationMinutes: (durationSeconds / 60).round().clamp(1, 999),
        polyline: _decodePolyline(encodedPolyline),
        isEstimate: false,
      );
    } catch (_) {
      return null;
    }
  }

  /// Decodes Google's polyline encoding (the same compact algorithm every
  /// Google routing/roads API returns) into a point list.
  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      var shift = 0;
      var result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
