import 'package:flutter/material.dart';

/// Colours shared across the app. Risk colours follow the scope's
/// Green / Yellow / Red classification (M4).
abstract final class AppColors {
  static const Color primary = Color(0xFF00695C);

  static const Color riskGreen = Color(0xFF2E7D32);
  static const Color riskYellow = Color(0xFFF9A825);
  static const Color riskRed = Color(0xFFC62828);

  /// Text and icon colours that stay readable on each risk colour.
  static const Color onRiskGreen = Colors.white;
  static const Color onRiskYellow = Color(0xFF212121);
  static const Color onRiskRed = Colors.white;

  static const Color statusOffline = Color(0xFF616161);
  static const Color statusPending = Color(0xFFEF6C00);
  static const Color statusSynced = Color(0xFF2E7D32);
}
