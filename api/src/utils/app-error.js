// An error the API expects and reports to the client as-is, for example a
// validation failure or a missing record. Anything else becomes a 500.
class AppError extends Error {
  constructor(status, code, message, details) {
    super(message);
    this.name = 'AppError';
    this.status = status;
    this.code = code;
    this.details = details;
  }
}

module.exports = AppError;
