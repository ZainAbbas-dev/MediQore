// LI-10: synthetic data generator (P0-8). Builds made-up districts, Union
// Councils, areas, accounts, households with GPS, pregnant women, visits and a
// few visits waiting in the conflict queue (M3 FE-2), so
// all development, testing and demos run without real patient data.
//
// generateSynthetic(client, options) inserts everything through `client`; the
// caller owns the transaction. Each module of the app adds its own step below
// (definition of done: "synthetic data for the module added to the seed script").
const bcrypt = require('bcryptjs');
const { createRandom } = require('./random');
const geography = require('./steps/geography');
const accounts = require('./steps/accounts');
const households = require('./steps/households');
const maternal = require('./steps/maternal');
const conflicts = require('./steps/conflicts');

const DEFAULTS = {
  seed: 1,
  prefix: 'syn', // marks every generated name and username, e.g. syn.lhw.001
  districts: 2,
  tehsilsPerDistrict: 2,
  ucsPerTehsil: 2,
  areasPerUc: 2,
  householdsPerLhw: 25,
  password: 'demo-password',
  now: undefined, // defaults to the current time
};

// Inserts row objects in chunks, one parameterised statement per chunk.
async function insertRows(client, table, rows) {
  if (!rows.length) return;
  const columns = Object.keys(rows[0]);
  const chunkSize = Math.floor(60000 / columns.length);
  for (let start = 0; start < rows.length; start += chunkSize) {
    const chunk = rows.slice(start, start + chunkSize);
    const params = [];
    const tuples = chunk.map((row, r) => {
      params.push(...columns.map((column) => row[column]));
      return `(${columns.map((_, c) => `$${r * columns.length + c + 1}`).join(', ')})`;
    });
    await client.query(`INSERT INTO ${table} (${columns.join(', ')}) VALUES ${tuples.join(', ')}`, params);
  }
}

// Builds every row in memory, without touching the database. The same seed,
// `now` and password hash always give exactly the same rows.
function buildSynthetic(overrides, passwordHash) {
  const options = { ...DEFAULTS, ...overrides };
  const ctx = {
    options,
    random: createRandom(options.seed),
    now: options.now ? new Date(options.now) : new Date(),
    passwordHash,
  };

  const geo = geography.build(ctx);
  const people = accounts.build(ctx, geo);
  const homes = households.build(ctx, people.lhws);
  const pregnant = maternal.build(ctx, homes);
  const held = conflicts.build(ctx, pregnant);

  // In insert order: parents before children.
  const tables = [
    ['districts', geo.districts],
    ['tehsils', geo.tehsils],
    ['union_councils', geo.unionCouncils],
    ['areas', geo.areas],
    ['users', people.users],
    ['lhw_profiles', people.lhwProfiles],
    ['supervisor_areas', people.supervisorAreas],
    ['households', homes.rows],
    ['women', pregnant.women],
    ['pregnancies', pregnant.pregnancies],
    ['obstetric_history', pregnant.obstetricHistory],
    ['visits', pregnant.visits],
    ['sync_conflicts', held.conflicts],
  ];
  return { tables, accounts: people.summary };
}

async function generateSynthetic(client, overrides = {}) {
  const password = overrides.password || DEFAULTS.password;
  const { tables, accounts: summary } = buildSynthetic(overrides, await bcrypt.hash(password, 10));
  for (const [table, rows] of tables) {
    await insertRows(client, table, rows);
  }
  return {
    counts: Object.fromEntries(tables.map(([table, rows]) => [table, rows.length])),
    accounts: summary,
  };
}

module.exports = { generateSynthetic, buildSynthetic, DEFAULTS };
