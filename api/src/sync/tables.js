const Joi = require('joi');

// Tables that devices may push and pull through /sync, with the fields the
// device sends (camelCase) and the column each maps to. Only tables listed here
// can be synced, and their names are the only identifiers ever placed in SQL.
// Add a table here when its module is built, together with its tests.
//
// Every listed table has the sync base columns (id, server_seq, area_id,
// created_by, created_on_device, synced_at, deleted_at); see docs/schema-v1.md.

const text = (max) => Joi.string().trim().max(max).empty('').allow(null).default(null);
const coordinate = (limit) => Joi.number().min(-limit).max(limit).precision(6).allow(null).default(null);

const TABLES = {
  // M2 FE-3: household with GPS. The first table synced end to end (P0-6).
  households: {
    fields: {
      householdNumber: { column: 'household_number', schema: text(50) },
      address: { column: 'address', schema: text(500) },
      village: { column: 'village', schema: text(200) },
      latitude: { column: 'latitude', type: 'number', schema: coordinate(90) },
      longitude: { column: 'longitude', type: 'number', schema: coordinate(180) },
    },
    check(data) {
      return (data.latitude === null) === (data.longitude === null)
        ? null
        : 'latitude and longitude must be given together';
    },
  },
};

// Joi schema for the `data` object of one table.
function dataSchema(def) {
  const keys = Object.fromEntries(Object.entries(def.fields).map(([name, field]) => [name, field.schema]));
  return Joi.object(keys).custom((value, helpers) => {
    const problem = def.check ? def.check(value) : null;
    return problem ? helpers.message(problem) : value;
  });
}

// A value as it is stored, so a resent record can be compared with the database row.
function normalise(field, value) {
  if (value === null || value === undefined) return null;
  return field.type === 'number' ? Number(value) : value;
}

module.exports = { TABLES, dataSchema, normalise };
