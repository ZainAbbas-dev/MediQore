# MediQore Full-Stack Implementation Roadmap

> Markdown copy of [`roadmap.pdf`](roadmap.pdf) (Oct 20, 2026), made so the roadmap can be searched and read inside the repo. The text and tables are copied unchanged; the architecture diagram is redrawn as a Mermaid chart. If this copy and the PDF ever differ, the PDF wins.
>
> This version replaces the earlier roadmap (Oct 10, 2026). It follows the updated final scope: record versions and the Conflict Review page, the Patient ID format, supervisor area assignments, households as their own table, pregnancies with an estimated delivery date, Puppeteer for PDF reports, manual escalation to the secondary contact, and per-child polio statuses.

Oct 20, 2026 · @Mehdi

## Overview

MediQore follows the schedule in the final scope (Table 5 and the Gantt chart): Design and foundation from 2 Nov to 27 Dec 2026, three development phases totalling 16 weeks from 4 Jan to 25 Apr 2027, testing until 20 Jun, and final submission by 18 Jul 2027. Analysis (7 Sep – 1 Nov 2026) is complete. Module 10 grows in every phase, so the supervisor portal always shows what the mobile app can already collect.

Every task is tagged with its ID in the updated final scope (for example M5 FE-2 = Module 5, FE-2). Any clinical rule a task uses comes from the versioned Clinical Rules Table, which the Clinical Advisor must sign before real patients are involved (M4 FE-4, LI-12).

| Phase | Modules | Dates (weeks) | Lead (support) | Exit gate |
|---|---|---|---|---|
| 0. Design and foundation | Figma, schema, API and auth skeleton, sync skeleton, Clinical Rules Table v0 | 2 Nov – 27 Dec 2026 (8) | Shared | One record created offline on the phone appears on the portal |
| 1. Core field workflow | M1, M2, M3, M10 base | 4 Jan – 7 Feb 2027 (5) | Zain Abbas (Zain Ali: M10 support, API, sync) | LHW activates once, unlocks offline with her PIN, registers a woman and records a visit with the danger-sign checklist; it syncs and shows on the dashboard with her last-sync time |
| 2. Intelligence and emergency | M4, M5, M6, M10 update | 8 Feb – 21 Mar 2027 (6) | Zain Abbas: M4, M10. Zain Ali: M5, M6 | A visit gets a risk result from the five- or six-feature model plus the danger-sign rules; an emergency reaches the supervisor by web push, SMS and call |
| 3. Child health and campaigns | M7, M8 (incl. child register), M9, M10 final | 22 Mar – 25 Apr 2027 (5) | Zain Ali: M7, M8, M9. Zain Abbas: M10 | All ten modules work; dashboard and reports cover every module |
| 4. Testing | Integration, final testing, documentation | 26 Apr – 20 Jun 2027 (8) | Shared | Full test pass on a low-spec Android phone; documentation complete |
| 5. Completion | Final submission and presentation | 21 Jun – 18 Jul 2027 (4) | Shared | FYP submitted and presented |

Phase 0 can start before 2 Nov; the dates are the latest it should finish.

Owners follow Table 4 of the scope document. Shared work (REST API, PostgreSQL schema, offline sync, integration testing, Figma, deployment) is split inside each phase as listed in the phase sections.

## Architecture and conventions

The Flutter app owns the whole field workflow and never needs the server to do its job; the server only collects, analyses and reports. Settle the rules below in Phase 0, because changing them after Phase 1 means rewriting synced data.

**The phone works alone; the server only collects, analyses and reports**

```mermaid
flowchart LR
    app["<b>LHW Android app</b><br/>Flutter<br/>Modules 1–9, Urdu/English, offline<br/>Encrypted DB (wrapped key)<br/>ONNX models + clinical rules<br/>Emergency: Internet, SMS, Call"]
    api["<b>REST API</b><br/>Node.js + Express<br/>Auth, sync, alerts<br/>Reports, audit log"]
    portal["<b>Supervisor portal</b><br/>React web app + Leaflet<br/>Dashboard, map, alerts<br/>Reports, admin panel"]
    phone["<b>Supervisor phone</b><br/>Web push alerts (portal)<br/>SMS and calls"]
    ml["<b>ML training pipeline</b><br/>scikit-learn, SMOTE, SHAP<br/>Exports 2 ONNX models + lookup"]
    db["<b>PostgreSQL 15</b><br/>Central data, audit log"]
    reports["<b>Report service</b><br/>Node.js: Puppeteer + ExcelJS<br/>PDF and Excel reports"]

    app ==>|"SMS and call over cellular, no internet needed"| phone
    app <-->|"sync, alert status"| api
    api <-->|HTTPS| portal
    api -->|web push| phone
    ml -.->|bundled at build time| app
    api <--> db
    api -->|report jobs| reports
```

*MediQore architecture · 7 components*

The highlighted path is the key design choice: an emergency SMS or call goes straight from the LHW's phone to the supervisor, with no server in between. If the supervisor has not acknowledged the alert within 15 minutes, the LHW contacts the secondary contact (for example the nearest referral hospital) the same way; this step is always manual (M5 FE-5).

| Component | Technology (from scope) | Responsibility |
|---|---|---|
| LHW mobile app | Flutter 3.x, Drift + SQLite3MultipleCiphers, flutter_secure_storage (Android Keystore), onnxruntime, google_mlkit_text_recognition, fl_chart, flutter_local_notifications | Modules 1–9 in Urdu and English (switch in Settings), fully offline; on-device AI models, danger-sign rules and vital trends; emergency alerts and the 15-minute escalation timer |
| REST API | Node.js 24 LTS + Express 5, jsonwebtoken, Joi, Puppeteer (headless Chromium) + ExcelJS | Auth and activation codes, sync and conflict detection, emergency alerts (web push to the supervisor, re-send at the time limit, alert status for the phone to check), PDF and Excel reports, audit log |
| Database | PostgreSQL 15 | Central store for all modules, audit log, sync sequence numbers |
| Supervisor and admin portal | React 18 (installable web app), Leaflet.js, Web Push | Module 10: dashboard, map, alerts with web push and acknowledgement, reports, admin panel, Conflict Review page, PIN-reset reply codes |
| ML training | Python 3.11, scikit-learn, imbalanced-learn, SHAP, skl2onnx | Offline training, validation and ONNX export of the five- and six-feature models |
| Clinical Rules Table | Versioned JSON configuration | Danger signs, BP and Hb levels, obstetric history flags, MUAC, IMCI and EPI timings, read by the app and the server |

