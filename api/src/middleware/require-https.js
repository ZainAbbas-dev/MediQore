const AppError = require('../utils/app-error');

// M1 FE-2: HTTPS only. Plain HTTP requests are refused, not redirected, so a
// password is never sent twice. Browsers are told to use HTTPS from now on.
function requireHttps(req, res, next) {
  if (!req.secure) {
    return next(new AppError(403, 'HTTPS_REQUIRED', 'Use HTTPS to reach this server'));
  }
  res.set('Strict-Transport-Security', 'max-age=15552000');
  return next();
}

module.exports = requireHttps;
