const dashboardService = require('../services/dashboard.service');

async function summary(req, res) {
  res.json(await dashboardService.summary(req.user));
}

async function filters(req, res) {
  res.json(await dashboardService.filters(req.user));
}

async function lhwActivity(req, res) {
  res.json(await dashboardService.lhwActivity(req.user, req.query));
}

module.exports = { summary, filters, lhwActivity };
