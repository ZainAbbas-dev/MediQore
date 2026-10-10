// P0-11: loading the Clinical Rules Table into the server. Run after `npm run migrate:up`.
const { describe, test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { Client } = require('pg');
const { loadClinicalRules, TABLE_FILE } = require('../seeds/clinical-rules');

const envFile = path.join(__dirname, '..', '.env');
if (fs.existsSync(envFile)) process.loadEnvFile(envFile);

describe('Clinical Rules Table loader', () => {
  let client;
  const text = fs.readFileSync(TABLE_FILE, 'utf8');
  const table = JSON.parse(text);
  // A version no real table uses, so the test never meets a loaded copy.
  const testText = text.replace(`"version": "${table.version}"`, '"version": "0.0.0-test"');

  before(async () => {
    assert.ok(process.env.DATABASE_URL, 'Set DATABASE_URL (see db/.env.example) and run npm run migrate:up first');
    client = new Client({ connectionString: process.env.DATABASE_URL });
    await client.connect();
  });

  after(async () => {
    await client?.end();
  });

  // loadClinicalRules commits its own transaction, so each test removes what it added.
  async function cleanUp() {
    await client.query(`DELETE FROM epi_schedule WHERE config_version = $1
      AND NOT EXISTS (SELECT 1 FROM clinical_rules_versions WHERE version <> '0.0.0-test' AND content->'epi_schedule'->>'schedule_version' = $1)`,
    [table.epi_schedule.schedule_version]);
    await client.query(`DELETE FROM clinical_rules_versions WHERE version = '0.0.0-test'`);
  }

  test('stores the version as pending clinical review, with its hash and EPI doses', async (t) => {
    t.after(cleanUp);
    assert.deepEqual(await loadClinicalRules(client, testText), { version: '0.0.0-test', loaded: true });
    const { rows: [row] } = await client.query(
      `SELECT review_status, content_sha256, content->>'status' AS status, signed_by FROM clinical_rules_versions WHERE version = '0.0.0-test'`,
    );
    assert.equal(row.review_status, 'pending_clinical_review');
    assert.equal(row.status, 'pending clinical review');
    assert.match(row.content_sha256, /^[0-9a-f]{64}$/);
    assert.equal(row.signed_by, null);

    const { rows: doses } = await client.query(
      `SELECT antigen, dose_number, recommended_age::text AS age, min_interval::text AS gap, rollout_by_area
       FROM epi_schedule WHERE config_version = $1`,
      [table.epi_schedule.schedule_version],
    );
    assert.equal(doses.length, table.epi_schedule.doses.length);
    const mr1 = doses.find((d) => d.antigen === 'MR' && d.dose_number === 1);
    assert.equal(mr1.age, '9 mons');
    const penta2 = doses.find((d) => d.antigen === 'Penta' && d.dose_number === 2);
    assert.equal(penta2.age, '70 days');
    assert.equal(penta2.gap, '28 days');
    assert.equal(doses.find((d) => d.antigen === 'HepB').rollout_by_area, true);
  });

  test('loading the same version again changes nothing', async (t) => {
    t.after(cleanUp);
    await loadClinicalRules(client, testText);
    assert.deepEqual(await loadClinicalRules(client, testText), { version: '0.0.0-test', loaded: false });
  });

  test('a changed table under the same version is refused', async (t) => {
    t.after(cleanUp);
    await loadClinicalRules(client, testText);
    const changed = testText.replace('"stillbirth_min_gestational_weeks": 28', '"stillbirth_min_gestational_weeks": 24');
    assert.notEqual(changed, testText);
    await assert.rejects(loadClinicalRules(client, changed), /already loaded with different content/);
  });
});
