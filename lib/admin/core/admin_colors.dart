import 'package:flutter/material.dart';

/// The AL HODHOD admin dashboard palette - dark, glass-panel aesthetic
/// (deep navy background, translucent frosted cards, a blue/purple/teal
/// accent family) replacing the earlier flat white/gold look, per the
/// reference UI design the dashboard was asked to match. Hudhud's own gold
/// survives as [accent] - used for the sidebar's brand mark and anywhere
/// warning-colored, same dual role it already had before this palette
/// changed. This is the *only* palette used anywhere under `lib/admin/` -
/// never mix in `AppColors` (the mobile customer palette) or
/// `BusinessColors` (the business portal's own, separate palette) here.
class AdminColors {
  AdminColors._();

  static const Color primary = Color(0xFF4C7CFF); // Vivid Blue
  static const Color secondary = Color(0xFF9B6BFF); // Violet
  static const Color teal = Color(0xFF2DD4BF);
  static const Color accent = Color(0xFFE6A62E); // Hudhud Gold
  static const Color accentLight = Color(0xFFF5C76A);

  static const Color background = Color(0xFF090D18);
  static const Color surface = Color(0xFF121A2C);
  // A low-opacity white laid over [surface] (or the glow background) to
  // get the "frosted glass" look together with a BackdropFilter blur - see
  // GlassCard. Not meant to be used as a flat fill on its own.
  static const Color surfaceGlass = Color(0x14FFFFFF);

  static const Color textPrimary = Color(0xFFF5F7FF);
  static const Color textSecondary = Color(0xFF8F9BBD);
  static const Color success = Color(0xFF2ECC8F);
  static const Color warning = Color(0xFFE6A62E);
  static const Color error = Color(0xFFFF5370);

  static const Color border = Color(0x1FFFFFFF);

  static const Color sidebarBackground = Color(0xFF0C1120);
  static const Color sidebarSelected = Color(0x1FFFFFFF);
  static const Color sidebarSelectedText = Color(0xFFFFFFFF);
  static const Color sidebarText = Color(0xFF7E89AC);

  /// Rotation of accent colors for stat-card icon chips/gradients, so a
  /// long grid of cards (the dashboard has 15) doesn't read as one flat
  /// color block - mirrors the reference design's mixed blue/purple/teal/
  /// gold icon chips instead of every card sharing [primary].
  static const List<Color> statAccents = [primary, teal, secondary, accent];
}