Use one GitHub monorepo so the API contract, migrations and app change together:

```
mediqore/
    mobile/           Flutter app (LHW)
    api/              Node.js + Express REST API
    web/              React supervisor and admin portal (installable web app)
    ml/               Python training, SHAP lookup, ONNX export
    clinical-rules/   Versioned Clinical Rules Table (JSON), shared by app and API
    db/               PostgreSQL migrations and synthetic seed scripts
    docs/             OpenAPI contract, ERD, test reports
```

| Area | Rule |
|---|---|
| Record IDs | Every record made on the device gets a UUID v4; the server adds a sequence number when it accepts it and keeps a version number that rises with each accepted edit. Never order records by device clock (LI-7, M3 FE-2). The human-readable Patient ID is [LHW code]-[activation number]-[sequence number], so it is unique before the first sync (M2 FE-1). |
| Deletes and audit | Soft deletes only. Every create, edit, delete, referral, alert and login writes an audit row with user and timestamp (M10 FE-3). |
| API and login | REST under /api/v1, JSON, Joi validation on every request body, JWT access and refresh tokens over HTTPS only. Offline unlock is local (PIN), never a JWT check (M1 FE-2). |
| Encryption keys | The local database key is a random 256-bit key, stored wrapped by a non-exportable Android Keystore key and unwrapped in memory only when the database opens; never derived from the password or PIN (M3 FE-2, LI-8). Report images are encrypted under a key protected the same way (M6 FE-2). |
| Units | One unit per value: BP in mmHg, pulse in bpm, temperature in °C, Hb in g/dL, weight in kg, MUAC in mm. Blood sugar is stored with the unit it was recorded in (M3 FE-1). Before inference, temperature is converted to °F and blood sugar in mg/dL to mmol/L (÷ 18), the units of the training data (M4 FE-1). |
| Clinical rules | Every clinical rule lives in the versioned Clinical Rules Table, never in code; defaults are marked "pending clinical review" until the Clinical Advisor signs the table (M4 FE-4, LI-12). Store the rules version on every result. |
| Languages | All labels in Flutter ARB files with Urdu and English entries; Settings → Language switches the whole app at runtime and the choice is saved (M3 FE-3). Urdu renders right to left in Jameel Noori Nastaleeq, English left to right; numbers always stay left to right. |
| Git workflow | main is always demo-ready; feature branches per FE (for example feature/m3-fe1-visit-form); every merge reviewed by the other member; GitHub Actions runs lint and tests. |
| Environments | Local PostgreSQL for development; one HTTPS staging server for supervisor reviews and demos (needed for web push). |

## Phase 0: Design and foundation (2 Nov – 27 Dec 2026)

Phase 0 is the scope's Design phase: Figma screens (4 weeks) and database schema plus API setup (4 weeks), with the project skeleton every module plugs into. Design the database for all ten modules now, even though most tables stay empty until later phases.

| ID | Task | Scope link | Owner |
|---|---|---|---|
| P0-1 | Create the monorepo, branch protection on main, and a GitHub Actions workflow that runs lint and unit tests | Tools: Git + GitHub | Shared |
| P0-2 | Flutter project: Urdu and English ARB localisation with a runtime language switch, bundled Jameel Noori Nastaleeq font, RTL theme for Urdu and LTR for English, and a small widget kit (large buttons, form fields, Green/Yellow/Red risk chips, offline status bar with unsynced count) | M3 FE-1, FE-3 | Zain Abbas |
| P0-3 | Express 5 API skeleton on Node.js 24 LTS: routes, controllers, services, Joi validation middleware, central error handler, request logging, OpenAPI file | M1 FE-2, Tools | Zain Ali |
| P0-4 | PostgreSQL schema v1 with migrations for all core entities (see Data model), including activation codes, supervisor area assignments, Clinical Rules Table versions, households as their own table, women and pregnancies as separate tables, pregnancy outcomes and the child register; every synced table carries a version number | Shared: DB schema; M2 FE-1, M3 FE-2, M8 FE-1 | Zain Ali |
| P0-5 | React portal skeleton set up as an installable web app: routing, login page, auth guard, layout with sidebar, empty Leaflet map component, service worker ready for web push | M10, M5 FE-2 | Zain Ali |
| P0-6 | Offline sync skeleton: device outbox table, POST /sync/push and GET /sync/pull?since=, one record proven end to end | M3 FE-2 | Shared |
| P0-7 | Figma screens for Phase 1: activation and PIN unlock, LHW home, registration, visit form with danger-sign checklist, Settings with the language switch, dashboard home, admin lists | Mockups 1, 2, 6 | Shared |
| P0-8 | Synthetic data generator: districts, tehsils, Union Councils, areas, LHWs, supervisors, households with GPS, pregnant women, visits | LI-10 | Zain Ali |
| P0-9 | Draft and submit the IEC application (due in Semester 7) | LI-10 | Shared |
| P0-10 | Start the ML track: download the UCI dataset, exploratory notebook, check duplicates and class balance, note that the data is from rural Bangladesh | M4 FE-1, LI-2 | Zain Abbas |
| P0-11 | Clinical Rules Table v0 with WHO-referenced defaults marked "pending clinical review", and approach a Clinical Advisor | M4 FE-4, LI-12, Stakeholders | Shared |
| P0-12 | Technical check: render a sample bilingual report page with the Jameel Noori Nastaleeq font to PDF with Puppeteer (headless Chromium) on the staging server | M6 FE-3, Tools: Report Generation | Shared |

### Exit gate for Phase 0

- One test record created on the phone offline, synced, stored in PostgreSQL and visible on the React portal
- CI runs on every pull request
- Schema v1 and OpenAPI v1 reviewed by both members
- IEC application submitted

## Phase 1: Core field workflow — M1, M2, M3, M10 base (4 Jan – 7 Feb 2027)

By the end of Phase 1 an LHW can activate her phone once, unlock it offline with her PIN, register a pregnant woman and record a visit with no internet, and the supervisor sees it on the portal after sync. Zain Abbas builds the mobile modules and leads Module 10; Zain Ali supports Module 10 and builds the API and sync engine, because his own modules start in Phase 2.

### Module 1: LHW onboarding and access control

