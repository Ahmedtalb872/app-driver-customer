import '../constants/fare_config.dart';

/// Breakdown of an open trip's live/final fare, computed from [FareConfig].
class FareBreakdown {
  final double baseFare;
  final double distanceFare;
  final double timeFare;
  final double waitingFare;
  final double subtotal;
  final double total;

  const FareBreakdown({
    required this.baseFare,
    required this.distanceFare,
    required this.timeFare,
    required this.waitingFare,
    required this.subtotal,
    required this.total,
  });
}

class FareCalculator {
  const FareCalculator._();

  /// fare = baseFare + (distanceKm * pricePerKm) + (movingMinutes * pricePerMinute)
  /// + (waitingMinutes * waitingPricePerMinute), floored at [FareConfig.minimumFare].
  static FareBreakdown calculate({
    required double distanceKm,
    required Duration movingDuration,
    required Duration waitingDuration,
  }) {
    final distanceFare = distanceKm * FareConfig.pricePerKm;
    final timeFare =
        (movingDuration.inSeconds / 60.0) * FareConfig.pricePerMinute;
    final waitingFare =
        (waitingDuration.inSeconds / 60.0) * FareConfig.waitingPricePerMinute;
    final subtotal =
        FareConfig.baseFare + distanceFare + timeFare + waitingFare;
    final total = subtotal < FareConfig.minimumFare
        ? FareConfig.minimumFare
        : subtotal;

    return FareBreakdown(
      baseFare: FareConfig.baseFare,
      distanceFare: distanceFare,
      timeFare: timeFare,
      waitingFare: waitingFare,
      subtotal: subtotal,
      total: total,
    );
  }
}
