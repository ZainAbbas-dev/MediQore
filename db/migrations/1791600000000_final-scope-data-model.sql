-- Up Migration

-- Schema v1 brought up to the updated final scope and the roadmap of 10 Oct 2026
-- (P0-4, "Data model overview"). One migration for the whole change, so review
-- can follow it against the roadmap table group by group.

-- ---------------------------------------------------------------------------
-- Users and access (M1 FE-2)
-- ---------------------------------------------------------------------------

-- One-time activation code issued by an admin for the first login on a phone:
-- random, about 8 characters, valid 48 hours, usable once, stored hashed.
-- Server-only. It replaces the earlier phone-approval code (otp_codes), which
-- stays until the Phase 1 sign-in is rebuilt on activation codes.
CREATE TABLE activation_codes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users (id),       -- the LHW (or supervisor) who will activate
  code_hash   text NOT NULL,
  issued_by   uuid NOT NULL REFERENCES users (id),       -- the admin who generated it
  expires_at  timestamptz NOT NULL,
  consumed_at timestamptz,
  device_id   uuid REFERENCES devices (id),              -- the phone it activated
  revoked_at  timestamptz,                               -- a newer code or a deactivation cancels it
  created_at  timestamptz NOT NULL DEFAULT now(),
  CHECK (expires_at > created_at),
  CHECK ((consumed_at IS NULL) = (device_id IS NULL))
);

CREATE INDEX activation_codes_user_id_idx ON activation_codes (user_id, created_at);

-- The phone receives a per-device secret at activation and uses it offline to
-- check the supervisor's PIN-reset reply code (M1 FE-2). The server keeps only a
-- reference to where that secret is held, never the secret in plain text.
ALTER TABLE devices ADD COLUMN activation_secret_ref text;
ALTER TABLE devices ADD COLUMN activated_at timestamptz;

-- ---------------------------------------------------------------------------
-- System: Clinical Rules Table versions (M4 FE-4, LI-12, P0-11)
-- ---------------------------------------------------------------------------

-- Every version of the Clinical Rules Table (clinical-rules/ in the repository)
-- that the server has loaded. Results store the version they were computed with.
-- Server-only.
CREATE TABLE clinical_rules_versions (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  version        text NOT NULL UNIQUE,
  review_status  text NOT NULL DEFAULT 'pending_clinical_review'
                   CHECK (review_status IN ('pending_clinical_review', 'signed', 'retired')),
  content        jsonb NOT NULL,                          -- the whole table as published
  content_sha256 text NOT NULL CHECK (content_sha256 ~ '^[0-9a-f]{64}$'),
  effective_from date NOT NULL,
  signed_by      text,                                    -- the Clinical Advisor, once signed
  signed_on      date,
  created_at     timestamptz NOT NULL DEFAULT now(),
  CHECK ((review_status = 'signed') = (signed_by IS NOT NULL AND signed_on IS NOT NULL)
         OR review_status = 'retired')
);

-- ---------------------------------------------------------------------------
-- Visits (M3 FE-1)
-- ---------------------------------------------------------------------------

-- Yes/no danger-sign checklist with pictures. NULL means the question was not
-- asked (visits recorded before the checklist existed).
ALTER TABLE visits ADD COLUMN convulsions           boolean;
ALTER TABLE visits ADD COLUMN severe_headache       boolean;
ALTER TABLE visits ADD COLUMN blurred_vision        boolean;
ALTER TABLE visits ADD COLUMN severe_abdominal_pain boolean;  -- severe or upper abdominal pain
ALTER TABLE visits ADD COLUMN fast_breathing        boolean;  -- fast or difficult breathing
ALTER TABLE visits ADD COLUMN fever_with_weakness   boolean;  -- too weak to get out of bed

-- Optional blood sugar is stored with its value, unit, date and source. The value
-- is always kept in mmol/L (one unit per value); blood_sugar_entered_unit records
-- what the LHW typed, so a mg/dL reading can be traced.
ALTER TABLE visits ADD COLUMN blood_sugar_entered_unit text
  CHECK (blood_sugar_entered_unit IN ('mmol_l', 'mg_dl'));
ALTER TABLE visits ADD COLUMN blood_sugar_measured_on date;
ALTER TABLE visits ADD COLUMN blood_sugar_source text
  CHECK (blood_sugar_source IN ('glucometer', 'lab_report'));
