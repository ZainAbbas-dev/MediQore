const reports = require('../services/reports.service');

async function list(req, res) {
  res.set('Cache-Control', 'private, no-store').json(await reports.list(req.user, req.query));
}

async function download(req, res) {
  const file = await reports.download(req.user, req.params.id);
  res.attachment(file.filename).type(file.contentType).set('Cache-Control', 'private, no-store').send(file.bytes);
}

module.exports = { list, download };
