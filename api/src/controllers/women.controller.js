const womenService = require('../services/women.service');

async function list(req, res) {
  res.json(await womenService.listForPortal(req.user, req.query));
}

async function visits(req, res) {
  res.json(await womenService.visitsForPortal(req.user, req.params.id));
}

module.exports = { list, visits };
