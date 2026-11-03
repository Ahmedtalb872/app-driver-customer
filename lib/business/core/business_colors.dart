import 'package:flutter/material.dart';

/// Palette for the business/institutions portal - deliberately distinct
/// from [AdminColors] (gold/white) so a restaurant owner never mistakes
/// this for the internal admin dashboard. Modeled on the purple SaaS
/// dashboard reference the portal's look was requested to match - never
/// mix `AdminColors` into anything under `lib/business/`.
class BusinessColors {
  BusinessColors._();

  static const Color primary = Color(0xFF6C4FE0);
  static const Color primaryDark = Color(0xFF2E1F6B);
  static const Color accentLight = Color(0xFFEDE8FC);
  static const Color background = Color(0xFFF5F3FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1E1B2E);
  static const Color textSecondary = Color(0xFF7A7390);
  static const Color success = Color(0xFF2E9E59);
  static const Color warning = Color(0xFFE6A62E);
  static const Color error = Color(0xFFD64545);
  static const Color border = Color(0xFFE6E1F5);

  static const Color sidebarBackground = primaryDark;
  static const Color sidebarSelected = Colors.white;
  static const Color sidebarSelectedText = primaryDark;
  static const Color sidebarText = Color(0xFFC9C0F0);
}