ALTER TABLE visits ADD CONSTRAINT visits_blood_sugar_details_need_value CHECK (
  blood_sugar_mmol_l IS NOT NULL
  OR (blood_sugar_entered_unit IS NULL AND blood_sugar_measured_on IS NULL AND blood_sugar_source IS NULL)
);

-- ---------------------------------------------------------------------------
-- Risk (M4 FE-1, FE-4)
-- ---------------------------------------------------------------------------

-- input_set: which model ran (five features by default, six with a same-visit
-- blood sugar). The rules can also give Yellow (raised BP alone), not only an
-- Emergency.
ALTER TABLE risk_assessments ADD COLUMN input_set text NOT NULL
  CHECK (input_set IN ('five_feature', 'six_feature'));
ALTER TABLE risk_assessments DROP CONSTRAINT risk_assessments_rule_result_check;
ALTER TABLE risk_assessments ADD CONSTRAINT risk_assessments_rule_result_check
  CHECK (rule_result IN ('none', 'yellow', 'emergency'));

-- Flags shown next to the risk colour that never change it unless the signed
-- Clinical Rules Table says so: obstetric history, anaemia (verified Hb) and
-- swelling (M2 FE-2, M4 FE-4, M6 FE-2). Synced table.
CREATE TABLE risk_flags (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq         bigint NOT NULL,
  area_id            uuid NOT NULL REFERENCES areas (id),
  created_by         uuid NOT NULL REFERENCES users (id),
  created_on_device  timestamptz,
  synced_at          timestamptz NOT NULL,
  deleted_at         timestamptz,
  pregnancy_id       uuid NOT NULL REFERENCES pregnancies (id),
  visit_id           uuid REFERENCES visits (id),
  risk_assessment_id uuid REFERENCES risk_assessments (id),
  health_document_id uuid REFERENCES health_documents (id),
  flag_type          text NOT NULL CHECK (flag_type IN ('obstetric', 'anaemia', 'swelling')),
  flag_key           text NOT NULL,                       -- rule key in the Clinical Rules Table
  rules_version      text NOT NULL
);

CREATE INDEX risk_flags_pregnancy_id_idx ON risk_flags (pregnancy_id);

CREATE TRIGGER risk_flags_server_seq BEFORE INSERT OR UPDATE ON risk_flags FOR EACH ROW EXECUTE FUNCTION assign_server_seq();
CREATE TRIGGER risk_flags_no_hard_delete BEFORE DELETE ON risk_flags FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE UNIQUE INDEX risk_flags_server_seq_key ON risk_flags (server_seq);
CREATE INDEX risk_flags_area_seq_idx ON risk_flags (area_id, server_seq);

-- ---------------------------------------------------------------------------
-- Emergency (M5 FE-5)
-- ---------------------------------------------------------------------------

-- Escalation ownership: the phone owns an alert until it has the server's
-- receipt; from then on the server owns it and escalates to the secondary
-- contact. A synced phone-owned alert is not escalated again.
ALTER TABLE emergency_alerts ADD COLUMN owner text NOT NULL DEFAULT 'phone'
  CHECK (owner IN ('phone', 'server'));
ALTER TABLE emergency_alerts ADD COLUMN server_owned_at timestamptz;
ALTER TABLE emergency_alerts ADD CONSTRAINT emergency_alerts_owner_time
  CHECK ((owner = 'server') = (server_owned_at IS NOT NULL));

-- ---------------------------------------------------------------------------
-- ANC and records (M6 FE-2, FE-3)
-- ---------------------------------------------------------------------------

-- Haemoglobin confirmed by the LHW from a scanned or typed report, in g/dL.
-- The anaemia flag is computed from it with the Clinical Rules Table.
ALTER TABLE health_documents ADD COLUMN verified_hb_g_dl numeric(4, 1) CHECK (verified_hb_g_dl > 0);
ALTER TABLE health_documents ADD COLUMN hb_measured_on date;
ALTER TABLE health_documents ADD CONSTRAINT health_documents_hb_date_needs_value
  CHECK (verified_hb_g_dl IS NOT NULL OR hb_measured_on IS NULL);

-- Trends are now computed on the phone in Dart (M6 FE-3, Tools table), so the
-- server-side trend results table is no longer part of the data model.
DROP TABLE trend_results;

-- ---------------------------------------------------------------------------
-- Pregnancy outcomes (M6 FE-4)
-- ---------------------------------------------------------------------------

