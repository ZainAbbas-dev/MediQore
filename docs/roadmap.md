# MediQore Full-Stack Implementation Roadmap

> Markdown copy of [`roadmap.pdf`](roadmap.pdf), made so the roadmap can be searched and read inside the repo. If this copy and the PDF ever differ, the PDF wins, except for the approved amendments listed below, which the PDF has not caught up with yet.

Oct 2, 2026 · @Mehdi

## Amendments after approval

These changes follow scope amendments the supervisor approved (see [`scope.md`](scope.md), "Amendments after approval"). Amended text below is marked *(A1)*.

| No. | Date | Change | Record |
|---|---|---|---|
| A1 | 2026-10-04 | Urdu/English language switch in the LHW app (M1 FE-4); voice guidance only in Urdu. Adds a Phase 1 task and updates the Urdu conventions, the Phase 1 exit gate, the testing table and the definition of done. The base switch was built at the end of Phase 0. | [Decision 0005](decisions/0005-language-switch.md) |

## Overview

MediQore is built in five phases over about 28 weeks: a 2-week foundation, your three module phases, and a 4-week hardening phase before final submission. Module 10 grows in every phase, so the supervisor portal always shows what the mobile app can already collect.

Every feature below is tagged with its scope ID (for example M5 FE-2 = Module 5, FE-2), so each task traces back to the final scope document. Week numbers are relative; map them onto your department's FYP-I and FYP-II evaluation dates.

| Phase | Modules | Weeks | Lead (support) | Exit gate |
|---|---|---|---|---|
| 0. Foundation | Shared setup, schema, auth and sync skeleton | 1–2 | Shared | App, API, DB and dashboard run end to end on one test record |
| 1. Core field workflow | M1, M2, M3, M10 base | 3–9 | Zain Abbas (Zain Ali: backend, sync, web) | LHW registers a woman and records a visit offline; it syncs and appears on the dashboard |
| 2. Intelligence and emergency | M4, M5, M6, M10 update | 10–17 | Zain Abbas: M4, M10. Zain Ali: M5, M6 | Visit produces a risk result with Urdu explanation; emergency alert reaches supervisor by internet, SMS and call |
| 3. Child health and campaigns | M7, M8, M9, M10 final | 18–24 | Zain Ali: M7, M8, M9. Zain Abbas: M10 | All ten modules work; dashboard and reports cover every module |
| 4. Hardening and delivery | Testing, performance, documentation | 25–28 | Shared | Full test pass on a low-spec Android device; final documentation and demo ready |

Owners follow Table 4 of the scope document. Shared work (REST API, PostgreSQL schema, offline sync, integration testing, Figma, deployment) is split inside each phase as listed in the phase sections.

## Architecture and conventions

The Flutter app owns the whole field workflow and never needs the server to do its job; the server only collects, analyses and reports. Settle the rules below in Phase 0, because changing them after Phase 1 means rewriting synced data.

**The phone works alone; the server only collects, analyses and reports**

```mermaid
flowchart LR
    app["<b>LHW Android app</b><br/>Flutter<br/>Modules 1–9, Urdu, offline<br/>Encrypted SQLite (SQLCipher)<br/>ONNX model + danger rules<br/>Emergency: Internet, SMS, Call"]
    api["<b>REST API</b><br/>Node.js + Express<br/>Auth, sync, alerts<br/>Reports, audit log"]
    portal["<b>Supervisor portal</b><br/>React + Leaflet<br/>Dashboard, map, alerts<br/>Reports, admin panel"]
    phone["<b>Supervisor phone</b><br/>Push alerts (FCM)<br/>SMS and calls"]
    ml["<b>ML training pipeline</b><br/>scikit-learn, SMOTE, SHAP<br/>Exports ONNX + Urdu lookup"]
    db["<b>PostgreSQL 15</b><br/>Central data, audit log"]
    worker["<b>Analytics worker</b><br/>Python: numpy + scipy<br/>Module 6 trends"]

    app ==>|"SMS and call over cellular, no internet needed"| phone
    app <-->|sync| api
    api <-->|HTTPS| portal
    api -->|"push (FCM)"| phone
    ml -.->|bundled at build time| app
    api <--> db
    api -->|trend jobs| worker
```

*MediQore architecture · 7 components*

The highlighted path is the key design choice: an emergency SMS or call goes straight from the LHW's phone to the supervisor, with no server in between.

