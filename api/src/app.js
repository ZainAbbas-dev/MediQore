// M1 FE-2: API skeleton (P0-3): routing under /api/v1, Joi validation,
// central error handling and request logging; HTTPS only in production.
const express = require('express');
const config = require('./config');
const requestLogger = require('./middleware/request-logger');
const requireHttps = require('./middleware/require-https');
const { notFound, errorHandler } = require('./middleware/error-handler');
const routes = require('./routes');

// `options` override config for tests: { requireHttps, trustProxy }.
function createApp(options = {}) {
  const { requireHttps: httpsOnly = config.requireHttps, trustProxy = config.trustProxy } = options;
  const app = express();

  app.disable('x-powered-by');
  if (trustProxy) app.set('trust proxy', trustProxy);
  app.use(requestLogger);
  if (httpsOnly) app.use(requireHttps);
  app.use(express.json());

  app.use('/api/v1', routes);

  app.use(notFound);
  app.use(errorHandler);

  return app;
}

module.exports = { createApp };
