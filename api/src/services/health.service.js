const { version } = require('../../package.json');

// Liveness information for the API process. A database check joins this once
// the API connects to PostgreSQL (P0-6).
function getHealth() {
  return {
    status: 'ok',
    service: 'mediqore-api',
    version,
    uptimeSeconds: Math.round(process.uptime()),
  };
}

module.exports = { getHealth };