-- Closes the pregnancy file. A live birth creates one child per baby; a
-- stillbirth or miscarriage creates none (boundary in the Clinical Rules Table,
-- so rules_version is stored); a maternal death is flagged for supervisor review.
-- Synced table.
CREATE TABLE pregnancy_outcomes (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq            bigint NOT NULL,
  area_id               uuid NOT NULL REFERENCES areas (id),
  created_by            uuid NOT NULL REFERENCES users (id),
  created_on_device     timestamptz,
  synced_at             timestamptz NOT NULL,
  deleted_at            timestamptz,
  pregnancy_id          uuid NOT NULL REFERENCES pregnancies (id),
  outcome_type          text NOT NULL CHECK (outcome_type IN (
                          'live_birth', 'stillbirth', 'miscarriage', 'maternal_death',
                          'moved_out', 'lost_to_follow_up')),
  outcome_on            date NOT NULL,
  place                 text CHECK (place IN ('home', 'health_facility', 'other')),
  gestational_age_weeks smallint CHECK (gestational_age_weeks BETWEEN 1 AND 45),
  needs_review          boolean NOT NULL DEFAULT false,   -- set for a maternal death
  rules_version         text,
  CHECK (outcome_type <> 'maternal_death' OR needs_review)
);

CREATE UNIQUE INDEX pregnancy_outcomes_one_per_pregnancy ON pregnancy_outcomes (pregnancy_id) WHERE deleted_at IS NULL;

CREATE TRIGGER pregnancy_outcomes_server_seq BEFORE INSERT OR UPDATE ON pregnancy_outcomes FOR EACH ROW EXECUTE FUNCTION assign_server_seq();
CREATE TRIGGER pregnancy_outcomes_no_hard_delete BEFORE DELETE ON pregnancy_outcomes FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE UNIQUE INDEX pregnancy_outcomes_server_seq_key ON pregnancy_outcomes (server_seq);
CREATE INDEX pregnancy_outcomes_area_seq_idx ON pregnancy_outcomes (area_id, server_seq);

-- ---------------------------------------------------------------------------
-- Children: the child register (M8 FE-1, M6 FE-4)
-- ---------------------------------------------------------------------------

-- Every child under 5 with caregiver and household. Newborns come from a
-- live-birth outcome (source 'outcome'); others are added by hand. A deceased
-- child's schedules and alerts stop.
ALTER TABLE children ADD COLUMN caregiver_name text;
ALTER TABLE children ADD COLUMN birth_weight_kg numeric(4, 2) CHECK (birth_weight_kg > 0);
ALTER TABLE children ADD COLUMN source text NOT NULL DEFAULT 'manual' CHECK (source IN ('outcome', 'manual'));
ALTER TABLE children ADD COLUMN pregnancy_outcome_id uuid REFERENCES pregnancy_outcomes (id);
ALTER TABLE children ADD COLUMN status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'deceased'));
ALTER TABLE children ADD COLUMN deceased_on date;
ALTER TABLE children ADD CONSTRAINT children_outcome_source
  CHECK ((source = 'outcome') = (pregnancy_outcome_id IS NOT NULL));
ALTER TABLE children ADD CONSTRAINT children_deceased_date
  CHECK ((status = 'deceased') = (deceased_on IS NOT NULL));

CREATE INDEX children_pregnancy_outcome_id_idx ON children (pregnancy_outcome_id);

-- ---------------------------------------------------------------------------
-- Polio (M7 FE-1–3)
-- ---------------------------------------------------------------------------

-- Each household in a round gets a status: all vaccinated, refusal or a
-- separate "not available" status. Both refusal and not available schedule a
-- revisit in the same round, so revisits now hang off the household status.
ALTER TABLE campaign_household_records RENAME TO campaign_household_status;
ALTER INDEX campaign_household_records_pkey RENAME TO campaign_household_status_pkey;
ALTER INDEX campaign_household_records_campaign_idx RENAME TO campaign_household_status_campaign_idx;
ALTER INDEX campaign_household_records_server_seq_key RENAME TO campaign_household_status_server_seq_key;
ALTER INDEX campaign_household_records_area_seq_idx RENAME TO campaign_household_status_area_seq_idx;
ALTER TRIGGER campaign_household_records_server_seq ON campaign_household_status RENAME TO campaign_household_status_server_seq;
ALTER TRIGGER campaign_household_records_no_hard_delete ON campaign_household_status RENAME TO campaign_household_status_no_hard_delete;
ALTER TABLE campaign_household_status ADD COLUMN status text NOT NULL
  CHECK (status IN ('all_vaccinated', 'refusal', 'not_available'));

