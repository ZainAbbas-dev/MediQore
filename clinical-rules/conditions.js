// M4 FE-4: reference implementation of the Clinical Rules Table's condition
// language, used by the table's own tests. The app (Dart) and the API follow the
// same semantics; test-cases.json holds the shared cases both must pass.
//
// A condition is one of:
//   { "all": [condition, ...] }            every condition holds
//   { "any": [condition, ...] }            at least one holds
//   { "field": f, "op": ">=", "value": n } also ">", "<=", "<", "=="
//   { "field": f, "op": "in", "value": [...] }
//   { "field": f, "op": "present" }        a non-empty value
// A field with no value (null or missing) never satisfies a comparison, so an
// unanswered question never raises or clears a rule on its own.

const COMPARISONS = {
  '>=': (a, b) => a >= b,
  '>': (a, b) => a > b,
  '<=': (a, b) => a <= b,
  '<': (a, b) => a < b,
  '==': (a, b) => a === b,
};

function holds(condition, record) {
  if (condition.all) return condition.all.every((c) => holds(c, record));
  if (condition.any) return condition.any.some((c) => holds(c, record));
  const value = record[condition.field];
  if (condition.op === 'present') return value !== null && value !== undefined && String(value).trim() !== '';
  if (value === null || value === undefined) return false;
  if (condition.op === 'in') return condition.value.includes(value);
  const compare = COMPARISONS[condition.op];
  if (!compare) throw new Error(`Unknown operator ${condition.op}`);
  return compare(value, condition.value);
}

// Every field a condition reads, with the operator and value used on it.
function comparisons(condition) {
  if (condition.all) return condition.all.flatMap(comparisons);
  if (condition.any) return condition.any.flatMap(comparisons);
  return [condition];
}

const RANK = { none: 0, yellow: 1, emergency: 2 };

// The danger-sign result for one visit: the strongest rule result, every rule
// that fired, and the flags shown next to the colour.
function maternalRuleResult(table, visit) {
  const section = table.maternal_risk;
  const triggered = section.rules.filter((rule) => holds(rule.when, visit));
  const result = triggered.reduce((best, rule) => (RANK[rule.result] > RANK[best] ? rule.result : best), 'none');
  const flags = section.flags.filter((flag) => holds(flag.when, visit)).map((flag) => flag.id);
  return { result, triggered: triggered.map((rule) => rule.id), flags };
}

// Final level: the higher of the model's level and the rules' level.
function finalLevel(table, modelClass, ruleResult) {
  const { levels, model_class_to_level: fromModel, emergency_level: emergency } = table.maternal_risk;
  const ruleLevel = { none: levels[0], yellow: 'yellow', emergency }[ruleResult];
  const modelLevel = fromModel[modelClass];
  return levels.indexOf(ruleLevel) > levels.indexOf(modelLevel) ? ruleLevel : modelLevel;
}

// The obstetric history flags for a woman at registration.
function obstetricFlags(table, history) {
  return table.obstetric_history_flags.flags.filter((flag) => holds(flag.when, history)).map((flag) => flag.id);
}

// The band a value falls in: { below } bands are open at the bottom, { from }
// bands open at the top.
function band(bands, value) {
  return bands.find((b) => (b.from === undefined || value >= b.from) && (b.below === undefined || value < b.below));
}

function malnutritionClass(table, { muacMm, oedema }) {
  if (oedema) return table.nutrition.bilateral_pitting_oedema_class;
  return band(table.nutrition.muac_bands_mm, muacMm).class;
}

function anaemiaLevel(table, hbGdl) {
  return band(table.anaemia.bands_g_dl, hbGdl).level;
}

function outcomeType(table, { liveBirth, gestationalWeeks }) {
  if (liveBirth) return 'live_birth';
  return gestationalWeeks >= table.pregnancy_outcomes.stillbirth_min_gestational_weeks ? 'stillbirth' : 'miscarriage';
}

function fastBreathing(table, { ageMonths, breathsPerMinute }) {
  const row = table.imci.fast_breathing.find((r) => ageMonths >= r.from_months && ageMonths < r.below_months);
  return row ? breathsPerMinute >= row.breaths_per_minute_at_least : null;
}

function pneumoniaClass(table, { ageMonths, breathsPerMinute, chestIndrawing, generalDangerSigns = [] }) {
  const [severe, pneumonia, cough] = table.imci.cough_or_difficult_breathing;
  if (generalDangerSigns.length > 0) return severe.classification;
  if (chestIndrawing || fastBreathing(table, { ageMonths, breathsPerMinute })) return pneumonia.classification;
  return cough.classification;
}

function dehydrationClass(table, signs) {
  const row = table.imci.dehydration.find((r) => r.signs.filter((s) => signs.includes(s)).length >= r.min_signs);
  return row.classification;
}

module.exports = {
  holds,
  comparisons,
  maternalRuleResult,
  finalLevel,
  obstetricFlags,
  band,
  malnutritionClass,
  anaemiaLevel,
  outcomeType,
  fastBreathing,
  pneumoniaClass,
  dehydrationClass,
};
