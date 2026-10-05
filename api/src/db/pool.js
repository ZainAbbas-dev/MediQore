const { Pool, types } = require('pg');
const config = require('../config');
const logger = require('../utils/logger');

// DATE columns (for example a pregnancy's registered_on) come back as the text
// the database holds, YYYY-MM-DD, instead of a JavaScript Date at local
// midnight, which would shift the day in some time zones.
const DATE_OID = 1082;
types.setTypeParser(DATE_OID, (value) => value);

// One connection pool for the whole API. Every query is parameterised: pass
// values as the params array, never by building SQL strings from input.
let pool;

function getPool() {
  if (!pool) {
    pool = new Pool({ connectionString: config.databaseUrl });
    // The server can close an idle connection, for example when a hosted
    // database pauses. Log it instead of crashing; the pool opens a new one.
    pool.on('error', (error) => logger.warn('Idle database connection closed', { message: error.message }));
  }
  return pool;
}

function query(text, params) {
  return getPool().query(text, params);
}

// Runs fn(client) inside one transaction: COMMIT if it resolves, ROLLBACK if it throws.
async function withTransaction(fn, { readOnly = false } = {}) {
  const client = await getPool().connect();
  try {
    await client.query(readOnly ? 'BEGIN ISOLATION LEVEL REPEATABLE READ READ ONLY' : 'BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally {
    client.release();
  }
}

async function closePool() {
  if (pool) {
    const current = pool;
    pool = undefined;
    await current.end();
  }
}

module.exports = { query, withTransaction, closePool };
