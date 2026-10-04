const conflictsService = require('../services/conflicts.service');

async function list(req, res) {
  res.json(await conflictsService.list(req.user, req.query));
}

async function resolve(req, res) {
  res.json(await conflictsService.resolve(req.user, req.params.id, req.body.resolution));
}

module.exports = { list, resolve };
