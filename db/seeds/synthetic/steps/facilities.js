// Facilities (M10 FE-3): a District Headquarters (DHQ) hospital per district and
// a Tehsil Headquarters (THQ) hospital per tehsil, near the areas they serve,
// created by the synthetic admin. Names and phone numbers are made up; the LHW
// app will use the list to find the nearest hospital (M5 FE-1, Phase 2).
const { round } = require('../random');

const average = (points) => [
  points.reduce((sum, p) => sum + p[0], 0) / points.length,
  points.reduce((sum, p) => sum + p[1], 0) / points.length,
];

function build({ options, random }, geo, people) {
  const admin = people.users.find((u) => u.role === 'admin');
  const centresOf = (tehsilIds) =>
    geo.areas.filter((a) => tehsilIds.includes(geo.areaMeta.get(a.id).tehsilId)).map((a) => geo.areaMeta.get(a.id).centre);
  const hospital = (districtId, name, facilityType, centre) => ({
    id: random.uuid(),
    created_by: admin.id,
    district_id: districtId,
    name,
    facility_type: facilityType,
    address: `${name}, main road`,
    phone: `0000-${random.int(1000000, 9999999)}`, // never a real number
    latitude: round(centre[0] + random.normal(0, 0.01, -0.03, 0.03), 6),
    longitude: round(centre[1] + random.normal(0, 0.01, -0.03, 0.03), 6),
  });

  const hospitals = [];
  for (const district of geo.districts) {
    const tehsils = geo.tehsils.filter((t) => t.district_id === district.id);
    const districtName = district.name.replace(` [${options.prefix}]`, '');
    hospitals.push(hospital(district.id, `DHQ Hospital ${districtName}`, 'DHQ', average(centresOf(tehsils.map((t) => t.id)))));
    for (const tehsil of tehsils) {
      hospitals.push(hospital(district.id, `THQ Hospital ${tehsil.name}`, 'THQ', average(centresOf([tehsil.id]))));
    }
  }
  return { hospitals };
}

module.exports = { build };