| Component | Technology (from scope) | Responsibility |
|---|---|---|
| LHW mobile app | Flutter 3.x, Drift + sqflite_sqlcipher, flutter_tts, onnxruntime, google_mlkit_text_recognition, fl_chart, shared_preferences *(A1)* | Modules 1–9 in Urdu (English selectable, A1), fully offline, on-device AI and danger-sign rules, emergency alerts |
| REST API | Node.js 20 + Express, jsonwebtoken, Joi, pdfkit + ExcelJS | Auth, sync endpoints, conflict detection, alerts, reports, audit log |
| Database | PostgreSQL 15 | Central store for all modules, audit log, sync sequence numbers |
| Supervisor and admin portal | React 18, Leaflet.js | Module 10: dashboard, map, alerts, reports, admin panel |
| ML and analytics | Python 3.11, scikit-learn, imbalanced-learn, SHAP, sklearn2onnx, numpy + scipy | Offline model training and export; backend trend analysis for Module 6 |
| Push notifications | Firebase Cloud Messaging | Layer 1 emergency alerts (M5 FE-2) |

Use one GitHub monorepo so the API contract, migrations and app change together:

```
mediqore/
  mobile/   Flutter app (LHW role + supervisor alert role)
  api/      Node.js + Express REST API
  web/      React supervisor and admin portal
  ml/       Python training, SHAP lookup, ONNX export, analytics worker
  db/       PostgreSQL migrations and synthetic seed scripts
  docs/     OpenAPI contract, ERD, test reports
```

| Area | Rule |
|---|---|
| Record IDs | Every record made on the device gets a UUID v4; the server adds a sequence number when it accepts it. Never order records by device clock (LI-7). |
| Deletes and audit | Soft deletes only. Every create, edit, delete, referral and login writes an audit row with user and timestamp (M10 FE-3). |
| API | REST under /api/v1, JSON, Joi validation on every request body, JWT access token plus refresh token, HTTPS only (M1 FE-2). |
| Units | Store one unit per vital: BP in mmHg, temperature in °C, blood sugar in mmol/L, weight in kg, MUAC in mm. Convert only at the model input or display layer. |
| Clinical rules | Danger-sign thresholds, EPI schedule, MUAC cut-offs and IMCI rules live in versioned JSON config files, never hard-coded, so clinical advisors can review them (M4 FE-4). |
| Urdu text | All labels in Flutter ARB localisation files, with an Urdu and an English entry. Urdu, the default, is rendered in Jameel Noori Nastaleeq inside RTL Directionality. *(A1)* English, when the LHW selects it (M1 FE-4), is rendered left to right in the standard Latin font. Numeric vitals stay left to right in both. |
| Git workflow | main is always demo-ready; feature branches per FE (for example feature/m3-fe1-visit-form); every merge reviewed by the other member; GitHub Actions runs lint and tests. |
| Environments | Local PostgreSQL for development; one HTTPS staging server for supervisor reviews and demos. |

## Phase 0: Foundation (weeks 1–2)

Phase 0 builds the skeleton every module plugs into, so Phase 1 is spent on features rather than setup. Design the database for all ten modules now, even though most tables stay empty until later phases.

| ID | Task | Scope link | Owner |
|---|---|---|---|
| P0-1 | Create the monorepo, branch protection on main, and a GitHub Actions workflow that runs lint and unit tests | Tools: Git + GitHub | Shared |
| P0-2 | Flutter project: Urdu ARB localisation, bundled Jameel Noori Nastaleeq font, RTL theme, and a small widget kit (large buttons, form fields, Green/Yellow/Red risk chips, offline status bar) | M3 FE-1 | Zain Abbas |
| P0-3 | Express API skeleton: routes, controllers, services, Joi validation middleware, central error handler, request logging, OpenAPI file | M1 FE-2 | Zain Ali |
| P0-4 | PostgreSQL schema v1 with migrations for all core entities (see Data model) and a migration tool such as Knex or node-pg-migrate | Shared: DB schema | Zain Ali |
| P0-5 | React portal skeleton: routing, login page, auth guard, layout with sidebar, empty Leaflet map component | M10 | Zain Ali |
| P0-6 | Offline sync skeleton: device outbox table, POST /sync/push and GET /sync/pull?since=, one record proven end to end | M3 FE-2 | Shared |
| P0-7 | Figma screens for Phase 1: login, LHW home, registration, visit form, dashboard home, admin lists | Mockups 1, 2, 6 | Shared |
| P0-8 | Synthetic data generator: districts, Union Councils, LHWs, households with GPS, pregnant women, visits | LI-10 | Zain Ali |
| P0-9 | Draft and submit the IEC application (due in Semester 7) | LI-10 | Shared |
| P0-10 | Start the ML track: download the UCI dataset, exploratory notebook, check duplicates and class balance | M4 FE-1 | Zain Abbas |
| P0-11 | Decide the open items in Risks and decisions (OTP channel, Urdu PDF method, Urdu voice source, model inputs) | All | Shared |

