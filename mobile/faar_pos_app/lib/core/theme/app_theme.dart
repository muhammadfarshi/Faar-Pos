import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// FAAR POS — Citrus Zest Design System Theme
/// A vibrant, high-contrast, professional design theme engineered for high-throughput
/// commercial checkout, cafes, restaurants, grocery markets, and retail terminals.
class FaarPosTheme {
  // Brand & Accent Colors (Citrus Zest Palette)
  static const kPrimary = Color(0xFFFF6D1F); // Zesty Clementine Orange
  static const kPrimaryVariant = Color(0xFFE65100); // Deep Citrus Amber
  static const kAccentYellow = Color(0xFFF9D857); // Lemon Zest Gold
  static const kSuccess = Color(0xFF10B981); // Fresh Lime Green (Settled/Stocked)
  static const kWarning = Color(0xFFF59E0B); // Amber Yellow (Low Stock/Hold)
  static const kDanger = Color(0xFFEF4444); // Grapefruit Crimson (Voids/Errors)
  static const kPromo = Color(0xFF8B5CF6); // Zest Purple (Discounts/Coupons)

  // Surface & Neutral Layering (Dark Mode)
  static const kBackground = Color(0xFF0F1015);
  static const kSurface = Color(0xFF181920);
  static const kSurfaceElevated = Color(0xFF22242D);
  static const kCardBorder = Color(0xFF2B2D38);
  static const kDivider = Color(0xFF262832);

  // Text & Content
  static const kTextPrimary = Color(0xFFF9FAFB);
  static const kTextSecondary = Color(0xFF9CA3AF);

  // Light Mode Surfaces (Optional Fresh Cafe mode)
  static const kLightBackground = Color(0xFFF8F9FC);
  static const kLightSurface = Color(0xFFFFFFFF);
  static const kLightSurfaceElevated = Color(0xFFF1F3F9);
  static const kLightCardBorder = Color(0xFFE5E7EB);
  static const kLightDivider = Color(0xFFE5E7EB);
  static const kLightTextPrimary = Color(0xFF111827);
  static const kLightTextSecondary = Color(0xFF6B7280);

