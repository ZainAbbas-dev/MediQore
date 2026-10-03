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
- **Soft deletes only:** a trigger (`prevent_hard_delete`) refuses `DELETE`; set `deleted_at` instead.
- **Audit log:** `audit_log` is append-only; a trigger refuses `UPDATE` and `DELETE`.
- **Server-only tables** (geography, users and tokens, audit log, conflicts, report jobs, EPI config) are never synced as rows.

## Tables

| Group (migration) | Tables | Synced | Scope |
|---|---|---|---|
| Geography | districts, tehsils, union_councils, areas | no | M1 FE-1, M10 FE-3 |
| Users and access | users, lhw_profiles, supervisor_areas, devices, refresh_tokens, otp_codes | no | M1 FE-1–3 |
| System | audit_log, sync_conflicts, report_jobs | no | M10 FE-3, M3 FE-2, M10 FE-2 |
| Households and women | households, women, pregnancies, obstetric_history | yes | M2 FE-1–3 |
| Visits | visits | yes | M3 FE-1 |
| Facilities | hospitals, referral_centres, escalation_contacts | yes (pulled) | M5 FE-1, M9 FE-2, M10 FE-3 |
| Risk | risk_assessments | yes | M4 FE-1–4 |
| Emergency | referrals, emergency_alerts, alert_attempts, alert_acknowledgements | yes | M5 FE-1–5 |
| ANC and records | anc_schedule, tt_doses, supplement_logs, health_documents, trend_results | yes | M6 FE-1–3 |
| Children | children | yes | M7–M9 (shared registry) |
| Polio | campaigns, campaign_household_records, refusals, revisits | yes | M7 FE-1–2 |
| Immunisation | epi_schedule (config), immunisations | immunisations only | M8 FE-1 |
| Nutrition | nutrition_screenings, sam_followups, imci_assessments | yes | M9 FE-1–3 |

In total there are 41 tables: 27 synced and 14 server-only.

## Decisions to review

The scope and roadmap name the tables but not every column. These choices were made in schema v1 and should be confirmed or changed in review:

1. **Address and village** from the registration form are stored on `households`. Name, age, husband's name and contact number are stored on `women`.
2. **Age** is stored as the age the form captures, not a date of birth (M2 FE-1).
3. **Pregnancies** have `status` `active` or `closed`, and a woman can have only one active pregnancy at a time.
4. **Anaemia signs** are `none`, `present` or `severe`, so the "severe anaemia signs" danger sign (M4 FE-4) can be recorded. **Fetal movement** is `normal`, `reduced` or `absent`, or NULL when not assessed.
5. **Vitals** carry their unit in the column name. **Height** is in cm; the roadmap's unit list does not cover height.
6. **Hospitals and referral centres** belong to a district, so their `area_id` is optional and the app pulls them by district.
7. **Escalation time** is stored per area in `escalation_contacts.escalate_after_minutes`, default 15 (M5 FE-5).
8. **Rules version:** `risk_assessments`, `nutrition_screenings` and `imci_assessments` store a `rules_version` next to any model version. This keeps results traceable when the JSON clinical config changes.
9. **`audit_log.action` values** are `create`, `edit`, `delete`, `referral`, `alert`, `login` and `sync_conflict`. Alert attempts are logged with their channel and status in `details`.
10. **Zero-dose (M7 FE-3)** needs per-child OPV records in each round. The roadmap's polio tables only hold per-household counts, so how to record per-child doses is left to Phase 3, in a new migration.
11. **Wasting** is stored as a flag next to the weight-for-age and height-for-age Z-scores that the scope names (M9 FE-1). No weight-for-height Z-score is stored.
12. **The OTP channel** column is free text until P0-11 decides it.
