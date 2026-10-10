// Checks schema v1 (P0-4) against the roadmap rules. Run after `npm run migrate:up`.
const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { Client } = require('pg');

const envFile = path.join(__dirname, '..', '.env');
if (fs.existsSync(envFile)) process.loadEnvFile(envFile);

// Tables that devices push or pull: they carry the sync base columns.
const SYNCED_TABLES = [
  'households', 'women', 'pregnancies', 'obstetric_history',
  'visits',
  'hospitals', 'referral_centres', 'escalation_contacts',
  'risk_assessments', 'risk_flags',
  'referrals', 'emergency_alerts', 'alert_attempts', 'alert_acknowledgements',
  'anc_schedule', 'tt_doses', 'supplement_logs', 'health_documents',
  'pregnancy_outcomes',
  'children',
  'campaigns', 'campaign_household_status', 'campaign_child_doses', 'refusals', 'revisits',
  'immunisations',
  'nutrition_screenings', 'sam_followups', 'imci_assessments',
];

const SERVER_ONLY_TABLES = [
  'districts', 'tehsils', 'union_councils', 'areas',
  'users', 'lhw_profiles', 'supervisor_areas', 'devices', 'activation_codes', 'refresh_tokens',
  'audit_log', 'sync_conflicts', 'report_jobs', 'clinical_rules_versions',
  'epi_schedule',
  'leave_and_campaign_weeks',
];

const BASE_COLUMNS = {
  id: 'uuid',
  server_seq: 'bigint',
  area_id: 'uuid',
  created_by: 'uuid',
  created_on_device: 'timestamp with time zone',
  synced_at: 'timestamp with time zone',
  deleted_at: 'timestamp with time zone',
};

