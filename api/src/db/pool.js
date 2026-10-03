const { Pool } = require('pg');
const config = require('../config');

// One connection pool for the whole API. Every query is parameterised: pass
// values as the params array, never by building SQL strings from input.
let pool;

function getPool() {
  if (!pool) {
    pool = new Pool({ connectionString: config.databaseUrl });
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
