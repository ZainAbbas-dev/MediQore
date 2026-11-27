const fs = require('node:fs/promises');
const path = require('node:path');
const ExcelJS = require('exceljs');

const FONT = path.resolve(__dirname, '../../../mobile/assets/fonts/JameelNooriNastaleeq.ttf');
const percent = (numerator, denominator) => denominator ? Math.round(numerator / denominator * 1000) / 10 : null;

function reportTitle(report) {
  return report.period === 'weekly' ? 'Weekly health report' : 'Monthly health report';
}

function sections(report) {
  const { maternal: m, coverage, polio, nutrition: n } = report;
  const polioMetrics = [
    ['Households visited', 'householdsVisited'], ['Eligible children', 'childrenEligible'],
    ['Children vaccinated', 'childrenVaccinated'], ['Fully covered households', 'allVaccinatedHouseholds'],
    ['Partially covered households', 'partialHouseholds'], ['Refusal households', 'refusalHouseholds'],
    ['Not available households', 'notAvailableHouseholds'], ['Households without eligible children', 'noEligibleHouseholds'],
    ['Refusals recorded', 'refusals'],
  ];
  return [
    {
      name: 'Maternal health', description: 'Registration, visit, outcome, referral and alert records dated within the reporting period.',
      tables: [
        { headers: ['Metric', 'Total'], rows: [
          ['Women registered for a pregnancy', m.womenRegistered], ['Pregnancies registered', m.registrations],
          ['Home visits', m.visits], ['Women with a red result', m.highRisk], ['Women with an emergency result', m.emergencies],
          ['Referrals made', m.referrals], ['Referrals attended by period end', m.referralsAttended],
          ['Referral completion (%)', percent(m.referralsAttended, m.referrals)],
          ['Alerts unacknowledged at period end', m.unacknowledgedAlerts], ['ANC visits due', m.ancDue],
          ['ANC visits missed by period end', m.ancMissed],
        ] },
        { headers: ['Pregnancy outcome', 'Total'], rows: report.outcomes.map(({ outcome, count }) => [
          ({ live_birth: 'Live birth', stillbirth: 'Stillbirth', miscarriage: 'Miscarriage', maternal_death: 'Maternal death',
            moved_out: 'Moved out', lost_to_follow_up: 'Lost to follow-up' })[outcome] ?? outcome, count,
        ]) },
      ],
    },
    {
      name: 'High-risk cases', description: 'One entry per woman with a red result during the period. The date is her latest red visit in the period.',
      tables: [{ headers: ['Patient ID', 'Visit date', 'Emergency during period'], rows: report.risk.map((row) => [
        row.patientCode, row.visitedOn, row.emergency ? 'Yes' : 'No',
      ]) }],
    },
    {
      name: 'LHW activity', description: 'Visits and pregnancy registrations attributed to the LHW who recorded them in this area.',
      tables: [{ headers: ['LHW code', 'Name', 'Visits', 'Pregnancies registered'], rows: report.activity.map((row) => [
        row.lhwCode, row.fullName, row.visits, row.registrations,
      ]) }],
    },
    {
      name: 'Polio progress', description: 'Campaign activity dated within the reporting period. No OPV dose is measured at period end.',
      tables: [
        { headers: ['Metric', 'Total'], rows: [
          ...polioMetrics.map(([label, key]) => [label, polio.summary[key]]),
          ['Children with no OPV dose recorded', polio.summary.noOpv ?? coverage.noOpv],
        ] },
        { headers: ['Campaign round', 'Start date', 'End date', 'Households visited', 'Eligible children', 'Children vaccinated',
          'Partial households', 'Refusal households', 'Not available households'],
          rows: polio.rounds.map((round) => [round.name, round.startsOn, round.endsOn, round.householdsVisited,
            round.childrenEligible, round.childrenVaccinated, round.partialHouseholds, round.refusalHouseholds,
            round.notAvailableHouseholds]) },
      ],
    },
    {
      name: 'Immunisation', description: `Coverage at period end under EPI schedule ${coverage.scheduleVersion ?? 'unavailable'}. A child is eligible for an antigen once the final required dose is due.`,
      tables: [
        { headers: ['Metric', 'Total'], rows: [['WHO zero-dose children (no Penta-1 after due age)', coverage.zeroDose]] },
        { headers: ['Antigen', 'Eligible children', 'Fully vaccinated', 'Coverage (%)', `Below ${coverage.coverageThreshold ?? 90}%`],
          rows: coverage.antigens.map((row) => [
          row.antigen, row.eligible, row.fullyVaccinated, row.percentage, row.eligible > 0 ? (row.lowCoverage ? 'Yes' : 'No') : null,
        ]) },
      ],
    },
    {
      name: 'Nutrition', description: 'Screenings during the reporting period, with health classifications from each child’s latest screening.',
      tables: [{ headers: ['Metric', 'Total'], rows: [
        ['Screenings', n.screenings], ['Distinct children screened', n.childrenScreened], ['Children with SAM', n.sam],
        ['Children with MAM', n.mam], ['Children classified as normal', n.normal], ['Underweight children', n.underweight],
        ['Children with stunting', n.stunting],
      ] }],
    },
  ];
}

