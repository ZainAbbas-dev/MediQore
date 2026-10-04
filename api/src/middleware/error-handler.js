const AppError = require('../utils/app-error');
const logger = require('../utils/logger');

// Every error response has the same shape:
//   { "error": { "code": "VALIDATION_ERROR", "message": "...", "details": [...] } }

function notFound(req, res, next) {
  next(new AppError(404, 'NOT_FOUND', 'Route not found'));
}

// Express recognises error handlers by their four arguments, so `next` stays
// in the signature even though it is unused.
// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  let error = err;

  // Errors raised by express.json() while reading the body.
  if (err.type === 'entity.parse.failed') {
    error = new AppError(400, 'INVALID_JSON', 'Request body is not valid JSON');
  } else if (err.type === 'entity.too.large') {
    error = new AppError(413, 'PAYLOAD_TOO_LARGE', 'Request body is too large');
  }

  if (!(error instanceof AppError)) {
    // Unexpected: log the details, but never send them to the client.
    logger.error('unhandled error', {
      method: req.method,
      path: req.originalUrl.split('?')[0],
      error: err.message,
      stack: err.stack,
    });
    error = new AppError(500, 'INTERNAL_ERROR', 'Something went wrong');
  }

  const body = { error: { code: error.code, message: error.message } };
  if (error.details) body.error.details = error.details;
  if (error.headers) res.set(error.headers);
  res.status(error.status).json(body);
}

module.exports = { notFound, errorHandler };
