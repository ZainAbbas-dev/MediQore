// M10 FE-3: every create, edit, delete, referral, alert and login writes an audit
// row. Pass the transaction's client so the audit row commits or rolls back
// together with the change it describes.
async function writeAudit(db, { userId = null, deviceId = null, action, entityType = null, entityId = null, details = {} }) {
  await db.query(
    `INSERT INTO audit_log (user_id, device_id, action, entity_type, entity_id, details)
     VALUES ($1, $2, $3, $4, $5, $6)`,
    [userId, deviceId, action, entityType, entityId, details],
  );
}

module.exports = { writeAudit };
