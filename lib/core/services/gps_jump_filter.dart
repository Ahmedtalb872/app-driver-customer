import 'package:geolocator/geolocator.dart';

/// Thresholds used to decide whether a new GPS reading is trustworthy enough
/// to count toward the traveled distance of an open trip.
class GpsFilterConfig {
  const GpsFilterConfig._();

  /// Readings less accurate than this (in meters) are ignored for distance math.
  static const double maxAccuracyMeters = 30.0;

  /// A jump implying a speed above this (m/s, ~162 km/h) is treated as a bad fix.
  static const double maxRealisticSpeedMps = 45.0;

  /// Movement below this (meters) is treated as GPS noise, not real travel.
  static const double minMovementMeters = 2.0;
}

class GpsFilterResult {
  final bool accepted;
  final double distanceDeltaMeters;
  const GpsFilterResult({
    required this.accepted,
    required this.distanceDeltaMeters,
  });
}

/// Filters raw GPS positions so unrealistic jumps and low-accuracy noise
/// never get accumulated into the traveled distance total.
class GpsJumpFilter {
  const GpsJumpFilter._();

  static GpsFilterResult evaluate({
    required Position previous,
    required Position current,
  }) {
    if (current.accuracy > GpsFilterConfig.maxAccuracyMeters) {
      return const GpsFilterResult(accepted: false, distanceDeltaMeters: 0);
    }

    final distanceMeters = Geolocator.distanceBetween(
      previous.latitude,
      previous.longitude,
      current.latitude,
      current.longitude,
    );

    final elapsedSeconds =
        current.timestamp.difference(previous.timestamp).inMilliseconds /
        1000.0;
    if (elapsedSeconds <= 0) {
      return const GpsFilterResult(accepted: false, distanceDeltaMeters: 0);
    }

    final speedMps = distanceMeters / elapsedSeconds;
    if (speedMps > GpsFilterConfig.maxRealisticSpeedMps) {
      return const GpsFilterResult(accepted: false, distanceDeltaMeters: 0);
    }

    if (distanceMeters < GpsFilterConfig.minMovementMeters) {
      return const GpsFilterResult(accepted: true, distanceDeltaMeters: 0);
    }

    return GpsFilterResult(accepted: true, distanceDeltaMeters: distanceMeters);
  }
}