| Task | Layer | Scope link | Owner |
|---|---|---|---|
| Admin creates an LHW with district, tehsil, Union Council and area; system issues a unique LHW ID and credentials | API + Web | FE-1 | Zain Ali |
| Supervisor accounts assigned to one or more areas; the API limits each LHW to her own area's records and each supervisor to her assigned areas | API + Web | FE-1 | Zain Ali |
| Her assigned-area patient list syncs at first login (it may be empty) | Mobile + API | FE-1 | Shared |
| Admin generates a one-time activation code: random, about 8 characters, valid 48 hours, usable once, stored hashed | API + Web | FE-2 | Zain Ali |
| First login on a device (online): username, password and activation code; JWT access and refresh tokens over HTTPS; login and activation endpoints rate-limited | Mobile + API | FE-2 | Shared |
| Random 256-bit database key generated on the phone and stored wrapped by a separate, non-exportable Android Keystore key (flutter_secure_storage); unwrapped in memory when the database opens and passed to SQLite3MultipleCiphers; never derived from password or PIN | Mobile | FE-2, LI-8 | Zain Abbas |
| Offline unlock with a 6-digit PIN checked against a slow hash; progressive delays of 30 s, 1 min, 5 min and 15 min, never a lockout that needs internet | Mobile | FE-2 | Zain Abbas |
| Offline PIN reset: the phone shows a short code, the supervisor enters it in the portal and reads back a reply code, which the phone checks with the secret received at activation | Mobile + Web + API | FE-2 | Shared |
| Lock screen "Emergency call supervisor" button | Mobile | FE-2 | Zain Abbas |
| Local auto-lock after inactivity, separate from server token expiry; tokens refresh at each sync; deactivation takes effect at the next connection | Mobile + API | FE-2, FE-3, LI-8 | Shared |
| Refresh tokens stored hashed on the server, rotated at each use and revoked on deactivation; the server checks the account status at every refresh; on the phone they are kept in flutter_secure_storage; lifetime configurable (default 30 days); after expiry the LHW signs in online with username and password (no new activation code) and her unsynced records are kept | Mobile + API | FE-2 | Shared |
| Admin area reassignment, activation and deactivation, password reset (no local data loss, because the key is not password-based); on reassignment the old area's records leave the device only after all pending uploads succeed, then the new area's records download | Web + API + Mobile | FE-3, LI-8, M3 FE-2 | Shared |

### Module 2: Pregnant woman registration

