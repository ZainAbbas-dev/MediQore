const rules = require('../../../../clinical-rules/clinical-rules.json');

const DAY_MS = 86_400_000;
const PAKISTAN_OFFSET_MS = 5 * 3_600_000;

function build({ options, random, now }, geo, people, homes, pregnant) {
  const risks = [];
  const alerts = [];
  const children = [];
  const doses = [];
  const screenings = [];
  const campaigns = [];
  const campaignVisits = [];
  const campaignDoses = [];
  const roundId = random.uuid();
  const dateAgo = (days) => new Date(now.getTime() + PAKISTAN_OFFSET_MS - days * DAY_MS).toISOString().slice(0, 10);
  const admin = people.users.find((user) => user.role === 'admin');

  for (const area of geo.areas) {
    const areaVisits = pregnant.visits.filter((visit) => visit.area_id === area.id)
      .sort((first, second) => first.visited_at - second.visited_at);
    const latestPerPregnancy = new Map(areaVisits.map((visit) => [visit.pregnancy_id, visit]));
    for (const [index, visit] of [...latestPerPregnancy.values()].slice(0, 3).entries()) {
      const emergency = index === 0;
      const base = { area_id: area.id, created_by: visit.created_by };
      const assessment = {
        ...base, id: random.uuid(), visit_id: visit.id, pregnancy_id: visit.pregnancy_id,
        model_version: 'synthetic', input_set: 'five_feature', rules_version: rules.version,
        model_level: ['high', 'mid', 'low'][index], final_level: ['red', 'yellow', 'green'][index],
        rule_result: emergency ? 'emergency' : 'none', is_emergency: emergency,
        triggered_rules: JSON.stringify(emergency ? ['vaginal_bleeding'] : []),
      };
      risks.push(assessment);
      if (emergency) {
        visit.bleeding = true;
        // Historical phone-owned alerts let reviewers try acknowledgement without sending a notification.
        alerts.push({
          ...base, id: random.uuid(), pregnancy_id: visit.pregnancy_id, visit_id: visit.id,
          risk_assessment_id: assessment.id, visit_recorded_at: visit.visited_at, raised_at: visit.visited_at, owner: 'phone',
        });
      }
    }

    const campaign = {
      id: random.uuid(), round_id: roundId, area_id: area.id, created_by: admin.id,
      name: `Synthetic polio round [${options.prefix}]`, starts_on: dateAgo(21), ends_on: dateAgo(1),
    };
    campaigns.push(campaign);

    const areaHomes = homes.rows.filter((home) => home.area_id === area.id).slice(0, 2);
    for (const [index, home] of areaHomes.entries()) {
      const base = { area_id: area.id, created_by: home.created_by };
      const childId = random.uuid();
      const visitedOn = dateAgo(8);
      const vaccinated = index === 1;
      children.push({
        ...base, id: childId, household_id: home.id, name: vaccinated ? 'Synthetic Maryam' : 'Synthetic Amina',
        date_of_birth: dateAgo(240), sex: 'female',
      });
      screenings.push({
        ...base, child_id: childId, screened_on: dateAgo(9), muac_mm: vaccinated ? 136 : 112,
        malnutrition_class: vaccinated ? 'normal' : 'sam', rules_version: rules.version,
      });
      const fieldVisit = {
        ...base, id: random.uuid(), household_id: home.id, campaign_id: campaign.id, visited_on: visitedOn,
        children_under_5: 1, children_vaccinated: Number(vaccinated), status: vaccinated ? 'all_vaccinated' : 'refusal',
      };
      campaignVisits.push(fieldVisit);
      if (vaccinated) {
        doses.push({
          ...base, child_id: childId, antigen: 'Penta', dose_number: 1, given_on: dateAgo(80),
          schedule_version: rules.epi_schedule.schedule_version,
        });
        campaignDoses.push({
          ...base, child_id: childId, campaign_id: campaign.id, campaign_household_status_id: fieldVisit.id, given_on: visitedOn,
        });
      }
    }
  }

  return [
    ['risk_assessments', risks], ['emergency_alerts', alerts], ['children', children], ['immunisations', doses],
    ['nutrition_screenings', screenings], ['campaigns', campaigns], ['campaign_household_status', campaignVisits],
    ['campaign_child_doses', campaignDoses],
  ];
}

module.exports = { build };
