const fs = require('node:fs');
const { parseEnv } = require('node:util');

// Copies variables from a .env file into process.env. Variables that are
// already set always win over values in the file.
function loadEnvFile(file) {
  if (!fs.existsSync(file)) return;
  for (const [key, value] of Object.entries(parseEnv(fs.readFileSync(file, 'utf8')))) {
    if (process.env[key] === undefined) process.env[key] = value;
  }
}

module.exports = { loadEnvFile };
