const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('../src/db/pool');

const hasTestDatabase = Boolean(process.env.TEST_DATABASE_URL);

// describe() for suites that need PostgreSQL; skipped when TEST_DATABASE_URL is not set.
const describeDb = hasTestDatabase ? describe : describe.skip;

const PASSWORD = 'correct-horse';

// Empties every table. Refuses to run unless the database name ends in "_test".
async function resetDatabase() {
  const { rows: [{ name }] } = await db.query('SELECT current_database() AS name');
  if (!name.endsWith('_test')) {
    throw new Error(`Refusing to empty database "${name}": test databases must end in _test`);
  }
  const { rows } = await db.query(
    `SELECT table_name FROM information_schema.tables
     WHERE table_schema = 'public' AND table_type = 'BASE TABLE' AND table_name <> 'pgmigrations'`,
  );
  await db.query(`TRUNCATE ${rows.map((r) => r.table_name).join(', ')} RESTART IDENTITY CASCADE`);
  await db.query('ALTER SEQUENCE lhw_code_seq RESTART WITH 1');
}

async function insertArea(name) {
  const { rows: [district] } = await db.query(`INSERT INTO districts (name) VALUES ($1) RETURNING id`, [`${name} District`]);
  const { rows: [tehsil] } = await db.query(`INSERT INTO tehsils (district_id, name) VALUES ($1, 'T') RETURNING id`, [district.id]);
  const { rows: [uc] } = await db.query(`INSERT INTO union_councils (tehsil_id, name) VALUES ($1, 'UC') RETURNING id`, [tehsil.id]);
  const { rows: [area] } = await db.query(`INSERT INTO areas (union_council_id, name) VALUES ($1, $2) RETURNING id`, [uc.id, name]);
  return area.id;
}

async function insertUser(username, role, { isActive = true } = {}) {
  const hash = await bcrypt.hash(PASSWORD, 4);
  const { rows: [user] } = await db.query(
    `INSERT INTO users (username, full_name, role, password_hash, is_active)
     VALUES ($1, $2, $3, $4, $5) RETURNING id`,
    [username, `Test ${username}`, role, hash, isActive],
  );
  return user.id;
}

// A phone already approved with a one-time code (M1 FE-2).
async function insertApprovedDevice(userId) {
  const { rows: [device] } = await db.query(
    'INSERT INTO devices (id, user_id, verified_at) VALUES (gen_random_uuid(), $1, now()) RETURNING id',
    [userId],
  );
  return device.id;
}

// Two areas, an LHW in each with an approved phone, a supervisor for area A,
// an admin and an inactive LHW.
async function createFixtures() {
  const areaA = await insertArea('Area A');
  const areaB = await insertArea('Area B');
  const lhwA = await insertUser('lhw.a', 'lhw');
  const lhwB = await insertUser('lhw.b', 'lhw');
  const inactiveLhw = await insertUser('lhw.inactive', 'lhw', { isActive: false });
  const supervisorA = await insertUser('supervisor.a', 'supervisor');
  const admin = await insertUser('admin', 'admin');
  await db.query(
    `INSERT INTO lhw_profiles (user_id, lhw_code, area_id) VALUES ($1, 'LHW-A', $3), ($2, 'LHW-B', $4)`,
    [lhwA, lhwB, areaA, areaB],
  );
  await db.query('INSERT INTO supervisor_areas (supervisor_id, area_id) VALUES ($1, $2)', [supervisorA, areaA]);
  const deviceA = await insertApprovedDevice(lhwA);
  const deviceB = await insertApprovedDevice(lhwB);
  return { areaA, areaB, lhwA, lhwB, inactiveLhw, supervisorA, admin, deviceA, deviceB };
}

// Signs an access token directly, for tests that are not about login itself.
// App tokens carry the phone they were issued to (`did`).
function tokenFor(userId, role, deviceId) {
  const claims = deviceId ? { role, did: deviceId } : { role };
  return jwt.sign(claims, process.env.JWT_ACCESS_SECRET, { subject: userId, expiresIn: '5m' });
}

module.exports = {
  describeDb, resetDatabase, createFixtures, insertArea, insertUser, insertApprovedDevice, tokenFor,
  closePool: db.closePool, query: db.query, PASSWORD,
};
