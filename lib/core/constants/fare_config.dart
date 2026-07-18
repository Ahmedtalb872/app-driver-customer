/// Single source of truth for open-trip (destination-unknown) fare pricing.
/// Change values here only — never hardcode fare numbers elsewhere.
class FareConfig {
  const FareConfig._();

  /// Flat charge applied to every open trip regardless of distance/time.
  static const double baseFare = 50.0;

  /// Charged per kilometer of distance actually traveled while running.
  static const double pricePerKm = 25.0;

  /// Charged per minute of moving (non-waiting) trip time.
  static const double pricePerMinute = 3.0;

  /// The final fare can never be lower than this, even for very short trips.
  static const double minimumFare = 100.0;

  /// Charged per minute while the driver has waiting mode active.
  static const double waitingPricePerMinute = 2.0;
}
