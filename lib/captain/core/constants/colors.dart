import 'package:flutter/material.dart';

class AppColors {
  // Brand gold from the الهدهد logo. Text/icons placed on top of a primary
  // fill use darkText (not white) for contrast - gold is too light for white
  // text to read well on. primaryDark is a deeper gold for text/borders/
  // icons sitting on white backgrounds, where the bright primary itself
  // would be too low-contrast.
  static const Color primary = Color(0xFFED9E35);
  static const Color primaryDark = Color(0xFFA6650C);
  static const Color secondary = Color(0xFF14B8A6);
  static const Color accent = Color(0xFFFFC107);
  static const Color background = Color(0xFFF8FAFC);
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
