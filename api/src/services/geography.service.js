const db = require('../db/pool');
const AppError = require('../utils/app-error');
const { writeAudit } = require('./audit.service');

// M10 FE-3: admins manage the district > tehsil > Union Council > area
// structure. Names are unique among siblings. Nothing is hard-deleted: a unit
// is deleted only when nothing uses it any more, and creating a sibling with
// the name of a deleted one brings that one back, so old records keep their
// links. Every change writes an audit row.

// The levels, child first. Table and column names come only from here.
const LEVELS = {
  districts: { table: 'districts', label: 'district' },
  tehsils: { table: 'tehsils', label: 'tehsil', parent: { level: 'districts', column: 'district_id' } },
  'union-councils': {
    table: 'union_councils',
    label: 'Union Council',
    parent: { level: 'tehsils', column: 'tehsil_id' },
  },
  areas: { table: 'areas', label: 'area', parent: { level: 'union-councils', column: 'union_council_id' } },
};

// What keeps a unit in use: its children, and the accounts, facilities and
// records that point at it. Each query counts rows that are not deleted.
const IN_USE = {
  districts: [
    ['tehsils', 'SELECT count(*)::int AS n FROM tehsils WHERE district_id = $1 AND deleted_at IS NULL'],
    ['hospitals', 'SELECT count(*)::int AS n FROM hospitals WHERE district_id = $1 AND deleted_at IS NULL'],
    ['referral centres', 'SELECT count(*)::int AS n FROM referral_centres WHERE district_id = $1 AND deleted_at IS NULL'],
  ],
  tehsils: [
    ['Union Councils', 'SELECT count(*)::int AS n FROM union_councils WHERE tehsil_id = $1 AND deleted_at IS NULL'],
  ],
  'union-councils': [['areas', 'SELECT count(*)::int AS n FROM areas WHERE union_council_id = $1 AND deleted_at IS NULL']],
  areas: [
    ['LHWs', `SELECT count(*)::int AS n FROM lhw_profiles p JOIN users u ON u.id = p.user_id
              WHERE (p.area_id = $1 OR p.previous_area_id = $1) AND p.deleted_at IS NULL AND u.deleted_at IS NULL`],
    ['supervisors', 'SELECT count(*)::int AS n FROM supervisor_areas WHERE area_id = $1 AND deleted_at IS NULL'],
    ['households', 'SELECT count(*)::int AS n FROM households WHERE area_id = $1'],
    ['women', 'SELECT count(*)::int AS n FROM women WHERE area_id = $1'],
  ],
};

function level(name) {
  const def = LEVELS[name];
  if (!def) throw new AppError(404, 'NOT_FOUND', 'Unknown level');
  return def;
}

const toUnit = (row) => ({ id: row.id, name: row.name });

// GET /admin/geography: the whole tree, with how many LHWs and supervisors each
// area has, for the admin panel and the account forms.
async function tree() {
  const [districts, tehsils, ucs, areas] = await Promise.all([
    db.query('SELECT id, name FROM districts WHERE deleted_at IS NULL ORDER BY name'),
    db.query('SELECT id, name, district_id FROM tehsils WHERE deleted_at IS NULL ORDER BY name'),
    db.query('SELECT id, name, tehsil_id FROM union_councils WHERE deleted_at IS NULL ORDER BY name'),
    db.query(
      `SELECT a.id, a.name, a.union_council_id,
              (SELECT count(*)::int FROM lhw_profiles p JOIN users u ON u.id = p.user_id
                WHERE p.area_id = a.id AND p.deleted_at IS NULL AND u.deleted_at IS NULL) AS lhws,
              (SELECT count(*)::int FROM supervisor_areas s JOIN users u ON u.id = s.supervisor_id
                WHERE s.area_id = a.id AND s.deleted_at IS NULL AND u.deleted_at IS NULL) AS supervisors
       FROM areas a WHERE a.deleted_at IS NULL ORDER BY a.name`,
    ),
  ]);
  const byParent = (rows, column, map) => {
    const grouped = new Map();
    for (const row of rows) {
      if (!grouped.has(row[column])) grouped.set(row[column], []);
      grouped.get(row[column]).push(map(row));
    }
    return (id) => grouped.get(id) ?? [];
  };
  const areasOf = byParent(areas.rows, 'union_council_id', (r) => ({ ...toUnit(r), lhws: r.lhws, supervisors: r.supervisors }));
  const ucsOf = byParent(ucs.rows, 'tehsil_id', (r) => ({ ...toUnit(r), areas: areasOf(r.id) }));
  const tehsilsOf = byParent(tehsils.rows, 'district_id', (r) => ({ ...toUnit(r), unionCouncils: ucsOf(r.id) }));
  return { districts: districts.rows.map((r) => ({ ...toUnit(r), tehsils: tehsilsOf(r.id) })) };
}

