const authService = require('../services/auth.service');

async function login(req, res) {
  res.json(await authService.login(req.body, { ip: req.ip }));
}

async function activate(req, res) {
  res.json(await authService.activate(req.body, { ip: req.ip }));
}

async function refresh(req, res) {
  res.json(await authService.refresh(req.body));
}

async function logout(req, res) {
  await authService.logout(req.body);
  res.status(204).end();
}

module.exports = { login, activate, refresh, logout };
