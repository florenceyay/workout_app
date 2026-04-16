import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette values — mutated at runtime via [AppColors.applyBrightness] so
/// widgets that reference them directly (instead of Theme.of) still
/// flip correctly between dark and light mode.
class AppColors {
  // Dark palette (default)
  static const _darkBackground   = Color(0xFF0F1116);
  static const _darkSurface      = Color(0xFF181B22);
  static const _darkSurfaceLight = Color(0xFF1F222B);
  static const _darkTextPrimary  = Color(0xFFF0F0F2);
  static const _darkTextSecondary= Color(0xFF8A8D96);
  static const _darkTextGhost    = Color(0xFF484B54);
  static const _darkDivider      = Color(0xFF232630);

  // Light palette
  static const _lightBackground   = Color(0xFFF6F7F9);
  static const _lightSurface      = Color(0xFFFFFFFF);
  static const _lightSurfaceLight = Color(0xFFECEEF2);
  static const _lightTextPrimary  = Color(0xFF16181D);
  static const _lightTextSecondary= Color(0xFF636872);
  static const _lightTextGhost    = Color(0xFFB4B8C0);
  static const _lightDivider      = Color(0xFFE1E3E8);

  // Mutable fields used throughout the app. Default to dark.
  static Color background    = _darkBackground;
  static Color surface       = _darkSurface;
  static Color surfaceLight  = _darkSurfaceLight;
  static Color textPrimary   = _darkTextPrimary;
  static Color textSecondary = _darkTextSecondary;
  static Color textGhost     = _darkTextGhost;
  static Color divider       = _darkDivider;

  static Color accent = const Color(0xFF40C4FF);

  // Constant accents — these don't change with brightness.
  static const prGold = Color(0xFFFFD700);
  static const error  = Color(0xFFCF6679);

  static void applyBrightness(Brightness b) {
    if (b == Brightness.light) {
      background    = _lightBackground;
      surface       = _lightSurface;
      surfaceLight  = _lightSurfaceLight;
      textPrimary   = _lightTextPrimary;
      textSecondary = _lightTextSecondary;
      textGhost     = _lightTextGhost;
      divider       = _lightDivider;
    } else {
      background    = _darkBackground;
      surface       = _darkSurface;
      surfaceLight  = _darkSurfaceLight;
      textPrimary   = _darkTextPrimary;
      textSecondary = _darkTextSecondary;
      textGhost     = _darkTextGhost;
      divider       = _darkDivider;
    }
  }
}

/// Dark-mode accent palette — vibrant, bright colors that pop on dark bg.
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

/// Light-mode accent palette — rich, dark colours that contrast well
/// against white surfaces and light-grey badges.
const List<Color> lightThemeColors = [
  Color(0xFF1B2A4A), // Deep Navy
  Color(0xFF2D3436), // Charcoal
  Color(0xFF1B4332), // Forest Green
  Color(0xFF6B2737), // Burgundy
  Color(0xFF4A1A6B), // Deep Purple
  Color(0xFF3D5A80), // Slate Blue
  Color(0xFF1A535C), // Dark Teal
  Color(0xFF3E2723), // Espresso
  Color(0xFF9B2335), // Dark Red
  Color(0xFF3730A3), // Indigo
  Color(0xFF9A3412), // Burnt Orange
  Color(0xFF374151), // Steel
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

ThemeData buildAppTheme({Color? accentColor, Brightness brightness = Brightness.dark}) {
  if (accentColor != null) {
    AppColors.accent = accentColor;
  }
  AppColors.applyBrightness(brightness);
  final accent = AppColors.accent;
  final textTheme = _buildTextTheme();
  final isDark = brightness == Brightness.dark;

  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
    colorScheme: (isDark ? ColorScheme.dark : ColorScheme.light)(
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
      labelStyle: TextStyle(color: AppColors.textSecondary),
      hintStyle: TextStyle(color: AppColors.textGhost),
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
    dividerTheme: DividerThemeData(color: AppColors.divider, thickness: 0.5),
    textTheme: textTheme,
  );
}
