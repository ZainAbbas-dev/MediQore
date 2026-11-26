const AppError = require('../utils/app-error');
const config = require('../config');

// M1 FE-2: login rate limiting. Counts failed sign-ins per client address and
// username; after too many in the window, further attempts are refused with 429
// until the window has passed. A successful sign-in clears the count.
//
// Counts live in this process's memory, which is enough for the prototype's
// single API server. Several servers would need a shared store.
class LoginThrottle {
  constructor({ maxFailures, windowMs, now = Date.now }) {
    this.maxFailures = maxFailures;
    this.windowMs = windowMs;
    this.now = now;
    this.failures = new Map(); // key -> timestamps of recent failures
    this.inFlight = new Map(); // key -> requests currently verifying credentials
  }

  static key(ip, username) {
    return `${ip}|${String(username).toLowerCase()}`;
  }

  recent(key) {
    const since = this.now() - this.windowMs;
    const kept = (this.failures.get(key) || []).filter((t) => t > since);
    if (kept.length) this.failures.set(key, kept);
    else this.failures.delete(key);
    return kept;
  }

  // Throws 429 TOO_MANY_ATTEMPTS while the key is blocked.
  check(key) {
    const recent = this.recent(key);
    if (recent.length + (this.inFlight.get(key) ?? 0) >= this.maxFailures) {
      const retryAfterSeconds = recent.length >= this.maxFailures
        ? Math.ceil((recent[0] + this.windowMs - this.now()) / 1000)
        : 1;
      throw new AppError(429, 'TOO_MANY_ATTEMPTS', 'Too many failed attempts. Try again later.', undefined, {
        'Retry-After': String(retryAfterSeconds),
      });
    }
  }

  async attempt(key, verify) {
    this.check(key);
    this.inFlight.set(key, (this.inFlight.get(key) ?? 0) + 1);
    try {
      const session = await verify(key);
      this.succeed(key);
      return session;
    } finally {
      const remaining = this.inFlight.get(key) - 1;
      if (remaining > 0) this.inFlight.set(key, remaining);
      else this.inFlight.delete(key);
    }
  }

  fail(key) {
    this.failures.set(key, [...this.recent(key), this.now()]);
  }

  succeed(key) {
    this.failures.delete(key);
  }

  reset() {
    this.failures.clear();
  }
}

const loginThrottle = new LoginThrottle({
  maxFailures: config.loginRateLimit.maxFailures,
  windowMs: config.loginRateLimit.windowMinutes * 60 * 1000,
});

module.exports = { LoginThrottle, loginThrottle };
