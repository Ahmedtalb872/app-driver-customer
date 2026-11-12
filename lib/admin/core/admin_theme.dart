import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'admin_colors.dart';

/// Material 3 theme for the TRENDE admin dashboard - RTL Arabic,
/// Tajawal font, dark/glass [AdminColors] throughout. `brightness: dark`
/// matters beyond the color values: it's what keeps every stock Material
/// widget that isn't explicitly restyled here (default icon tints, overlay
/// colors, etc.) legible against a dark background instead of assuming a
/// light one.
class AdminTheme {
  AdminTheme._();

  static ThemeData get theme {
    // Registers the real Tajawal font under the 'Tajawal' family name via
    // google_fonts - every TextStyle(fontFamily: 'Tajawal') hardcoded below
    // (and across lib/admin/'s screens) resolves through this same loaded
    // family, so this one call is enough to make it render everywhere.
    final tajawalTextTheme = GoogleFonts.tajawalTextTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    );

    final colorScheme = ColorScheme.fromSeed(
      seedColor: AdminColors.primary,
      brightness: Brightness.dark,
      primary: AdminColors.primary,
      secondary: AdminColors.secondary,
      tertiary: AdminColors.teal,
      surface: AdminColors.surface,
      error: AdminColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AdminColors.background,
      fontFamily: GoogleFonts.tajawal().fontFamily,
      appBarTheme: const AppBarTheme(
        backgroundColor: AdminColors.surface,
        foregroundColor: AdminColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AdminColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
          fontFamily: 'Tajawal',
        ),
      ),
      cardTheme: CardThemeData(
        color: AdminColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AdminColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AdminColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Tajawal',
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AdminColors.textPrimary,
          side: const BorderSide(color: AdminColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AdminColors.primary),
      ),
      iconTheme: const IconThemeData(color: AdminColors.textSecondary),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AdminColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AdminColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AdminColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AdminColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AdminColors.error),
        ),
        hintStyle: const TextStyle(
          color: AdminColors.textSecondary,
          fontFamily: 'Tajawal',
        ),
        labelStyle: const TextStyle(
          color: AdminColors.textSecondary,
          fontFamily: 'Tajawal',
        ),
      ),
      textTheme: tajawalTextTheme.apply(
        bodyColor: AdminColors.textPrimary,
        displayColor: AdminColors.textPrimary,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(AdminColors.surfaceGlass),
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AdminColors.textPrimary,
          fontFamily: 'Tajawal',
        ),
        dataTextStyle: const TextStyle(
          color: AdminColors.textPrimary,
          fontFamily: 'Tajawal',
        ),
        dividerThickness: 0.6,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AdminColors.primary,
        unselectedLabelColor: AdminColors.textSecondary,
        indicatorColor: AdminColors.primary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AdminColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AdminColors.border),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AdminColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AdminColors.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AdminColors.surfaceGlass,
        labelStyle: const TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 12,
          color: AdminColors.textPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AdminColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(color: AdminColors.border),
    );
  }
}
