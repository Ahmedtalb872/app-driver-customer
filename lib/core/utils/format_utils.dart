class FormatUtils {
  const FormatUtils._();

  static String duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final mm = m.toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:$mm:$ss';
    }
    return '$mm:$ss';
  }

  static String fare(double amount) => '${amount.round()} أوقية';

  static String km(double amount) => '${amount.toStringAsFixed(2)} كم';
}
