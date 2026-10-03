const syncService = require('../services/sync.service');

async function push(req, res) {
  res.json(await syncService.push(req.user, req.body.deviceId, req.body.records));
}

async function pull(req, res) {
  res.json(await syncService.pull(req.user, req.query.since, req.query.limit));
}

module.exports = { push, pull };