async function requireParent(client, def, parentId) {
  if (!def.parent) return;
  const parent = LEVELS[def.parent.level];
  const { rowCount } = await client.query(`SELECT 1 FROM ${parent.table} WHERE id = $1 AND deleted_at IS NULL`, [parentId]);
  if (!rowCount) throw new AppError(400, 'UNKNOWN_PARENT', `This ${parent.label} does not exist`);
}

async function findUnit(client, def, id, { lock = false } = {}) {
  const { rows: [row] } = await client.query(
    `SELECT * FROM ${def.table} WHERE id = $1 AND deleted_at IS NULL${lock ? ' FOR UPDATE' : ''}`,
    [id],
  );
  if (!row) throw new AppError(404, 'NOT_FOUND', `No ${def.label} with this ID`);
  return row;
}

// A sibling with the same name (case-insensitive), deleted or not.
async function sibling(client, def, parentId, name, exceptId = null) {
  const params = [name, exceptId];
  let sql = `SELECT id, deleted_at FROM ${def.table} WHERE lower(name) = lower($1) AND id IS DISTINCT FROM $2`;
  if (def.parent) {
    params.push(parentId);
    sql += ` AND ${def.parent.column} = $3`;
  }
  const { rows: [row] } = await client.query(`${sql} FOR UPDATE`, params);
  return row;
}

// POST /admin/geography/:level
async function create(admin, levelName, { name, parentId }) {
  const def = level(levelName);
  if (def.parent && !parentId) throw new AppError(400, 'VALIDATION_ERROR', `A ${def.label} needs its parent`);
  return db.withTransaction(async (client) => {
    await requireParent(client, def, parentId);
    const existing = await sibling(client, def, parentId, name);
    if (existing && existing.deleted_at === null) {
      throw new AppError(409, 'DUPLICATE_NAME', `A ${def.label} with this name already exists here`);
    }
    let row;
    if (existing) {
      // Brought back, with its ID, so records made in it stay linked.
      ({ rows: [row] } = await client.query(
        `UPDATE ${def.table} SET deleted_at = NULL, name = $2 WHERE id = $1 RETURNING *`,
        [existing.id, name],
      ));
      await writeAudit(client, {
        userId: admin.id, action: 'edit', entityType: def.table, entityId: row.id, details: { change: 'restore', name },
      });
    } else {
      const columns = def.parent ? `(name, ${def.parent.column})` : '(name)';
      const values = def.parent ? '($1, $2)' : '($1)';
      try {
        ({ rows: [row] } = await client.query(
          `INSERT INTO ${def.table} ${columns} VALUES ${values} RETURNING *`,
          def.parent ? [name, parentId] : [name],
        ));
      } catch (error) {
        // Another admin created the same name a moment ago.
        if (error.code === '23505') throw new AppError(409, 'DUPLICATE_NAME', `A ${def.label} with this name already exists here`);
        throw error;
      }
      await writeAudit(client, {
        userId: admin.id, action: 'create', entityType: def.table, entityId: row.id,
        details: { name, ...(def.parent ? { parentId } : {}) },
      });
    }
    return { unit: { ...toUnit(row), parentId: def.parent ? row[def.parent.column] : null } };
  });
}

// PATCH /admin/geography/:level/:id: rename.
async function rename(admin, levelName, id, { name }) {
  const def = level(levelName);
  return db.withTransaction(async (client) => {
    const before = await findUnit(client, def, id, { lock: true });
    if (before.name !== name) {
      const parentId = def.parent ? before[def.parent.column] : null;
      if (await sibling(client, def, parentId, name, id)) {
        throw new AppError(409, 'DUPLICATE_NAME', `A ${def.label} with this name already exists here`);
      }
      await client.query(`UPDATE ${def.table} SET name = $2 WHERE id = $1`, [id, name]);
      await writeAudit(client, {
        userId: admin.id, action: 'edit', entityType: def.table, entityId: id, details: { changes: { name: { from: before.name, to: name } } },
      });
    }
    return { unit: { ...toUnit({ id, name }), parentId: def.parent ? before[def.parent.column] : null } };
  });
}

// DELETE /admin/geography/:level/:id: soft delete, only when nothing uses it.
async function remove(admin, levelName, id) {
  const def = level(levelName);
  return db.withTransaction(async (client) => {
    const before = await findUnit(client, def, id, { lock: true });
    const uses = [];
    for (const [what, sql] of IN_USE[levelName]) {
      const { rows: [{ n }] } = await client.query(sql, [id]);
      if (n > 0) uses.push(`${n} ${what}`);
    }
    if (uses.length) {
      throw new AppError(409, 'IN_USE', `This ${def.label} is still used by ${uses.join(', ')}`, { uses });
    }
    await client.query(`UPDATE ${def.table} SET deleted_at = now() WHERE id = $1`, [id]);
    await writeAudit(client, { userId: admin.id, action: 'delete', entityType: def.table, entityId: id, details: { name: before.name } });
  });
}

module.exports = { tree, create, rename, remove, LEVELS };
