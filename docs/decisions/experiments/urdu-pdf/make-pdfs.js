// P0-11 experiment: print the same one-page Urdu report two ways, so the team
// can see which method shapes Nastaliq and orders right-to-left text correctly
// (roadmap, Risks: "Urdu text in PDF reports").
//
//   npm install
//   CHROME_PATH=/path/to/chrome npm start      (Windows: $env:CHROME_PATH="C:\Program Files\Google\Chrome\Application\chrome.exe")
//
// Writes out/pdfkit.pdf and out/chrome.pdf. All names and values are made up (LI-10).
const fs = require('node:fs');
const path = require('node:path');
const PDFDocument = require('pdfkit');
const puppeteer = require('puppeteer-core');

const FONT = path.resolve(__dirname, '../../../../mobile/assets/fonts/JameelNooriNastaleeq.ttf');
const OUT = path.join(__dirname, 'out');
const VERSIONS = require('./package.json').dependencies;

// One synthetic patient summary: Urdu with embedded IDs, numbers and units, as in
// the M6 FE-3 progress report.
const REPORT = {
  title: 'ماہانہ صحت رپورٹ',
  englishTitle: 'Monthly health report (synthetic data)',
  rows: [
    ['مریضہ کا نام', 'عائشہ خان'],
    ['مریضہ نمبر', 'SYN-RWP-001-0001'],
    ['بلڈ پریشر', '140/90 mmHg'],
    ['درجہ حرارت', '37.2 °C'],
    ['خطرے کی سطح', 'زیادہ'],
  ],
  paragraph:
    'یہ رپورٹ صرف فیصلے میں مدد کے لیے ہے، طبی تشخیص نہیں۔ اگر خطرے کی علامات ظاہر ہوں تو فوراً قریبی ہسپتال سے رابطہ کریں۔ اگلا معائنہ 15 دن بعد ہوگا۔',
};

function withPdfkit(file) {
  return new Promise((resolve, reject) => {
    const doc = new PDFDocument({ size: 'A4', margin: 56 });
    const stream = fs.createWriteStream(file);
    doc.pipe(stream);
    doc.registerFont('Nastaleeq', FONT);
    doc.font('Helvetica').fontSize(11).text(`pdfkit ${VERSIONS.pdfkit}`, { align: 'left' });
    doc.font('Helvetica-Bold').fontSize(16).text(REPORT.englishTitle, { align: 'left' });
    doc.moveDown(0.5);
    doc.font('Nastaleeq').fontSize(22).text(REPORT.title, { align: 'right' });
    doc.fontSize(15);
    for (const [label, value] of REPORT.rows) {
      doc.text(`${label}: ${value}`, { align: 'right' });
    }
    doc.moveDown(0.5);
    doc.text(REPORT.paragraph, { align: 'right' });
    doc.end();
    stream.on('finish', resolve);
    stream.on('error', reject);
  });
}

function html() {
  const fontUrl = `data:font/ttf;base64,${fs.readFileSync(FONT).toString('base64')}`;
  const rows = REPORT.rows
    .map(([label, value]) => `<tr><th>${label}</th><td><bdi>${value}</bdi></td></tr>`)
    .join('');
  return `<!doctype html>
<html lang="ur" dir="rtl"><head><meta charset="utf-8">
<style>
  @font-face { font-family: 'Jameel Noori Nastaleeq'; src: url('${fontUrl}'); }
  @page { size: A4; margin: 20mm; }
  body { font-family: 'Jameel Noori Nastaleeq', serif; font-size: 15pt; line-height: 2.1; }
  .en { font-family: Helvetica, Arial, sans-serif; direction: ltr; text-align: left; line-height: 1.4; }
  h1 { font-size: 22pt; font-weight: normal; margin: 0.3em 0; }
  th { text-align: right; font-weight: normal; padding-left: 1.5em; }
  bdi { unicode-bidi: isolate; }
</style></head>
<body>
  <p class="en" style="font-size:11pt;margin:0">HTML + headless Chrome (puppeteer-core ${VERSIONS['puppeteer-core']})</p>
  <p class="en" style="font-size:16pt;font-weight:bold;margin:0">${REPORT.englishTitle}</p>
  <h1>${REPORT.title}</h1>
  <table>${rows}</table>
  <p>${REPORT.paragraph}</p>
</body></html>`;
}

async function withChrome(file) {
  const executablePath = process.env.CHROME_PATH;
  if (!executablePath) throw new Error('Set CHROME_PATH to a Chrome or Chromium executable');
  const browser = await puppeteer.launch({ executablePath, args: ['--no-sandbox'] });
  try {
    const page = await browser.newPage();
    await page.setContent(html(), { waitUntil: 'load' });
    await page.evaluateHandle('document.fonts.ready');
    await page.pdf({ path: file, format: 'A4', printBackground: true });
  } finally {
    await browser.close();
  }
}

async function main() {
  fs.mkdirSync(OUT, { recursive: true });
  await withPdfkit(path.join(OUT, 'pdfkit.pdf'));
  await withChrome(path.join(OUT, 'chrome.pdf'));
  console.log(`Wrote ${OUT}/pdfkit.pdf and ${OUT}/chrome.pdf`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
