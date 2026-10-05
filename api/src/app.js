// M1 FE-2: API skeleton (P0-3): routing under /api/v1, Joi validation,
// central error handling and request logging; HTTPS only in production.
const path = require('node:path');
const express = require('express');
const config = require('./config');
const requestLogger = require('./middleware/request-logger');
const requireHttps = require('./middleware/require-https');
const { notFound, errorHandler } = require('./middleware/error-handler');
const routes = require('./routes');

// `options` override config for tests: { requireHttps, trustProxy, portalDir }.
function createApp(options = {}) {
  const {
    requireHttps: httpsOnly = config.requireHttps,
    trustProxy = config.trustProxy,
    portalDir = config.portalDir,
  } = options;
  const app = express();

  app.disable('x-powered-by');
  if (trustProxy) app.set('trust proxy', trustProxy);
  app.use(requestLogger);
  if (httpsOnly) app.use(requireHttps);
  app.use(express.json());

  app.use('/api/v1', routes);

  // Staging (docs/staging.md): the portal's files, and its index.html for any
  // other page address, so a reload on /conflicts still opens the portal.
  // Same origin as the API, so the browser needs no CORS.
  if (portalDir) {
    app.use(express.static(portalDir));
    app.use((req, res, next) => {
      const api = req.path === '/api' || req.path.startsWith('/api/');
      if (api || (req.method !== 'GET' && req.method !== 'HEAD')) return next();
      return res.sendFile(path.join(portalDir, 'index.html'));
    });
  }

  app.use(notFound);
  app.use(errorHandler);

  return app;
}

module.exports = { createApp };
