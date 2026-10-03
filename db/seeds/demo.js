// Minimal synthetic accounts for the Phase 0 end-to-end check (P0-6): one area,
// an admin, a supervisor assigned to that area and one LHW in it. All names are
// made up (LI-10). The full synthetic data set is seeds/synthetic (P0-8).
//
//   npm run seed:demo                      (uses DATABASE_URL from db/.env)
//   DEMO_PASSWORD=... npm run seed:demo    (choose the demo password)
//
// Safe to run more than once: existing rows are kept. Never run it against the
// staging server; the demo password is for local development only.
const fs = require('node:fs');
const path = require('node:path');
const bcrypt = require('bcryptjs');
const { Client } = require('pg');

const envFile = path.join(__dirname, '..', '.env');
if (fs.existsSync(envFile)) process.loadEnvFile(envFile);

const PASSWORD = process.env.DEMO_PASSWORD || 'demo-password';

const USERS = [
  { username: 'admin.demo', fullName: 'Demo Admin', role: 'admin' },
  { username: 'supervisor.demo', fullName: 'Demo Supervisor', role: 'supervisor' },
  { username: 'lhw.demo', fullName: 'Demo LHW', role: 'lhw', lhwCode: 'LHW-DEMO-001' },
];

// Returns the id of the row found by `select`, inserting it first if missing.
async function findOrInsert(client, select, selectParams, insert, insertParams = selectParams) {
  const found = await client.query(select, selectParams);
  if (found.rows.length) return found.rows[0].id;
  const { rows } = await client.query(insert, insertParams);
  return rows[0].id;
}

async function main() {
  if (!process.env.DATABASE_URL) throw new Error('Set DATABASE_URL (see db/.env.example)');
  const client = new Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();
  try {
    await client.query('BEGIN');

    const districtId = await findOrInsert(client,
      'SELECT id FROM districts WHERE name = $1', ['Demo District'],
      'INSERT INTO districts (name) VALUES ($1) RETURNING id');
    const tehsilId = await findOrInsert(client,
      'SELECT id FROM tehsils WHERE district_id = $1 AND name = $2', [districtId, 'Demo Tehsil'],
      'INSERT INTO tehsils (district_id, name) VALUES ($1, $2) RETURNING id');
    const ucId = await findOrInsert(client,
      'SELECT id FROM union_councils WHERE tehsil_id = $1 AND name = $2', [tehsilId, 'Demo Union Council'],
      'INSERT INTO union_councils (tehsil_id, name) VALUES ($1, $2) RETURNING id');
    const areaId = await findOrInsert(client,
      'SELECT id FROM areas WHERE union_council_id = $1 AND name = $2', [ucId, 'Demo Area 1'],
      'INSERT INTO areas (union_council_id, name) VALUES ($1, $2) RETURNING id');

    const passwordHash = await bcrypt.hash(PASSWORD, 10);
    for (const user of USERS) {
      const userId = await findOrInsert(client,
        'SELECT id FROM users WHERE lower(username) = lower($1)', [user.username],
        'INSERT INTO users (username, full_name, role, password_hash) VALUES ($1, $2, $3, $4) RETURNING id',
        [user.username, user.fullName, user.role, passwordHash]);

      if (user.role === 'lhw') {
        await client.query(
          `INSERT INTO lhw_profiles (user_id, lhw_code, area_id) VALUES ($1, $2, $3)
           ON CONFLICT (user_id) DO NOTHING`,
          [userId, user.lhwCode, areaId]);
      }
      if (user.role === 'supervisor') {
        await client.query(
          `INSERT INTO supervisor_areas (supervisor_id, area_id) VALUES ($1, $2)
           ON CONFLICT (supervisor_id, area_id) WHERE deleted_at IS NULL DO NOTHING`,
          [userId, areaId]);
      }
    }

    await client.query('COMMIT');
    console.log(`Demo data ready in "Demo Area 1". Users: ${USERS.map((u) => u.username).join(', ')}`);
    console.log(process.env.DEMO_PASSWORD ? 'Password: the DEMO_PASSWORD you set.' : `Password: ${PASSWORD}`);
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    await client.end();
  }
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
