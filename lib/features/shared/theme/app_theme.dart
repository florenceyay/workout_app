import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const background = Color(0xFF0F1116);
  static const surface = Color(0xFF181B22);
  static const surfaceLight = Color(0xFF1F222B); // elevated cards
  static Color accent = const Color(0xFF40C4FF);
  static const textPrimary = Color(0xFFF0F0F2);
  static const textSecondary = Color(0xFF8A8D96);
  static const textGhost = Color(0xFF484B54);
  static const prGold = Color(0xFFFFD700);
  static const divider = Color(0xFF232630);
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

TextTheme _buildTextTheme() {
  final base = GoogleFonts.plusJakartaSansTextTheme();
  return base.copyWith(
    headlineLarge: base.headlineLarge?.copyWith(
        color: AppColors.textPrimary, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
    headlineMedium: base.headlineMedium?.copyWith(
        color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
    titleLarge: base.titleLarge?.copyWith(
        color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2),
    titleMedium: base.titleMedium?.copyWith(
        color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
    bodyLarge: base.bodyLarge?.copyWith(
        color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w400),
    bodyMedium: base.bodyMedium?.copyWith(
        color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w400),
    bodySmall: base.bodySmall?.copyWith(
        color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w400),
    labelLarge: base.labelLarge?.copyWith(
        color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
  );
}

ThemeData buildAppTheme({Color? accentColor}) {
  if (accentColor != null) {
    AppColors.accent = accentColor;
  }
  final accent = AppColors.accent;
  final textTheme = _buildTextTheme();

  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
    colorScheme: ColorScheme.dark(
      primary: accent,
      secondary: accent,
      surface: AppColors.surface,
      error: AppColors.error,
      onPrimary: AppColors.textPrimary,
      onSecondary: AppColors.textPrimary,
      onSurface: AppColors.textPrimary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: EdgeInsets.zero,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: accent,
      unselectedItemColor: AppColors.textGhost,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: accent, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textGhost),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: AppColors.textPrimary,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: accent),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 0.5),
    textTheme: textTheme,
  );
}
