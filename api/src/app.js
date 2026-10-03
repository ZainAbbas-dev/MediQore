// M1 FE-2: API skeleton (P0-3): routing under /api/v1, Joi validation,
// central error handling and request logging.
const express = require('express');
const requestLogger = require('./middleware/request-logger');
const { notFound, errorHandler } = require('./middleware/error-handler');
const routes = require('./routes');

function createApp() {
  const app = express();

  app.disable('x-powered-by');
  app.use(requestLogger);
  app.use(express.json());

  app.use('/api/v1', routes);

  app.use(notFound);
  app.use(errorHandler);

  return app;
}

module.exports = { createApp };
