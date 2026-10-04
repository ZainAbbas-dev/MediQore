import 'package:flutter/material.dart';

import 'app_colors.dart';

/// App-wide theme for field use (M3 FE-1): large touch-friendly controls in
/// both languages (M1 FE-4).
/// - Urdu (default): Jameel Noori Nastaleeq with taller lines for Nastaliq script.
/// - English: the phone's standard Latin font with normal line height.
///
/// Right-to-left or left-to-right layout comes from the locale set in [MediQoreApp].
abstract final class AppTheme {
  /// Font family declared in pubspec.yaml once the font file is bundled.
  static const String urduFontFamily = 'JameelNooriNastaleeq';

  /// Nastaliq glyphs are taller than Latin ones; extra line height stops
  /// letters from being clipped.
  static const double urduLineHeight = 1.7;

  /// Minimum height for buttons and other tap targets.
  static const double largeControlHeight = 64;

  static ThemeData light({bool urdu = true}) {
    final colorScheme = ColorScheme.fromSeed(seedColor: AppColors.primary);
    final base = ThemeData(
      colorScheme: colorScheme,
      fontFamily: urdu ? urduFontFamily : null,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );

    // Built from the theme's own label style so buttons keep the language's
    // font: a bare TextStyle here would replace it with the system font.
    final buttonText = base.textTheme.labelLarge!.copyWith(fontSize: 20, height: urdu ? urduLineHeight : null);
    const buttonSize = Size(double.infinity, largeControlHeight);
    const buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12)));

    return base.copyWith(
      textTheme: urdu ? _withLineHeight(base.textTheme, urduLineHeight) : base.textTheme,
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: buttonSize, textStyle: buttonText, shape: buttonShape),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(minimumSize: buttonSize, textStyle: buttonText, shape: buttonShape),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
      checkboxTheme: const CheckboxThemeData(visualDensity: VisualDensity.standard),
      listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
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
