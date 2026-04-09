import 'package:flutter/material.dart';

class AppColors {
  static const background = Color(0xFF111318);
  static const surface = Color(0xFF1C1E24);
  static Color accent = const Color(0xFF40C4FF);
  static const textPrimary = Color(0xFFF5F5F5);
  static const textSecondary = Color(0xFFAAAAAA);
  static const textGhost = Color(0xFF555555);
  static const prGold = Color(0xFFFFD700);
  static const divider = Color(0xFF2A2A2A);
  static const error = Color(0xFFCF6679);
}

const List<Color> themeColors = [
  Color(0xFF40C4FF), // Cyan (default)
  Color(0xFF7B68EE), // Medium Slate Blue
  Color(0xFF00FF87), // Spring Green
  Color(0xFFFF006E), // Hot Pink
  Color(0xFFFFBE0B), // Gold
  Color(0xFF8338EC), // Purple
  Color(0xFFFF6B35), // Orange
  Color(0xFFE63946), // Red
  Color(0xFF06FFA5), // Mint
  Color(0xFFFFFFFF), // White
  Color(0xFFEC4899), // Pink
  Color(0xFF14B8A6), // Teal
];

ThemeData buildAppTheme({Color? accentColor}) {
  if (accentColor != null) {
    AppColors.accent = accentColor;
  }
  final accent = AppColors.accent;
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.dark(
      primary: accent,
      secondary: accent,
      surface: AppColors.surface,
      error: AppColors.error,
      onPrimary: AppColors.textPrimary,
      onSecondary: AppColors.textPrimary,
      onSurface: AppColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.zero,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: accent,
      unselectedItemColor: AppColors.textSecondary,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: accent, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textGhost),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: AppColors.textPrimary,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accent),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
      bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 16),
      bodyMedium: TextStyle(color: AppColors.textSecondary, fontSize: 14),
      bodySmall: TextStyle(color: AppColors.textSecondary, fontSize: 12),
      labelLarge: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
    ),
  );
}
