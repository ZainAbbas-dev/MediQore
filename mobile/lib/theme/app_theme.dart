import 'package:flutter/material.dart';

import 'app_colors.dart';

/// App-wide theme for field use (M3 FE-1), in the final design chosen for
/// Phase 1 (P0-7: Clinical Teal, docs/design/phase1-screens.md): large pill
/// buttons, white cards with a soft shadow on a light teal background, a teal
/// header with rounded bottom corners, in both languages (M3 FE-3).
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

  /// Height of the main buttons and other large tap targets (final design: 60 dp).
  static const double largeControlHeight = 60;

  /// Corner radius of cards.
  static const double radius = 20;

  /// Corner radius of input fields.
  static const double fieldRadius = 18;

  /// Corner radius of the bottom of a teal header and the top of a bottom sheet.
  static const double headerRadius = 32;

  static ThemeData light({bool urdu = true}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: AppColors.primaryDark,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      onSurfaceVariant: AppColors.mutedText,
      outline: AppColors.fieldBorder,
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
    const buttonShape = StadiumBorder();
    const fieldCorners = BorderRadius.all(Radius.circular(fieldRadius));

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(headerRadius)),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 2,
        shadowColor: AppColors.shadow,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(radius))),
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
        border: const OutlineInputBorder(borderRadius: fieldCorners),
        enabledBorder: const OutlineInputBorder(
          borderRadius: fieldCorners,
          borderSide: BorderSide(color: AppColors.fieldBorder),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: fieldCorners,
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        errorMaxLines: 3,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        extendedTextStyle: buttonText,
        extendedSizeConstraints: const BoxConstraints.tightFor(height: 58),
        shape: const StadiumBorder(),
        elevation: 4,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(headerRadius))),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
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
