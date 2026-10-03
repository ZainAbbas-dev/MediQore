import 'package:flutter/material.dart';

import 'app_colors.dart';

/// App-wide theme for Urdu field use (M3 FE-1): Jameel Noori Nastaleeq,
/// taller lines for Nastaliq script, and large touch-friendly controls.
///
/// Right-to-left layout comes from the Urdu locale set in [MediQoreApp].
abstract final class AppTheme {
  /// Font family declared in pubspec.yaml once the font file is bundled.
  static const String urduFontFamily = 'JameelNooriNastaleeq';

  /// Nastaliq glyphs are taller than Latin ones; extra line height stops
  /// letters from being clipped.
  static const double urduLineHeight = 1.7;

  /// Minimum height for buttons and other tap targets.
  static const double largeControlHeight = 64;

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(seedColor: AppColors.primary);
    final base = ThemeData(
      colorScheme: colorScheme,
      fontFamily: urduFontFamily,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );

    const buttonText = TextStyle(fontSize: 20, height: urduLineHeight);
    const buttonSize = Size(double.infinity, largeControlHeight);
    const buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12)));

    return base.copyWith(
      textTheme: _withLineHeight(base.textTheme, urduLineHeight),
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
