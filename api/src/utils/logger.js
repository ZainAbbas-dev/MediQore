const config = require('../config');

// Minimal structured logger: one JSON object per line on stdout/stderr.
// Silent under Jest so test output stays readable.
function write(level, message, fields = {}) {
  if (config.isTest) return;
  const line = JSON.stringify({ time: new Date().toISOString(), level, message, ...fields });
  if (level === 'error') {
    process.stderr.write(`${line}\n`);
  } else {
    process.stdout.write(`${line}\n`);
  }
}

module.exports = {
  info: (message, fields) => write('info', message, fields),
  warn: (message, fields) => write('warn', message, fields),
  error: (message, fields) => write('error', message, fields),
};