**Exit gate for Phase 0**

- [ ] One test record created on the phone offline, synced, stored in PostgreSQL and visible on the React portal
- [ ] CI runs on every pull request
- [ ] Schema v1 and OpenAPI v1 reviewed by both members
- [ ] IEC application submitted

## Phase 1: Core field workflow — M1, M2, M3, M10 base (weeks 3–9)

By the end of Phase 1 an LHW can log in, register a pregnant woman and record a visit with no internet, and the supervisor sees it on the portal after sync. Zain Abbas builds the mobile modules; Zain Ali builds the API, sync engine and most Phase 1 web screens, because his own modules start in Phase 2.

### Module 1: LHW onboarding and access control

| Task | Layer | Scope link | Owner |
|---|---|---|---|
| Admin creates an LHW with district, Union Council and area; system issues a unique LHW ID and credentials | API + Web | FE-1 | Zain Ali |
| On first login the app downloads only that LHW's area data (her patient list) | Mobile + API | FE-1 | Shared |
| JWT login with access and refresh tokens, login rate limiting, HTTPS only, server-side validation | API | FE-2 | Zain Ali |
| OTP verification on first login and on a new device (channel decided in P0-11) | API + Mobile | FE-2 | Zain Ali |
| Offline login: derive the SQLCipher key from the password with a slow key-derivation function (PBKDF2 or Argon2) and a stored salt; a correct password unlocks the local database | Mobile | FE-2, LI-8 | Zain Abbas |
| Auto-lock after inactivity and session expiry; deactivated accounts are refused at next sync | Mobile + API | FE-2, FE-3 | Shared |
| Admin area reassignment, activation and deactivation, password reset with a "sync before reset" warning | Web + API | FE-3, LI-8 | Zain Ali |
| *(A1)* Language switch on the login screen and in settings: Urdu (default) or English, kept on the phone, the whole app follows it (Urdu right to left, English left to right); voice guidance only in Urdu. The base switch exists from Phase 0. | Mobile | FE-4, M3 FE-3 | Zain Abbas |

### Module 2: Expecting woman registration

