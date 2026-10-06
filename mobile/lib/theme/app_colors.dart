import 'package:flutter/material.dart';

/// Colours shared across the app. Risk colours follow the scope's
/// Green / Yellow / Red classification (M4).
abstract final class AppColors {
  /// The MediQore teal: app bars, primary buttons and highlights.
  static const Color primary = Color(0xFF00695C);

  /// Screen background behind the white cards.
  static const Color background = Color(0xFFF3F6F5);

  /// Card and field surfaces.
  static const Color surface = Colors.white;

  /// Thin borders around cards and fields.
  static const Color border = Color(0xFFDCE3E1);

  /// Secondary text: labels, hints, IDs under a name.
  static const Color mutedText = Color(0xFF5F6B69);

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
  static const Color statusPending = Color(0xFFB45309);
  static const Color statusPendingBackground = Color(0xFFFFF4E0);
  static const Color statusSynced = Color(0xFF2E7D32);
  static const Color statusSyncedBackground = Color(0xFFE6F4EA);
  static const Color statusProblem = Color(0xFFB3261E);
  static const Color statusProblemBackground = Color(0xFFFCE8E6);
}
