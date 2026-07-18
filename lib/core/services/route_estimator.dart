import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// A distance/duration estimate for a pickup -> destination pair, plus the
/// line to draw between them.
///
/// [isEstimate] is always `true` for every [RouteEstimator] implementation
/// in this app today (see [HaversineRouteEstimator]), since none of them
/// call a real routing engine. UI code must surface [isEstimate] to the
/// operator rather than presenting the number as an actual road distance.
class RouteEstimate {
  const RouteEstimate({
    required this.distanceKm,
    required this.durationMinutes,
    required this.polyline,
    this.isEstimate = true,
  });

  final double distanceKm;
  final int durationMinutes;
  final List<LatLng> polyline;
  final bool isEstimate;
}

/// Computes a [RouteEstimate] between two points.
///
/// Swap the implementation - e.g. a future `GoogleDirectionsRouteEstimator`
/// backed by the Google Directions API - to move from the straight-line
/// fallback to real road distance/duration/turn-by-turn polylines without
/// changing any screen that consumes [RouteEstimate].
abstract class RouteEstimator {
  const RouteEstimator();

  /// Returns null when [destination] is null (nothing to estimate yet).
  RouteEstimate? estimate({required LatLng pickup, LatLng? destination});
}

/// Temporary fallback used everywhere in this app: straight-line
/// (great-circle) distance via the Haversine formula, and a duration guess
/// from a flat average city speed. Needs no network call and no API key,
/// so it always works offline - at the cost of not knowing about roads,
/// traffic, or one-way streets. Callers must label results as an estimate.
class HaversineRouteEstimator extends RouteEstimator {
  const HaversineRouteEstimator({this.averageSpeedKmh = 30});

  /// Assumed average travel speed used to turn distance into a duration
  /// guess. 30 km/h approximates mixed city driving.
  final double averageSpeedKmh;

  static const _earthRadiusKm = 6371.0;

  @override
  RouteEstimate? estimate({required LatLng pickup, LatLng? destination}) {
    if (destination == null) return null;
    final distanceKm = _haversineKm(pickup, destination);
    final durationMinutes = ((distanceKm / averageSpeedKmh) * 60).round().clamp(
      1,
      999,
    );
    return RouteEstimate(
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
      polyline: [pickup, destination],
    );
  }

  double _haversineKm(LatLng a, LatLng b) {
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLon = _degToRad(b.longitude - a.longitude);
    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);

    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return _earthRadiusKm * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);
}
