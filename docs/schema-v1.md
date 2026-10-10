# Schema v1 (P0-4)

PostgreSQL schema for all ten modules, built from the roadmap's [Data model overview](roadmap.md#data-model-overview). The SQL lives in [`db/migrations/`](../db/migrations), one file per table group. Most tables stay empty until their phase, as the roadmap asks.

Phase 0 exit gate: **"Schema v1 and OpenAPI v1 reviewed by both members."** Review the tables below and the decisions at the end, then tick the gate in issue #4.

## How sync works in the schema

- **Synced tables** are the ones devices push or pull. They all have the same base columns:
  - `id`: UUID v4 generated on the device.
  - `server_seq`: server sequence number.
  - `area_id`
  - `created_by`
  - `created_on_device`: device clock; informational only.
  - `synced_at`
  - `deleted_at`
- **`server_seq` assignment:** a trigger (`assign_server_seq`) sets it from one shared sequence on every insert and every update, together with `synced_at`. A value sent by a device is ignored.
  - The pull query is `WHERE area_id = $1 AND server_seq > $since ORDER BY server_seq`. It never uses device time (LI-7).
  - Every edit gets a new `server_seq`, so other devices and the portal pick it up on their next pull.
  - The trigger takes a transaction-level advisory lock, so concurrent writers are numbered in commit order (added in P0-6). Without the lock, a row that commits late could be skipped by a pull that has already moved past its number.
- **Soft deletes only:** a trigger (`prevent_hard_delete`) refuses `DELETE`; set `deleted_at` instead.
- **Audit log:** `audit_log` is append-only; a trigger refuses `UPDATE` and `DELETE`.
- **Server-only tables** (geography, users, codes and tokens, audit log, conflicts, report jobs, Clinical Rules Table versions, EPI config, leave and campaign weeks) are never synced as rows.

## Tables

The groups follow the roadmap's data model (10 Oct 2026). Tables marked *Phase 1 rework* exist only until the sign-in is rebuilt on activation codes.

| Group (migration) | Tables | Synced | Scope |
|---|---|---|---|
| Geography | districts, tehsils, union_councils, areas | no | M1 FE-1, M10 FE-3 |
| Users and access | users, lhw_profiles, supervisor_areas, devices (with activation secret reference), activation_codes, refresh_tokens; otp_codes (*Phase 1 rework*) | no | M1 FE-1–3 |
| System | audit_log, sync_conflicts, report_jobs, clinical_rules_versions | no | M10 FE-3, M3 FE-2, M10 FE-2, M4 FE-4 |
| Households and women | households, women, pregnancies, obstetric_history | yes | M2 FE-1–3 |
| Visits | visits (vitals including pulse; optional blood sugar with unit, date and source; danger-sign checklist) | yes | M3 FE-1 |
| Facilities | hospitals, referral_centres, escalation_contacts | yes (pulled) | M5 FE-1, M9 FE-2, M10 FE-3 |
| Risk | risk_assessments (input set, model result, rule result, final level, explanation key, model version, rules version), risk_flags | yes | M4 FE-1–4 |
| Emergency | referrals, emergency_alerts (owner: phone or server), alert_attempts, alert_acknowledgements | yes | M5 FE-1–5 |
| ANC and records | anc_schedule, tt_doses, supplement_logs, health_documents (with verified Hb) | yes | M6 FE-1–2 |
| Pregnancy outcomes | pregnancy_outcomes | yes | M6 FE-4 |
| Children | children (status including deceased; source: outcome or manual; caregiver) | yes | M8 FE-1, used by M7 and M9 |
| Polio | campaigns, campaign_household_status, campaign_child_doses, refusals, revisits | yes | M7 FE-1–3 |
| Immunisation | epi_schedule (config), immunisations (with schedule version) | immunisations only | M8 FE-1 |
| Nutrition | nutrition_screenings (MUAC, oedema, weight-for-age, height-for-age), sam_followups, imci_assessments | yes | M9 FE-1–3 |
| Supervision | leave_and_campaign_weeks | no | M10 FE-4 |

In total there are 46 tables: 29 synced and 17 server-only.

## Changes since v1

Each change is a new migration in `db/migrations/`; v1's files are not edited.

| Migration | Change | Scope |
|---|---|---|
| `lhw-code-sequence` | `lhw_code_seq` numbers new LHW IDs (`LHW-00001`); an index on phones waiting for approval | M1 FE-1, FE-2 |
| `lhw-previous-area` | `lhw_profiles.previous_area_id`: the area before the last reassignment, so records a phone made there and syncs late keep that area | M1 FE-3 |
| `final-scope-data-model` | Brings v1 up to the updated final scope and the roadmap of 10 Oct 2026, listed below | P0-4 |

### What `final-scope-data-model` changes

