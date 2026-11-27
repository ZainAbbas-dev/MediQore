const { execFile } = require('node:child_process');
const { promisify } = require('node:util');
const { randomUUID } = require('node:crypto');
const request = require('supertest');
const ExcelJS = require('exceljs');
const { createApp } = require('../src/app');
const { renderReport } = require('../src/services/reports-render.service');
const { runReportCycle } = require('../src/services/reports.service');
const { describeDb, resetDatabase, createFixtures, tokenFor, closePool, query } = require('./db');

const app = createApp();
const at = (date) => new Date(date);
const fakeRender = jest.fn(async (format, report) => Buffer.from(JSON.stringify({ format, report })));
const binary = (res, callback) => {
  const chunks = [];
  res.on('data', (chunk) => chunks.push(chunk));
  res.on('end', () => callback(null, Buffer.concat(chunks)));
  res.on('error', callback);
};

function get(token, path) {
  return request(app).get(`/api/v1/reports${path}`).set('Authorization', `Bearer ${token}`);
}

async function push(ids, records) {
  const response = await request(app).post('/api/v1/sync/push')
    .set('Authorization', `Bearer ${tokenFor(ids.lhwA, 'lhw', ids.deviceA)}`)
    .send({ deviceId: ids.deviceA, records });
  expect(response.status).toBe(200);
  expect(response.body.results.map((row) => row.status)).toEqual(records.map(() => 'created'));
}

const registration = (registeredOn) => {
  const household = { table: 'households', id: randomUUID(), createdOnDevice: `${registeredOn}T09:00:00Z`, data: { village: 'Synthetic Village' } };
  const woman = {
    table: 'women', id: randomUUID(), createdOnDevice: household.createdOnDevice,
    data: { householdId: household.id, patientCode: 'SYNTH-REPORT-A', name: 'Synthetic Woman', age: 26 },
  };
  const pregnancy = {
    table: 'pregnancies', id: randomUUID(), createdOnDevice: household.createdOnDevice,
    data: { womanId: woman.id, registeredOn, pregnancyMonthAtRegistration: 3 },
  };
  return [household, woman, pregnancy];
};

const visit = (pregnancyId, visitedAt) => ({
  table: 'visits', id: randomUUID(), createdOnDevice: visitedAt, data: { pregnancyId, visitedAt, pulseBpm: 84 },
});