describe('schema v1', () => {
  let client;

  before(async () => {
    assert.ok(process.env.DATABASE_URL, 'Set DATABASE_URL (see db/.env.example) and run npm run migrate:up first');
    client = new Client({ connectionString: process.env.DATABASE_URL });
    await client.connect();
  });

  after(async () => {
    await client?.end();
  });

  // Runs fn inside a transaction that is always rolled back, so tests leave no data behind.
  async function inRollback(fn) {
    await client.query('BEGIN');
    try {
      return await fn();
    } finally {
      await client.query('ROLLBACK');
    }
  }

  // Minimal rows every synced row depends on: geography and a user.
  async function insertArea() {
    const { rows: [district] } = await client.query(`INSERT INTO districts (name) VALUES ('Test District') RETURNING id`);
    const { rows: [tehsil] } = await client.query(`INSERT INTO tehsils (district_id, name) VALUES ($1, 'Test Tehsil') RETURNING id`, [district.id]);
    const { rows: [uc] } = await client.query(`INSERT INTO union_councils (tehsil_id, name) VALUES ($1, 'Test UC') RETURNING id`, [tehsil.id]);
    const { rows: [area] } = await client.query(`INSERT INTO areas (union_council_id, name) VALUES ($1, 'Test Area') RETURNING id`, [uc.id]);
    const { rows: [user] } = await client.query(
      `INSERT INTO users (role, username, full_name, password_hash) VALUES ('lhw', 'lhw-test', 'Test LHW', 'x') RETURNING id`,
    );
    return { areaId: area.id, userId: user.id };
  }

  async function insertHousehold({ areaId, userId }, extra = {}) {
    const { rows: [row] } = await client.query(
      `INSERT INTO households (id, area_id, created_by, created_on_device, village, server_seq)
       VALUES (coalesce($1, gen_random_uuid()), $2, $3, now(), 'Test village', $4)
       RETURNING id, server_seq, synced_at`,
      [extra.id ?? null, areaId, userId, extra.serverSeq ?? null],
    );
    return row;
  }

  test('every table in the data model exists, and nothing else', async () => {
    const { rows } = await client.query(
      `SELECT table_name FROM information_schema.tables
       WHERE table_schema = 'public' AND table_type = 'BASE TABLE' AND table_name <> 'pgmigrations'`,
    );
    const actual = rows.map((r) => r.table_name).sort();
    assert.deepEqual(actual, [...SYNCED_TABLES, ...SERVER_ONLY_TABLES].sort());
  });

  test('every synced table carries the base columns with the right types', async () => {
    const { rows } = await client.query(
      `SELECT table_name, column_name, data_type FROM information_schema.columns
       WHERE table_schema = 'public' AND table_name = ANY($1)`,
      [SYNCED_TABLES],
    );
    for (const table of SYNCED_TABLES) {
      for (const [column, type] of Object.entries(BASE_COLUMNS)) {
        const found = rows.find((r) => r.table_name === table && r.column_name === column);
        assert.ok(found, `${table}.${column} is missing`);
        assert.equal(found.data_type, type, `${table}.${column} should be ${type}`);
      }
    }
  });

  test('every synced table assigns server_seq and refuses hard deletes', async () => {
    const { rows } = await client.query(
      `SELECT c.relname AS table_name, p.proname AS function_name
       FROM pg_trigger t
       JOIN pg_class c ON c.oid = t.tgrelid
       JOIN pg_proc p ON p.oid = t.tgfoid
       WHERE NOT t.tgisinternal`,
    );
    for (const table of SYNCED_TABLES) {
      const functions = rows.filter((r) => r.table_name === table).map((r) => r.function_name);
      assert.ok(functions.includes('assign_server_seq'), `${table} has no server_seq trigger`);
      assert.ok(functions.includes('prevent_hard_delete'), `${table} has no soft-delete guard`);
    }
  });

  test('server_seq is assigned on insert and increases on every update', async () => {
    await inRollback(async () => {
      const ids = await insertArea();
      const first = await insertHousehold(ids);
      const second = await insertHousehold(ids);
      assert.ok(first.server_seq, 'server_seq not assigned');
      assert.ok(first.synced_at, 'synced_at not assigned');
      assert.ok(BigInt(second.server_seq) > BigInt(first.server_seq));

      const { rows: [updated] } = await client.query(
        `UPDATE households SET village = 'Moved' WHERE id = $1 RETURNING server_seq`,
        [first.id],
      );
      assert.ok(BigInt(updated.server_seq) > BigInt(second.server_seq), 'update did not bump server_seq');
    });
  });

  test('a server_seq sent by a device is ignored', async () => {
    await inRollback(async () => {
      const ids = await insertArea();
      const row = await insertHousehold(ids, { serverSeq: 1 });
      const { rows: [{ last_value: lastValue }] } = await client.query('SELECT last_value FROM sync_server_seq');
      assert.equal(String(row.server_seq), String(lastValue));
    });
  });

  test('writes to synced tables are serialised so server_seq follows commit order', async () => {
    const tryLock = `SELECT pg_try_advisory_xact_lock(hashtext('mediqore.sync_server_seq')) AS locked`;
    const other = new Client({ connectionString: process.env.DATABASE_URL });
    await other.connect();
    try {
      await inRollback(async () => {
        const ids = await insertArea();
        await insertHousehold(ids); // holds the sync lock until this transaction ends
        const { rows: [busy] } = await other.query(tryLock);
        assert.equal(busy.locked, false, 'a second writer must wait');
      });
      const { rows: [free] } = await other.query(tryLock);
      assert.equal(free.locked, true, 'the lock is released at rollback or commit');
    } finally {
      await other.end();
    }
  });

  test('the device-generated UUID is kept as the primary key', async () => {
    await inRollback(async () => {
      const ids = await insertArea();
      const deviceId = '0b7f8e2a-3c4d-4e5f-8a9b-1c2d3e4f5a6b';
      const row = await insertHousehold(ids, { id: deviceId });
      assert.equal(row.id, deviceId);
    });
  });

  test('hard deletes are refused; soft deletes work', async () => {
    await inRollback(async () => {
      const ids = await insertArea();
      const row = await insertHousehold(ids);
      await client.query('SAVEPOINT before_delete');
      await assert.rejects(client.query('DELETE FROM households WHERE id = $1', [row.id]), /soft-deleted only/);
      await client.query('ROLLBACK TO SAVEPOINT before_delete');

      const { rows: [deleted] } = await client.query(
        'UPDATE households SET deleted_at = now() WHERE id = $1 RETURNING deleted_at',
        [row.id],
      );
      assert.ok(deleted.deleted_at);
    });
  });

  test('audit_log is append-only', async () => {
    await inRollback(async () => {
      const { rows: [entry] } = await client.query(
        `INSERT INTO audit_log (action, entity_type, details) VALUES ('login', 'users', '{"result":"failed"}') RETURNING id`,
      );
      await client.query('SAVEPOINT before_change');
      await assert.rejects(client.query(`UPDATE audit_log SET action = 'edit' WHERE id = $1`, [entry.id]), /append-only/);
      await client.query('ROLLBACK TO SAVEPOINT before_change');
      await assert.rejects(client.query('DELETE FROM audit_log WHERE id = $1', [entry.id]), /append-only/);
    });
  });

  test('a woman can have only one active pregnancy', async () => {
    await inRollback(async () => {
      const ids = await insertArea();
      const household = await insertHousehold(ids);
      const { rows: [woman] } = await client.query(
        `INSERT INTO women (area_id, created_by, household_id, patient_code, name)
         VALUES ($1, $2, $3, 'LHW001-0001', 'Test Woman') RETURNING id`,
        [ids.areaId, ids.userId, household.id],
      );
      const insertPregnancy = () => client.query(
        `INSERT INTO pregnancies (area_id, created_by, woman_id, registered_on, pregnancy_month_at_registration)
         VALUES ($1, $2, $3, current_date, 4)`,
        [ids.areaId, ids.userId, woman.id],
      );
      await insertPregnancy();
      await assert.rejects(insertPregnancy(), /pregnancies_one_active_per_woman/);
    });
  });

  // Inserts a household, a woman and her active pregnancy; returns their ids.
  async function insertWomanWithPregnancy(ids) {
    const household = await insertHousehold(ids);
    const { rows: [woman] } = await client.query(
      `INSERT INTO women (area_id, created_by, household_id, patient_code, name)
       VALUES ($1, $2, $3, 'LHW001-0002', 'Test Woman') RETURNING id`,
      [ids.areaId, ids.userId, household.id],
    );
    const { rows: [pregnancy] } = await client.query(
      `INSERT INTO pregnancies (area_id, created_by, woman_id, registered_on, pregnancy_month_at_registration)
       VALUES ($1, $2, $3, current_date, 4) RETURNING id`,
      [ids.areaId, ids.userId, woman.id],
    );
    return { householdId: household.id, pregnancyId: pregnancy.id };
  }

  // Runs a statement that must fail, inside a savepoint so the test can go on.
  async function rejects(sql, params, pattern) {
    await client.query('SAVEPOINT expect_failure');
    await assert.rejects(client.query(sql, params), pattern);
    await client.query('ROLLBACK TO SAVEPOINT expect_failure');
  }

  test('blood sugar details need a value; the danger-sign checklist is stored (M3 FE-1)', async () => {
    await inRollback(async () => {
      const ids = await insertArea();
      const { pregnancyId } = await insertWomanWithPregnancy(ids);
      const insertVisit = (sugar, source) => client.query(
        `INSERT INTO visits (area_id, created_by, pregnancy_id, visited_at, pulse_bpm, blood_sugar_mmol_l,
           blood_sugar_entered_unit, blood_sugar_measured_on, blood_sugar_source, convulsions, fever_with_weakness)
         VALUES ($1, $2, $3, now(), 80, $4, 'mg_dl', current_date, $5, false, true) RETURNING convulsions, fever_with_weakness`,
        [ids.areaId, ids.userId, pregnancyId, sugar, source],
      );
      const { rows: [visit] } = await insertVisit(5.4, 'glucometer');
      assert.equal(visit.convulsions, false);
      assert.equal(visit.fever_with_weakness, true);
      await rejects(
        `INSERT INTO visits (area_id, created_by, pregnancy_id, visited_at, blood_sugar_source)
         VALUES ($1, $2, $3, now(), 'glucometer')`,
        [ids.areaId, ids.userId, pregnancyId],
        /visits_blood_sugar_details_need_value/,
      );
      await rejects(
        `INSERT INTO visits (area_id, created_by, pregnancy_id, visited_at, blood_sugar_mmol_l, blood_sugar_source)
         VALUES ($1, $2, $3, now(), 5.4, 'guess')`,
        [ids.areaId, ids.userId, pregnancyId],
        /blood_sugar_source_check/,
      );
    });
  });

  test('a child from a pregnancy outcome links to it; a deceased child has a date (M6 FE-4, M8 FE-1)', async () => {
    await inRollback(async () => {
      const ids = await insertArea();
      const { householdId, pregnancyId } = await insertWomanWithPregnancy(ids);
      const { rows: [outcome] } = await client.query(
        `INSERT INTO pregnancy_outcomes (area_id, created_by, pregnancy_id, outcome_type, outcome_on, place, rules_version)
         VALUES ($1, $2, $3, 'live_birth', current_date, 'health_facility', '0.1.0') RETURNING id`,
        [ids.areaId, ids.userId, pregnancyId],
      );
      const { rows: [child] } = await client.query(
        `INSERT INTO children (area_id, created_by, household_id, pregnancy_id, name, date_of_birth, sex,
           caregiver_name, birth_weight_kg, source, pregnancy_outcome_id)
         VALUES ($1, $2, $3, $4, 'Test Baby', current_date, 'female', 'Test Woman', 2.9, 'outcome', $5)
         RETURNING status`,
        [ids.areaId, ids.userId, householdId, pregnancyId, outcome.id],
      );
      assert.equal(child.status, 'active');
      await rejects(
        `INSERT INTO children (area_id, created_by, household_id, name, date_of_birth, sex, source)
         VALUES ($1, $2, $3, 'Test Child', current_date, 'male', 'outcome')`,
        [ids.areaId, ids.userId, householdId],
        /children_outcome_source/,
      );
      await rejects(
        `INSERT INTO children (area_id, created_by, household_id, name, date_of_birth, sex, status)
         VALUES ($1, $2, $3, 'Test Child', current_date, 'male', 'deceased')`,
        [ids.areaId, ids.userId, householdId],
        /children_deceased_date/,
      );
      await rejects(
        `INSERT INTO pregnancy_outcomes (area_id, created_by, pregnancy_id, outcome_type, outcome_on)
         VALUES ($1, $2, $3, 'stillbirth', current_date)`,
        [ids.areaId, ids.userId, pregnancyId],
        /pregnancy_outcomes_one_per_pregnancy/,
      );
    });
  });

  test('a maternal death is always flagged for review (M6 FE-4)', async () => {
    await inRollback(async () => {
      const ids = await insertArea();
      const { pregnancyId } = await insertWomanWithPregnancy(ids);
      await rejects(
        `INSERT INTO pregnancy_outcomes (area_id, created_by, pregnancy_id, outcome_type, outcome_on)
         VALUES ($1, $2, $3, 'maternal_death', current_date)`,
        [ids.areaId, ids.userId, pregnancyId],
        /pregnancy_outcomes_check/,
      );
    });
  });

  test('activation codes record the phone they activated; leave weeks start on Monday (M1 FE-2, M10 FE-4)', async () => {
    await inRollback(async () => {
      const ids = await insertArea();
      const { rows: [admin] } = await client.query(
        `INSERT INTO users (role, username, full_name, password_hash) VALUES ('admin', 'admin-test', 'Test Admin', 'x') RETURNING id`,
      );
      await client.query(
        `INSERT INTO activation_codes (user_id, code_hash, issued_by, expires_at)
         VALUES ($1, 'hash', $2, now() + interval '48 hours')`,
        [ids.userId, admin.id],
      );
      await rejects(
        `INSERT INTO activation_codes (user_id, code_hash, issued_by, expires_at, consumed_at)
         VALUES ($1, 'hash', $2, now() + interval '48 hours', now())`,
        [ids.userId, admin.id],
        /activation_codes_check/,
      );
      await client.query(
        `INSERT INTO leave_and_campaign_weeks (lhw_user_id, week_start, kind, marked_by)
         VALUES ($1, date '2027-01-04', 'leave', $2)`,
        [ids.userId, admin.id],
      );
      await rejects(
        `INSERT INTO leave_and_campaign_weeks (lhw_user_id, week_start, kind, marked_by)
         VALUES ($1, date '2027-01-05', 'campaign', $2)`,
        [ids.userId, admin.id],
        /leave_and_campaign_weeks_week_start_check/,
      );
    });
  });

  test('a signed Clinical Rules Table version names who signed it (LI-12)', async () => {
    await inRollback(async () => {
      const insert = (status, signer) => client.query(
        `INSERT INTO clinical_rules_versions (version, review_status, content, content_sha256, effective_from, signed_by, signed_on)
         VALUES ($1, $2, '{}', repeat('a', 64), current_date, $3, CASE WHEN $3::text IS NULL THEN NULL ELSE current_date END)`,
        [`test-${status}`, status, signer],
      );
      await insert('pending_clinical_review', null);
      await insert('signed', 'Test Advisor');
      await rejects(
        `INSERT INTO clinical_rules_versions (version, review_status, content, content_sha256, effective_from)
         VALUES ('test-unsigned', 'signed', '{}', repeat('a', 64), current_date)`,
        [],
        /clinical_rules_versions_check/,
      );
    });
  });
});
