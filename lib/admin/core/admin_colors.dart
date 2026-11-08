import 'package:flutter/material.dart';

/// The AL HODHOD admin dashboard palette - dark, glass-panel aesthetic
/// tuned to the actual Hudhud logo mark (deep teal hoopoe/car silhouette +
/// warm gold crest), replacing the earlier blue/violet accent family that
/// didn't relate to the brand mark at all. [primary]/[teal] carry the
/// logo's teal, [secondary]/[accent] carry its gold - every other admin
/// widget pulls hover glows, selection bars and button fills from these
/// four, so retuning them here is enough to re-tint the whole dashboard.
/// This is the *only* palette used anywhere under `lib/admin/` - never mix
/// in `AppColors` (the mobile customer palette) or `BusinessColors` (the
/// business portal's own, separate palette) here.
class AdminColors {
  AdminColors._();

  static const Color primary = Color(0xFF17A398); // Logo teal, brightened
  static const Color secondary = Color(0xFFD98C2B); // Logo gold, deep tone
  static const Color teal = Color(0xFF0E5750); // Logo teal, deep tone
  static const Color accent = Color(0xFFE6A62E); // Hudhud Gold
  static const Color accentLight = Color(0xFFF5C76A);

  static const Color background = Color(0xFF07140F);
  static const Color surface = Color(0xFF112421);
  // A low-opacity white laid over [surface] (or the glow background) to
  // get the "frosted glass" look together with a BackdropFilter blur - see
  // GlassCard. Not meant to be used as a flat fill on its own.
  static const Color surfaceGlass = Color(0x14FFFFFF);

  static const Color textPrimary = Color(0xFFF5F7FF);
  static const Color textSecondary = Color(0xFF93A3A6);
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFE6A62E);
  static const Color error = Color(0xFFFF5370);

  static const Color border = Color(0x1FFFFFFF);

  static const Color sidebarBackground = Color(0xFF0A1917);
  static const Color sidebarSelected = Color(0x1FFFFFFF);
  static const Color sidebarSelectedText = Color(0xFFFFFFFF);
  static const Color sidebarText = Color(0xFF7B8C8E);

  /// Rotation of accent colors for stat-card icon chips/gradients, so a
  /// long grid of cards (the dashboard has 15) doesn't read as one flat
  /// color block - mixes the brand's teal and gold tones instead of every
  /// card sharing [primary].
  static const List<Color> statAccents = [primary, teal, secondary, accent];
}
