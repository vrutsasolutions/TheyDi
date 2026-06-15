// ─────────────────────────────────────────────────────────────────────────────
// picker_theme_helper.dart
//
// Single source of truth for the light Theme used by ALL showDatePicker()
// and showTimePicker() calls across the TieIn app.
//
// Usage:
//   final picked = await showDatePicker(
//     context: context,
//     ...
//     builder: PickerTheme.wrap,
//   );
//
//   final picked = await showTimePicker(
//     context: context,
//     ...
//     builder: PickerTheme.wrap,
//   );
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PickerTheme {
  PickerTheme._();

  /// Drop-in `builder` for showDatePicker / showTimePicker.
  /// Forces a white background with emerald-green selections and
  /// fully black/dark-grey text — readable on any background.
  static Widget wrap(BuildContext ctx, Widget? child) {
    return Theme(
      data: _lightPickerTheme(ctx),
      child: child!,
    );
  }

  static ThemeData _lightPickerTheme(BuildContext ctx) {
    return Theme.of(ctx).copyWith(
      // ── Color scheme: light, white surface, emerald selections ──────────────
      colorScheme: const ColorScheme.light(
        primary: TheyDiColors.primary,          // selected circle / clock hand
        onPrimary: Colors.white,               // text on selected circle
        surface: Colors.white,                 // dialog background
        onSurface: Colors.black,               // all unselected text/numbers
        secondary: TheyDiColors.primary,
        onSecondary: Colors.white,
        outline: Color(0xFFE5E7EB),            // divider / border
      ),

      // ── Dialog itself ───────────────────────────────────────────────────────
      dialogBackgroundColor: Colors.white,

      // ── Date picker theming ─────────────────────────────────────────────────
      datePickerTheme: DatePickerThemeData(
        backgroundColor: Colors.white,
        headerBackgroundColor: TheyDiColors.primary,
        headerForegroundColor: Colors.white,
        headerHeadlineStyle: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.w700,
        ),
        headerHelpStyle: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
        ),
        // Weekday labels (Mon, Tue …)
        weekdayStyle: const TextStyle(
          color: Color(0xFF4B5563),       // dark grey — clearly visible
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        // All day numbers
        dayStyle: const TextStyle(
          color: Colors.black,
          fontSize: 13,
        ),
        // Selected day circle
        dayBackgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return TheyDiColors.primary;
          }
          if (states.contains(MaterialState.pressed)) {
            return TheyDiColors.primary.withOpacity(0.12);
          }
          return null;
        }),
        // Foreground (text) on day cells
        dayForegroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.disabled)) {
            return const Color(0xFF9CA3AF);   // greyed-out past dates
          }
          if (states.contains(MaterialState.selected)) {
            return Colors.white;               // white on green circle
          }
          return Colors.black;                 // black for all others
        }),
        // "Today" ring
        todayBackgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return TheyDiColors.primary;
          }
          return Colors.transparent;
        }),
        todayForegroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return Colors.white;
          return TheyDiColors.primary;          // emerald today-ring text
        }),
        todayBorder: const BorderSide(
          color: TheyDiColors.primary,
          width: 1.5,
        ),
        // Year/month picker
        yearStyle: const TextStyle(color: Colors.black, fontSize: 13),
        yearForegroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return Colors.white;
          return Colors.black;
        }),
        yearBackgroundColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return TheyDiColors.primary;
          return null;
        }),
        // Range highlight (if ever used)
        rangePickerBackgroundColor: Colors.white,
        rangeSelectionBackgroundColor: TheyDiColors.primary.withOpacity(0.12),
        // Shape
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
      ),

      // ── Time picker theming ─────────────────────────────────────────────────
      timePickerTheme: TimePickerThemeData(
        backgroundColor: Colors.white,
        // Clock dial
        dialBackgroundColor: const Color(0xFFF3F4F6),
        dialHandColor: TheyDiColors.primary,
        dialTextColor: MaterialStateColor.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return Colors.white;
          return Colors.black;
        }),
        // Hour / minute boxes
        hourMinuteColor: MaterialStateColor.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return TheyDiColors.primary;
          }
          return const Color(0xFFF3F4F6);
        }),
        hourMinuteTextColor: MaterialStateColor.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return Colors.white;
          return Colors.black;
        }),
        hourMinuteTextStyle: const TextStyle(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
        // AM/PM toggle
        dayPeriodColor: MaterialStateColor.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return TheyDiColors.primary;
          }
          return const Color(0xFFF3F4F6);
        }),
        dayPeriodTextColor: MaterialStateColor.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return Colors.white;
          return Colors.black;
        }),
        dayPeriodBorderSide: const BorderSide(
          color: Color(0xFFE5E7EB),
        ),
        dayPeriodTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        // "Select time" header text
        helpTextStyle: const TextStyle(
          color: Color(0xFF4B5563),
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
        // Entry mode icon (keyboard icon)
        entryModeIconColor: TheyDiColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
      ),

      // ── Text buttons (Cancel / OK) ──────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: TheyDiColors.primary,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}