describeDb('scheduled M10 reports', () => {
  let ids;
  let supervisor;
  let admin;
  beforeEach(async () => {
    await resetDatabase();
    ids = await createFixtures();
    supervisor = tokenFor(ids.supervisorA, 'supervisor');
    admin = tokenFor(ids.admin, 'admin');
    fakeRender.mockClear();
  });
  afterAll(closePool);

  async function list(token, period = 'weekly') {
    const response = await get(token, `?period=${period}`);
    expect(response.status).toBe(200);
    return response.body.reports;
  }

  it('uses Monday and month boundaries in Pakistan time and retries without duplicate jobs', async () => {
    await runReportCycle({ now: at('2026-05-31T18:59:59Z'), render: fakeRender, limit: 100 });
    expect((await list(supervisor)).map((row) => row.periodStart)).toEqual(['2026-05-18']);
    expect((await list(supervisor, 'monthly')).map((row) => row.periodStart)).toEqual(['2026-04-01']);
    expect(fakeRender).toHaveBeenCalledTimes(8);

    const boundary = { now: at('2026-05-31T19:00:00Z'), render: fakeRender, limit: 100 };
    await runReportCycle(boundary);
    expect((await list(supervisor)).map((row) => [row.periodStart, row.periodEnd])).toEqual([
      ['2026-05-25', '2026-05-31'], ['2026-05-18', '2026-05-24'],
    ]);
    expect((await list(supervisor, 'monthly')).map((row) => row.periodStart)).toEqual(['2026-05-01', '2026-04-01']);
    await runReportCycle(boundary);
    expect(fakeRender).toHaveBeenCalledTimes(16);
    expect((await query('SELECT count(*)::int AS count FROM report_jobs')).rows[0].count).toBe(16);

    const first = await get(admin, '?period=weekly&limit=1').expect(200);
    const next = await get(admin, `?period=weekly&limit=1&before=${first.body.nextBefore}`).expect(200);
    expect(first.body.reports[0].periodStart).toBe(next.body.reports[0].periodStart);
    expect(first.body.reports[0].areaId).not.toBe(next.body.reports[0].areaId);
  });

  it('regenerates the affected period after a late successful sync and keeps both artifact IDs', async () => {
    const records = registration('2026-05-28');
    const pregnancyId = records[2].id;
    const tuesday = visit(pregnancyId, '2026-05-26T02:00:00Z');
    const nextMonday = visit(pregnancyId, '2026-05-31T19:00:00Z');
    await push(ids, [...records, tuesday, nextMonday]);
    const cycle = { now: at('2026-06-01T00:00:00Z'), render: fakeRender, limit: 100 };
    await runReportCycle(cycle);
    const [before] = await list(supervisor);
    const getWorkbook = (id) => get(supervisor, `/${id}/download`).buffer(true).parse(binary).expect(200);
    const first = await getWorkbook(before.files.xlsx.id);
    expect(JSON.parse(first.body).report.maternal).toMatchObject({ registrations: 1, visits: 1 });

    const lateVisit = visit(pregnancyId, '2026-05-31T18:59:59Z');
    await push(ids, [lateVisit]);
    fakeRender.mockClear();
    await runReportCycle(cycle);
    const [after] = await list(supervisor);
    expect(after.files.pdf.id).toBe(before.files.pdf.id);
    expect(after.files.xlsx.id).toBe(before.files.xlsx.id);
    const second = await getWorkbook(after.files.xlsx.id);
    expect(JSON.parse(second.body).report.maternal).toMatchObject({ registrations: 1, visits: 2 });
    expect(fakeRender.mock.calls.map(([, report]) => report.area.id)).toEqual(Array(4).fill(ids.areaA));
    await runReportCycle(cycle);
    expect(fakeRender).toHaveBeenCalledTimes(4);
  });

  it('limits report IDs and filters to current assignments and records a successful download', async () => {
    await runReportCycle({ now: at('2026-06-01T00:00:00Z'), render: fakeRender, limit: 100 });
    const own = (await list(supervisor))[0];
    const other = (await list(admin)).find((row) => row.areaId === ids.areaB);
    expect(own.areaId).toBe(ids.areaA);
    await get(supervisor, `?areaId=${ids.areaB}`).expect(404);
    await get(supervisor, `/${other.files.pdf.id}/download`).expect(404);
    await get(tokenFor(ids.lhwA, 'lhw', ids.deviceA), `/${own.files.pdf.id}/download`).expect(403);
    await request(app).get(`/api/v1/reports/${own.files.pdf.id}/download`).expect(401);

    await get(supervisor, `/${own.files.pdf.id}/download`).buffer(true).parse(binary)
      .expect('Content-Type', 'application/pdf').expect('Cache-Control', /no-store/).expect(200);
    const { rows } = await query("SELECT user_id, entity_id FROM audit_log WHERE action = 'report_download'");
    expect(rows).toEqual([{ user_id: ids.supervisorA, entity_id: own.files.pdf.id }]);
    await query('UPDATE supervisor_areas SET deleted_at = now() WHERE supervisor_id = $1', [ids.supervisorA]);
    await get(supervisor, `/${own.files.pdf.id}/download`).expect(404);
  });

  it('exports maternal and child totals reconciled with synthetic source records', async () => {
    const records = registration('2026-05-28');
    const pregnancyId = records[2].id;
    const first = visit(pregnancyId, '2026-05-28T10:00:00Z');
    const second = visit(pregnancyId, '2026-05-29T08:00:00Z');
    await push(ids, [...records, first, second]);
    const source = [ids.areaA, ids.lhwA, pregnancyId];
    await query(`INSERT INTO risk_assessments
      (area_id, created_by, pregnancy_id, visit_id, model_level, model_version,
       rule_result, rules_version, final_level, input_set, is_emergency)
      VALUES ($1,$2,$3,$4,'high','fixture','none','fixture','red','five_feature',false),
             ($1,$2,$3,$5,'low','fixture','emergency','fixture','red','five_feature',true)`, [...source, first.id, second.id]);
    await query(`INSERT INTO referrals (area_id, created_by, pregnancy_id, referred_at, attended, outcome_recorded_at)
      VALUES ($1,$2,$3,'2026-05-28T10:00:00Z',true,'2026-05-28T11:00:00Z'),
             ($1,$2,$3,'2026-05-29T08:00:00Z',true,'2026-05-31T19:00:00Z')`, source);
    const { rows: [alert] } = await query(`INSERT INTO emergency_alerts
      (area_id, created_by, pregnancy_id, visit_recorded_at, raised_at, status)
      VALUES ($1,$2,$3,'2026-05-29T08:00:00Z','2026-05-29T08:00:00Z','acknowledged') RETURNING id`, source);
    await query(`INSERT INTO alert_acknowledgements (area_id, created_by, alert_id, method, acknowledged_at)
      VALUES ($1,$2,$3,'dashboard','2026-05-31T19:00:00Z')`, [ids.areaA, ids.supervisorA, alert.id]);
    const { rows: [child] } = await query(`INSERT INTO children (area_id, created_by, household_id, name, date_of_birth, sex)
      VALUES ($1,$2,$3,'Synthetic Child','2026-01-01','female') RETURNING id`, [ids.areaA, ids.lhwA, records[0].id]);
    const { rows: [campaign] } = await query(`INSERT INTO campaigns (area_id, created_by, name, starts_on, ends_on)
      VALUES ($1,$2,'Synthetic Campaign','2026-05-27','2026-06-05') RETURNING id`, [ids.areaA, ids.admin]);
    await query(`INSERT INTO campaign_household_status
      (area_id, created_by, campaign_id, household_id, visited_on, status, children_under_5, children_vaccinated)
      VALUES ($1,$2,$3,$4,'2026-05-28','refusal',2,1)`, [ids.areaA, ids.lhwA, campaign.id, records[0].id]);
    await query(`INSERT INTO nutrition_screenings (area_id, created_by, child_id, screened_on, malnutrition_class, rules_version)
      VALUES ($1,$2,$3,'2026-05-27','mam','fixture'), ($1,$2,$3,'2026-05-29','sam','fixture')`,
    [ids.areaA, ids.lhwA, child.id]);

    const render = (format, report) => format === 'xlsx' ? renderReport(format, report) : fakeRender(format, report);
    await runReportCycle({ now: at('2026-06-01T00:00:00Z'), render, limit: 100 });
    const [{ files }] = await list(supervisor);
    const { body } = await get(supervisor, `/${files.xlsx.id}/download`).buffer(true).parse(binary).expect(200);
    const workbook = new ExcelJS.Workbook();
    await workbook.xlsx.load(body);
    const counts = (sheet) => Object.fromEntries(workbook.getWorksheet(sheet).getRows(6, 20)
      .map((row) => [row.getCell(1).value, row.getCell(2).value]));
    expect(counts('Maternal health')).toMatchObject({
      'Pregnancies registered': 1, 'Home visits': 2, 'Women with a red result': 1,
      'Women with an emergency result': 1, 'Referrals made': 2, 'Referrals attended by period end': 1,
      'Referral completion (%)': 50, 'Alerts unacknowledged at period end': 1,
    });
    expect(workbook.getWorksheet('High-risk cases').getRow(6).values.slice(1)).toEqual(['SYNTH-REPORT-A', '2026-05-29', 'Yes']);
    expect(counts('Polio progress')).toMatchObject({ 'Households visited': 1, 'Partially covered households': 1 });
    expect(counts('Immunisation')['WHO zero-dose children (no Penta-1 after due age)']).toBe(1);
    expect(counts('Nutrition')).toMatchObject({ 'Screenings': 2, 'Distinct children screened': 1, 'Children with SAM': 1 });
  });

  it('retains the successful Excel file and retries only the failed PDF job', async () => {
    const render = jest.fn(async (format, report) => {
      if (format === 'pdf' && report.area.id === ids.areaA) throw new Error('renderer temporarily unavailable');
      return Buffer.from(format);
    });
    const now = at('2026-06-01T00:00:00Z');
    await runReportCycle({ now, render, limit: 100 });
    const [before] = await list(supervisor);
    expect(before.files).toMatchObject({ pdf: { status: 'failed' }, xlsx: { status: 'done' } });
    await get(supervisor, `/${before.files.pdf.id}/download`).expect(404);
    await runReportCycle({ now, render: fakeRender, limit: 100 });
    const [after] = await list(supervisor);
    expect(after.files).toMatchObject({ pdf: { id: before.files.pdf.id, status: 'done' }, xlsx: before.files.xlsx });
    expect(fakeRender.mock.calls.map(([format]) => format)).toEqual(['pdf', 'pdf']);
  });
});