| Task | Layer | Scope link | Owner |
|---|---|---|---|
| Registration form (name, age, husband's name, contact, address, pregnancy month, LMP date or EDD when known, village) in Urdu with validation | Mobile | FE-1 | Zain Abbas |
| Estimated delivery date stored (from the LMP date or EDD, otherwise from the pregnancy month); gestational age in weeks calculated for any date and used by the ANC schedule, the fetal-movement rule and outcome classification | Mobile | FE-1 | Zain Abbas |
| Patient ID that is unique before the first sync: [LHW code]-[activation number]-[sequence number], where the activation number is issued by the server at each device activation; stored alongside the record UUID | Mobile + API | FE-1 | Zain Abbas |
| Create the pregnancy file: a woman is registered once and each pregnancy is a separate record linked to her Patient ID; a later pregnancy opens a new file for the same patient and updates her obstetric history | Mobile + DB | FE-1 | Zain Abbas |
| Obstetric history: previous pregnancies, C-sections, stillbirths, known conditions | Mobile | FE-2 | Zain Abbas |
| Obstetric risk-factor flags (for example "Previous C-section") shown on the profile and result screen; they never change the risk colour unless the signed Clinical Rules Table says so | Mobile | FE-2 | Zain Abbas |
| Household record with GPS capture (geolocator package): household number, village and GPS; the woman is linked to an existing household or a new one; reused later by the child register, polio and nutrition modules | Mobile + DB | FE-3, M8 FE-1 | Zain Abbas |
| Area-based search, and patients sorted by estimated distance from her current location (no maps needed) | Mobile | FE-3 | Zain Abbas |

### Module 3: Field visit and vitals collection

| Task | Layer | Scope link | Owner |
|---|---|---|---|
| Visit form: BP, pulse, weight, temperature, fetal movement, swelling, bleeding, fever, anaemia signs, urine symptoms, using checkboxes, dropdowns and large controls; fetal movement shows "Not applicable yet" before the gestational age set in the Clinical Rules Table | Mobile | FE-1, M4 FE-4 | Zain Abbas |
| Pulse required: read from the BP device, or counted with a 30-second on-screen counter (tap per beat, app doubles the count) | Mobile | FE-1 | Zain Abbas |
| Optional blood sugar stored with value, unit, date and source (glucometer or verified lab report) | Mobile | FE-1, M4 FE-1 | Zain Abbas |
| Yes/no danger-sign checklist with pictures: convulsions or fits, severe headache, blurred vision, severe or upper abdominal pain, fast or difficult breathing, fever with weakness | Mobile | FE-1, M4 FE-4 | Zain Abbas |
| Range checks to catch typing errors (for example systolic BP outside 60–250 asks for confirmation) | Mobile | FE-1 | Zain Abbas |
| Encrypted local database: Drift native database with SQLite3MultipleCiphers, SQLCipher-compatible AES-256 cipher, using the database key unwrapped in memory from its Keystore-wrapped copy (Module 1) | Mobile | FE-2 | Zain Abbas |
| Sync engine: outbox with retry, idempotent push by UUID (a re-sent record is acknowledged again and is never a conflict), server sequence IDs and record versions, pull by cursor including deletions, background sync when online | Mobile + API | FE-2 | Shared |
| Pull to the device for her area: referral facilities, escalation contacts, Clinical Rules Table and EPI configuration, campaign rounds, alert acknowledgements and conflict resolutions | Mobile + API | FE-2 | Shared |
| Conflict detection: an edit sent with an older base version than the server's is a conflict; a likely duplicate patient or child (same name, husband's or caregiver's name and household) is flagged as a possible duplicate; both are kept, listed on the supervisor's Conflict Review page and logged in the audit log, never overwritten | API | FE-2, LI-7 | Zain Ali |
| Language switch: Settings → Language toggles the whole app between Urdu (right to left) and English (left to right) at runtime; the choice is saved on the device and Urdu is the default | Mobile | FE-3, LI-6 | Zain Abbas |

### Module 10 base: supervisor portal

| Task | Layer | Scope link | Owner |
|---|---|---|---|
| Admin panel: district, tehsil, Union Council and area hierarchy; LHW and supervisor accounts; supervisor area assignments; activation codes; hospitals and referral centres with phone numbers; role permissions | Web + API | FE-3 | Zain Ali |
| Audit log viewer with filters by user, action and date | Web + API | FE-3 | Zain Ali |
| Near-real-time dashboard cards of synchronised data: each LHW's last-sync time, registered patients, visits this week, last login | Web + API | FE-1 | Zain Abbas |
| Leaflet map of registered households from Module 2 GPS, filter by district, Union Council, LHW and time period, auto-refresh every 5 minutes | Web | FE-1 | Zain Abbas |
| PIN-reset reply-code page for supervisors | Web + API | M1 FE-2 | Zain Ali |
| Conflict Review page: supervisors compare and resolve sync conflicts and possible duplicate records; each resolution syncs back to the device | Web + API | FE-3, M3 FE-2 | Zain Ali |

### ML track (runs alongside Phase 1)

Zain Abbas trains both models in January (scope Gantt row 3.4), so Module 4 starts Phase 2 with two ready ONNX files. Details are in Phase 2 under Module 4.

### Exit gate for Phase 1

- LHW activates once online, then works fully offline: PIN unlock, registration, visit with danger-sign checklist, in both Urdu and English
- Forgotten PIN is reset offline with a supervisor reply code; a password reset loses no local data
- Records sync automatically when online; a re-sent record is accepted once without creating a conflict, and an outdated edit or a likely duplicate patient appears on the Conflict Review page instead of being overwritten
- Admin manages areas, accounts, supervisor area assignments, activation codes and hospitals; every action appears in the audit log
- Supervisor sees patients, visits, each LHW's last-sync time and the household map for her assigned areas only
- Unit tests for form validation, sync and auth pass in CI

## Phase 2: Intelligence and emergency — M4, M5, M6, M10 update (8 Feb – 21 Mar 2027)

By the end of Phase 2 every visit produces a risk result with an Urdu explanation, a critical case can reach the supervisor by web push, SMS or call, and each pregnancy has a full record with on-device trends and a recorded outcome. Zain Abbas owns Module 4 and the Module 10 update; Zain Ali owns Modules 5 and 6.

### Module 4: AI-based maternal risk assessment

| Task | Layer | Scope link | Owner |
|---|---|---|---|
| Clean the UCI data: remove duplicate rows, keep a stratified 20% hold-out test set untouched until the end | ML | FE-1, BO-2 | Zain Abbas |
| imbalanced-learn Pipeline with SMOTE applied inside each training fold only, so synthetic rows never leak into validation | ML | FE-1, BO-2 | Zain Abbas |
| Train two input sets: a default five-feature model (no blood sugar) and a six-feature model; compare Logistic Regression, Random Forest and Gradient Boosting with 5-fold stratified CV; report macro-F1, per-class precision, recall and F1, and ROC-AUC for each set separately | ML | FE-1, BO-2 | Zain Abbas |
| Select each model with a target of at least 90% high-risk recall, applied to each input set separately, then best macro-F1; if a tuned probability threshold is used for the high-risk class, the app applies the same threshold; if the selected model for an input set misses the target, report the shortfall (the danger-sign rules remain the main safeguard) | ML | BO-2 | Zain Abbas |
| Write the dataset note: rural Bangladesh data, not equivalent to Pakistan, performance on Pakistani patients unknown until field validation | ML | LI-2 | Zain Abbas |
| Run SHAP on each chosen model, derive feature-threshold rules per class, map each to reviewed Urdu and English phrases, export the JSON lookup | ML | FE-2 | Zain Abbas |
| Export both models with skl2onnx (plain probability output, no ZipMap); parity test that Python and ONNX agree on every test row, including unit-converted cases | ML | FE-1 | Zain Abbas |
| Run inference with onnxruntime after each visit: the six-feature model only when same-visit blood sugar exists (configurable window), otherwise the five-feature model; convert inputs to the training units first (temperature °C → °F, blood sugar mg/dL → mmol/L by dividing by 18, age on the visit date) | Mobile | FE-1 | Zain Abbas |
| Run the model only when age, systolic and diastolic BP, temperature and pulse are all recorded; otherwise run the danger-sign rules alone and show "AI assessment not available" | Mobile | FE-1 | Zain Abbas |
| Benchmark inference time on the lowest-spec test phone (target under 1 second) | Mobile | FE-1 | Zain Abbas |
| Result screen: colour-coded risk, Urdu explanation (the triggered rule when the danger-sign rules set the final level, otherwise the SHAP phrase), obstetric and anaemia flags shown separately, decision-support disclaimer | Mobile | FE-2, LI-5 | Zain Abbas |
| Risk trend across visits: store each result, alert the LHW when the level worsens across visits | Mobile | FE-3 | Zain Abbas |
| Danger-sign rules read from the Clinical Rules Table make an Emergency for: severe hypertension (systolic ≥160 or diastolic ≥110); raised BP (≥140/90) with severe headache, blurred vision or upper abdominal pain; vaginal bleeding; convulsions or fits; severe headache with blurred vision; severe abdominal pain; fast or difficult breathing; fever with weakness, or high fever (≥38 °C) with another danger sign; absent or markedly reduced fetal movement (only from the gestational age set in the table); severe anaemia signs. Raised BP alone gives at least Yellow; swelling is a flag only; final level = higher of model and rules; one unit test per rule | Mobile | FE-4, LI-12 | Zain Abbas |
| Route the result: a rule-based Emergency opens the Module 5 emergency screen; a Red from the model alone, without any danger sign, opens the one-tap referral and is shown to the supervisor after sync, with no alarm and no escalation timer | Mobile | FE-4 | Zain Abbas |
| Store model version, input set and rules version on every risk result | Mobile + DB | FE-4 | Zain Abbas |

### Module 5: Emergency referral coordination

| Task | Layer | Scope link | Owner |
|---|---|---|---|
| One-tap referral pre-filled with patient details, risk factors and the nearest registered referral facility with its saved phone number, found by GPS distance to the cached facility list | Mobile | FE-1 | Zain Ali |
| Emergency screen (rule-based Emergency only, M4 FE-4) opens immediately with three equal buttons (Internet, SMS, Call) and Send all, all live at once; each button shows whether it is usable now | Mobile | FE-2, FE-4 | Zain Ali |
| Check bar for typed values ("BP 190/120 — is this correct? Correct / Edit"); editing re-runs the rules and, if the case no longer qualifies, closes the screen with the logged reason "value corrected"; the buttons never wait for it | Mobile | FE-4 | Zain Ali |
| Screen can be minimised to a banner that stays visible; it closes only with a logged reason (referral done, supervisor reached, false alarm with corrected values) shown to the supervisor; nothing is sent until she taps a button | Mobile | FE-4 | Zain Ali |
| Layer 1: alert to the API and web push from the supervisor portal (installable web app), plus a live alerts page | Mobile + API + Web | FE-2 | Zain Ali |
| Layer 2: pre-filled SMS sent from the LHW's phone (another_telephony, SEND_SMS) with sent and delivered callbacks; if permission is denied, url_launcher opens the SMS app pre-filled | Mobile | FE-2, LI-4 | Zain Ali |
| Layer 3: one-tap call to the supervisor and the secondary contact (flutter_phone_direct_caller) | Mobile | FE-2 | Zain Ali |
| Alarm tone with vibration, protocol checklist, per-option status (Sent, Failed, Not available) with retry; "Alert not yet delivered" stays until one option is confirmed: the server's receipt (Internet), the sent or delivery report (SMS sent inside the app), or the LHW tapping "SMS sent" or "Supervisor reached" (SMS through the phone's SMS app, or a call), logged as a manual confirmation | Mobile | FE-4 | Zain Ali |
| Save the alert record locally and sync it in the background when internet returns (workmanager); record time-to-escalation | Mobile + API | FE-4 | Zain Ali |
| Acknowledgement from the web portal on desktop or phone; LHW can mark "supervisor reached" after a call or SMS reply | Mobile + Web + API | FE-5 | Zain Ali |
| Acknowledgement status on the phone: while the emergency screen or banner is open and internet is available, the app checks the alert's status on the server every 30 seconds, and also when the app opens and at every sync; the banner shows "Waiting for supervisor" with the time elapsed, "Acknowledged by supervisor at [time]" or "Not acknowledged", and offline the last known status with the time it was checked; an acknowledgement or "supervisor reached" stops the timer | Mobile + API | FE-5 | Zain Ali |
| Escalation (default 15 minutes, configurable): the timer runs on the phone from the moment the alert is created, whether or not the server has it; escalation to the secondary contact (for example the nearest referral hospital) is always manual: at the time limit a local notification (flutter_local_notifications) and the banner prompt one-tap "SMS secondary contact" and "Call secondary contact", and nothing is sent automatically; if the server has the alert, it re-sends the web push to the supervisor at the time limit; the synced alert history includes any SMS or call to the secondary contact | Mobile + API | FE-5, LI-4 | Zain Ali |
| Referral outcome: attended or not, and outcome, visible to the supervisor | Mobile + Web | FE-3 | Zain Ali |

