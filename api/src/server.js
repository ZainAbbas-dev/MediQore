const config = require('./config');
const logger = require('./utils/logger');
const { closePool } = require('./db/pool');
const { createApp } = require('./app');

const missing = [
  ['DATABASE_URL', config.databaseUrl],
  ['JWT_ACCESS_SECRET', config.jwt.accessSecret],
].filter(([, value]) => !value).map(([name]) => name);

if (missing.length) {
  logger.error('Missing required environment variables; see api/.env.example', { missing });
  process.exit(1);
}

const server = createApp().listen(config.port, () => {
  logger.info('MediQore API listening', { port: config.port, env: config.nodeEnv });
});

function shutdown(signal) {
  logger.info('Shutting down', { signal });
  server.close(async () => {
    await closePool();
    process.exit(0);
  });
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
