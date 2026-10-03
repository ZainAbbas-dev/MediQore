const jwt = require('jsonwebtoken');
const config = require('../config');
const AppError = require('../utils/app-error');
const usersService = require('../services/users.service');

// M1 FE-2: requires a valid JWT access token (Authorization: Bearer <token>) and
// an active account. Sets req.user = { id, role, fullName }.
async function authenticate(req, res, next) {
  const [scheme, token] = (req.get('authorization') || '').split(' ');
  if (scheme !== 'Bearer' || !token) {
    throw new AppError(401, 'UNAUTHORIZED', 'Sign in required');
  }

  let payload;
  try {
    payload = jwt.verify(token, config.jwt.accessSecret, { algorithms: ['HS256'] });
  } catch {
    throw new AppError(401, 'UNAUTHORIZED', 'Session expired or invalid');
  }

  const user = await usersService.findActiveById(payload.sub);
  if (!user) {
    throw new AppError(401, 'UNAUTHORIZED', 'Account is not active');
  }
  req.user = user;
  next();
}

// Role check for a route, used after authenticate:
//   router.get('/', authenticate, requireRole('supervisor', 'admin'), controller.list);
function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return next(new AppError(403, 'FORBIDDEN', 'Your role cannot use this route'));
    }
    return next();
  };
}

module.exports = { authenticate, requireRole };
