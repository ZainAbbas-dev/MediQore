const syncService = require('../services/sync.service');

async function push(req, res) {
  res.json(await syncService.push(req.user, req.body.deviceId, req.body.records));
}

async function pull(req, res) {
  res.json(await syncService.pull(req.user, req.query.since, req.query.limit));
}

async function config(req, res) {
  res.json(await syncService.config(req.user, req.query.have));
}

module.exports = { push, pull, config };