ALTER TABLE refusals RENAME COLUMN campaign_household_record_id TO campaign_household_status_id;
ALTER TABLE refusals DROP CONSTRAINT refusals_reason_check;
ALTER TABLE refusals ADD CONSTRAINT refusals_reason_check
  CHECK (reason IN ('religious_concern', 'misinformation', 'past_reaction'));

ALTER TABLE revisits DROP COLUMN refusal_id;
ALTER TABLE revisits ADD COLUMN campaign_household_status_id uuid NOT NULL REFERENCES campaign_household_status (id);
CREATE INDEX revisits_household_status_idx ON revisits (campaign_household_status_id);

-- One row per child ticked as vaccinated in a round (OPV, campaign date), so
-- "No OPV dose recorded" can be checked per child. Synced table.
CREATE TABLE campaign_child_doses (
  id                           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq                   bigint NOT NULL,
  area_id                      uuid NOT NULL REFERENCES areas (id),
  created_by                   uuid NOT NULL REFERENCES users (id),
  created_on_device            timestamptz,
  synced_at                    timestamptz NOT NULL,
  deleted_at                   timestamptz,
  campaign_id                  uuid NOT NULL REFERENCES campaigns (id),
  campaign_household_status_id uuid NOT NULL REFERENCES campaign_household_status (id),
  child_id                     uuid NOT NULL REFERENCES children (id),
  vaccine_type                 text NOT NULL DEFAULT 'OPV' CHECK (vaccine_type = 'OPV'),
  given_on                     date NOT NULL
);

CREATE UNIQUE INDEX campaign_child_doses_one_per_round ON campaign_child_doses (campaign_id, child_id) WHERE deleted_at IS NULL;
CREATE INDEX campaign_child_doses_child_id_idx ON campaign_child_doses (child_id);

CREATE TRIGGER campaign_child_doses_server_seq BEFORE INSERT OR UPDATE ON campaign_child_doses FOR EACH ROW EXECUTE FUNCTION assign_server_seq();
CREATE TRIGGER campaign_child_doses_no_hard_delete BEFORE DELETE ON campaign_child_doses FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE UNIQUE INDEX campaign_child_doses_server_seq_key ON campaign_child_doses (server_seq);
CREATE INDEX campaign_child_doses_area_seq_idx ON campaign_child_doses (area_id, server_seq);

-- ---------------------------------------------------------------------------
-- Immunisation (M8 FE-1)
-- ---------------------------------------------------------------------------

-- Server copy of the EPI schedule from the Clinical Rules Table: for each dose
-- its number, minimum age, recommended age, minimum interval from the previous
-- dose, maximum age where applicable, schedule version and effective date.
-- Ages are intervals, so "9 months" stays calendar months. rollout_by_area marks
-- doses switched on per area (for example the Hep B birth dose).
ALTER TABLE epi_schedule DROP CONSTRAINT epi_schedule_config_version_antigen_key;
ALTER TABLE epi_schedule DROP COLUMN due_age_days;
ALTER TABLE epi_schedule ADD COLUMN dose_number smallint NOT NULL CHECK (dose_number >= 0);
ALTER TABLE epi_schedule ADD COLUMN min_age interval NOT NULL CHECK (min_age >= interval '0');
ALTER TABLE epi_schedule ADD COLUMN recommended_age interval NOT NULL;
ALTER TABLE epi_schedule ADD COLUMN min_interval interval CHECK (min_interval > interval '0');
ALTER TABLE epi_schedule ADD COLUMN max_age interval;
ALTER TABLE epi_schedule ADD COLUMN effective_from date NOT NULL;
ALTER TABLE epi_schedule ADD COLUMN rollout_by_area boolean NOT NULL DEFAULT false;
ALTER TABLE epi_schedule ADD CONSTRAINT epi_schedule_dose_key UNIQUE (config_version, antigen, dose_number);
ALTER TABLE epi_schedule ADD CONSTRAINT epi_schedule_ages
  CHECK (min_age <= recommended_age AND (max_age IS NULL OR max_age >= recommended_age));

