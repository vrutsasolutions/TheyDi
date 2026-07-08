import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:theydi/core/theme/app_theme.dart';

class TheyDiColors {
  TheyDiColors._();
  static const primary = Color(0xFF10B981);
  static const secondary = Color(0xFF34D399);
  static const accent = Color(0xFFD1FAE5);
  static const dark = Color(0xFFFFFFFF);
  static const card = Color(0xFFF9FAFB);
  static const cardLight = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF3F4F6);
  static const textPrimary = Color(0xFF000000);
  static const textSecondary = Color(0xFF4B5563);
  static const textMuted = Color(0xFF9CA3AF);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);
  static const divider = Color(0xFFE5E7EB);
  static const inputFill = Color(0xFFF3F4F6);
  static const overlay = Color(0x0D000000);
  static const gradientPrimary = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const gradientLight = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF3F4F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class TheyDiTextStyles {
  TheyDiTextStyles._();

  static TextStyle get displayLarge => GoogleFonts.inter(
      fontSize: 36, fontWeight: FontWeight.w700,
      color: TheyDiColors.textPrimary, height: 1.15);

  static TextStyle get displayMedium => GoogleFonts.inter(
      fontSize: 28, fontWeight: FontWeight.w700,
      color: TheyDiColors.textPrimary, height: 1.2);

  static TextStyle get displaySmall => GoogleFonts.inter(
      fontSize: 22, fontWeight: FontWeight.w600,
      color: TheyDiColors.textPrimary, height: 1.25);

  static TextStyle get headlineMedium => GoogleFonts.inter(
      fontSize: 18, fontWeight: FontWeight.w600,
      color: TheyDiColors.textPrimary);

  static TextStyle get headlineSmall => GoogleFonts.inter(
      fontSize: 16, fontWeight: FontWeight.w600,
      color: TheyDiColors.textPrimary);

  static TextStyle get bodyLarge => GoogleFonts.roboto(
      fontSize: 16, fontWeight: FontWeight.w400,
      color: TheyDiColors.textPrimary, height: 1.5);

  static TextStyle get bodyMedium => GoogleFonts.roboto(
      fontSize: 14, fontWeight: FontWeight.w400,
      color: TheyDiColors.textPrimary, height: 1.5);

  static TextStyle get bodySmall => GoogleFonts.roboto(
      fontSize: 12, fontWeight: FontWeight.w400,
      color: TheyDiColors.textSecondary, height: 1.4);

  static TextStyle get labelLarge => GoogleFonts.roboto(
      fontSize: 14, fontWeight: FontWeight.w500,
      color: TheyDiColors.textPrimary, letterSpacing: 0.1);

  static TextStyle get labelMedium => GoogleFonts.roboto(
      fontSize: 12, fontWeight: FontWeight.w500,
      color: TheyDiColors.textSecondary, letterSpacing: 0.2);

  static TextStyle get labelSmall => GoogleFonts.roboto(
      fontSize: 11, fontWeight: FontWeight.w500,
      color: TheyDiColors.textMuted, letterSpacing: 0.3);

  static TextStyle get caption => GoogleFonts.roboto(
      fontSize: 11, fontWeight: FontWeight.w400,
      color: TheyDiColors.textMuted, height: 1.4);
}

class TheyDiTheme {
  TheyDiTheme._();

  static ThemeData get dark {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: TheyDiColors.primary,
      onPrimary: Colors.white,
      secondary: TheyDiColors.secondary,
      onSecondary: Colors.white,
      tertiary: TheyDiColors.accent,
      onTertiary: Colors.white,
      error: TheyDiColors.error,
      onError: Colors.white,
      surface: TheyDiColors.card,
      onSurface: TheyDiColors.textPrimary,
      outline: TheyDiColors.divider,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: TheyDiColors.dark,
      appBarTheme: AppBarTheme(
        backgroundColor: TheyDiColors.dark,
        foregroundColor: TheyDiColors.textPrimary,
        iconTheme: const IconThemeData(color: Colors.black),
        actionsIconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TheyDiTextStyles.headlineMedium,
      ),
      cardColor: TheyDiColors.card,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: TheyDiColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize: const Size(double.infinity, 54),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: TheyDiColors.inputFill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TheyDiColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TheyDiColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: TheyDiColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: TheyDiColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: TheyDiColors.error, width: 1.5),
        ),
        hintStyle: TheyDiTextStyles.bodyMedium
            .copyWith(color: TheyDiColors.textMuted),
        prefixIconColor: TheyDiColors.textMuted,
        suffixIconColor: TheyDiColors.textMuted,
      ),
      dividerTheme: const DividerThemeData(
        color: TheyDiColors.divider, thickness: 1, space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: TheyDiColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: TheyDiColors.cardLight,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}