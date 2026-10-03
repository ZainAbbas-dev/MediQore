const authService = require('../services/auth.service');

async function login(req, res) {
  res.json(await authService.login(req.body.username, req.body.password));
}

module.exports = { login };
