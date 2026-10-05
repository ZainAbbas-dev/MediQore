const db = require('../db/pool');
const AppError = require('../utils/app-error');
const { writeAudit } = require('./audit.service');

// M10 FE-3: hospitals and referral centres, kept by admins on the portal. Each
// serves a district (and optionally one area). The LHW app will pull them to
// find the nearest hospital offline (M5 FE-1, Phase 2), so they carry the sync
// base columns: the database numbers each change (server_seq) and deletes are
// soft. Every change writes an audit row.

// Table and column names come only from here.
const KINDS = {
  hospitals: { table: 'hospitals', typeColumn: 'facility_type', label: 'hospital' },
  'referral-centres': { table: 'referral_centres', typeColumn: 'centre_type', label: 'referral centre' },
};

const FIELDS = {
  name: 'name',
  type: null, // the kind's typeColumn
  districtId: 'district_id',
  areaId: 'area_id',
  address: 'address',
  phone: 'phone',
  latitude: 'latitude',
  longitude: 'longitude',
};

function kind(name) {
  const def = KINDS[name];
  if (!def) throw new AppError(404, 'NOT_FOUND', 'Unknown kind of facility');
  return def;
}

const columnOf = (def, field) => (field === 'type' ? def.typeColumn : FIELDS[field]);

function selectSql(def) {
  return `
    SELECT f.id, f.name, f.${def.typeColumn} AS type, f.address, f.phone, f.latitude, f.longitude,
           f.district_id, d.name AS district_name, f.area_id, a.name AS area_name,
           f.server_seq, f.synced_at
    FROM ${def.table} f
    JOIN districts d ON d.id = f.district_id
    LEFT JOIN areas a ON a.id = f.area_id
    WHERE f.deleted_at IS NULL`;
}

function toFacility(row) {
  return {
    id: row.id,
    name: row.name,
    type: row.type,
    address: row.address,
    phone: row.phone,
    latitude: row.latitude === null ? null : Number(row.latitude),
    longitude: row.longitude === null ? null : Number(row.longitude),
    district: { id: row.district_id, name: row.district_name },
    area: row.area_id ? { id: row.area_id, name: row.area_name } : null,
    serverSeq: Number(row.server_seq),
    updatedAt: row.synced_at,
  };
}

async function find(client, def, id) {
  const { rows: [row] } = await client.query(`${selectSql(def)} AND f.id = $1`, [id]);
  if (!row) throw new AppError(404, 'NOT_FOUND', `No ${def.label} with this ID`);
  return row;
}

// The district must exist; an area, if given, must be in that district.
async function checkPlace(client, districtId, areaId) {
  const { rowCount } = await client.query('SELECT 1 FROM districts WHERE id = $1 AND deleted_at IS NULL', [districtId]);
  if (!rowCount) throw new AppError(400, 'UNKNOWN_DISTRICT', 'This district does not exist');
  if (!areaId) return;
  const { rowCount: inDistrict } = await client.query(
    `SELECT 1 FROM areas a JOIN union_councils uc ON uc.id = a.union_council_id JOIN tehsils t ON t.id = uc.tehsil_id
     WHERE a.id = $1 AND a.deleted_at IS NULL AND t.district_id = $2`,
    [areaId, districtId],
  );
  if (!inDistrict) throw new AppError(400, 'AREA_NOT_IN_DISTRICT', 'This area is not in the chosen district');
}

// GET /admin/hospitals and /admin/referral-centres
async function list(kindName, { districtId, search }) {
  const def = kind(kindName);
  const params = [];
  let sql = selectSql(def);
  if (districtId) {
    params.push(districtId);
    sql += ` AND f.district_id = $${params.length}`;
  }
  if (search) {
    params.push(`%${search.toLowerCase()}%`);
    sql += ` AND (lower(f.name) LIKE $${params.length} OR lower(coalesce(f.${def.typeColumn}, '')) LIKE $${params.length})`;
  }
  const { rows } = await db.query(`${sql} ORDER BY d.name, f.name`, params);
  return { facilities: rows.map(toFacility) };
}

// POST /admin/hospitals and /admin/referral-centres
async function create(admin, kindName, values) {
  const def = kind(kindName);
  return db.withTransaction(async (client) => {
    await checkPlace(client, values.districtId, values.areaId);
    const fields = Object.keys(FIELDS).filter((field) => values[field] !== undefined);
    const columns = fields.map((field) => columnOf(def, field));
    // created_on_device stays NULL: made on the portal, not on a phone. The
    // trigger sets server_seq and synced_at on every insert and update.
    const { rows: [row] } = await client.query(
      `INSERT INTO ${def.table} (${columns.join(', ')}, created_by)
       VALUES (${fields.map((_, i) => `$${i + 1}`).join(', ')}, $${fields.length + 1})
       RETURNING id`,
      [...fields.map((field) => values[field]), admin.id],
    );
    await writeAudit(client, {
      userId: admin.id, action: 'create', entityType: def.table, entityId: row.id,
      details: { name: values.name, districtId: values.districtId },
    });
    return { facility: toFacility(await find(client, def, row.id)) };
  });
}

// PATCH /admin/hospitals/:id and /admin/referral-centres/:id
async function update(admin, kindName, id, values) {
  const def = kind(kindName);
  return db.withTransaction(async (client) => {
    const before = await find(client, def, id);
    const current = toFacility(before);
    const now = {
      name: current.name, type: current.type, districtId: current.district.id, areaId: current.area?.id ?? null,
      address: current.address, phone: current.phone, latitude: current.latitude, longitude: current.longitude,
    };
    const changes = {};
    for (const field of Object.keys(FIELDS)) {
      if (values[field] !== undefined && values[field] !== now[field]) changes[field] = { from: now[field], to: values[field] };
    }
    const districtId = values.districtId ?? now.districtId;
    const areaId = values.areaId !== undefined ? values.areaId : now.areaId;
    if (changes.districtId || changes.areaId) await checkPlace(client, districtId, areaId);
    const latitude = values.latitude !== undefined ? values.latitude : now.latitude;
    const longitude = values.longitude !== undefined ? values.longitude : now.longitude;
    if ((latitude === null) !== (longitude === null)) {
      throw new AppError(400, 'VALIDATION_ERROR', 'Give both latitude and longitude, or neither');
    }
    const fields = Object.keys(changes);
    if (fields.length) {
      await client.query(
        `UPDATE ${def.table} SET ${fields.map((field, i) => `${columnOf(def, field)} = $${i + 2}`).join(', ')} WHERE id = $1`,
        [id, ...fields.map((field) => values[field])],
      );
      await writeAudit(client, { userId: admin.id, action: 'edit', entityType: def.table, entityId: id, details: { changes } });
    }
    return { facility: toFacility(await find(client, def, id)) };
  });
}

// DELETE /admin/hospitals/:id and /admin/referral-centres/:id: soft delete.
async function remove(admin, kindName, id) {
  const def = kind(kindName);
  return db.withTransaction(async (client) => {
    const before = await find(client, def, id);
    await client.query(`UPDATE ${def.table} SET deleted_at = now() WHERE id = $1`, [id]);
    await writeAudit(client, { userId: admin.id, action: 'delete', entityType: def.table, entityId: id, details: { name: before.name } });
  });
}

module.exports = { list, create, update, remove, KINDS };
