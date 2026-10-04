const lhwsService = require('../services/lhws.service');

async function listAreas(req, res) {
  res.json(await lhwsService.listAreas());
}

async function listLhws(req, res) {
  res.json(await lhwsService.list(req.query));
}

async function createLhw(req, res) {
  res.status(201).json(await lhwsService.create(req.user, req.body));
}

async function updateLhw(req, res) {
  res.json(await lhwsService.update(req.user, req.params.id, req.body));
}

async function deactivateLhw(req, res) {
  res.json(await lhwsService.setActive(req.user, req.params.id, false));
}

async function activateLhw(req, res) {
  res.json(await lhwsService.setActive(req.user, req.params.id, true));
}

async function resetPassword(req, res) {
  res.json(await lhwsService.resetPassword(req.user, req.params.id));
}

module.exports = { listAreas, listLhws, createLhw, updateLhw, deactivateLhw, activateLhw, resetPassword };
