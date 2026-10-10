# Clinical Rules Table (P0-11)

`clinical-rules.json` is MediQore's one versioned Clinical Rules Table (scope M4 FE-4, LI-12; roadmap "Architecture and conventions", "Clinical rules"). Every clinical rule the app or the server uses is read from it, never written in code.

**Status: version 0.1.0, pending clinical review.** The values are WHO-referenced defaults chosen by the team. No Clinical Advisor has reviewed them yet, so the table may be used only with synthetic data (LI-10). It must be signed before any use with real patients.

## What it holds

| Section | Used by | Content | Main reference |
|---|---|---|---|
| `visit_entry_checks` | M3 FE-1 | Allowed and plausible range of each vital (typing-error checks), the 30-second pulse counter, the mg/dL → mmol/L factor | Roadmap (systolic 60–250); others proposed |
| `maternal_risk` | M4 FE-4 | The 12 danger-sign rules (11 give Emergency, raised BP alone gives at least Yellow), the swelling flag, model class → colour, final level = higher of model and rules | WHO PCPNC 2015, WHO MCPC 2017 |
| `anaemia` | M6 FE-2 | Hb bands in g/dL (severe < 7, moderate 7–9.9, mild 10–10.9) | WHO 2011; WHO 2024 noted for review |
| `obstetric_history_flags` | M2 FE-2 | Previous C-section, previous stillbirth, five or more previous pregnancies, known condition, age under 18, age 35 or above | WHO MCPC 2017, WHO ANC 2016 |
| `pregnancy_outcomes` | M6 FE-4 | Stillbirth from 28 completed weeks; earlier is a miscarriage | WHO 2016 |
| `anc_schedule` | M6 FE-1 | Eight contacts: up to 12, then 20, 26, 30, 34, 36, 38, 40 weeks | WHO ANC 2016 |
| `tetanus_toxoid` | M6 FE-1 | TT/Td doses 1–5 with minimum intervals | WHO 2017 |
| `supplements` | M6 FE-1 | Daily iron (30–60 mg) and folic acid (400 µg) | WHO ANC 2016 |
| `epi_schedule` | M8 FE-1, FE-2 | BCG, Hep B-0 (switched on per area), OPV-0 to OPV-3, Penta 1–3, PCV 1–3, Rota 1–2, IPV-I and IPV-II, MR 1–2, TCV: dose number, minimum and recommended age, minimum interval, maximum age; schedule version and effective date; the Penta-1 zero-dose indicator | National Immunization Policy 2022 |
| `nutrition` | M9 FE-1 | MUAC < 115 mm SAM, 115 to < 125 mm MAM, ≥ 125 mm normal (6–59 months); bilateral pitting oedema = SAM; underweight and stunting Z-score cut-offs | WHO/UNICEF 2009, WHO 2013, WHO 2006 |
| `imci` | M9 FE-3 | Fast-breathing thresholds by age, the 60-second count, pneumonia and dehydration classifications with severity colour and action key | WHO IMCI 2014 |

Fields marked `review_note` list what the team proposed beyond the scope and what the Clinical Advisor must decide (for example the time for a facility check after raised BP, and maximum vaccine ages).

## Condition language

Rules and flags say when they apply with a small condition language, so the app (Dart) and the server (JavaScript) evaluate the same table the same way. `conditions.js` is the reference implementation:

- `{ "all": [...] }`, `{ "any": [...] }`
- `{ "field": "systolicBpMmhg", "op": ">=", "value": 160 }`; also `>`, `<=`, `<`, `==`
- `{ "field": "fetalMovement", "op": "in", "value": ["reduced", "absent"] }`
- `{ "field": "knownConditions", "op": "present" }`

Fields use the sync field names of the API (`docs/openapi.yaml`). An unanswered field (null or missing) never satisfies a comparison.

`test-cases.json` holds the shared cases, at least one for every rule and flag. Each implementation (the app in Phase 2, the API if it evaluates rules) must pass all of them.

## Who reads it

- **App:** bundles an exact copy at `mobile/assets/clinical/clinical-rules.json` (Flutter assets must live inside the app folder). `mobile/test/clinical_rules_test.dart` and `api/tests/visit-ranges.test.js` fail if the copy differs. The visit form reads its ranges from it today; the danger-sign rules and the other sections are read by the modules that use them (Phases 2 and 3).
- **API:** `api/src/sync/tables.js` takes each vital's bounds from `visit_entry_checks`.
- **Database:** `cd db; npm run rules:load` stores the version in `clinical_rules_versions` (content, SHA-256, review status) and its EPI doses in `epi_schedule`. The staging server runs it at every start.
- **Results:** every risk result, flag, outcome, screening and immunisation stores the version it used (`rules_version`, `schedule_version`).

## Changing the table

1. Edit `clinical-rules.json` and raise `version` (a loaded version can never change: `rules:load` refuses different content under the same version). Raise `epi_schedule.schedule_version` too if the EPI rows change.
2. Add or update cases in `test-cases.json` and set its `rules_version`.
3. Copy the file to `mobile/assets/clinical/clinical-rules.json`.
4. Run `node --test` here, `npm test` in `api/` and `db/`, and `flutter test` in `mobile/`.

## Sign-off by the Clinical Advisor

The roadmap's most urgent open item is finding a Clinical Advisor (an obstetrician or community-health doctor) by 27 Dec 2026. When the advisor has reviewed every section:

1. Resolve each `review_note`, then remove it.
2. Set `status` to `signed` and fill `sign_off.clinical_advisor` (name and qualification) and `sign_off.signed_on` (date).
3. Raise `version` (for example `1.0.0`) and follow "Changing the table".

Until then the app and portal must treat every result as decision support on synthetic data only (LI-5, LI-10).

| Section | Reviewed by | Date | Changes asked for |
|---|---|---|---|
| `visit_entry_checks` | | | |
| `maternal_risk` | | | |
| `anaemia` | | | |
| `obstetric_history_flags` | | | |
| `pregnancy_outcomes` | | | |
| `anc_schedule`, `tetanus_toxoid`, `supplements` | | | |
| `epi_schedule` | | | |
| `nutrition` | | | |
| `imci` | | | |

## Commands

```powershell
cd clinical-rules
node --test        # table checks and shared test cases (Node.js 24, no install needed)
```
