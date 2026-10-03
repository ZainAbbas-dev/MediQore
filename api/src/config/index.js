const path = require('node:path');
const { loadEnvFile } = require('./load-env');

// Load api/.env when it exists (copy it from .env.example).
loadEnvFile(path.resolve(__dirname, '../../.env'));

const nodeEnv = process.env.NODE_ENV || 'development';

module.exports = {
  nodeEnv,
  isTest: nodeEnv === 'test',
  port: Number.parseInt(process.env.PORT, 10) || 3000,
  databaseUrl: process.env.DATABASE_URL,
  jwt: {
    accessSecret: process.env.JWT_ACCESS_SECRET,
    accessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN || '15m',
  },
};