| Group | Change | Scope |
|---|---|---|
| Users and access | New `activation_codes` (hashed, 48-hour expiry, single use, issuing admin, the phone it activated). `devices.activation_secret_ref` and `devices.activated_at` for the offline PIN reset | M1 FE-2 |
| System | New `clinical_rules_versions`: each loaded version of the Clinical Rules Table, its review status (`pending_clinical_review`, `signed`, `retired`), content, SHA-256, effective date and signer | M4 FE-4, LI-12 |
| Visits | Danger-sign checklist: `convulsions`, `severe_headache`, `blurred_vision`, `severe_abdominal_pain`, `fast_breathing`, `fever_with_weakness`. Blood sugar `blood_sugar_entered_unit`, `blood_sugar_measured_on`, `blood_sugar_source` (allowed only with a value) | M3 FE-1 |
| Risk | `risk_assessments.input_set` (`five_feature`, `six_feature`); `rule_result` can now be `yellow` (raised BP alone). New `risk_flags` (obstetric, anaemia, swelling) with `rules_version` | M4 FE-1, FE-4; M2 FE-2 |
| Emergency | `emergency_alerts.owner` (`phone` until the server's receipt, then `server`) and `server_owned_at` | M5 FE-5 |
| ANC and records | `health_documents.verified_hb_g_dl` and `hb_measured_on`. `trend_results` is dropped: trends are computed on the phone (M6 FE-3) and the data model no longer lists it | M6 FE-2, FE-3 |
| Pregnancy outcomes | New `pregnancy_outcomes`: type, date, place, gestational age, `needs_review` (always set for a maternal death), `rules_version`; one per pregnancy | M6 FE-4 |
| Children | `caregiver_name`, `birth_weight_kg`, `source` (`outcome` or `manual`) with `pregnancy_outcome_id`, `status` (`active`, `deceased`) with `deceased_on` | M8 FE-1, M6 FE-4 |
| Polio | `campaign_household_records` renamed `campaign_household_status`, with `status` (`all_vaccinated`, `refusal`, `not_available`). Refusal reasons no longer include "family absent", which is now the not-available status. Revisits link to the household status, so both refusals and not-available households get one. New `campaign_child_doses`: one row per child vaccinated in a round | M7 FE-1–3 |
| Immunisation | `epi_schedule`: `dose_number`, `min_age`, `recommended_age` (replaces `due_age_days`), `min_interval`, `max_age` (PostgreSQL intervals, so "9 months" stays calendar months), `effective_from`, `rollout_by_area`. `immunisations.dose_number` and `schedule_version` | M8 FE-1 |
| Nutrition | `nutrition_screenings.oedema`; `muac_class` renamed `malnutrition_class` (from MUAC and oedema together); `wasting` dropped (the scope has no wasting classification) | M9 FE-1 |
| Supervision | New `leave_and_campaign_weeks` (LHW, Monday of the week, `leave` or `campaign`, who marked it) | M10 FE-4 |

The Phase 2 and Phase 3 tables it changes were still empty. It was tested on a database holding the full synthetic data set, and the down section restores the earlier schema.

## Decisions to review

The scope and roadmap name the tables but not every column. These choices were made in schema v1 and should be confirmed or changed in review:

1. **Address and village** from the registration form are stored on `households`. Name, age, husband's name and contact number are stored on `women`.
2. **Age** is stored as the age the form captures, not a date of birth (M2 FE-1).
3. **Pregnancies** have `status` `active` or `closed`, and a woman can have only one active pregnancy at a time. A recorded outcome closes the pregnancy (M6 FE-4).
4. **Anaemia signs** are `none`, `present` or `severe`, so the "severe anaemia signs" danger sign (M4 FE-4) can be recorded. **Fetal movement** is `normal`, `reduced` or `absent`, or NULL when not assessed.
5. **Vitals** carry their unit in the column name. **Height** is in cm; the roadmap's unit list does not cover height. **Hb** is in g/dL.
6. **Hospitals and referral centres** belong to a district, so their `area_id` is optional and the app pulls them by district.
7. **Escalation time** is stored per area in `escalation_contacts.escalate_after_minutes`, default 15 (M5 FE-5).
8. **Rules version:** `risk_assessments`, `risk_flags`, `pregnancy_outcomes`, `nutrition_screenings` and `imci_assessments` store a `rules_version`; `immunisations` stores its `schedule_version`. This keeps results traceable when the Clinical Rules Table changes (roadmap, "Clinical rules").
9. **`audit_log.action` values** are `create`, `edit`, `delete`, `referral`, `alert`, `login` and `sync_conflict`. Alert attempts are logged with their channel and status in `details`.
10. **Danger-sign checklist answers** are nullable booleans: NULL means "not asked", so visits recorded before the checklist stay honest. The Phase 1 visit form requires every answer.
11. **Pulse is required** (M3 FE-1), but `visits.pulse_bpm` stays nullable in the database because earlier synced visits may lack it. The API requires it from Phase 1.
12. **Blood sugar** is always stored in mmol/L. The unit the LHW typed (`mmol_l` or `mg_dl`) is kept in `blood_sugar_entered_unit` for traceability; the date and the source (`glucometer` or `lab_report`) are stored with it.
13. **Activation secret:** the server stores only a reference (`devices.activation_secret_ref`) to where the per-device secret is held, never the secret in plain text. Where it is held is settled when the PIN reset is built in Phase 1.
14. **Outcome place** is `home`, `health_facility` or `other`.
15. **Hep B birth dose and other area-dependent doses** are marked `rollout_by_area` in `epi_schedule`. Which areas switch them on is set in the Clinical Rules Table's EPI section in Phase 3.
16. **`otp_codes`** (the earlier phone-approval code) stays until Phase 1 replaces it with `activation_codes`; a later migration then drops it.