### Module 6: Pregnancy journey, health records and ANC monitoring

| Task | Layer | Scope link | Owner |
|---|---|---|---|
| ANC schedule generated from gestational age in weeks, calculated from the estimated delivery date recorded at registration (WHO 2016); local reminders (flutter_local_notifications); missed visits flagged | Mobile | FE-1, M2 FE-1 | Zain Ali |
| TT dose schedule plus iron and folic acid tracking, with a supplement compliance score on the patient profile | Mobile | FE-1 | Zain Ali |
| Report scan: in-app camera capture (not saved to the phone's gallery) or gallery import, grayscale and contrast preprocessing, ML Kit text recognition fully offline (Latin-script reports; Urdu and handwritten reports use manual entry) | Mobile | FE-2, LI-9 | Zain Ali |
| Dart regex engine extracting BP, haemoglobin, blood glucose, temperature, weight and urine protein; high-confidence values pre-filled, others confirmed; manual entry fallback | Mobile | FE-2, LI-9 | Zain Ali |
| Anaemia flag from verified Hb values with value, unit, date and source; colour mapping only from the signed Clinical Rules Table | Mobile | FE-2 | Zain Ali |
| Store the original report image: compressed, encrypted on the device with AES-256 under a key protected by the Android Keystore scheme, uploaded after the record data, and stored on the server as a file referenced from PostgreSQL | Mobile + API | FE-2, LI-8 | Zain Ali |
| On-device trends in Dart: linear slope per vital, flag a vital rising across the last three visits that has reached or is near its approved threshold (no Z-scores) | Mobile | FE-3 | Zain Ali |
| Offline progress summary on the phone with fl_chart trend graphs, visit history and ANC compliance | Mobile | FE-3 | Zain Ali |
| Bilingual PDF progress report generated on the server after sync (needs connectivity), rendered from HTML with Puppeteer (headless Chromium) so that Urdu text is shaped and runs right to left correctly; the LHW exports it to share with the patient or referral facility | API | FE-3 | Zain Ali |
| Pregnancy outcome recording: date, place, live birth (one child record per baby, sex and birth weight; twins give two), stillbirth or miscarriage (no child record; told apart by gestational age using the boundary in the Clinical Rules Table), maternal death (flag for review), moved out or lost to follow-up | Mobile + DB | FE-4 | Zain Ali |

### Module 10 update

| Task | Layer | Scope link | Owner |
|---|---|---|---|
| Risk distribution chart (Green, Yellow, Red) and high-risk cluster layer on the map | Web + API | FE-1 | Zain Abbas |
| Referral completion rate, overdue follow-ups and missed ANC visits per LHW | Web + API | FE-1 | Zain Abbas |
| High-risk list: a Red from the model alone appears as a high-risk case with a web push once the visit syncs (no escalation timer) | Web + API | FE-1, M4 FE-4 | Zain Abbas |
| Web push for emergency alerts (service worker, FCM for web) and a phone-friendly alerts page: channel used, time-to-escalation, acknowledge button, unacknowledged alerts highlighted, alerts re-sent at the time limit marked | Web + API | FE-1, M5 FE-2, FE-5 | Zain Abbas |
| Admin: emergency escalation contacts per area (supervisor and secondary contact, for example the nearest referral hospital), synced to devices for the SMS and Call buttons | Web + API | FE-3 | Zain Abbas |
| Weekly and monthly PDF and Excel reports (PDF rendered with Puppeteer): maternal summary, high-risk list, referral completion, LHW activity, emergency alerts; downloaded by authorised supervisors for manual submission | API + Web | FE-2 | Zain Abbas |
| Inactivity detection by visit date: a week is judged only after the LHW synced past it; flag when more than 2 SD below her mean and at least 3 visits lower, after 6 weeks of history (both configurable); leave and campaign weeks excluded; statuses Active, Unusual inactivity, Not enough synced data | API + Web | FE-4 | Zain Abbas |

### Exit gate for Phase 2

- Both models are validated and reported separately; ONNX parity tests pass; any shortfall against the 90% recall target is documented
- Every danger-sign rule forces an Emergency result in tests, even when the model says low risk; the fetal-movement rule does not fire before its gestational-age threshold
- A Red from the model alone opens the referral and reaches the dashboard after sync, without the alarm or the escalation timer
- Emergency alert sent by each of the three options: SMS and call in airplane mode with a SIM, web push online
- "Alert not yet delivered" clears only on a confirmation: server receipt, SMS report, or the LHW's manual confirmation
- A typed-value typo is corrected from the check bar without delaying the alert buttons
- With no acknowledgement in 15 minutes the phone prompts "SMS / Call secondary contact" both online and offline and sends nothing on its own; a portal acknowledgement reaches the phone through the status check and stops the timer
- OCR pre-fills values from a printed report; a handwritten or Urdu report falls back to manual entry
- A live birth outcome creates a child record; a stillbirth does not
- Dashboard shows risk, referrals, alerts and reports for maternal data

## Phase 3: Child health and campaigns — M7, M8, M9, M10 final (22 Mar – 25 Apr 2027)

By the end of Phase 3 all ten modules work and the portal reports on every one of them. Start with the child register in Module 8 FE-1 in the first week, because Modules 7, 8 and 9 all depend on it.

### Child register — Module 8 FE-1 (first week)

| Task | Layer | Scope link | Owner |
|---|---|---|---|
| Child record for every child under 5 in the area: name, date of birth, sex, caregiver, household (reusing household GPS from Module 2) | Mobile + DB | M8 FE-1 | Zain Ali |
| Household roster for every household in the area, not only those with a pregnant woman; the LHW can add a household from the household list at any time | Mobile + DB | M8 FE-1, M7 FE-1 | Zain Ali |
| Newborn records created from Module 6 live-birth outcomes appear in the register automatically | Mobile | M6 FE-4, M8 FE-1 | Zain Ali |
| Deceased status stops a child's schedules and alerts | Mobile + API | M6 FE-4 | Zain Ali |
| Child list per household with age in months, used by Modules 7, 8 and 9 | Mobile | M7–M9 | Zain Ali |

### Module 7: Polio campaign field operations

| Task | Layer | Scope link | Owner |
|---|---|---|---|
| Campaign rounds (name, dates, target areas), created in the admin panel (Module 10 final), pulled to devices | API + Mobile | FE-1, M10 FE-3 | Zain Ali |
| House-to-house screen lists the household's registered children under 5; she marks each child Vaccinated, Refused (with reason) or Not available this round (OPV, campaign date); household totals calculated automatically; saved offline | Mobile | FE-1 | Zain Ali |
| "New child found" button adds visiting children and unregistered newborns; "New household" button adds a household that is not yet in the list | Mobile | FE-1 | Zain Ali |
| Refusals recorded per child with the reason (religious concern, misinformation, past reaction), with a separate "Not available" status; household status derived from its children: all vaccinated, partially covered, refusal, not available or no eligible child; a revisit is scheduled in the same round for the children not yet vaccinated | Mobile | FE-1, FE-2 | Zain Ali |
| Revisit list for the LHW, sorted by distance from her current location | Mobile | FE-2 | Zain Ali |
| "No OPV dose recorded" check across campaign records and routine OPV from Module 8; priority list on the device for her area and on the server for the district | Mobile + API | FE-3 | Zain Ali |

### Module 8: Child immunisation and EPI management

| Task | Layer | Scope link | Owner |
|---|---|---|---|
| EPI schedule config verified against the Federal Directorate of Immunization schedule: BCG, Hep B-0, OPV-0 to OPV-3, Penta 1–3, PCV 1–3, Rota 1–2, IPV-I and IPV-II, MR 1–2 and TCV (National Immunization Policy 2022), with doses whose rollout varies by area (such as the Hep B birth dose) switched on per area; for each dose the dose number, minimum age, recommended age, minimum interval, maximum age where applicable, schedule version and effective date | Config | FE-1 | Zain Ali |
| Personal vaccination timeline per child under 2; dose recording; routine OPV kept separate from campaign doses; each record stores its schedule version | Mobile | FE-1 | Zain Ali |
| Catch-up due dates: next dose due from the previous dose date plus the minimum interval, not only from date of birth | Mobile | FE-1 | Zain Ali |
| Defaulter alert on the LHW home screen when a dose passes its due date; supervisor notified after sync | Mobile + API | FE-2 | Zain Ali |
| WHO zero-dose indicator: no recorded Penta-1 after its due age | Mobile + API | FE-2 | Zain Ali |
| Coverage per antigen and per sub-area, with low-coverage sub-areas highlighted | API + Web | FE-3 | Zain Ali |

### Module 9: Child nutrition and growth screening

| Task | Layer | Scope link | Owner |
|---|---|---|---|
| MUAC entry for ages 6–59 months with WHO classification: below 115 mm SAM, 115 to under 125 mm MAM, 125 mm or above Normal; colour-coded Urdu result | Mobile | FE-1 | Zain Ali |
| Bilateral pitting oedema check: SAM regardless of MUAC | Mobile | FE-1 | Zain Ali |
| Weight-for-age (underweight) and height-for-age (stunting, only when height is measured) Z-scores from bundled WHO Child Growth Standards tables; no wasting classification | Mobile | FE-1 | Zain Ali |
| Unit tests that check Z-score output against WHO reference values | Mobile | FE-1 | Zain Ali |
| SAM referral to the nearest Nutrition Rehabilitation Centre, attendance tracking and weight recovery across follow-ups | Mobile + Web | FE-2 | Zain Ali |
| IMCI checklist (WHO 2014): respiratory rate with a 60-second counter, chest indrawing, stool frequency, dehydration signs; severity and Urdu action from the Clinical Rules Table | Mobile | FE-3 | Zain Ali |
| Test the IMCI rules against the worked cases in the WHO IMCI chart booklet | Mobile | FE-3 | Zain Ali |

### Module 10 final

| Task | Layer | Scope link | Owner |
|---|---|---|---|
| Polio campaign progress, refusals, not-available and partially covered households, and "No OPV dose recorded" counts per area | Web + API | FE-1 | Zain Abbas |
| Map layers for malnutrition hotspots and immunisation coverage gaps, using household GPS shared by the child register | Web | FE-1 | Zain Abbas |
| Full report set: adds polio progress, immunisation coverage (including WHO zero-dose) and nutrition screening to the weekly and monthly PDF and Excel reports | API + Web | FE-2 | Zain Abbas |
| Admin: polio campaign rounds (round name, dates, target areas) and Nutrition Rehabilitation Centre records | Web + API | FE-3 | Zain Abbas |
| Performance: database indexes, paginated tables, clustered map markers for large areas | Web + API + DB | FE-1 | Zain Abbas |

### Exit gate for Phase 3

- A polio round runs end to end offline, including a child refused with a reason, a child not available, a partially covered household, a household added during the round, a revisit and a child with no OPV dose recorded
- A late-starting child's EPI timeline gives correct catch-up due dates and a defaulter alert that reaches the supervisor
- MUAC, oedema, Z-score and IMCI results match WHO reference cases
- Dashboard, map layers and reports cover all ten modules

## Phase 4: Testing and completion (26 Apr – 18 Jul 2027)

Phase 4 adds no new features; it proves the system works under field conditions and packages it for evaluation. It covers the scope's Testing phase (8 weeks) and Completion phase (4 weeks); features freeze on 26 Apr and only bugs are fixed after that.

| Dates | Task | Owner |
|---|---|---|
| 26 Apr – 23 May | System integration: end-to-end scenarios across all modules (registration → visit → Emergency → alert → escalation → referral outcome → report; pregnancy outcome → child register; polio round; EPI defaulter; SAM referral) | Shared |
| 26 Apr – 23 May | Field simulation on 3 or more phones in airplane mode for several days of synthetic work, then a mass sync with deliberate conflicts | Shared |
| 26 Apr – 23 May | Low-spec device test (a 2 GB RAM Android phone): app start time, form speed, inference time for both models, sync of 1,000 records, battery use | Zain Abbas |
| 26 Apr – 23 May | Security tests: activation code reuse and expiry, PIN delays and offline reset, expired and tampered tokens, refresh-token rotation and re-login after expiry without losing unsynced records, a supervisor trying to read another area's records (must fail), SQL injection attempts, HTTPS enforcement, database file and report images unreadable when copied off the phone | Zain Ali |
| 24 May – 20 Jun | Emergency tests: SMS and call in airplane mode with a SIM, SMS fallback with permission denied and manual confirmation, web push on a supervisor's phone, the 15-minute escalation prompt online and offline, and an acknowledgement reaching the phone through the status check | Shared |
| 24 May – 20 Jun | Usability check of the Urdu and English interfaces and the language switch; with LHWs only if IEC approval has arrived, otherwise with peers on synthetic data | Shared |
| 24 May – 20 Jun | Bug fixing, regression run of the full test suite, documentation: model report (both input sets, metrics, SHAP), Clinical Rules Table with review status, API reference, test report, deployment guide, user guides | Shared |
| 21 Jun – 18 Jul | Final mockups for Appendix A, signed release APK, staging deployment, demo script with synthetic data, final submission and presentation | Shared |

### Exit gate for Phase 4

- All Phase 1–3 exit gates still pass on the release build
- No open critical or high-severity bugs
- Documentation and Appendix A mockups complete
- Demo rehearsed twice on the release APK and staging server

## Cross-cutting tracks

Four concerns run through every phase; each new module must follow these rules rather than invent its own.

### Offline sync

Every write on the device goes to its local table and to an outbox in the same transaction. The sync service pushes outbox rows in batches (about 100 per request) when online, and the server replies with the sequence number it assigned to each UUID. Pull uses the last sequence number the device has seen, so nothing depends on device clocks.

Emergency alert records always go first in the push order (M5 FE-4). Report images upload separately after the data rows, so a slow photo never delays clinical data. Resending the same UUID is harmless and never creates a conflict. Each record carries a version number: an edit made on an older version than the server's goes to the supervisor's Conflict Review page, and so does a likely duplicate patient or child (same name, husband's or caregiver's name and household) (M3 FE-2, M10 FE-3).

Pull brings down, for the device's area, all changed records including deletions, plus referral facilities, escalation contacts, the Clinical Rules Table and EPI configuration, campaign rounds, alert acknowledgements and conflict resolutions. When an LHW is reassigned, the old area's records leave the device only after all her pending uploads succeed.

### Security and access

| Rule | Scope link |
|---|---|
| Passwords hashed on the server with bcrypt; one-time activation codes are random, expire in 48 hours, work once and are stored hashed; login and activation endpoints rate-limited | M1 FE-2 |
| Short-lived access token and longer refresh token (lifetime configurable, default 30 days), used only for server calls and refreshed at each sync; refresh tokens stored hashed, rotated at each use and revoked on deactivation; the server checks the account status at every refresh, so deactivation takes effect at the next connection | M1 FE-2, FE-3, LI-8 |
| Offline PIN checked against a slow hash with progressive delays; offline reset by supervisor reply code; lock-screen emergency call button | M1 FE-2 |
| Role check middleware on every route: LHW, supervisor, admin | M1 FE-2 |
| Area scoping in every query: an LHW sees only her area, a supervisor only the areas assigned to them | M1 FE-1 |
| Parameterised SQL only, Joi validation before any database call | Tools: Joi |
| Local database encrypted with AES-256 (SQLite3MultipleCiphers) using a random key wrapped by a non-exportable Android Keystore key; report images encrypted under a key protected the same way | M3 FE-2, M6 FE-2, LI-8 |
| Audit row for every create, edit, delete, referral, alert and login | M10 FE-3 |

### Urdu and English

Write no visible string in Dart code; every label goes into the ARB files from the start, with an Urdu and an English entry. Test every screen on a small phone, because Nastaliq text is taller than Latin text and overflows easily. The Settings language switch changes the locale at runtime and saves the choice; test every screen in both languages, because the layout direction flips between them (M3 FE-3).

### Testing

| Level | Tool | What it covers |
|---|---|---|
| Unit | flutter_test, Jest, pytest | Form validation, every rule in the Clinical Rules Table, EPI and catch-up dates, MUAC and Z-score maths, IMCI rules, regex extraction, trend slopes, unit conversion before inference, model metrics |
| Widget | flutter_test | Urdu and English screens render without overflow, RTL and LTR layouts, language switch, emergency screen states, check bar and escalation banner states |
| API | Jest + Supertest | Auth and activation codes, refresh-token rotation, role checks, area scoping, sync push and pull, version-based conflict and duplicate detection, alert status and web push re-send |
| Integration | Manual scripts on real phones | Offline-to-online flows, three alert options, web push, 15-minute escalation prompt, multi-device sync |
| Model | pytest + saved metrics | Hold-out recall for both input sets, ONNX parity |

Each FE is done only when its tests pass in CI and it works on a real phone in airplane mode.

## Data model overview

The same tables exist in PostgreSQL and, for field data, in the device's Drift database. Every synced table carries the same base columns: id (UUID), server_seq, version, area_id, created_by, created_on_device, synced_at and deleted_at.

| Table group | Key tables | Built in | Used by |
|---|---|---|---|
| Geography | districts, tehsils, union_councils, areas | Phase 0 | M1, M10 |
| Users and access | users (with role), lhw_profiles, supervisor_areas, devices (with activation number and activation secret reference), activation_codes, refresh_tokens (hashed) | Phase 0–1 | M1 |
| System | audit_log, sync_conflicts (version conflicts and possible duplicates), report_jobs, clinical_rules_versions | Phase 0–1 | M3, M4, M10 |
| Households and women | households (household number, village, GPS), women (Patient ID), pregnancies (LMP or EDD, estimated delivery date), obstetric_history | Phase 1 | M2, M7, M8 |
| Visits | visits (all vitals including pulse, optional blood sugar with unit, date and source, danger-sign checklist) | Phase 1 | M3, M4, M6 |
| Facilities | hospitals, referral_centres (with phone numbers), escalation_contacts | Phase 1–2 (Nutrition Rehabilitation Centres in Phase 3) | M5, M9, M10 |
| Risk | risk_assessments (input set, model result, rule result, final level, explanation key, model version, rules version), risk_flags (obstetric, anaemia, swelling) | Phase 2 | M4, M10 |
| Emergency | referrals, emergency_alerts (visit timestamp, time-to-escalation, acknowledgement status, escalation prompt time), alert_attempts (channel, recipient: supervisor or secondary contact, status, confirmation: automatic or manual, time), alert_acknowledgements | Phase 2 | M5, M10 |
| ANC and records | anc_schedule, tt_doses, supplement_logs, health_documents (image file reference, extracted values, confidence, verified Hb) | Phase 2 | M6 |
| Pregnancy outcomes | pregnancy_outcomes (date, place, type), newborn links to children | Phase 2 | M6, M8 |
| Children | children (status including deceased, source: outcome or manual) | Phase 2 (from outcomes), Phase 3 (full register) | M7, M8, M9 |
| Polio | campaigns (round name, dates, target areas), campaign_child_status (vaccinated, refused with reason, not available, campaign date), campaign_household_status (derived: all vaccinated, partially covered, refusal, not available, no eligible child), revisits | Phase 3 | M7 |
| Immunisation | epi_schedule (versioned config), immunisations (with schedule version) | Phase 3 | M8 |
| Nutrition | nutrition_screenings (MUAC, oedema, weight-for-age, height-for-age), sam_followups, imci_assessments | Phase 3 | M9 |
| Supervision | leave_and_campaign_weeks | Phase 2 | M10 |

Store the model version, input set and rules version on every risk result, so results stay traceable when the model or the Clinical Rules Table changes later (LI-2, LI-12).

## Risks and decisions

Several of the earlier open decisions are now fixed in the final scope. The open items below must be settled by the date shown; the most urgent is finding a Clinical Advisor, because no clinical rule can be used with real patients until the table is signed.

| Risk or decision | Status | Action | Settle by |
|---|---|---|---|
| Clinical Advisor | Open | Approach an obstetrician or community-health doctor to review and sign the Clinical Rules Table (LI-12) | 27 Dec 2026 |
| Model inputs missing from the visit form | Decided in scope | Pulse required, blood sugar optional, five- and six-feature models (M3 FE-1, M4 FE-1) | Done |
| OTP channel | Decided in scope | One-time admin activation code; SMS OTP only in production (M1 FE-2) | Done |
| Urdu text in PDF reports | Decided in scope | PDFs are rendered from HTML with Puppeteer (headless Chromium) and the bundled Jameel Noori Nastaleeq font (M6 FE-3, Tools); P0-12 confirms the output on the staging server | 27 Dec 2026 |
| Urdu voice on the phone | Removed from scope | No longer needed: voice guidance was removed from the scope; Urdu and English are handled by the language switch (M3 FE-3) | Done |
| Where Layer 1 push lands | Decided in scope | Web push from the installable supervisor portal; no separate supervisor app (M5 FE-2) | Done |
| Escalation to the secondary contact | Decided in scope | Always manual from the LHW's phone with the SMS and Call buttons after 15 minutes without acknowledgement; no server-side SMS in the prototype (M5 FE-5, LI-4) | Done |
| Timing of the 15-minute prompt | Open | Android can delay a scheduled notification under battery saving; request the exact-alarm permission ("Alarms & reminders") and test the prompt on the low-spec phone with the screen off | 21 Mar 2027 |
| Urdu SMS length | Open | Urdu SMS fits about 70 characters per part; keep the template short, patient ID and key facts first | 21 Mar 2027 |
| SMS sending permission | Decided in scope | Signed APK for the FYP; Google Play allows SEND_SMS for emergency-alert apps; SMS-app fallback if denied (LI-4) | Done |
| OCR language | Decided in scope | Latin-script reports only; Urdu and handwritten reports use manual entry (LI-9) | Done |
| Phase 2 workload | Open | Zain Ali carries Modules 5 and 6 in six weeks; Zain Abbas builds the Module 6 server PDF report with the Module 10 report service | 7 Feb 2027 |
| Dataset size and transferability | Accepted limitation | Rural Bangladesh data with many duplicates; remove duplicates, report hold-out results honestly; field validation is future work (LI-2) | Ongoing |
| IEC approval delay | Accepted limitation | All testing and demos on synthetic data (LI-10) | Ongoing |

## Definition of done

A module counts as finished only when every item below is true. Copy this list into each module's tracking issue on GitHub.

- [ ] Every FE in the scope document for that module works on a real Android phone
- [ ] Works fully offline where the scope says so, and syncs correctly afterwards
- [ ] All screens work in both Urdu and English with no text overflow; numbers display left to right
- [ ] Every clinical rule it uses is read from the Clinical Rules Table and has a unit test
- [ ] API routes validated with Joi, role-checked and area-scoped
- [ ] Every create, edit and delete writes an audit row
- [ ] Unit and API tests written and passing in CI
- [ ] Module 10 shows the module's data (dashboard, map or report, as the scope says)
- [ ] Synthetic data for the module added to the seed script
- [ ] Reviewed and merged by the other team member
- [ ] Short note added to the user guide and test report