function scopeText({ areaName, unionCouncilName, tehsilName, districtName }) {
  return [areaName, unionCouncilName, tehsilName, districtName].filter(Boolean).join(' / ');
}

async function excel(report) {
  const workbook = new ExcelJS.Workbook();
  workbook.creator = 'MediQore';
  for (const section of sections(report)) {
    const sheet = workbook.addWorksheet(section.name, { views: [{ state: 'frozen', ySplit: 5 }] });
    sheet.addRow([`MediQore | ${reportTitle(report)}`]).font = { bold: true, size: 15, color: { argb: 'FF124D47' } };
    sheet.addRow([scopeText(report.area)]);
    sheet.addRow([`${report.periodStart} to ${report.periodEnd} (Pakistan time)`]);
    sheet.addRow([section.description]);
    for (const { headers, rows } of section.tables) {
      const header = sheet.addRow(headers);
      header.font = { bold: true, color: { argb: 'FFFFFFFF' } };
      header.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: 'FF12675E' } };
      for (const row of rows) sheet.addRow(row.map((value) => value ?? null));
      if (rows.length === 0) sheet.addRow(['No records']);
      sheet.addRow([]);
    }
    const columns = Math.max(...section.tables.map((table) => table.headers.length));
    for (let i = 1; i <= columns; i++) {
      const labels = section.tables.map((table) => table.headers[i - 1]?.length ?? 0);
      sheet.getColumn(i).width = Math.max(i === 1 ? 50 : 20, ...labels.map((length) => length + 2));
    }
    for (let row = 1; row <= 4; row++) sheet.mergeCells(row, 1, row, columns);
  }
  return Buffer.from(await workbook.xlsx.writeBuffer());
}

