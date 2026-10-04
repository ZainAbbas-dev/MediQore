// M3 FE-1: range checks on the visit form, read from the versioned config file
// assets/clinical/visit_ranges.json (CLAUDE.md: clinical rules live in JSON
// config, never in code), so clinical advisors can review them.
import 'dart:convert';

import 'package:flutter/services.dart';

/// The limits for one vital, in its stored unit.
class VitalRange {
  const VitalRange({required this.decimals, required this.allowed, required this.plausible});

  factory VitalRange.fromJson(Map<String, dynamic> json) => VitalRange(
        decimals: json['decimals'] as int,
        allowed: _pair(json['allowed']),
        plausible: _pair(json['plausible']),
      );

  /// Digits allowed after the decimal point.
  final int decimals;

  /// Outside this, the value is impossible and the server refuses it.
  final (num, num) allowed;

  /// Outside this (but allowed), the LHW confirms the value before saving.
  final (num, num) plausible;

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
  const VisitRanges({required this.version, required this.vitals});

  factory VisitRanges.fromJson(Map<String, dynamic> json) => VisitRanges(
        version: json['version'] as int,
        vitals: {
          for (final MapEntry(:key, :value) in (json['vitals'] as Map<String, dynamic>).entries)
            key: VitalRange.fromJson(value as Map<String, dynamic>),
        },
      );

  static const String asset = 'assets/clinical/visit_ranges.json';

  /// Reads the config bundled with the app.
  static Future<VisitRanges> load([AssetBundle? bundle]) async =>
      VisitRanges.fromJson(jsonDecode(await (bundle ?? rootBundle).loadString(asset)) as Map<String, dynamic>);

  final int version;
  final Map<String, VitalRange> vitals;

  VitalRange operator [](String field) => vitals[field] ?? (throw ArgumentError.value(field, 'field', 'no range in $asset'));
}
