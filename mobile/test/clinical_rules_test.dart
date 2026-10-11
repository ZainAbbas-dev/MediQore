// P0-11: the app bundles a copy of the Clinical Rules Table
// (clinical-rules/clinical-rules.json at the repository root), because Flutter
// assets must live inside the app folder. The copy must stay identical, and the
// visit form must read its ranges from it.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mediqore/clinical/clinical_rules.dart';
import 'package:mediqore/clinical/conditions.dart';
import 'package:mediqore/clinical/visit_ranges.dart';

void main() {
  final bundled = File(VisitRanges.asset);
  final shared = File('../clinical-rules/clinical-rules.json');

  test('the bundled table is an exact copy of clinical-rules/clinical-rules.json', () {
    expect(bundled.readAsStringSync(), shared.readAsStringSync(),
        reason: 'Copy clinical-rules/clinical-rules.json to mobile/${VisitRanges.asset}');
  });

  test('the table is marked pending clinical review until the Clinical Advisor signs it', () {
    final table = jsonDecode(bundled.readAsStringSync()) as Map<String, dynamic>;
    final signOff = table['sign_off'] as Map<String, dynamic>;
    expect(table['status'] == 'pending clinical review', signOff['clinical_advisor'] == null);
  });

  test('the visit form ranges come from the table, with its version', () {
    final table = jsonDecode(bundled.readAsStringSync()) as Map<String, dynamic>;
    final ranges = VisitRanges.fromJson(table);
    expect(ranges.version, table['version']);
    expect(ranges['systolicBpMmhg'].plausible, (60, 250));
    expect(ranges.vitals.keys, containsAll(<String>['systolicBpMmhg', 'diastolicBpMmhg', 'weightKg', 'temperatureC', 'pulseBpm', 'bloodSugarMmolL']));
  });

  group('the condition language, against the shared cases (clinical-rules/test-cases.json)', () {
    final table = jsonDecode(bundled.readAsStringSync()) as Map<String, dynamic>;
    final cases = jsonDecode(File('../clinical-rules/test-cases.json').readAsStringSync()) as Map<String, dynamic>;
    final rules = ClinicalRules.fromJson(table);

    test('the cases are for this version of the table', () {
      expect(cases['rules_version'], rules.version);
    });

    test('obstetric history flags (M2 FE-2) match every case', () {
      for (final c in (cases['obstetric_histories'] as List).cast<Map<String, dynamic>>()) {
        expect(rules.obstetricFlags(Map<String, Object?>.from(c['history'] as Map)), c['flags'], reason: '${c['history']}');
      }
    });

    test('every flag in the table is covered by a case', () {
      final covered = {
        for (final c in (cases['obstetric_histories'] as List)) ...(c as Map)['flags'] as List,
      };
      expect(covered, containsAll(rules.obstetricFlagRules.map((r) => r.id)));
    });

    test('the danger-sign rules fire as in every visit case (the same evaluator, ahead of M4 FE-4)', () {
      final maternal = table['maternal_risk'] as Map<String, dynamic>;
      for (final c in (cases['maternal_visits'] as List).cast<Map<String, dynamic>>()) {
        final visit = Map<String, Object?>.from(c['visit'] as Map);
        final fired = [
          for (final rule in (maternal['rules'] as List).cast<Map<String, dynamic>>())
            if (conditionHolds(Map<String, dynamic>.from(rule['when'] as Map), visit)) rule['id'],
        ];
        expect(fired, c['triggered'], reason: c['name'] as String);
      }
    });

    test('a missing value never satisfies a comparison; present needs a non-empty value', () {
      expect(conditionHolds({'field': 'x', 'op': '>=', 'value': 1}, {}), isFalse);
      expect(conditionHolds({'field': 'x', 'op': '<', 'value': 1}, {'x': null}), isFalse);
      expect(conditionHolds({'field': 'x', 'op': 'present'}, {'x': '  '}), isFalse);
      expect(conditionHolds({'field': 'x', 'op': 'present'}, {'x': 'asthma'}), isTrue);
      expect(conditionHolds({'field': 'x', 'op': 'in', 'value': ['a', 'b']}, {'x': 'b'}), isTrue);
      expect(
        conditionHolds({
          'any': [
            {'field': 'x', 'op': '==', 'value': true},
            {'all': [{'field': 'y', 'op': '>', 'value': 2}, {'field': 'z', 'op': '<=', 'value': 5}]},
          ],
        }, {'x': false, 'y': 3, 'z': 5}),
        isTrue,
      );
    });
  });
}
