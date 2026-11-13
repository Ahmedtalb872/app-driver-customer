import 'package:flutter/material.dart';

class AppColors {
  // Brand palette - matches the TRENDE logo's green (#006D36, same value
  // as the splash screen's brand text, the launcher icon theme_color, and
  // web/manifest.json). Previously left as the old Al Hodhod teal/gold
  // during the rebrand's first pass (logo/text only) - every screen using
  // these still showed the old colors until this changed.
  static const Color primary = Color(0xFF006D36);
  static const Color primaryDark = Color(0xFF004F27);
  static const Color secondary = Color(0xFF00A651);
  static const Color accent = Color(0xFF1A1A1A);
  static const Color background = Color(0xFFEBEEF2);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color darkText = Color(0xFF0F172A);
  static const Color secondaryText = Color(0xFF64748B);

  static const Color success = Color(0xFF16A34A);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);

  static const Color border = Color(0xFFE2E8F0);
  static const Color shimmerBase = Color(0xFFE2E8F0);
  static const Color shimmerHighlight = Color(0xFFF1F5F9);
}
