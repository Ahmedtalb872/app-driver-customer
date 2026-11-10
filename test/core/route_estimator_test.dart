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

    test('matches the well-known Warsaw -> Rome great-circle distance, '
        'corrected for road distance', () {
      // Commonly used cross-library reference vector for the Haversine
      // formula: Warsaw (52.2296756, 21.0122287) -> Rome (41.8919300,
      // 12.5113300) is ~1315.5 km great-circle - scaled by the estimator's
      // 1.3x road-distance correction factor (see its doc comment).
      final result = estimator.estimate(
        pickup: const LatLng(52.2296756, 21.0122287),
        destination: const LatLng(41.8919300, 12.5113300),
      );

      expect(result, isNotNull);
      expect(result!.distanceKm, closeTo(1315.5 * 1.3, 3.0));
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

        // Raw great-circle distance (~11.12km) scaled by the 1.3x road
        // correction factor before duration is derived from it.
        expect(result!.distanceKm, closeTo(11.12 * 1.3, 0.15));
        // ~14.46km at 60km/h ~= 14.46 minutes -> rounds to 14.
        expect(result.durationMinutes, 14);
      },
    );

    test('applies a 1.3x road-distance correction to the raw great-circle '
        'line, so the fallback reads closer to an actual road distance '
        'instead of a pure straight-line lower bound', () {
      const fastEstimator = HaversineRouteEstimator(averageSpeedKmh: 60);
      final corrected = fastEstimator.estimate(
        pickup: const LatLng(18.0858, -15.9785),
        destination: const LatLng(18.1858, -15.9785),
      );
      final rawHaversineKm = 11.12;

      expect(corrected!.distanceKm, greaterThan(rawHaversineKm));
      expect(corrected.distanceKm, closeTo(rawHaversineKm * 1.3, 0.15));
    });
  });
}
