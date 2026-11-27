const request = require('supertest');
const { createApp } = require('../src/app');
const {
  describeDb, resetDatabase, createFixtures, closePool, query, tokenFor,
} = require('./db');

const app = createApp();
const END = '2026-06-01';
const START = '2026-05-01';
const base = '/api/v1/child-analytics';

describeDb('Module 10 child analytics', () => {
  let f;
  let house;
  let otherHouse;
  let supervisor;

  async function household(areaId, createdBy, gps = true) {
    const { rows: [row] } = await query(
      `INSERT INTO households (area_id, created_by, village, latitude, longitude)
       VALUES ($1, $2, 'Test village', $3, $4) RETURNING id`,
      [areaId, createdBy, gps ? 33.33 : null, gps ? 73.44 : null],
    );
    return row.id;
  }

  async function child(name, dob, options = {}) {
    const { rows: [row] } = await query(
      `INSERT INTO children (area_id, created_by, household_id, name, date_of_birth, sex, status, deceased_on)
       VALUES ($1, $2, $3, $4, $5, 'female', $6, $7) RETURNING id`,
      [options.area ?? f.areaA, options.creator ?? f.lhwA, options.house ?? house, name, dob,
        options.deceasedOn ? 'deceased' : 'active', options.deceasedOn ?? null],
    );
    return row.id;
  }

  function routine(childId, antigen, dose, given = '2026-05-01', area = f.areaA) {
    return query(
      `INSERT INTO immunisations (area_id, created_by, child_id, antigen, dose_number, given_on, schedule_version)
       VALUES ($1, $2, $3, $4, $5, $6, 'pk-epi-2022.1')`,
      [area, f.lhwA, childId, antigen, dose, given],
    );
  }

  async function campaign(area = f.areaA, round = null) {
    const { rows: [row] } = await query(
      `INSERT INTO campaigns (area_id, created_by, name, starts_on, ends_on, round_id)
       VALUES ($1, $2, 'Spring round', $3, $4, COALESCE($5, gen_random_uuid())) RETURNING id, round_id`,
      [area, f.admin, START, END, round],
    );
    return row;
  }

  async function visit(campaignId, householdId, date, status, eligible, given, area = f.areaA) {
    const { rows: [row] } = await query(
      `INSERT INTO campaign_household_status (area_id, created_by, campaign_id, household_id, visited_on, status,
               children_under_5, children_vaccinated)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id`,
      [area, f.lhwA, campaignId, householdId, date, status, eligible, given],
    );
    return row.id;
  }

  function screen(childId, date, classification, options = {}) {
    return query(
      `INSERT INTO nutrition_screenings (area_id, created_by, child_id, screened_on, malnutrition_class,
               oedema, underweight, stunting, rules_version)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'fixture')`,
      [options.area ?? f.areaA, f.lhwA, childId, date, classification, options.oedema ?? false,
        options.underweight ?? false, options.stunting ?? false],
    );
  }

  function get(path, search = {}, token = supervisor) {
    return request(app).get(`${base}${path}`).query(search).set('Authorization', `Bearer ${token}`);
  }

  beforeEach(async () => {
    await resetDatabase();
    f = await createFixtures();
    supervisor = tokenFor(f.supervisorA, 'supervisor');
    house = await household(f.areaA, f.lhwA);
    otherHouse = await household(f.areaB, f.lhwB);
  });

  afterAll(closePool);

  test('counts age-eligible routine series, distinguishes zero-dose from no OPV, and scopes lists', async () => {
    const complete = await child('Series complete', '2026-01-01');
    await routine(complete, 'Penta', 1, '2026-02-12');
    await routine(complete, 'Penta', 2, '2026-03-12');
    await routine(complete, 'Penta', 3, '2026-04-09');
    const missedFirst = await child('Missing Penta-1', '2026-01-02');
    await routine(missedFirst, 'Penta', 2);
    await routine(missedFirst, 'OPV', 0, '2026-01-02');
    await child('Six weeks exactly', '2026-04-20');
    await child('Five years exactly', '2021-06-01');
    await child('Deceased before snapshot', '2026-01-03', { deceasedOn: '2026-04-01' });
    const hidden = await child('Outside scope', '2026-01-02', { area: f.areaB, house: otherHouse, creator: f.lhwB });
    await routine(complete, 'OPV', 1, '2026-06-02');
    await routine(complete, 'OPV', 0, '2026-05-02', f.areaB);
    await routine(hidden, 'Penta', 1, '2026-05-01', f.areaA);

    const response = await get('/coverage', { endDate: END }).expect(200);
    expect(response.body).toMatchObject({ asOf: END, totalChildren: 3, zeroDose: 1, noOpv: 2, reviewStatus: 'pending_clinical_review' });
    expect(response.body.areas.map((a) => a.areaId)).toEqual([f.areaA]);
    expect(response.body.antigens).toContainEqual(
      expect.objectContaining({ antigen: 'Penta', eligible: 2, fullyVaccinated: 1, percentage: 50, lowCoverage: true }),
    );
    expect(response.body.antigens.map((a) => a.antigen)).not.toContain('HepB');
    const zeroDose = await get('/children', { endDate: END, followUp: 'zero-dose' }).expect(200);
    expect(zeroDose.body.children.map((c) => c.id)).toEqual([missedFirst]);
    const noOpv = await get('/children', { endDate: END, followUp: 'no-opv', limit: 1, page: 2 }).expect(200);
    expect(noOpv.body).toMatchObject({ total: 2, page: 2, limit: 1 });
    expect(noOpv.body.children.map((c) => c.id)).toEqual([complete]);
    const outside = await get('/children', { areaId: f.areaB, endDate: END }).expect(200);
    expect(outside.body).toMatchObject({ children: [], total: 0 });
    const { rows: [{ district_id: districtId }] } = await query(
      `SELECT t.district_id FROM areas a JOIN union_councils u ON u.id = a.union_council_id
       JOIN tehsils t ON t.id = u.tehsil_id WHERE a.id = $1`, [f.areaB],
    );
    const wrongDistrict = await get('/coverage', { areaId: f.areaA, districtId, endDate: END }).expect(200);
    expect(wrongDistrict.body).toMatchObject({ totalChildren: 0, areas: [] });
  });

  test('selects the effective EPI version and keeps optional doses in their rollout area', async () => {
    const areaAChild = await child('Early routine dose', '2026-04-11');
    await child('Outside rollout', '2026-04-11', { area: f.areaB, house: otherHouse, creator: f.lhwB });
    await routine(areaAChild, 'HepB', 0, '2026-04-11');
    const rules = structuredClone(require('../../clinical-rules/clinical-rules.json'));
    rules.version = 'analytics-fixture';
    rules.epi_schedule.schedule_version = 'test-rollout';
    rules.epi_schedule.effective_from = END;
    rules.epi_schedule.doses.find((dose) => dose.antigen === 'HepB').enabled_area_ids = [f.areaA];
    rules.epi_schedule.doses.find((dose) => dose.antigen === 'Penta' && dose.dose_number === 1).recommended_age.weeks = 8;
    await query(
      `INSERT INTO clinical_rules_versions (version, content, content_sha256, effective_from)
       VALUES ($1, $2, repeat('a', 64), $3)`, [rules.version, rules, END],
    );
    const admin = tokenFor(f.admin, 'admin');

    const previous = await get('/coverage', { endDate: '2026-05-31' }, admin).expect(200);
    expect(previous.body).toMatchObject({ scheduleVersion: 'pk-epi-2022.1', zeroDose: 2 });
    const updated = await get('/coverage', { endDate: END }, admin).expect(200);
    expect(updated.body).toMatchObject({ scheduleVersion: 'test-rollout', zeroDose: 0 });
    expect(updated.body.antigens).toContainEqual(
      expect.objectContaining({ antigen: 'HepB', eligible: 1, fullyVaccinated: 1, percentage: 100 }),
    );
    expect(updated.body.areas.find((area) => area.areaId === f.areaB).antigens.map((a) => a.antigen)).not.toContain('HepB');
  });

  test('groups campaign areas and counts latest visits, repeat visits and campaign OPV once', async () => {
    const first = await child('Campaign dose', '2024-01-01');
    await child('No dose', '2024-01-02');
    const round = await campaign();
    const otherRoundArea = await campaign(f.areaB, round.round_id);
    const unavailableHouse = await household(f.areaA, f.lhwA);
    const noEligibleHouse = await household(f.areaA, f.lhwA);
    await visit(round.id, house, '2026-05-02', 'not_available', 2, 0);
    const latest = await visit(round.id, house, '2026-05-03', 'refusal', 2, 1);
    await visit(round.id, unavailableHouse, '2026-05-04', 'not_available', 1, 0);
    await visit(round.id, noEligibleHouse, '2026-05-04', 'all_vaccinated', 0, 0);
    await visit(otherRoundArea.id, otherHouse, '2026-05-03', 'all_vaccinated', 9, 9, f.areaB);
    await query(
      `INSERT INTO campaign_child_doses (area_id, created_by, campaign_id, campaign_household_status_id, child_id, given_on)
       VALUES ($1, $2, $3, $4, $5, '2026-05-03')`, [f.areaA, f.lhwA, round.id, latest, first],
    );
    await query(
      `INSERT INTO refusals (area_id, created_by, campaign_household_status_id, reason) VALUES ($1, $2, $3, 'past_reaction')`,
      [f.areaA, f.lhwA, latest],
    );
    await query(
      `INSERT INTO revisits (area_id, created_by, campaign_household_status_id, scheduled_on) VALUES ($1, $2, $3, '2026-05-10')`,
      [f.areaA, f.lhwA, latest],
    );

    const { body } = await get('/polio', { roundId: round.round_id, startDate: START, endDate: END, limit: 2 }).expect(200);
    expect(body).toMatchObject({
      total: 3, households: expect.any(Array),
      summary: {
        householdsVisited: 3, childrenEligible: 3, childrenVaccinated: 1, partialHouseholds: 1,
        refusalHouseholds: 0, notAvailableHouseholds: 1, noEligibleHouseholds: 1, refusals: 1, noOpv: 1,
      },
    });
    expect(body.rounds.map((entry) => entry.id)).toEqual([round.round_id]);
    const page2 = await get('/polio', { roundId: round.round_id, startDate: START, endDate: END, limit: 2, page: 2 }).expect(200);
    expect(page2.body.households).toEqual([
      expect.objectContaining({ status: 'partially_covered', refusals: 1, nextRevisitOn: '2026-05-10' }),
    ]);
    const admin = tokenFor(f.admin, 'admin');
    const adminPolio = await get('/polio', { roundId: round.round_id, endDate: END }, admin).expect(200);
    expect(adminPolio.body.summary).toMatchObject({ householdsVisited: 4, childrenVaccinated: 10 });
    const filters = await get('/filters').expect(200);
    expect(filters.body.rounds.map((entry) => entry.id)).toEqual([round.round_id]);
  });

  test('maps GPS only and counts recent latest nutrition classifications without treating missing GPS as missing screenings', async () => {
    const mappedChild = await child('Recent screening', '2024-01-01');
    const unmappedChild = await child('No GPS', '2024-01-02', { house: await household(f.areaA, f.lhwA, false) });
    await screen(mappedChild, '2026-04-05', 'mam');
    await screen(mappedChild, '2026-05-05', 'sam', { oedema: true, underweight: true });
    await screen(mappedChild, '2026-05-06', 'normal', { stunting: true });
    await screen(unmappedChild, '2026-05-05', 'sam');
    const { body } = await get('/hotspots', { startDate: START, endDate: END }).expect(200);
    expect(body).toMatchObject({
      total: 1,
      households: [expect.objectContaining({ id: house, sam: 0, mam: 0, stunting: 1, zeroDose: 1, noOpv: 1 })],
    });
    const { nutrition } = require('../src/services/child-analytics.service');
    await expect(nutrition({ role: 'supervisor', id: f.supervisorA }, { startDate: START, endDate: END })).resolves.toEqual({
      screenings: 3, childrenScreened: 2, sam: 1, mam: 0, normal: 1, underweight: 0, stunting: 1,
    });
  });

  test('validates query parameters, handles empty scopes, and denies LHW portal requests', async () => {
    await get('/children', { endDate: '2026-02-30' }).expect(400);
    await get('/polio', { startDate: END, endDate: START }).expect(400);
    await get('/hotspots', { limit: 2001 }).expect(400);
    await get('/coverage', {}, tokenFor(f.lhwA, 'lhw', f.deviceA)).expect(403);
    const { body } = await get('/hotspots', { areaId: f.areaB }).expect(200);
    expect(body).toEqual({ households: [], total: 0, page: 1, limit: 500 });
  });
});
