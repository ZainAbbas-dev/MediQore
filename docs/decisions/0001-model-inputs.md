# 0001. Model inputs

- **Status:** Accepted: decided by the updated final scope (M3 FE-1, M4 FE-1, BO-2) and the roadmap of 10 Oct 2026 ("Model inputs missing from the visit form: Decided in scope")
- **Date:** 2026-10-03
- **Scope:** M4 FE-1, M3 FE-1, BO-2, LI-2
- **Roadmap:** Risks and decisions, row 1 ("Model inputs missing from the visit form"); Phase 2 task "Run inference with onnxruntime after each visit … handle a missing blood sugar value as decided in P0-11"

> **Update, 2026-10-10 (updated final scope and roadmap of 10 Oct 2026).** The scope now fixes option 3: pulse is required, blood sugar is optional, and two input sets are trained, validated and reported separately: a default five-feature model (SystolicBP, DiastolicBP, BodyTemp, HeartRate, Age) and a six-feature model used only when a same-visit blood sugar reading exists (configurable window). The input set is stored on every result in `risk_assessments.input_set` (`five_feature`, `six_feature`), added by the `final-scope-data-model` migration, so point 2 below no longer relies on the model version name alone. Blood sugar is stored with its unit, date and source (glucometer or verified lab report). Points 4 and "To decide in Phase 2" stay open for Phase 2.

## Context

The risk model is trained on the UCI Maternal Health Risk dataset. It uses six inputs: Age, SystolicBP, DiastolicBP, BS (blood sugar), BodyTemp and HeartRate.

The scope's visit form (M3 FE-1) collected neither blood sugar nor heart rate. The roadmap's mitigation has three parts:

- add pulse, which any LHW can count;
- add an optional blood sugar field;
- train one model with all six features and one without blood sugar, and use the second when no reading exists.

Phase 0 already follows this:

- schema v1 has `visits.pulse_bpm` and the optional `visits.blood_sugar_mmol_l` (P0-4);
- the Phase 1 visit form spec includes both fields (P0-7).

What remains to decide is the exact inputs, their units, and what to do with readings the dataset never saw.

## Evidence

Source: `ml/notebooks/01_uci_exploration.ipynb`, run on the real file (1,014 rows).

| Finding | Number | Why it matters |
|---|---|---|
| Unique rows | 452 of 1,014 (562 exact duplicates) | Small training set; duplicates must go before the split |
| Unique-row balance | 234 low, 106 mid, 112 high | About 22 high-risk cases in a 20% hold-out set; one miss moves recall by about 4.5 points |
| Blood sugar ≥ 8 mmol/L | 72 of 112 high-risk rows, 3 of 234 low-risk rows | Blood sugar is the strongest single signal, so a model without it will probably be weaker |
| Lowest blood sugar | 6.0 mmol/L | Normal readings of 4–5.9 mmol/L from the app are outside the training range |
| Body temperature | °F; 8 distinct values, 79% of rows at 98 °F | The app stores °C, so convert at the model input |
| Conflicting labels | 35 feature rows (71 unique rows) with more than one label | A cleaning choice for Phase 2 |
| Entry error | HeartRate = 7 (2 rows, 1 unique) | Drop it in Phase 2 cleaning |

## Options

1. **Six features only.** Blood sugar is required on every visit. *Rejected:* most LHWs have no glucometer, so the form could not be saved, or the model would not run.
2. **Six features, with a missing blood sugar filled in** (for example the training median). *Rejected:* a made-up value for the strongest signal would hide real risk without warning.
3. **Two models (roadmap):**
   - model A uses all six features;
   - model B uses five, without blood sugar, and runs when the visit has no blood sugar reading.

## Proposed decision

Option 3, with these details:

1. **Inputs and mapping** (one unit per vital, conversion only at the model input):

   | Model input | MediQore source | Conversion |
   |---|---|---|
   | Age | `women.age` | none (years) |
   | SystolicBP | `visits.systolic_bp_mmhg` | none (mmHg) |
   | DiastolicBP | `visits.diastolic_bp_mmhg` | none (mmHg) |
   | BS | `visits.blood_sugar_mmol_l` | none (mmol/L); model A only |
   | BodyTemp | `visits.temperature_c` | °F = °C × 9/5 + 32 |
   | HeartRate | `visits.pulse_bpm` | none (beats/min) |

2. **Choosing the model.** Model A runs when the visit has a blood sugar reading, and model B when it does not.
   - `risk_assessments.model_version` names the variant, for example `2026.1-bs` and `2026.1-nobs`, so every stored result says which model made it (LI-2).
   - No schema change is needed.
3. **Both models are judged against BO-2 separately:** at least 90% high-risk recall on the hold-out set, then F1-macro.
   - Phase 2 reports both models' scores honestly.
   - If model B misses the target, the team decides then, with the supervisor. The likely choices are to accept it as decision support only (LI-5, with the danger-sign rules of M4 FE-4 still overriding), or to ask LHWs to take a blood sugar reading where a glucometer is available.
4. **Readings outside the training range** (for example blood sugar below 6.0 mmol/L): clip each input to the training minimum and maximum at the model input.
   - Export the ranges with the model, so the app and the Python tests use the same numbers.
   - Phase 2 tests this choice and may replace it.
5. **Not model inputs:** danger signs (bleeding, fetal movement, swelling and the others) feed the rule-based override (M4 FE-4) from the versioned clinical config, never the model.

## To decide in Phase 2 (not now)

- Conflicting labels: keep the rows, drop them, or keep the higher risk level. Record the choice in the Phase 2 training notes.
- The exact format of `model_version`.

## Consequences

- The visit form needs pulse as a required field and blood sugar as optional (already in the P0-7 spec).
- Phase 2 trains, evaluates, exports and parity-tests two ONNX models instead of one. The app bundles both.
- The SHAP Urdu lookup (M4 FE-2) needs one table per model.

## Sign-off

| Name | Role | Decision | Date |
|---|---|---|---|
| Muhammad Zain Abbas | Team (ML owner) | | |
| Zain Ali | Team | | |
