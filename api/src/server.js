const config = require('./config');
const logger = require('./utils/logger');
const { createApp } = require('./app');

const server = createApp().listen(config.port, () => {
  logger.info('MediQore API listening', { port: config.port, env: config.nodeEnv });
});

function shutdown(signal) {
  logger.info('Shutting down', { signal });
  server.close(() => process.exit(0));
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
