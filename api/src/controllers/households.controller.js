const householdsService = require('../services/households.service');

async function list(req, res) {
  res.json({ households: await householdsService.listForPortal(req.user, req.query.limit) });
}

module.exports = { list };
