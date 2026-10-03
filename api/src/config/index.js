const fs = require('node:fs');
const path = require('node:path');

// Load api/.env when it exists (copy it from .env.example). Real environment
// variables always win over values in the file.
const envFile = path.resolve(__dirname, '../../.env');
if (fs.existsSync(envFile)) {
  process.loadEnvFile(envFile);
}

const nodeEnv = process.env.NODE_ENV || 'development';

module.exports = {
  nodeEnv,
  isTest: nodeEnv === 'test',
  port: Number.parseInt(process.env.PORT, 10) || 3000,
};
