const devicesService = require('../services/devices.service');

async function listPending(req, res) {
  res.json(await devicesService.listPending(req.user));
}

async function issueCode(req, res) {
  res.status(201).json(await devicesService.issueCode(req.user, req.params.id));
}

module.exports = { listPending, issueCode };
