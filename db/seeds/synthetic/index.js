// LI-10: synthetic data generator (P0-8), command line.
//
//   npm run seed:synthetic                         (DATABASE_URL from db/.env)
//   npm run seed:synthetic -- --seed 7 --households 40
//   npm run seed:synthetic -- --help
//
// Everything it writes is made up. The same --seed always gives the same data.
const fs = require('node:fs');
const path = require('node:path');
const { parseArgs } = require('node:util');
const { Client } = require('pg');
const { generateSynthetic, DEFAULTS } = require('./generate');
const { DISTRICTS } = require('./names');

const envFile = path.join(__dirname, '..', '..', '.env');
if (fs.existsSync(envFile)) process.loadEnvFile(envFile);

const HELP = `Usage: npm run seed:synthetic -- [options]

  --seed <n>           random seed (default ${DEFAULTS.seed})
  --prefix <text>      marks every name and username (default "${DEFAULTS.prefix}")
  --districts <n>      1-${DISTRICTS.length} (default ${DEFAULTS.districts})
  --tehsils <n>        tehsils per district (default ${DEFAULTS.tehsilsPerDistrict})
  --ucs <n>            Union Councils per tehsil (default ${DEFAULTS.ucsPerTehsil})
  --areas <n>          areas per Union Council, one LHW each (default ${DEFAULTS.areasPerUc})
  --households <n>     households per LHW (default ${DEFAULTS.householdsPerLhw})
  --reset              empty every table first (local databases only)
  --allow-remote       allow a DATABASE_URL that is not on this computer, e.g. staging
  --help               show this text

Every account gets the password in SYNTHETIC_PASSWORD, or "${DEFAULTS.password}".`;

const LOCAL_HOSTS = new Set(['localhost', '127.0.0.1', '[::1]', '']);

function readOptions(argv) {
  const { values } = parseArgs({
    args: argv,
    options: {
      seed: { type: 'string' },
      prefix: { type: 'string' },
      districts: { type: 'string' },
      tehsils: { type: 'string' },
      ucs: { type: 'string' },
      areas: { type: 'string' },
      households: { type: 'string' },
      reset: { type: 'boolean', default: false },
      'allow-remote': { type: 'boolean', default: false },
      help: { type: 'boolean', default: false },
    },
  });
  const count = (name, min, max) => {
    if (values[name] === undefined) return undefined;
    const n = Number(values[name]);
    if (!Number.isInteger(n) || n < min || n > max) throw new Error(`--${name} must be a whole number from ${min} to ${max}`);
    return n;
  };
  const options = {
    seed: count('seed', 0, 2 ** 32 - 1),
    prefix: values.prefix,
    districts: count('districts', 1, DISTRICTS.length),
    tehsilsPerDistrict: count('tehsils', 1, 20),
    ucsPerTehsil: count('ucs', 1, 50),
    areasPerUc: count('areas', 1, 20),
    householdsPerLhw: count('households', 1, 500),
    password: process.env.SYNTHETIC_PASSWORD,
  };
  if (options.prefix !== undefined && !/^[a-z][a-z0-9]{0,9}$/.test(options.prefix)) {
    throw new Error('--prefix must be 1-10 lower-case letters or digits, starting with a letter');
  }
  return {
    help: values.help,
    reset: values.reset,
    allowRemote: values['allow-remote'],
    overrides: Object.fromEntries(Object.entries(options).filter(([, v]) => v !== undefined)),
  };
}

async function main() {
  const { help, reset, allowRemote, overrides } = readOptions(process.argv.slice(2));
  if (help) {
    console.log(HELP);
    return;
  }
  if (!process.env.DATABASE_URL) throw new Error('Set DATABASE_URL (see db/.env.example)');
  const host = new URL(process.env.DATABASE_URL).hostname;
  const local = LOCAL_HOSTS.has(host);
  if (!local && !allowRemote) {
    throw new Error(`DATABASE_URL points to "${host}". Add --allow-remote if you really mean to seed that server.`);
  }
  if (reset && !local) throw new Error('--reset only works on a database on this computer');

  const prefix = overrides.prefix || DEFAULTS.prefix;
  const client = new Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();
  try {
    await client.query('BEGIN');
    if (reset) {
      const { rows } = await client.query(
        `SELECT table_name FROM information_schema.tables
         WHERE table_schema = 'public' AND table_type = 'BASE TABLE' AND table_name <> 'pgmigrations'`,
      );
      await client.query(`TRUNCATE ${rows.map((r) => r.table_name).join(', ')} RESTART IDENTITY CASCADE`);
    } else {
      const { rowCount } = await client.query('SELECT 1 FROM users WHERE lower(username) = lower($1)', [`${prefix}.admin`]);
      if (rowCount) {
        throw new Error(`Synthetic data with prefix "${prefix}" is already loaded. Use another --prefix, or --reset to empty the local database first.`);
      }
    }

    const { counts, accounts } = await generateSynthetic(client, overrides);
    await client.query('COMMIT');

    console.log('Synthetic data loaded (LI-10: made-up records only).');
    for (const [table, n] of Object.entries(counts)) console.log(`  ${table.padEnd(18)} ${n}`);
    console.log(`Sign in as ${accounts.admin}, ${accounts.supervisors[0]} … ${accounts.supervisors.at(-1)} or ${accounts.lhws[0]} … ${accounts.lhws.at(-1)}.`);
    console.log(process.env.SYNTHETIC_PASSWORD ? 'Password: the SYNTHETIC_PASSWORD you set.' : `Password: ${accounts.password}`);
    if (reset) console.log('The database was emptied first; run npm run seed:demo again if you need the demo accounts.');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    await client.end();
  }
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message);
    process.exit(1);
  });
}

module.exports = { readOptions };
