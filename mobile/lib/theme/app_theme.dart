import 'package:flutter/material.dart';

import 'app_colors.dart';

/// App-wide theme for field use (M3 FE-1): large touch-friendly controls in
/// both languages (M1 FE-4), white cards on a soft background and a teal app
/// bar.
/// - Urdu (default): Urdu letters in Jameel Noori Nastaleeq with taller lines
///   for Nastaliq script. Latin letters and digits inside Urdu screens (names
///   typed in English, IDs, numbers) use the phone's standard Latin font, so
///   they look the same as in English.
/// - English: the phone's standard Latin font with normal line height.
///
/// Right-to-left or left-to-right layout comes from the locale set in [MediQoreApp].
abstract final class AppTheme {
  /// Font family declared in pubspec.yaml for the bundled Urdu font.
  static const String urduFontFamily = 'JameelNooriNastaleeq';

  /// Android's standard Latin font (Roboto), by the name every Android phone
  /// knows it under.
  static const String latinFontFamily = 'sans-serif';

  /// Nastaliq glyphs are taller than Latin ones; extra line height stops
  /// letters from being clipped.
  static const double urduLineHeight = 1.7;

  /// Minimum height for buttons and other tap targets (P0-7: at least 64 dp).
  static const double largeControlHeight = 64;

  /// Corner radius of cards, fields and buttons.
  static const double radius = 14;

  static ThemeData light({bool urdu = true}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.surface,
      outlineVariant: AppColors.border,
    );
    // In Urdu: the phone's Latin font first, then the Urdu font for the letters
    // it does not have. Urdu words come out in Nastaliq; Latin text and digits
    // keep the standard font instead of the Urdu font's own Latin letters.
    final base = ThemeData(
      colorScheme: colorScheme,
      fontFamily: urdu ? latinFontFamily : null,
      fontFamilyFallback: urdu ? const [urduFontFamily] : null,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      scaffoldBackgroundColor: AppColors.background,
    );
    final textTheme = urdu ? _withLineHeight(base.textTheme, urduLineHeight) : base.textTheme;

    // Built from the theme's own label style so buttons keep the language's
    // font: a bare TextStyle here would replace it with the system font.
    final buttonText = textTheme.labelLarge!.copyWith(fontSize: 18, fontWeight: FontWeight.w600);
    const buttonSize = Size(double.infinity, largeControlHeight);
    const buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(radius)));
    const fieldRadius = BorderRadius.all(Radius.circular(12));

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(radius)),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: buttonSize, textStyle: buttonText, shape: buttonShape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          textStyle: buttonText,
          shape: buttonShape,
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.primary),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        constraints: const BoxConstraints(minHeight: 56),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: const OutlineInputBorder(borderRadius: fieldRadius),
        enabledBorder: const OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: Color(0xFFB9C4C1)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: fieldRadius,
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorMaxLines: 3,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        extendedTextStyle: buttonText,
        extendedSizeConstraints: const BoxConstraints.tightFor(height: 56),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
      checkboxTheme: const CheckboxThemeData(visualDensity: VisualDensity.standard),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }

  static TextTheme _withLineHeight(TextTheme t, double height) {
    TextStyle? h(TextStyle? s) => s?.copyWith(height: height);
    return t.copyWith(
      displayLarge: h(t.displayLarge),
      displayMedium: h(t.displayMedium),
      displaySmall: h(t.displaySmall),
      headlineLarge: h(t.headlineLarge),
      headlineMedium: h(t.headlineMedium),
      headlineSmall: h(t.headlineSmall),
      titleLarge: h(t.titleLarge),
      titleMedium: h(t.titleMedium),
      titleSmall: h(t.titleSmall),
      bodyLarge: h(t.bodyLarge),
      bodyMedium: h(t.bodyMedium),
      bodySmall: h(t.bodySmall),
      labelLarge: h(t.labelLarge),
      labelMedium: h(t.labelMedium),
      labelSmall: h(t.labelSmall),
    );
  }
}
