const dashboardService = require('../services/dashboard.service');

async function summary(req, res) {
  res.json(await dashboardService.summary(req.user));
}

module.exports = { summary };