const entities = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
const escape = (value) => String(value ?? '–').replace(/[&<>"']/g, (character) => entities[character]);
const cell = (value) => `<bdi>${escape(value)}</bdi>`;

function pdfSection({ name, description, tables }) {
  return `<section><h2>${escape(name)}</h2><p class="context">${escape(description)}</p>${tables.map(({ headers, rows }) => `
    <table><thead><tr>${headers.map((header) => `<th scope="col">${escape(header)}</th>`).join('')}</tr></thead>
    <tbody>${rows.length ? rows.map((row) => `<tr>${row.map((value) => `<td>${cell(value)}</td>`).join('')}</tr>`).join('')
      : `<tr><td colspan="${headers.length}" class="context">No records</td></tr>`}</tbody></table>`).join('')}</section>`;
}

function reportHtml(report, font) {
  const title = report.period === 'weekly' ? 'ہفتہ وار صحت رپورٹ' : 'ماہانہ صحت رپورٹ';
  const summary = [
    ['درج شدہ حمل', report.maternal.registrations], ['گھریلو معائنے', report.maternal.visits],
    ['زیادہ خطرے والے کیس', report.maternal.highRisk], ['ہسپتال بھیجے گئے کیس', report.maternal.referrals],
    ['پینٹا کی پہلی خوراک کے بغیر بچے', report.coverage.zeroDose], ['غذائی معائنے', report.nutrition.screenings],
  ];
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>${reportTitle(report)} | MediQore</title>
  <style>
    @font-face { font-family: 'Jameel Noori Nastaleeq'; src: url('data:font/ttf;base64,${font}') format('truetype'); }
    @page { size: A4; margin: 15mm; }
    * { box-sizing: border-box; }
    body { margin: 0; color: #142f2c; font: 10pt Arial, 'Jameel Noori Nastaleeq', sans-serif; }
    header { padding: 16px 18px; background: #e8f3ef; border-top: 4px solid #11645b; }
    .brand { color: #12675e; font-weight: bold; }
    h1 { font-size: 23pt; margin: 5px 0 10px; }
    h2 { font-size: 14pt; margin: 19px 0 5px; break-after: avoid; }
    p { margin: 4px 0; }
    .context { color: #4a605d; }
    .urdu { font-family: 'Jameel Noori Nastaleeq', serif; line-height: 1.95; }
    bdi { unicode-bidi: isolate; }
    .urdu bdi { display: inline; font-family: Arial, 'Jameel Noori Nastaleeq', sans-serif; }
    .urdu h2 { font-size: 20pt; margin: 10px 0 2px; font-weight: normal; }
    table { width: 100%; border-collapse: collapse; margin: 8px 0 12px; }
    thead { display: table-header-group; }
    th, td { padding: 5px 7px; text-align: start; border-bottom: 1px solid #dce7e4; overflow-wrap: anywhere; }
    th { color: #124d47; background: #e8f3ef; }
    tr { break-inside: avoid; }
    .urdu table { font-size: 13pt; }
    .urdu th, .urdu td { padding-block: 0; }
    .urdu th { font-weight: normal; }
  </style></head><body>
    <header><div class="brand">MediQore</div><h1>${reportTitle(report)}</h1>
      <p>${cell(scopeText(report.area))}</p><p>${cell(report.periodStart)} to ${cell(report.periodEnd)} (Pakistan time)</p></header>
    <section lang="ur" dir="rtl" class="urdu"><h2>${title}</h2>
      <table><tbody>${summary.map(([label, value]) => `<tr><th scope="row">${label}</th><td><bdi dir="ltr">${escape(value)}</bdi></td></tr>`).join('')}</tbody></table>
    </section>${sections(report).map(pdfSection).join('')}
  </body></html>`;
}

let font;
async function pdf(report) {
  const executablePath = process.env.CHROME_PATH;
  if (!executablePath) throw new Error('CHROME_PATH is required to render a PDF');
  if (!font) font = (await fs.readFile(FONT)).toString('base64');
  const args = process.env.CHROME_NO_SANDBOX === 'true' ? ['--no-sandbox'] : [];
  const { launch } = await import('puppeteer-core');
  const browser = await launch({ executablePath, args });
  try {
    const page = await browser.newPage();
    await page.setContent(reportHtml(report, font), { waitUntil: 'load' });
    const shaped = await page.evaluate(async () => {
      // eslint-disable-next-line no-undef -- Evaluated in Chromium.
      const fonts = await document.fonts.load('20pt "Jameel Noori Nastaleeq"', 'ماہانہ صحت رپورٹ');
      return fonts.length > 0 && fonts.every((face) => face.status === 'loaded');
    });
    if (!shaped) throw new Error('The Urdu report font could not be loaded');
    return Buffer.from(await page.pdf({ printBackground: true, preferCSSPageSize: true }));
  } finally {
    await browser.close();
  }
}

async function renderReport(format, report) {
  return format === 'xlsx' ? excel(report) : pdf(report);
}

module.exports = { renderReport };