-- Each routine dose stores its dose number and the schedule version it was
-- recorded under. Campaign OPV doses stay in Module 7.
DROP INDEX immunisations_dose_key;
ALTER TABLE immunisations ADD COLUMN dose_number smallint NOT NULL CHECK (dose_number >= 0);
ALTER TABLE immunisations ADD COLUMN schedule_version text NOT NULL;
CREATE UNIQUE INDEX immunisations_dose_key ON immunisations (child_id, antigen, dose_number) WHERE deleted_at IS NULL;

-- ---------------------------------------------------------------------------
-- Nutrition (M9 FE-1)
-- ---------------------------------------------------------------------------

-- Bilateral pitting oedema makes the child SAM regardless of MUAC, so the stored
-- class is the acute malnutrition class from MUAC and oedema together. The
-- scope has no wasting classification.
ALTER TABLE nutrition_screenings ADD COLUMN oedema boolean;
ALTER TABLE nutrition_screenings RENAME COLUMN muac_class TO malnutrition_class;
ALTER TABLE nutrition_screenings DROP COLUMN wasting;

-- ---------------------------------------------------------------------------
-- Supervision (M10 FE-4)
-- ---------------------------------------------------------------------------

-- Leave and campaign weeks a supervisor marks for an LHW; inactivity detection
-- skips them. Weeks start on Monday. Server-only.
CREATE TABLE leave_and_campaign_weeks (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lhw_user_id uuid NOT NULL REFERENCES users (id),
  week_start  date NOT NULL CHECK (extract(isodow FROM week_start) = 1),
  kind        text NOT NULL CHECK (kind IN ('leave', 'campaign')),
  marked_by   uuid NOT NULL REFERENCES users (id),
  created_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz
);

CREATE UNIQUE INDEX leave_and_campaign_weeks_one_per_week ON leave_and_campaign_weeks (lhw_user_id, week_start) WHERE deleted_at IS NULL;

CREATE TRIGGER leave_and_campaign_weeks_no_hard_delete BEFORE DELETE ON leave_and_campaign_weeks FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();

-- Down Migration

DROP TABLE leave_and_campaign_weeks;

ALTER TABLE nutrition_screenings ADD COLUMN wasting boolean;
ALTER TABLE nutrition_screenings RENAME COLUMN malnutrition_class TO muac_class;
ALTER TABLE nutrition_screenings DROP COLUMN oedema;

DROP INDEX immunisations_dose_key;
ALTER TABLE immunisations DROP COLUMN schedule_version;
ALTER TABLE immunisations DROP COLUMN dose_number;
CREATE UNIQUE INDEX immunisations_dose_key ON immunisations (child_id, antigen) WHERE deleted_at IS NULL;

ALTER TABLE epi_schedule DROP CONSTRAINT epi_schedule_ages;
ALTER TABLE epi_schedule DROP CONSTRAINT epi_schedule_dose_key;
ALTER TABLE epi_schedule DROP COLUMN rollout_by_area;
ALTER TABLE epi_schedule DROP COLUMN effective_from;
ALTER TABLE epi_schedule DROP COLUMN max_age;
ALTER TABLE epi_schedule DROP COLUMN min_interval;
ALTER TABLE epi_schedule DROP COLUMN recommended_age;
ALTER TABLE epi_schedule DROP COLUMN min_age;
ALTER TABLE epi_schedule DROP COLUMN dose_number;
ALTER TABLE epi_schedule ADD COLUMN due_age_days integer NOT NULL CHECK (due_age_days >= 0);
ALTER TABLE epi_schedule ADD CONSTRAINT epi_schedule_config_version_antigen_key UNIQUE (config_version, antigen);

DROP TABLE campaign_child_doses;

DROP INDEX revisits_household_status_idx;
ALTER TABLE revisits DROP COLUMN campaign_household_status_id;
ALTER TABLE revisits ADD COLUMN refusal_id uuid NOT NULL REFERENCES refusals (id);
CREATE INDEX revisits_refusal_id_idx ON revisits (refusal_id);

ALTER TABLE refusals DROP CONSTRAINT refusals_reason_check;
ALTER TABLE refusals ADD CONSTRAINT refusals_reason_check
  CHECK (reason IN ('religious_concern', 'misinformation', 'past_reaction', 'absent_family'));
ALTER TABLE refusals RENAME COLUMN campaign_household_status_id TO campaign_household_record_id;