const sample = {
  area: { id: 'test', areaName: 'Synthetic Area', districtName: 'Synthetic District' },
  period: 'weekly', periodStart: '2026-05-25', periodEnd: '2026-05-31',
  maternal: { registrations: 2, visits: 4, highRisk: 1, referrals: 2, referralsAttended: 1, unacknowledgedAlerts: 1 },
  outcomes: [], risk: [], activity: [],
  coverage: { scheduleVersion: 'test', zeroDose: 1, noOpv: 1, antigens: [] },
  polio: { summary: {}, rounds: [] }, nutrition: { screenings: 4, sam: 1 },
};

it('writes numeric workbook cells and all health sections', async () => {
  const workbook = new ExcelJS.Workbook();
  await workbook.xlsx.load(await renderReport('xlsx', sample));
  expect(workbook.worksheets.map((sheet) => sheet.name)).toEqual([
    'Maternal health', 'High-risk cases', 'LHW activity', 'Polio progress', 'Immunisation', 'Nutrition',
  ]);
  expect(workbook.getWorksheet('Maternal health').getColumn(2).values).toContain(4);
});

const chromeTest = process.env.CHROME_PATH ? it : it.skip;
chromeTest('prints and embeds the Urdu font in a downloadable PDF', async () => {
  const { stdout: output } = await promisify(execFile)(process.execPath, ['-e',
    `require('./src/services/reports-render.service').renderReport('pdf', JSON.parse(process.argv[1]))
      .then((file) => process.stdout.write(file))`, JSON.stringify(sample)], { encoding: 'buffer' });
  expect(output.subarray(0, 5).toString()).toBe('%PDF-');
  expect(output.toString('latin1')).toMatch(/Nastaleeq/i);
}, 20000);
