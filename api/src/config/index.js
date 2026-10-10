const path = require('node:path');
const { loadEnvFile } = require('./load-env');

// Load api/.env when it exists (copy it from .env.example).
loadEnvFile(path.resolve(__dirname, '../../.env'));

const nodeEnv = process.env.NODE_ENV || 'development';
const int = (value, fallback) => {
  const n = Number.parseInt(value, 10);
  return Number.isFinite(n) ? n : fallback;
};

module.exports = {
  nodeEnv,
  isTest: nodeEnv === 'test',
  port: int(process.env.PORT, 3000),
  databaseUrl: process.env.DATABASE_URL,
  jwt: {
    accessSecret: process.env.JWT_ACCESS_SECRET,
    accessExpiresIn: process.env.JWT_ACCESS_EXPIRES_IN || '15m',
  },
  // M1 FE-2: opaque refresh tokens, stored hashed and revocable.
  refreshTokenTtlDays: int(process.env.REFRESH_TOKEN_TTL_DAYS, 30),
  // M1 FE-2: login rate limiting, per client address and username.
  loginRateLimit: {
    maxFailures: int(process.env.LOGIN_MAX_FAILURES, 5),
    windowMinutes: int(process.env.LOGIN_WINDOW_MINUTES, 15),
  },
  // M1 FE-2: one-time activation codes for the first sign-in on a phone, and
  // the key that the phones' PIN-reset secrets come from (optional: derived
  // from JWT_ACCESS_SECRET when unset).
  activation: {
    codeTtlHours: int(process.env.ACTIVATION_CODE_TTL_HOURS, 48),
    pinResetSecret: process.env.PIN_RESET_SECRET || null,
  },
  // M1 FE-2: HTTPS only. On by default in production; behind a reverse proxy,
  // set TRUST_PROXY (for example 1) so the API sees the original https scheme.
  requireHttps: process.env.REQUIRE_HTTPS ? process.env.REQUIRE_HTTPS === 'true' : nodeEnv === 'production',
  trustProxy: process.env.TRUST_PROXY ? int(process.env.TRUST_PROXY, process.env.TRUST_PROXY) : false,
  // Staging: the built portal (web/dist) to serve next to /api/v1, so both
  // share one HTTPS address. A path relative to api/. Unset in development,
  // where Vite serves the portal.
  portalDir: process.env.PORTAL_DIR ? path.resolve(__dirname, '../..', process.env.PORTAL_DIR) : null,
};
