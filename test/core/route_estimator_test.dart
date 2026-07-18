import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:alhudhud/core/services/route_estimator.dart';

void main() {
  group('HaversineRouteEstimator', () {
    const estimator = HaversineRouteEstimator();

    test('returns null when destination is not set yet', () {
      final result = estimator.estimate(
        pickup: const LatLng(18.0858, -15.9785),
        destination: null,
      );
      expect(result, isNull);
    });

    test('matches the well-known Warsaw -> Rome great-circle distance', () {
      // Commonly used cross-library reference vector for the Haversine
      // formula: Warsaw (52.2296756, 21.0122287) -> Rome (41.8919300,
      // 12.5113300) is ~1315.5 km great-circle.
      final result = estimator.estimate(
        pickup: const LatLng(52.2296756, 21.0122287),
        destination: const LatLng(41.8919300, 12.5113300),
      );

      expect(result, isNotNull);
      expect(result!.distanceKm, closeTo(1315.5, 2.0));
      expect(result.isEstimate, isTrue);
      expect(result.polyline, hasLength(2));
    });

    test('zero distance when pickup equals destination', () {
      const point = LatLng(18.0858, -15.9785);
      final result = estimator.estimate(pickup: point, destination: point);

      expect(result!.distanceKm, closeTo(0, 1e-9));
      expect(result.durationMinutes, 1); // clamped to a 1-minute floor
    });

    test(
      'duration is derived from distance and the configured average speed',
      () {
        const fastEstimator = HaversineRouteEstimator(averageSpeedKmh: 60);
        final result = fastEstimator.estimate(
          pickup: const LatLng(18.0858, -15.9785),
          destination: const LatLng(18.1858, -15.9785), // ~11.1 km north
        );

        expect(result!.distanceKm, closeTo(11.12, 0.1));
        // ~11.12km at 60km/h ~= 11.1 minutes -> rounds to 11.
        expect(result.durationMinutes, 11);
      },
    );
  });
}
