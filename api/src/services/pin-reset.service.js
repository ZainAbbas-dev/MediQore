const db = require('../db/pool');
const AppError = require('../utils/app-error');
const activation = require('./activation.service');
const { writeAudit } = require('./audit.service');
const { supervisorAreaIds } = require('./scope.service');

// M1 FE-2: offline PIN reset. A phone whose LHW forgot her PIN shows a
// 6-digit code; the LHW reads it to her supervisor, who enters it here with
// the LHW's name and reads back the 8-digit reply code. The phone checks the
// reply with the secret it received at activation, without internet.
// A supervisor can do this only for LHWs in their own areas; an admin for any LHW.

// POST /pin-reset/reply-code
async function replyCode(viewer, { lhwId, challenge }) {
  return db.withTransaction(async (client) => {
    const params = [lhwId];
    let scope = '';
    if (viewer.role !== 'admin') {
      params.push(await supervisorAreaIds(client, viewer.id));
      scope = ` AND p.area_id = ANY($${params.length})`;
    }
    const { rows: [lhw] } = await client.query(
      `SELECT u.id, u.full_name, p.lhw_code
       FROM users u JOIN lhw_profiles p ON p.user_id = u.id AND p.deleted_at IS NULL
       WHERE u.id = $1 AND u.role = 'lhw' AND u.deleted_at IS NULL${scope}`,
      params,
    );
    if (!lhw) throw new AppError(404, 'NOT_FOUND', 'No LHW with this ID in your areas');

    // Her most recently activated phone that is still allowed.
    const { rows: [device] } = await client.query(
      `SELECT id, model, activated_at, activation_secret_ref FROM devices
       WHERE user_id = $1 AND activated_at IS NOT NULL AND revoked_at IS NULL AND activation_secret_ref IS NOT NULL
       ORDER BY activated_at DESC LIMIT 1`,
      [lhw.id],
    );
    if (!device) throw new AppError(404, 'NO_ACTIVATED_PHONE', 'This LHW has no activated phone');

    const secret = activation.deviceSecret(device.id, device.activation_secret_ref);
    // Never log the reply code.
    await writeAudit(client, {
      userId: viewer.id, action: 'create', entityType: 'pin_reset_codes', entityId: null,
      details: { forUser: lhw.id, deviceId: device.id },
    });
    return {
      replyCode: activation.replyCode(secret, challenge),
      lhw: { id: lhw.id, fullName: lhw.full_name, lhwCode: lhw.lhw_code },
      device: { model: device.model, activatedAt: device.activated_at },
    };
  });
}

module.exports = { replyCode };
