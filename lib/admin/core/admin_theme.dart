import 'package:flutter/material.dart';

import 'admin_colors.dart';

/// Material 3 theme for the AL HODHOD admin dashboard - RTL Arabic, Cairo
/// font (matches the mobile app's font so both brands feel related), and
/// exclusively the [AdminColors] palette.
class AdminTheme {
  AdminTheme._();

  static ThemeData get theme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AdminColors.primary,
      brightness: Brightness.light,
      primary: AdminColors.primary,
      secondary: AdminColors.secondary,
      tertiary: AdminColors.accent,
      surface: AdminColors.surface,
      error: AdminColors.error,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AdminColors.background,
      fontFamily: 'Cairo',
      appBarTheme: const AppBarTheme(
        backgroundColor: AdminColors.surface,
        foregroundColor: AdminColors.textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AdminColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
          fontFamily: 'Cairo',
        ),
      ),
      cardTheme: CardThemeData(
        color: AdminColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
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
            fontFamily: 'Cairo',
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AdminColors.primary,
          side: const BorderSide(color: AdminColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AdminColors.primary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AdminColors.background,
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
        labelStyle: const TextStyle(
          color: AdminColors.textSecondary,
          fontFamily: 'Cairo',
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(AdminColors.background),
        headingTextStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AdminColors.textPrimary,
          fontFamily: 'Cairo',
        ),
        dataTextStyle: const TextStyle(
          color: AdminColors.textPrimary,
          fontFamily: 'Cairo',
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AdminColors.primary,
        unselectedLabelColor: AdminColors.textSecondary,
        indicatorColor: AdminColors.primary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AdminColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AdminColors.background,
        labelStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: const DividerThemeData(color: AdminColors.border),
    );
  }
}
