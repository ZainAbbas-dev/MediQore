// Accounts (M1 FE-1): one admin, one supervisor per tehsil (assigned to all its
// areas) and one LHW per area. Every account shares the synthetic password.
const { WOMEN, FAMILY } = require('../names');

const pad = (n, width) => String(n).padStart(width, '0');

function build({ options, random, passwordHash }, geo) {
  const users = [];
  const lhwProfiles = [];
  const supervisorAreas = [];
  const lhws = [];
  const user = (username, role, fullName) => {
    const row = { id: random.uuid(), username, full_name: fullName, role, password_hash: passwordHash };
    users.push(row);
    return row;
  };

  user(`${options.prefix}.admin`, 'admin', 'Synthetic Admin');

  geo.tehsils.forEach((tehsil, i) => {
    const supervisor = user(`${options.prefix}.sup.${pad(i + 1, 2)}`, 'supervisor', `${random.pick(WOMEN)} ${random.pick(FAMILY)}`);
    for (const area of geo.areas) {
      if (geo.areaMeta.get(area.id).tehsilId === tehsil.id) {
        supervisorAreas.push({ id: random.uuid(), supervisor_id: supervisor.id, area_id: area.id });
      }
    }
  });

  geo.areas.forEach((area, i) => {
    const meta = geo.areaMeta.get(area.id);
    const lhw = user(`${options.prefix}.lhw.${pad(i + 1, 3)}`, 'lhw', `${random.pick(WOMEN)} ${random.pick(FAMILY)}`);
    const lhwCode = `${options.prefix.toUpperCase()}-${meta.districtCode}-${pad(i + 1, 3)}`;
    lhwProfiles.push({ user_id: lhw.id, lhw_code: lhwCode, area_id: area.id });
    lhws.push({ userId: lhw.id, lhwCode, areaId: area.id, centre: meta.centre });
  });

  return {
    users,
    lhwProfiles,
    supervisorAreas,
    lhws,
    summary: {
      password: options.password,
      admin: `${options.prefix}.admin`,
      supervisors: users.filter((u) => u.role === 'supervisor').map((u) => u.username),
      lhws: users.filter((u) => u.role === 'lhw').map((u) => u.username),
    },
  };
}

module.exports = { build };