| Task | Layer | Scope link | Owner |
|---|---|---|---|
| Registration form (name, age, husband's name, contact, address, pregnancy month, village) in Urdu with validation | Mobile | FE-1 | Zain Abbas |
| Patient ID that is unique offline: LHW code plus a local counter, alongside the record UUID | Mobile | FE-1 | Zain Abbas |
| Create the pregnancy file (one woman can have several pregnancies over time) | Mobile + DB | FE-1 | Zain Abbas |
| Obstetric history: previous pregnancies, C-sections, stillbirths, known conditions; stored as the baseline risk profile | Mobile | FE-2 | Zain Abbas |
| Household entity with GPS capture (geolocator package), linked to the woman; reused later by polio and child modules | Mobile + DB | FE-3 | Zain Abbas |
| Area-based patient search and list sorting by village | Mobile | FE-3 | Zain Abbas |

### Module 3: Field visit and vitals collection

| Task | Layer | Scope link | Owner |
|---|---|---|---|
| Visit form: BP, weight, temperature, fetal movement, swelling, bleeding, fever, anaemia signs, urine symptoms, using checkboxes, dropdowns and large controls | Mobile | FE-1 | Zain Abbas |
| Add pulse (heart rate) and optional blood sugar fields now, because the Phase 2 model needs them (see Risks) | Mobile | FE-1, M4 FE-1 | Zain Abbas |
| Range checks to catch typing errors (for example systolic BP outside 60–250 asks for confirmation) | Mobile | FE-1 | Zain Abbas |
| AES-256 encrypted local storage with Drift + sqflite_sqlcipher | Mobile | FE-2 | Zain Abbas |
| Sync engine: outbox with retry, idempotent push by UUID, server sequence IDs, pull by cursor, background sync when online | Mobile + API | FE-2 | Shared |
| Conflict detection for duplicate offline submissions; conflicted records flagged for supervisor review and kept in the audit log | API | FE-2, LI-7 | Zain Ali |
| Voice guidance: on field focus, flutter_tts reads the Urdu label; mute toggle in settings; *(A1)* off while the app is in English | Mobile | FE-3, LI-6, M1 FE-4 | Zain Abbas |

### Module 10 base: supervisor portal

| Task | Layer | Scope link | Owner |
|---|---|---|---|
| Admin panel: district, tehsil, Union Council and area hierarchy; LHW and supervisor accounts; hospitals and referral centres; role permissions | Web + API | FE-3 | Zain Ali |
| Audit log viewer with filters by user, action and date | Web + API | FE-3 | Zain Ali |
| Dashboard cards: registered patients, visits this week, LHW visit counts, last login | Web + API | FE-1 | Zain Ali |
| Leaflet map of registered households from Module 2 GPS, filter by district, Union Council, LHW and time period, auto-refresh every 5 minutes | Web | FE-1 | Zain Abbas |
| Sync conflict review queue for supervisors | Web + API | M3 FE-2 | Zain Ali |

### ML track (runs alongside Phase 1)

Zain Abbas trains the model now so Module 4 starts in Phase 2 with a ready ONNX file. Details are in Phase 2 under Module 4.

**Exit gate for Phase 1**

- [ ] LHW logs in online once, then works fully offline: login, registration, visit with voice guidance
- [ ] *(A1)* The LHW can switch the app between Urdu and English; voice guidance works in Urdu and is off in English
- [ ] Records sync automatically when online; a duplicate submission is flagged, not overwritten
- [ ] Admin manages areas, accounts and hospitals; every action appears in the audit log
- [ ] Supervisor sees patients, visits, LHW activity and the household map
- [ ] Unit tests for form validation, sync and auth pass in CI

## Phase 2: Intelligence and emergency — M4, M5, M6, M10 update (weeks 10–17)

By the end of Phase 2 every visit produces a risk result with an Urdu explanation, a critical case can reach the supervisor by internet, SMS or call, and each pregnancy has a full health record with trends. Zain Abbas owns Module 4 and the Module 10 update; Zain Ali owns Modules 5 and 6.

### Module 4: AI-based maternal risk assessment

| Task | Layer | Scope link | Owner |
|---|---|---|---|
| Clean the UCI data: remove duplicate rows, keep a stratified 20% hold-out test set untouched until the end | ML | FE-1 | Zain Abbas |
| imbalanced-learn Pipeline with SMOTE applied inside each training fold only, so synthetic rows never leak into validation | ML | FE-1, BO-2 | Zain Abbas |
| Compare Logistic Regression, Random Forest and Gradient Boosting with 5-fold stratified CV; report F1-macro, per-class F1, per-class recall and ROC-AUC | ML | FE-1, BO-2 | Zain Abbas |
| Select the model: high-risk recall of at least 90% first, then best F1-macro | ML | BO-2 | Zain Abbas |
| Write the PDHS 2017–18 feature-alignment note for the report | ML | FE-1, LI-2 | Zain Abbas |
| Run SHAP on the chosen model, derive feature-threshold rules per class, map each to a reviewed Urdu phrase, export the JSON lookup | ML | FE-2 | Zain Abbas |
| Export to ONNX with sklearn2onnx (plain probability output, no ZipMap); parity test that Python and ONNX agree on every test row | ML | FE-1 | Zain Abbas |
| Run inference with onnxruntime after each visit; convert units to the dataset's (UCI body temperature is in °F); handle a missing blood sugar value as decided in P0-11 | Mobile | FE-1 | Zain Abbas |
| Benchmark inference time on the lowest-spec test phone (target under 1 second) | Mobile | FE-1 | Zain Abbas |
| Result screen: colour-coded risk, Urdu explanation from the lookup, decision-support disclaimer | Mobile | FE-2, LI-5 | Zain Abbas |
| Risk trend across visits: store each result, alert the LHW when the level or BP trend worsens across the last visits | Mobile | FE-3 | Zain Abbas |
| Danger-sign rules engine read from JSON config; final level = higher of model and rules; Emergency hands off to Module 5; one unit test per rule | Mobile | FE-4, LI-12 | Zain Abbas |

### Module 5: Emergency referral coordination

| Task | Layer | Scope link | Owner |
|---|---|---|---|
| One-tap referral pre-filled with patient details, risk factors and the nearest hospital, found by GPS distance to the cached hospital list | Mobile | FE-1 | Zain Ali |
| Emergency screen with three equal buttons (Internet, SMS, Call) and Send all; each button shows if it is usable now (connectivity_plus plus the phone's service state) | Mobile | FE-2 | Zain Ali |
| Layer 1: alert to the API, Firebase Cloud Messaging push to the supervisor's phone, and a live alerts panel on the dashboard | Mobile + API + Web | FE-2 | Zain Ali |
| Layer 2: pre-filled SMS sent from the LHW's phone (another_telephony, SEND_SMS permission) with sent and delivered callbacks | Mobile | FE-2, LI-4 | Zain Ali |
| Layer 3: one-tap call to the supervisor and the secondary contact (flutter_phone_direct_caller, CALL_PHONE permission) | Mobile | FE-2 | Zain Ali |
| Persistent emergency screen, Urdu voice announcement, protocol checklist, per-option status (Sent, Failed, Not available) with retry | Mobile | FE-4 | Zain Ali |
| Save the alert record locally and sync it in the background when internet returns (workmanager); record time-to-escalation | Mobile + API | FE-4 | Zain Ali |
| Acknowledgement: supervisor acknowledges in the app or dashboard; LHW can mark "supervisor reached" after a call or SMS reply | Mobile + Web + API | FE-5 | Zain Ali |
| 15-minute escalation on two sides: a server job for alerts the server knows about, and a device timer that prompts the LHW to contact the secondary contact for SMS-only or call-only alerts | Mobile + API | FE-5 | Zain Ali |
| Referral outcome: attended or not, and outcome, visible to the supervisor | Mobile + Web | FE-3 | Zain Ali |

### Module 6: Pregnancy journey, health records and ANC monitoring

| Task | Layer | Scope link | Owner |
|---|---|---|---|
| ANC schedule generated from gestational age at registration; local reminders (flutter_local_notifications); missed visits flagged | Mobile | FE-1 | Zain Ali |
| TT dose schedule plus iron and folic acid tracking, with a supplement compliance score on the patient profile | Mobile | FE-1 | Zain Ali |
| Report scan: camera or gallery, grayscale and contrast preprocessing, ML Kit text recognition fully offline | Mobile | FE-2, LI-9 | Zain Ali |
| Dart regex engine extracting BP, haemoglobin, blood glucose, temperature, weight and urine protein; high-confidence values pre-filled, others confirmed; manual entry fallback | Mobile | FE-2, LI-9 | Zain Ali |
| Store the original report image (compressed, encrypted on device, uploaded on sync) | Mobile + API | FE-2 | Zain Ali |
| Vital trend graphs on the device with fl_chart, built from local data so they work offline | Mobile | FE-3 | Zain Ali |
| Python analytics worker (numpy + scipy) called by the API: linear-regression slope per vital, Z-score anomalies, weighted compliance score; results returned on next sync | ML + API | FE-3 | Zain Ali |
| Bilingual PDF progress report: trend graphs, visit history, ANC compliance, doctor notes, Urdu summary | API | FE-3 | Zain Ali |

### Module 10 update

| Task | Layer | Scope link | Owner |
|---|---|---|---|
| Risk distribution chart (Green, Yellow, Red) and high-risk cluster layer on the map | Web + API | FE-1 | Zain Abbas |
| Referral completion rate, overdue follow-ups and missed ANC visits per LHW | Web + API | FE-1 | Zain Abbas |
| Emergency alerts panel: channel used, time-to-escalation, acknowledge button, unacknowledged alerts highlighted | Web + API | M5 FE-5 | Zain Abbas |
| Admin: emergency escalation contacts per area (supervisor and secondary numbers) | Web + API | FE-3 | Zain Abbas |
| Weekly and monthly PDF and Excel reports: maternal summary, high-risk list, referral completion, LHW activity, emergency alerts | API + Web | FE-2 | Zain Abbas |
| Inactivity anomaly flag: weekly visits more than 2 standard deviations below the LHW's own mean, only after 4 weeks of history | API + Web | FE-4 | Zain Abbas |

**Exit gate for Phase 2**

- [ ] Chosen model meets at least 90% high-risk recall on the hold-out set, and ONNX parity test passes
- [ ] Every danger-sign rule forces an Emergency result in tests, even when the model says low risk
- [ ] Emergency alert sent by each of the three options in airplane mode (SMS and call) and online (internet)
- [ ] Unacknowledged alert escalates to the secondary contact after the set time
- [ ] OCR pre-fills values from a printed report; a handwritten report falls back to manual entry
- [ ] Dashboard shows risk, referrals, alerts and reports for maternal data

## Phase 3: Child health and campaigns — M7, M8, M9, M10 final (weeks 18–24)

By the end of Phase 3 all ten modules work and the portal reports on every one of them. Start with a shared child registry in week 18, because Modules 7, 8 and 9 all depend on it and the scope does not assign it to a single module.

### Shared child registry (week 18)

| Task | Layer | Scope link | Owner |
|---|---|---|---|
| Household roster for every household in the LHW's area, not only those with a pregnant woman, reusing the Phase 1 household entity and GPS | Mobile + DB | M7 FE-1 | Shared |
| Child record: name, date of birth, sex, household, optional link to the mother's pregnancy file | Mobile + DB | M7 FE-3, M8 FE-1 | Shared |
| Child list per household with age shown in months, used by all three modules | Mobile | M7–M9 | Shared |

### Module 7: Polio campaign field operations

| Task | Layer | Scope link | Owner |
|---|---|---|---|
| Campaign rounds (name, dates, area) created on the portal and pulled to devices | Web + API + Mobile | FE-1 | Zain Ali |
| House-to-house record: children under 5, children vaccinated, vaccine type (OPV), date; saved offline | Mobile | FE-1 | Zain Ali |
| Refusal record with reason dropdown (religious concern, misinformation, past reaction, absent family) and an automatic revisit in the same round | Mobile | FE-2 | Zain Ali |
| Revisit list for the LHW, sorted by distance from her current location | Mobile | FE-2 | Zain Ali |
| Zero-dose check: any child under 5 with no OPV dose in any round goes on a priority list, on the device for her area and on the server for the whole district | Mobile + API | FE-3 | Zain Ali |

### Module 8: Child immunisation and EPI management

| Task | Layer | Scope link | Owner |
|---|---|---|---|
| EPI schedule config (BCG, OPV-0, Penta 1–3, PCV 1–3, Rota 1–2, IPV, MR) with due ages taken from the official Pakistan EPI schedule | Config | FE-1 | Zain Ali |
| Personal vaccination timeline per child under 2 from date of birth; dose recording; birth-dose OPV-0 kept separate from campaign doses | Mobile | FE-1 | Zain Ali |
| Defaulter alert on the LHW home screen when a dose passes its due date; supervisor notified after sync | Mobile + API | FE-2 | Zain Ali |
| Coverage per antigen and per sub-area, with low-coverage sub-areas highlighted | API + Web | FE-3 | Zain Ali |

### Module 9: Child nutrition and growth screening

| Task | Layer | Scope link | Owner |
|---|---|---|---|
| MUAC entry with WHO classification: below 115 mm SAM, 115–125 mm MAM, above 125 mm Normal; colour-coded Urdu result; age check for 6–59 months | Mobile | FE-1 | Zain Ali |
| Weight-for-age and height-for-age Z-scores from bundled WHO Child Growth Standards tables; stunting, wasting and underweight flags | Mobile | FE-1 | Zain Ali |
| Unit tests that check Z-score output against WHO reference values | Mobile | FE-1 | Zain Ali |
| SAM referral to the nearest Nutrition Rehabilitation Centre, attendance tracking and weight recovery across follow-ups | Mobile + Web | FE-2 | Zain Ali |
| IMCI checklist: respiratory rate with an on-screen 60-second counter, chest indrawing, stool frequency, dehydration signs; severity and Urdu action from IMCI rules config | Mobile | FE-3 | Zain Ali |
| Test the IMCI rules against the worked cases in the WHO IMCI chart booklet | Mobile | FE-3 | Zain Ali |

### Module 10 final

| Task | Layer | Scope link | Owner |
|---|---|---|---|
| Polio campaign progress, refusals and zero-dose counts per area | Web + API | FE-1 | Zain Abbas |
| Map layers for malnutrition hotspots and immunisation coverage gaps, beside the high-risk pregnancy layer | Web | FE-1 | Zain Abbas |
| Full report set: adds polio progress, immunisation coverage and nutrition screening to the weekly and monthly PDF and Excel reports | API + Web | FE-2 | Zain Abbas |
| Admin: campaign rounds and Nutrition Rehabilitation Centre records | Web + API | FE-3 | Zain Abbas |
| Performance: database indexes, paginated tables, clustered map markers for large areas | Web + API + DB | FE-1 | Zain Abbas |

**Exit gate for Phase 3**

- [ ] A polio round runs end to end offline, including a refusal, its revisit and a zero-dose child
- [ ] A child's EPI timeline produces a defaulter alert that reaches the supervisor
- [ ] MUAC, Z-score and IMCI results match WHO reference cases
- [ ] Dashboard, map layers and reports cover all ten modules

## Phase 4: Hardening and final delivery (weeks 25–28)

Phase 4 adds no new features; it proves the system works under field conditions and packages it for evaluation. Freeze features at the start of week 25 and only fix bugs after that.

| Week | Task | Owner |
|---|---|---|
| 25 | End-to-end scenarios across all modules: registration → visit → Emergency → alert → referral outcome → report; polio round; EPI defaulter; SAM referral | Shared |
| 25 | Field simulation on 3 or more phones in airplane mode for several days of synthetic work, then a mass sync with deliberate conflicts | Shared |
| 26 | Low-spec device test (a 2 GB RAM Android phone): app start time, form speed, inference time, sync of 1,000 records, battery use | Zain Abbas |
| 26 | Security review: expired and tampered tokens, SQL injection attempts, HTTPS enforcement, lost-device test (local database unreadable without the password) | Zain Ali |
| 26 | Usability check of the Urdu interface and voice guidance; with LHWs only if IEC approval has arrived, otherwise with peers on dummy data | Shared |
| 27 | Bug fixing and regression run of the full test suite | Shared |
| 27 | Documentation: model report (metrics, confusion matrix, SHAP), API reference, test report, deployment guide, user guides for LHW (Urdu), supervisor and admin | Shared |
| 28 | Final mockups for Appendix A, signed release APK, staging deployment, demo script with synthetic data, presentation | Shared |

**Exit gate for Phase 4**

- [ ] All Phase 1–3 exit gates still pass on the release build
- [ ] No open critical or high-severity bugs
- [ ] Documentation and Appendix A mockups complete
- [ ] Demo rehearsed twice on the release APK and staging server

## Cross-cutting tracks

Four concerns run through every phase; each new module must follow these rules rather than invent its own.

### Offline sync

Every write on the device goes to its local table and to an outbox in the same transaction. The sync service pushes outbox rows in batches (about 100 per request) when online, and the server replies with the sequence number it assigned to each UUID. Pull uses the last sequence number the device has seen, so nothing depends on device clocks.

Emergency alert records always go first in the push order (M5 FE-4). Report images upload separately after the data rows, so a slow photo never delays clinical data. Resending the same UUID is harmless; a different record for the same woman on the same day goes to the supervisor conflict queue (M3 FE-2).

### Security and access

| Rule | Scope link |
|---|---|
| Passwords hashed on the server with bcrypt; short-lived access token, longer refresh token, both revocable on deactivation | M1 FE-2, FE-3 |
| Role check middleware on every route: LHW, supervisor, admin | M1 FE-2 |
| Area scoping in every query: an LHW sees only her area, a supervisor only the areas assigned to them | M1 FE-1 |
| Parameterised SQL only, Joi validation before any database call | Tools: Joi |
| Local database encrypted with AES-256; report images stored encrypted; nothing patient-related in plain shared storage | M3 FE-2, LI-8 |
| Audit row for every create, edit, delete, referral, alert and login | M10 FE-3 |

### Urdu and voice

Write no visible string in Dart code; every label goes into the ARB files from the start, with an Urdu and an English entry. *(A1)* The app runs in Urdu by default and in English when the LHW chooses it (M1 FE-4), so both entries are shown to users. Test every screen in both languages on a small phone, because Nastaliq text is taller than Latin text and overflows easily. Voice guidance speaks Urdu only, so it is switched off while the app is in English. For voice guidance, check whether the test phones have an Urdu text-to-speech voice in Phase 0; if not, record short audio clips for the fixed field labels (see Risks).

### Testing

| Level | Tool | What it covers |
|---|---|---|
| Unit | flutter_test, Jest, pytest | Form validation, danger-sign rules, EPI dates, MUAC and Z-score maths, IMCI rules, regex extraction, model metrics |
| Widget | flutter_test | Urdu and English *(A1)* screens render without overflow, RTL and LTR layout, emergency screen states |
| API | Jest + Supertest | Auth, role checks, area scoping, sync push and pull, conflict detection |
| Integration | Manual scripts on real phones | Offline-to-online flows, three alert options, multi-device sync |
| Model | pytest + saved metrics | Hold-out recall threshold, ONNX parity |

Each FE is done only when its tests pass in CI and it works on a real phone in airplane mode.

## Data model overview

The same tables exist in PostgreSQL and, for field data, in the device's Drift database. Every synced table carries the same base columns: id (UUID), server_seq, area_id, created_by, created_on_device, synced_at and deleted_at.

| Table group | Key tables | Built in | Used by |
|---|---|---|---|
| Geography | districts, tehsils, union_councils, areas | Phase 0 | M1, M10 |
| Users and access | users (with role), lhw_profiles, supervisor_areas, devices, refresh_tokens, otp_codes | Phase 0–1 | M1 |
| System | audit_log, sync_conflicts, report_jobs | Phase 0–1 | M3, M10 |
| Households and women | households (with GPS), women, pregnancies, obstetric_history | Phase 1 | M2, M7 |
| Visits | visits (all vitals and symptoms) | Phase 1 | M3, M4, M6 |
| Facilities | hospitals, referral_centres, escalation_contacts | Phase 1–2 (Nutrition Rehabilitation Centres in Phase 3) | M5, M9, M10 |
| Risk | risk_assessments (model result, rule result, final level, explanation key, model version) | Phase 2 | M4, M10 |
| Emergency | referrals, emergency_alerts, alert_attempts (channel, status, time), alert_acknowledgements | Phase 2 | M5, M10 |
| ANC and records | anc_schedule, tt_doses, supplement_logs, health_documents (image, extracted values, confidence), trend_results | Phase 2 | M6 |
| Children | children | Phase 3 | M7, M8, M9 |
| Polio | campaigns, campaign_household_records, refusals, revisits | Phase 3 | M7 |
| Immunisation | epi_schedule (config), immunisations | Phase 3 | M8 |
| Nutrition | nutrition_screenings (MUAC, Z-scores), sam_followups, imci_assessments | Phase 3 | M9 |

Store the model version on every risk assessment, so results stay traceable when the model is retrained on field data later (LI-2).

## Risks and decisions to settle early

The first row is the most urgent: the model planned for Module 4 needs two inputs that the Module 3 form does not collect. Settle all of these in Phase 0 (task P0-11) so later phases do not stall.

| Risk or decision | Why it matters | Recommended action | Settle by |
|---|---|---|---|
| Model inputs missing from the visit form | The UCI dataset uses blood sugar and heart rate; Module 3 FE-1 collects neither | Add pulse (any LHW can count it) and optional blood sugar to the form; train one model with all six features and one without blood sugar, and use the second when no reading exists | Phase 0 |
| OTP channel | SMS OTP needs a paid gateway, which LI-4 says the prototype avoids | Use email OTP or an admin-issued one-time code for the prototype; keep the OTP service swappable | Phase 0 |
| Urdu text in PDF reports | pdfkit may not join Nastaliq letters or order right-to-left text correctly | Test a one-page Urdu PDF in Phase 0; if it breaks, render the report as HTML with the Urdu font and print it to PDF with headless Chrome (Puppeteer) | Phase 0 |
| Urdu voice on the phone | Many Android phones have no Urdu text-to-speech voice installed | Check the test phones; if missing, record short Urdu clips for the fixed field labels and play those instead | Phase 0 |
| Where Layer 1 push lands | Firebase Cloud Messaging needs the supervisor's device | Add a small supervisor role in the Flutter app (alerts inbox and acknowledge) plus browser alerts on the dashboard | Phase 1 |
| Urdu SMS length | Urdu SMS fits about 70 characters per part, so alerts split into several parts | Keep the alert template short, with patient ID and key facts first | Phase 2 |
| SMS and call permissions | Google Play restricts apps that send SMS or place calls | Distribute the FYP build as a signed APK, not through Play Store | Phase 2 |
| OCR language | ML Kit reads Latin script, not Urdu | Fine for English lab reports; Urdu or handwritten reports use manual entry (LI-9) | Phase 2 |
| Phase 2 workload | Zain Ali carries both Module 5 and Module 6 | Zain Abbas takes the Module 6 analytics worker (FE-3), since it is Python and he runs the ML track | Phase 1 |
| Small training dataset | About 1,000 rows with many duplicates; scores can look better than they are | Remove duplicates, report hold-out results honestly, and present field-data retraining as future work (LI-2) | Phase 2 |
| IEC approval delay | No real patient data before approval (LI-10) | All testing and demos on the synthetic data generator from P0-8 | Ongoing |

## Definition of done

A module counts as finished only when every item below is true. Copy this list into each module's tracking issue on GitHub.

- [ ] Every FE in the scope document for that module works on a real Android phone
- [ ] Works fully offline where the scope says so, and syncs correctly afterwards
- [ ] All screens in Urdu and English *(A1)* with no text overflow; numeric values display left to right
- [ ] API routes validated with Joi, role-checked and area-scoped
- [ ] Every create, edit and delete writes an audit row
- [ ] Unit and API tests written and passing in CI
- [ ] Module 10 shows the module's data (dashboard, map or report, as the scope says)
- [ ] Synthetic data for the module added to the seed script
- [ ] Reviewed and merged by the other team member
- [ ] Short note added to the user guide and test report
