// Runs before every test file (jest setupFiles).
//
// Database tests use TEST_DATABASE_URL only (from the environment or api/.env).
// It must name a database ending in "_test" that already has the migrations
// applied. Without it they are skipped, and DATABASE_URL points nowhere, so no
// test can ever touch the dev database.
const path = require('node:path');
const { loadEnvFile } = require('../src/config/load-env');

loadEnvFile(path.resolve(__dirname, '../.env')); // never overrides variables already set

process.env.DATABASE_URL = process.env.TEST_DATABASE_URL || 'postgres://no-test-database.invalid/none';
process.env.JWT_ACCESS_SECRET = 'test-access-secret';
process.env.JWT_ACCESS_EXPIRES_IN = '15m';
