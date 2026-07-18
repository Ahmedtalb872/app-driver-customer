import 'package:flutter/material.dart';

/// The AL HODHOD admin dashboard palette, extracted from the new logo.
/// This is the *only* palette used anywhere under `lib/admin/` - never mix
/// in `AppColors` (the mobile customer/captain palette) here.
class AdminColors {
  AdminColors._();

  static const Color primary = Color(0xFF0B6E72); // Deep Teal
  static const Color secondary = Color(0xFF128A8D); // Teal
  static const Color accent = Color(0xFFE6A62E); // Gold
  static const Color accentLight = Color(0xFFF5C76A); // Light Gold
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF12343B);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color success = Color(0xFF2E9E59);
  static const Color warning = Color(0xFFE6A62E);
  static const Color error = Color(0xFFD64545);

  static const Color border = Color(0xFFE2E8F0);
  static const Color sidebarBackground = Color(0xFF0B6E72);
  static const Color sidebarSelected = Color(0xFF128A8D);
}
