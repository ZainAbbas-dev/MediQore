const healthService = require('../services/health.service');

function getHealth(req, res) {
  res.json(healthService.getHealth());
}

module.exports = { getHealth };
