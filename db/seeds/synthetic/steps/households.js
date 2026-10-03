// Households with GPS (M2 FE-3), scattered around each area's centre.
const { VILLAGE_FIRST, VILLAGE_SECOND } = require('../names');
const { round } = require('../random');

const DAY = 24 * 60 * 60 * 1000;
const pad = (n, width) => String(n).padStart(width, '0');

function build({ options, random, now }, lhws) {
  const rows = [];
  const byId = new Map();
  for (const lhw of lhws) {
    const villages = Array.from({ length: 3 }, () => `${random.pick(VILLAGE_FIRST)} ${random.pick(VILLAGE_SECOND)}`);
    for (let h = 1; h <= options.householdsPerLhw; h++) {
      const createdOnDevice = new Date(now.getTime() - random.int(60, 200) * DAY);
      const row = {
        id: random.uuid(),
        area_id: lhw.areaId,
        created_by: lhw.userId,
        created_on_device: createdOnDevice,
        household_number: `${lhw.lhwCode}-H${pad(h, 3)}`,
        address: `House ${random.int(1, 400)}, Street ${random.int(1, 30)}`,
        village: random.pick(villages),
        latitude: round(lhw.centre[0] + random.normal(0, 0.01, -0.03, 0.03), 6),
        longitude: round(lhw.centre[1] + random.normal(0, 0.01, -0.03, 0.03), 6),
      };
      rows.push(row);
      byId.set(row.id, { row, lhw });
    }
  }
  return { rows, byId };
}

module.exports = { build };
