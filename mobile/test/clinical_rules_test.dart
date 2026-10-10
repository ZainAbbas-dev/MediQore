// P0-11: the app bundles a copy of the Clinical Rules Table
// (clinical-rules/clinical-rules.json at the repository root), because Flutter
// assets must live inside the app folder. The copy must stay identical, and the
// visit form must read its ranges from it.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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
}
