const jwt = require('jsonwebtoken');
const config = require('../config');
const AppError = require('../utils/app-error');
const usersService = require('../services/users.service');
const { rolesFor } = require('../auth/permissions');

// M1 FE-2: requires a valid JWT access token (Authorization: Bearer <token>) and
// an active account. Sets req.user = { id, role, fullName, deviceId }; deviceId
// is the activated phone the token was issued to, or null for portal sign-ins.
// A deactivated account gets 403 ACCOUNT_INACTIVE, so the app can say why
// (M1 FE-3: deactivated accounts are refused at their next sync).
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

  const user = await usersService.findById(payload.sub);
  if (!user) {
    throw new AppError(401, 'UNAUTHORIZED', 'Account not found');
  }
  if (!user.isActive) {
    throw new AppError(403, 'ACCOUNT_INACTIVE', 'This account has been deactivated');
  }
  req.user = { id: user.id, role: user.role, fullName: user.fullName, deviceId: payload.did || null };
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

// Permission check for a route (M10 FE-3), used after authenticate. The roles
// that hold each permission are listed once in auth/permissions.js:
//   router.get('/', authenticate, requirePermission('records.view'), controller.list);
function requirePermission(permission) {
  return requireRole(...rolesFor(permission)); // an unknown name fails at startup
}

module.exports = { authenticate, requireRole, requirePermission };
