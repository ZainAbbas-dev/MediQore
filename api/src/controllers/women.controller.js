const womenService = require('../services/women.service');

async function list(req, res) {
  res.json(await womenService.listForPortal(req.user, req.query));
}

module.exports = { list };
