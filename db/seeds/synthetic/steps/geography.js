// Geography (M1 FE-1, M10 FE-3): district > tehsil > Union Council > area.
const { DISTRICTS } = require('../names');
const { round } = require('../random');

const pad = (n, width) => String(n).padStart(width, '0');

function build({ options, random }) {
  const districts = [];
  const tehsils = [];
  const unionCouncils = [];
  const areas = [];

  DISTRICTS.slice(0, options.districts).forEach((d) => {
    const district = { id: random.uuid(), name: `${d.name} [${options.prefix}]` };
    districts.push(district);
    for (let t = 1; t <= options.tehsilsPerDistrict; t++) {
      const tehsil = { id: random.uuid(), district_id: district.id, name: `${d.name} Tehsil ${t}` };
      tehsils.push(tehsil);
      for (let u = 1; u <= options.ucsPerTehsil; u++) {
        const uc = { id: random.uuid(), tehsil_id: tehsil.id, name: `UC-${pad(t, 2)}${pad(u, 2)}` };
        unionCouncils.push(uc);
        for (let a = 1; a <= options.areasPerUc; a++) {
          areas.push({
            id: random.uuid(),
            union_council_id: uc.id,
            name: `Area ${pad(t, 2)}${pad(u, 2)}-${a}`,
            // Not stored: used to place this area's households on the map.
            meta: {
              districtCode: d.code,
              tehsilId: tehsil.id,
              centre: [round(d.lat + random.normal(0, 0.12, -0.3, 0.3), 6), round(d.lng + random.normal(0, 0.12, -0.3, 0.3), 6)],
            },
          });
        }
      }
    }
  });

  return {
    districts,
    tehsils,
    unionCouncils,
    areas: areas.map(({ meta, ...row }) => row),
    areaMeta: new Map(areas.map((a) => [a.id, a.meta])),
  };
}

module.exports = { build };
