const logger = require('../utils/logger');

// Logs one line per request when the response finishes. Only the path is
// logged, never the query string or body, so no patient data reaches the logs.
function requestLogger(req, res, next) {
  const start = process.hrtime.bigint();
  res.on('finish', () => {
    const durationMs = Number(process.hrtime.bigint() - start) / 1e6;
    logger.info('request', {
      method: req.method,
      path: req.originalUrl.split('?')[0],
      status: res.statusCode,
      durationMs: Math.round(durationMs * 10) / 10,
    });
  });
  next();
}

module.exports = requestLogger;
