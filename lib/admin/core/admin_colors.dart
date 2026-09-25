import 'package:flutter/material.dart';

/// The AL HODHOD admin dashboard palette - white and gold, matching the
/// logo (the teal is on the car/bird mark only; the wordmark's own accent
/// is gold). Gold carries every primary/brand role here; teal is gone.
/// This is the *only* palette used anywhere under `lib/admin/` - never mix
/// in `AppColors` (the mobile customer/captain palette) here.
class AdminColors {
  AdminColors._();

  static const Color primary = Color(0xFFB8860B); // Deep Gold
  static const Color secondary = Color(0xFFC9A227); // Amber Gold
  static const Color accent = Color(0xFFE6A62E); // Gold
  static const Color accentLight = Color(0xFFF5C76A); // Light Gold
  static const Color background = Color(0xFFFFFCF5);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF2B2013);
  static const Color textSecondary = Color(0xFF8A7B5E);
  static const Color success = Color(0xFF2E9E59);
  static const Color warning = Color(0xFFE6A62E);
  static const Color error = Color(0xFFD64545);

  static const Color border = Color(0xFFEFE4C8);
  static const Color sidebarBackground = Color(0xFFFFFFFF);
  static const Color sidebarSelected = Color(0xFFE6A62E);
  static const Color sidebarSelectedText = Color(0xFF2B2013);
  static const Color sidebarText = Color(0xFF8A7B5E);
}