ALTER TABLE campaign_household_status DROP COLUMN status;
ALTER TRIGGER campaign_household_status_no_hard_delete ON campaign_household_status RENAME TO campaign_household_records_no_hard_delete;
ALTER TRIGGER campaign_household_status_server_seq ON campaign_household_status RENAME TO campaign_household_records_server_seq;
ALTER INDEX campaign_household_status_area_seq_idx RENAME TO campaign_household_records_area_seq_idx;
ALTER INDEX campaign_household_status_server_seq_key RENAME TO campaign_household_records_server_seq_key;
ALTER INDEX campaign_household_status_campaign_idx RENAME TO campaign_household_records_campaign_idx;
ALTER INDEX campaign_household_status_pkey RENAME TO campaign_household_records_pkey;
ALTER TABLE campaign_household_status RENAME TO campaign_household_records;

DROP INDEX children_pregnancy_outcome_id_idx;
ALTER TABLE children DROP CONSTRAINT children_deceased_date;
ALTER TABLE children DROP CONSTRAINT children_outcome_source;
ALTER TABLE children DROP COLUMN deceased_on;
ALTER TABLE children DROP COLUMN status;
ALTER TABLE children DROP COLUMN pregnancy_outcome_id;
ALTER TABLE children DROP COLUMN source;
ALTER TABLE children DROP COLUMN birth_weight_kg;
ALTER TABLE children DROP COLUMN caregiver_name;

DROP TABLE pregnancy_outcomes;

CREATE TABLE trend_results (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_seq        bigint NOT NULL,
  area_id           uuid NOT NULL REFERENCES areas (id),
  created_by        uuid REFERENCES users (id),
  created_on_device timestamptz,
  synced_at         timestamptz NOT NULL,
  deleted_at        timestamptz,
  pregnancy_id      uuid NOT NULL REFERENCES pregnancies (id),
  computed_at       timestamptz NOT NULL DEFAULT now(),
  vital_slopes      jsonb NOT NULL DEFAULT '{}',
  anomalies         jsonb NOT NULL DEFAULT '[]',
  compliance_score  numeric(5, 2) CHECK (compliance_score BETWEEN 0 AND 100)
);
CREATE INDEX trend_results_pregnancy_id_idx ON trend_results (pregnancy_id);
CREATE TRIGGER trend_results_server_seq BEFORE INSERT OR UPDATE ON trend_results FOR EACH ROW EXECUTE FUNCTION assign_server_seq();
CREATE TRIGGER trend_results_no_hard_delete BEFORE DELETE ON trend_results FOR EACH ROW EXECUTE FUNCTION prevent_hard_delete();
CREATE UNIQUE INDEX trend_results_server_seq_key ON trend_results (server_seq);
CREATE INDEX trend_results_area_seq_idx ON trend_results (area_id, server_seq);

ALTER TABLE health_documents DROP CONSTRAINT health_documents_hb_date_needs_value;
ALTER TABLE health_documents DROP COLUMN hb_measured_on;
ALTER TABLE health_documents DROP COLUMN verified_hb_g_dl;

ALTER TABLE emergency_alerts DROP CONSTRAINT emergency_alerts_owner_time;
ALTER TABLE emergency_alerts DROP COLUMN server_owned_at;
ALTER TABLE emergency_alerts DROP COLUMN owner;

DROP TABLE risk_flags;

ALTER TABLE risk_assessments DROP CONSTRAINT risk_assessments_rule_result_check;
ALTER TABLE risk_assessments ADD CONSTRAINT risk_assessments_rule_result_check
  CHECK (rule_result IN ('none', 'emergency'));
ALTER TABLE risk_assessments DROP COLUMN input_set;

ALTER TABLE visits DROP CONSTRAINT visits_blood_sugar_details_need_value;
ALTER TABLE visits DROP COLUMN blood_sugar_source;
ALTER TABLE visits DROP COLUMN blood_sugar_measured_on;
ALTER TABLE visits DROP COLUMN blood_sugar_entered_unit;
ALTER TABLE visits DROP COLUMN fever_with_weakness;
ALTER TABLE visits DROP COLUMN fast_breathing;
ALTER TABLE visits DROP COLUMN severe_abdominal_pain;
ALTER TABLE visits DROP COLUMN blurred_vision;
ALTER TABLE visits DROP COLUMN severe_headache;
ALTER TABLE visits DROP COLUMN convulsions;

DROP TABLE clinical_rules_versions;

ALTER TABLE devices DROP COLUMN activated_at;
ALTER TABLE devices DROP COLUMN activation_secret_ref;

DROP TABLE activation_codes;
