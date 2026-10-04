// M1 FE-2: HTTPS only, and the login rate limiter's time window. No database needed.
const request = require('supertest');
const { createApp } = require('../src/app');
const { LoginThrottle } = require('../src/services/login-throttle');

describe('HTTPS only', () => {
  it('refuses plain HTTP when HTTPS is required', async () => {
    const res = await request(createApp({ requireHttps: true })).get('/api/v1/health');

    expect(res.status).toBe(403);
    expect(res.body.error.code).toBe('HTTPS_REQUIRED');
  });

  it('accepts HTTPS ended at a trusted proxy and tells browsers to keep using it', async () => {
    const res = await request(createApp({ requireHttps: true, trustProxy: 1 }))
      .get('/api/v1/health')
      .set('X-Forwarded-Proto', 'https');

    expect(res.status).toBe(200);
    expect(res.headers['strict-transport-security']).toMatch(/max-age=\d+/);
  });

  it('ignores X-Forwarded-Proto from an untrusted client', async () => {
    const res = await request(createApp({ requireHttps: true })).get('/api/v1/health').set('X-Forwarded-Proto', 'https');

    expect(res.status).toBe(403);
  });
});

describe('LoginThrottle', () => {
  it('blocks after the limit and lets the key in again once the window has passed', () => {
    let now = 0;
    const throttle = new LoginThrottle({ maxFailures: 3, windowMs: 1000, now: () => now });
    const key = LoginThrottle.key('1.2.3.4', 'LHW-00001');

    for (let i = 0; i < 3; i += 1) {
      throttle.check(key);
      throttle.fail(key);
    }
    expect(() => throttle.check(key)).toThrow(expect.objectContaining({ status: 429, headers: { 'Retry-After': '1' } }));
    expect(() => throttle.check(LoginThrottle.key('1.2.3.4', 'other'))).not.toThrow();

    now = 1001;
    expect(() => throttle.check(key)).not.toThrow();
  });

  it('treats usernames case-insensitively', () => {
    expect(LoginThrottle.key('ip', 'LHW-00001')).toBe(LoginThrottle.key('ip', 'lhw-00001'));
  });
});
