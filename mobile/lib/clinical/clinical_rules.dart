// P0-11: the Clinical Rules Table bundled with the app (an exact copy of
// clinical-rules/clinical-rules.json, see test/clinical_rules_test.dart). Every
// clinical rule the app uses is read from here, never written in code, and the
// table's version is stored with each result (M4 FE-4, LI-12). Its defaults are
// "pending clinical review" until the Clinical Advisor signs it (LI-10).
import 'dart:convert';

import 'package:flutter/services.dart';

import 'conditions.dart';
import 'visit_ranges.dart';

/// One obstetric history flag (M2 FE-2), for example a previous C-section.
class ObstetricFlagRule {
  const ObstetricFlagRule({required this.id, required this.when});

  final String id;
  final Map<String, dynamic> when;
}

class ClinicalRules {
  ClinicalRules._(this.table)
    : version = table['version'] as String,
      status = table['status'] as String,
      visitRanges = VisitRanges.fromJson(table),
      obstetricFlagRules = [
        for (final flag in (table['obstetric_history_flags'] as Map<String, dynamic>)['flags'] as List)
          ObstetricFlagRule(id: flag['id'] as String, when: Map<String, dynamic>.from(flag['when'] as Map)),
      ];

  factory ClinicalRules.fromJson(Map<String, dynamic> table) => ClinicalRules._(table);

  static const String asset = VisitRanges.asset;

  /// Reads the table bundled with the app.
  static Future<ClinicalRules> load([AssetBundle? bundle]) async =>
      ClinicalRules.fromJson(jsonDecode(await (bundle ?? rootBundle).loadString(asset)) as Map<String, dynamic>);

  final Map<String, dynamic> table;

  /// For example 0.1.0.
  final String version;

  /// "pending clinical review" until the Clinical Advisor signs the table.
  final String status;

  /// The visit form's range checks (M3 FE-1).
  final VisitRanges visitRanges;

  final List<ObstetricFlagRule> obstetricFlagRules;

  /// The risk-factor flags of an obstetric history at registration (M2 FE-2):
  /// shown on the woman's file; they never change the risk colour unless the
  /// signed table says so. Fields: age, previousPregnancies, previousCSections,
  /// stillbirths, knownConditions.
  List<String> obstetricFlags(Map<String, Object?> history) =>
      [for (final rule in obstetricFlagRules) if (conditionHolds(rule.when, history)) rule.id];
}
