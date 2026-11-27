const alerts = require('../services/alerts.service');

async function list(req, res) {
  res.json(await alerts.list(req.user, req.query));
}

async function acknowledge(req, res) {
  res.json(await alerts.acknowledge(req.user, req.params.id));
}

async function subscribe(req, res) {
  res.json(await alerts.subscribe(req.user, req.body.token));
}

async function unsubscribe(req, res) {
  await alerts.unsubscribe(req.user, req.params.id);
  res.status(204).end();
}

module.exports = { list, acknowledge, subscribe, unsubscribe };
