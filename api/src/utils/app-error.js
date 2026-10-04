// An error the API expects and reports to the client as-is, for example a
// validation failure or a missing record. Anything else becomes a 500.
// `headers` are added to the response, for example Retry-After on a 429.
class AppError extends Error {
  constructor(status, code, message, details, headers) {
    super(message);
    this.name = 'AppError';
    this.status = status;
    this.code = code;
    this.details = details;
    this.headers = headers;
  }
}

module.exports = AppError;