  /// Default Citrus Zest Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: kBackground,
      colorScheme: const ColorScheme.dark(
        primary: kPrimary,
        primaryContainer: kPrimaryVariant,
        secondary: kPrimary,
        secondaryContainer: Color(0xFF332014),
        surface: kSurface,
        surfaceContainerHighest: kSurfaceElevated,
        error: kDanger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: kTextPrimary,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.dark().textTheme.copyWith(
          displayLarge: GoogleFonts.jetBrainsMono(color: kTextPrimary, fontWeight: FontWeight.bold),
          displayMedium: GoogleFonts.jetBrainsMono(color: kTextPrimary, fontWeight: FontWeight.bold),
          displaySmall: GoogleFonts.jetBrainsMono(color: kTextPrimary, fontWeight: FontWeight.bold),
          headlineLarge: GoogleFonts.plusJakartaSans(color: kTextPrimary, fontWeight: FontWeight.bold),
          headlineMedium: GoogleFonts.plusJakartaSans(color: kTextPrimary, fontWeight: FontWeight.bold),
          headlineSmall: GoogleFonts.plusJakartaSans(color: kTextPrimary, fontWeight: FontWeight.w600),
          titleLarge: GoogleFonts.plusJakartaSans(color: kTextPrimary, fontWeight: FontWeight.bold),
          titleMedium: GoogleFonts.plusJakartaSans(color: kTextPrimary, fontWeight: FontWeight.w600),
          titleSmall: GoogleFonts.plusJakartaSans(color: kTextPrimary, fontWeight: FontWeight.w600),
          bodyLarge: GoogleFonts.plusJakartaSans(color: kTextPrimary, fontWeight: FontWeight.w500),
          bodyMedium: GoogleFonts.plusJakartaSans(color: kTextPrimary),
          bodySmall: GoogleFonts.plusJakartaSans(color: kTextSecondary),
          labelLarge: GoogleFonts.plusJakartaSans(color: kTextPrimary, fontWeight: FontWeight.w600),
          labelMedium: GoogleFonts.jetBrainsMono(color: kTextSecondary),
          labelSmall: GoogleFonts.jetBrainsMono(color: kTextSecondary),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: kSurface,
        foregroundColor: kTextPrimary,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: kDivider, width: 1)),
      ),
      cardTheme: CardThemeData(
        color: kSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: kCardBorder),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: kPrimary,
          side: const BorderSide(color: kPrimary, width: 1.5),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: kPrimary,
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kCardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kCardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kPrimary, width: 2),
        ),
        labelStyle: const TextStyle(color: kTextSecondary),
        hintStyle: const TextStyle(color: kTextSecondary),
      ),
      listTileTheme: const ListTileThemeData(
        tileColor: kSurface,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: kSurfaceElevated,
        selectedColor: kPrimary.withValues(alpha: 0.2),
        checkmarkColor: kPrimary,
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: kCardBorder),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: kSurface,
        selectedItemColor: kPrimary,
        unselectedItemColor: kTextSecondary,
      ),
      dividerTheme: const DividerThemeData(
        color: kDivider,
        thickness: 1,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: kSurfaceElevated,
        contentTextStyle: GoogleFonts.plusJakartaSans(color: kTextPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: kCardBorder),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      tabBarTheme: const TabBarThemeData(
        indicatorColor: kPrimary,
        unselectedLabelColor: kTextSecondary,
        labelColor: kPrimary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: kSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: kCardBorder),
        ),
      ),
    );
  }

  /// Citrus Zest Light Theme (Optional Daytime / Cafe mode)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: kLightBackground,
      colorScheme: const ColorScheme.light(
        primary: kPrimary,
        primaryContainer: kPrimaryVariant,
        secondary: kPrimary,
        surface: kLightSurface,
        surfaceContainerHighest: kLightSurfaceElevated,
        error: kDanger,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: kLightTextPrimary,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(
        ThemeData.light().textTheme.copyWith(
          displayLarge: GoogleFonts.jetBrainsMono(color: kLightTextPrimary, fontWeight: FontWeight.bold),
          displayMedium: GoogleFonts.jetBrainsMono(color: kLightTextPrimary, fontWeight: FontWeight.bold),
          displaySmall: GoogleFonts.jetBrainsMono(color: kLightTextPrimary, fontWeight: FontWeight.bold),
          headlineLarge: GoogleFonts.plusJakartaSans(color: kLightTextPrimary, fontWeight: FontWeight.bold),
          headlineMedium: GoogleFonts.plusJakartaSans(color: kLightTextPrimary, fontWeight: FontWeight.bold),
          headlineSmall: GoogleFonts.plusJakartaSans(color: kLightTextPrimary, fontWeight: FontWeight.w600),
          titleLarge: GoogleFonts.plusJakartaSans(color: kLightTextPrimary, fontWeight: FontWeight.bold),
          titleMedium: GoogleFonts.plusJakartaSans(color: kLightTextPrimary, fontWeight: FontWeight.w600),
          bodyLarge: GoogleFonts.plusJakartaSans(color: kLightTextPrimary),
          bodyMedium: GoogleFonts.plusJakartaSans(color: kLightTextPrimary),
          bodySmall: GoogleFonts.plusJakartaSans(color: kLightTextSecondary),
          labelLarge: GoogleFonts.plusJakartaSans(color: kLightTextPrimary, fontWeight: FontWeight.w600),
          labelMedium: GoogleFonts.jetBrainsMono(color: kLightTextSecondary),
          labelSmall: GoogleFonts.jetBrainsMono(color: kLightTextSecondary),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: kLightSurface,
        foregroundColor: kLightTextPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: Border(bottom: BorderSide(color: kLightDivider, width: 1)),
      ),
      cardTheme: CardThemeData(
        color: kLightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: kLightCardBorder),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 50),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}
