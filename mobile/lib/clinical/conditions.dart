// The Clinical Rules Table's condition language (clinical-rules/conditions.js
// is the reference; both pass clinical-rules/test-cases.json):
//   { "all": [condition, ...] }            every condition holds
//   { "any": [condition, ...] }            at least one holds
//   { "field": f, "op": ">=", "value": n } also ">", "<=", "<", "=="
//   { "field": f, "op": "in", "value": [...] }
//   { "field": f, "op": "present" }        a non-empty value
// A field with no value (null or missing) never satisfies a comparison, so an
// unanswered question never raises or clears a rule on its own.

/// Whether [condition] holds for [record] (field name → value).
bool conditionHolds(Map<String, dynamic> condition, Map<String, Object?> record) {
  final all = condition['all'];
  if (all is List) return all.every((c) => conditionHolds(c as Map<String, dynamic>, record));
  final any = condition['any'];
  if (any is List) return any.any((c) => conditionHolds(c as Map<String, dynamic>, record));

  final value = record[condition['field'] as String];
  final op = condition['op'] as String;
  if (op == 'present') return value != null && '$value'.trim().isNotEmpty;
  if (value == null) return false;
  final expected = condition['value'];
  if (op == 'in') return (expected as List).contains(value);
  if (op == '==') return value == expected;
  if (value is! num || expected is! num) return false;
  return switch (op) {
    '>=' => value >= expected,
    '>' => value > expected,
    '<=' => value <= expected,
    '<' => value < expected,
    _ => throw ArgumentError.value(op, 'op', 'unknown operator'),
  };
}
