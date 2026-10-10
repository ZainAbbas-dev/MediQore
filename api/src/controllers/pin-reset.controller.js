const pinResetService = require('../services/pin-reset.service');

async function replyCode(req, res) {
  res.json(await pinResetService.replyCode(req.user, req.body));
}

module.exports = { replyCode };
