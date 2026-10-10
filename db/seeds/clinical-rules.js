// P0-11, M4 FE-4: loads the Clinical Rules Table (clinical-rules/clinical-rules.json)
// into clinical_rules_versions, and its EPI schedule into epi_schedule, so the
// server knows every version that results refer to (LI-12).
//
//   npm run rules:load        (uses DATABASE_URL from db/.env)
//
// Safe to run more than once. A version is never changed once loaded: if the
// file's content differs from the stored copy of the same version, the load
// stops and asks for a new version number.
const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
const { Client } = require('pg');

const envFile = path.join(__dirname, '..', '.env');
if (fs.existsSync(envFile)) process.loadEnvFile(envFile);

const TABLE_FILE = path.join(__dirname, '..', '..', 'clinical-rules', 'clinical-rules.json');

const REVIEW_STATUS = { 'pending clinical review': 'pending_clinical_review', signed: 'signed' };

// { "weeks": 6 } -> '6 weeks', for a PostgreSQL interval.
function interval(duration) {
  if (duration === null) return null;
  const [[unit, n]] = Object.entries(duration);
  return `${n} ${unit}`;
}

// Loads the table text (the file's exact bytes are hashed). Returns
// { version, loaded } where loaded is false when that version was already there.
async function loadClinicalRules(client, text = fs.readFileSync(TABLE_FILE, 'utf8')) {
  const table = JSON.parse(text);
  const sha256 = crypto.createHash('sha256').update(text).digest('hex');
  const reviewStatus = REVIEW_STATUS[table.status];
  if (!reviewStatus) throw new Error(`Unknown Clinical Rules Table status "${table.status}"`);

  const existing = await client.query('SELECT content_sha256 FROM clinical_rules_versions WHERE version = $1', [table.version]);
  if (existing.rows.length) {
    if (existing.rows[0].content_sha256 !== sha256) {
      throw new Error(`Clinical Rules Table ${table.version} is already loaded with different content: give the changed table a new version`);
    }
    return { version: table.version, loaded: false };
  }

  await client.query('BEGIN');
  try {
    await client.query(
      `INSERT INTO clinical_rules_versions (version, review_status, content, content_sha256, effective_from, signed_by, signed_on)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [table.version, reviewStatus, text, sha256, table.effective_from, table.sign_off.clinical_advisor, table.sign_off.signed_on],
    );
    const epi = table.epi_schedule;
    for (const dose of epi.doses) {
      await client.query(
        `INSERT INTO epi_schedule (config_version, antigen, dose_number, min_age, recommended_age, min_interval, max_age,
           effective_from, rollout_by_area)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
         ON CONFLICT (config_version, antigen, dose_number) DO NOTHING`,
        [
          epi.schedule_version, dose.antigen, dose.dose_number, interval(dose.min_age), interval(dose.recommended_age),
          interval(dose.min_interval), interval(dose.max_age), epi.effective_from, dose.rollout_by_area,
        ],
      );
    }
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  }
  return { version: table.version, loaded: true };
}

async function main() {
  if (!process.env.DATABASE_URL) throw new Error('Set DATABASE_URL (see db/.env.example)');
  const client = new Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();
  try {
    const { version, loaded } = await loadClinicalRules(client);
    console.log(loaded ? `Loaded Clinical Rules Table ${version}.` : `Clinical Rules Table ${version} is already loaded.`);
  } finally {
    await client.end();
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message);
    process.exitCode = 1;
  });
}

module.exports = { loadClinicalRules, TABLE_FILE };
