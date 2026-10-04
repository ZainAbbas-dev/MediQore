const authService = require('../services/auth.service');

async function login(req, res) {
  const result = await authService.login(req.body, { ip: req.ip });
  // 202: the password was right, but this phone still needs its one-time code.
  res.status(result.status === 'otp_required' ? 202 : 200).json(result);
}

async function verifyOtp(req, res) {
  res.json(await authService.verifyOtp(req.body, { ip: req.ip }));
}

async function refresh(req, res) {
  res.json(await authService.refresh(req.body));
}

async function logout(req, res) {
  await authService.logout(req.body);
  res.status(204).end();
}

module.exports = { login, verifyOtp, refresh, logout };
