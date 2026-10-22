// M3 FE-1: range checks on the visit form, read from the visit_entry_checks
// section of the Clinical Rules Table (P0-11). The app bundles a copy of
// clinical-rules/clinical-rules.json as assets/clinical/clinical-rules.json
// (CLAUDE.md: clinical rules live in that table, never in code), so the Clinical
// Advisor reviews one file and the server checks the same bounds.
import 'dart:convert';

import 'package:flutter/services.dart';

/// The limits for one vital, in its stored unit.
class VitalRange {
  const VitalRange({required this.decimals, required this.allowed, required this.plausible, this.normal});

  factory VitalRange.fromJson(Map<String, dynamic> json) => VitalRange(
        decimals: json['decimals'] as int,
        allowed: _pair(json['allowed']),
        plausible: _pair(json['plausible']),
        normal: json['normal'] == null ? null : _pair(json['normal']),
      );

  /// Digits allowed after the decimal point.
  final int decimals;

  /// Outside this, the value is impossible and the server refuses it.
  final (num, num) allowed;

  /// Outside this (but allowed), the LHW confirms the value before saving.
  final (num, num) plausible;

  /// Outside this, the value is highlighted on the form (SRS FR3.3); null when
  /// the table sets no normal range. It never changes the risk level.
  final (num, num)? normal;

  /// Whether [value] lies outside the normal range, and on which side.
  bool isAboveNormal(num value) => normal != null && value > normal!.$2;
  bool isBelowNormal(num value) => normal != null && value < normal!.$1;

  bool isAllowed(num value) => value >= allowed.$1 && value <= allowed.$2;
  bool isPlausible(num value) => value >= plausible.$1 && value <= plausible.$2;

  static (num, num) _pair(Object? json) {
    final [min, max] = (json as List).cast<num>();
    return (min, max);
  }
}

/// The ranges of every vital on the visit form, by the field name the server
/// uses (docs/openapi.yaml, VisitData).
class VisitRanges {
  const VisitRanges({
    required this.version,
    required this.vitals,
    this.pulseCountSeconds = 30,
    this.pulseMultiplier = 2,
    this.mgDlPerMmolL = 18.0,
  });

  /// Reads the visit_entry_checks section of the whole Clinical Rules Table.
  factory VisitRanges.fromJson(Map<String, dynamic> json) {
    final checks = json['visit_entry_checks'] as Map<String, dynamic>;
    final counter = checks['pulse_counter'] as Map<String, dynamic>;
    final conversion = checks['blood_sugar_conversion'] as Map<String, dynamic>;
    return VisitRanges(
      version: json['version'] as String,
      vitals: {
        for (final MapEntry(:key, :value) in (checks['vitals'] as Map<String, dynamic>).entries)
          key: VitalRange.fromJson(value as Map<String, dynamic>),
      },
      pulseCountSeconds: counter['count_seconds'] as int,
      pulseMultiplier: counter['multiplier'] as int,
      mgDlPerMmolL: (conversion['mg_dl_per_mmol_l'] as num).toDouble(),
    );
  }

  static const String asset = 'assets/clinical/clinical-rules.json';

  /// Reads the config bundled with the app.
  static Future<VisitRanges> load([AssetBundle? bundle]) async =>
      VisitRanges.fromJson(jsonDecode(await (bundle ?? rootBundle).loadString(asset)) as Map<String, dynamic>);

  /// The Clinical Rules Table version, for example 0.1.0.
  final String version;
  final Map<String, VitalRange> vitals;

  /// The pulse counter (M3 FE-1): count for this many seconds, multiply by this.
  final int pulseCountSeconds;
  final int pulseMultiplier;

  /// A blood sugar in mg/dL is mg/dL ÷ this in mmol/L. Blood sugar is stored
  /// in the unit it was recorded in (M3 FE-1); the ranges are in mmol/L.
  final double mgDlPerMmolL;

  /// [mgDl] in mmol/L, with one decimal, for the ranges.
  double mmolLFromMgDl(num mgDl) => (mgDl / mgDlPerMmolL * 10).round() / 10;

  VitalRange operator [](String field) =>
      vitals[field] ?? (throw ArgumentError.value(field, 'field', 'no range in $asset'));
}
