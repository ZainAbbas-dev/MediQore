# Urdu PDF experiment (P0-11)

This experiment prints the same one-page Urdu report with **pdfkit** and with **HTML + headless Chrome** (puppeteer-core). The roadmap asks for this test in Phase 0 (Risks and decisions, "Urdu text in PDF reports"). The results and the proposed decision are in [`../../0003-urdu-pdf-method.md`](../../0003-urdu-pdf-method.md).

## Run it

You need Node.js 20 and an installed Chrome or Chromium. From this folder (PowerShell):

```powershell
npm install
$env:CHROME_PATH = "C:\Program Files\Google\Chrome\Application\chrome.exe"
npm start
```

It writes `out/pdfkit.pdf` and `out/chrome.pdf`. The `out/` folder is git-ignored. Open both PDFs and compare them with `results/`.

## Files

- `make-pdfs.js`: the experiment. All names and values are made up (LI-10).
- `results/pdfkit.png`, `results/chrome.png`: the top of each page at 100 dpi, made with `pdftoppm` (poppler).

This folder is a one-off test, not part of the API. If decision 0003 is accepted, the report code goes into `api/` in Phase 2.
