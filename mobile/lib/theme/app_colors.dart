import 'package:flutter/material.dart';

/// Colours shared across the app, from the final design (Clinical Teal, P0-7).
/// Risk colours follow the scope's Green / Yellow / Red classification (M4).
abstract final class AppColors {
  /// Clinical Teal: headers, primary buttons and highlights.
  static const Color primary = Color(0xFF00695C);

  /// Dark teal: text and icons on the light teal, pressed states.
  static const Color primaryDark = Color(0xFF004D40);

  /// Light teal: avatars, icon buttons on white, selected chips.
  static const Color primaryLight = Color(0xFFC8EDE6);

  /// Very light teal: information panels inside a form.
  static const Color primarySoft = Color(0xFFE3F2EF);

  /// Screen background behind the white cards.
  static const Color background = Color(0xFFF1F7F6);

  /// Card and field surfaces.
  static const Color surface = Colors.white;

  /// Main text.
  static const Color text = Color(0xFF17312D);

  /// Dividers inside cards.
  static const Color border = Color(0xFFE4ECEA);

  /// Outline of an input field that does not have focus.
  static const Color fieldBorder = Color(0xFFB9C9C5);

  /// Secondary text: labels, hints, IDs under a name.
  static const Color mutedText = Color(0xFF4F5E5B);

  /// The soft shadow under cards and floating buttons.
  static const Color shadow = Color(0x1F004D40);

  static const Color riskGreen = Color(0xFF2E7D32);
  static const Color riskYellow = Color(0xFFF9A825);
  static const Color riskRed = Color(0xFFC62828);

  /// Text and icon colours that stay readable on each risk colour.
  static const Color onRiskGreen = Colors.white;
  static const Color onRiskYellow = Color(0xFF212121);
  static const Color onRiskRed = Colors.white;

  /// The sync status strip and chips (M3 FE-2): a soft background with a
  /// strong text colour, so the state is clear without alarming the LHW.
  static const Color statusOffline = Color(0xFF455A64);
  static const Color statusOfflineBackground = Color(0xFFE9EEF0);
  static const Color statusPending = Color(0xFF8A4B08);
  static const Color statusPendingBackground = Color(0xFFFFF1DC);
  static const Color statusSynced = Color(0xFF1E6B3A);
  static const Color statusSyncedBackground = Color(0xFFE3F4E8);
  static const Color statusProblem = Color(0xFFB3261E);
  static const Color statusProblemBackground = Color(0xFFFCE8E6);
}
