# MediQore

**An AI-assisted, offline-ready digital health platform for Lady Health Workers (LHWs) in Pakistan.**

Final-year project, BS Computer Science, COMSATS University Islamabad (2023–2027).

MediQore replaces the LHW's paper registers with an Android app, in Urdu by default with an English option, that works fully offline. LHWs can:

- register pregnant women and record home visits;
- get an on-device AI maternal risk result (Green / Yellow / Red) with an Urdu explanation;
- raise emergency alerts by internet, SMS or call;
- cover polio campaigns, EPI child immunisation and child nutrition screening.

The app syncs with a central server whenever a connection is available. Supervisors and admins use a web portal for a live dashboard and map, alerts, PDF/Excel reports and administration.

> **Status:** Phase 0 (Design and foundation, roadmap of 10 Oct 2026) is built on `dev`:
> - monorepo with GitHub Actions lint and tests for every part (P0-1);
> - the Flutter app with Urdu and English, the bundled Jameel Noori Nastaleeq font, right to left and left to right layouts, and a widget kit in the final Clinical Teal design (P0-2);
> - the Express 5 API skeleton on Node.js 24 LTS with Joi validation, a central error handler, request logging and the OpenAPI file (P0-3);
> - database schema v1 for all ten modules, including activation codes, Clinical Rules Table versions, pregnancy outcomes and the child register (P0-4);
> - the portal skeleton as an installable web app with a service worker ready for web push (P0-5);
> - the offline sync skeleton, proven end to end: a record made on the phone offline is synced, stored in PostgreSQL and shown on the portal (P0-6);
> - the Phase 1 screens in the final design (P0-7, [docs/design/phase1-screens.md](docs/design/phase1-screens.md));
> - the synthetic data generator (P0-8);
> - the IEC application draft, ready for the team to submit (P0-9);
> - the start of the ML track: UCI dataset download and exploratory notebook (P0-10);
> - the Clinical Rules Table v0 with WHO-referenced defaults, marked "pending clinical review" ([clinical-rules/](clinical-rules/README.md), P0-11);
> - the Urdu PDF check: pdfkit runs Urdu lines left to right, so reports use HTML printed to PDF ([decision 0003](docs/decisions/0003-urdu-pdf-method.md), P0-12).
>
> Still with people: branch protection on `main` (P0-1), submitting the IEC application (P0-9), a Clinical Advisor for the rules table (P0-11), and the review of schema v1 and OpenAPI v1 by both members.
>
> **Phase 1 (Modules 1, 2, 3 and the Module 10 base)** was built on `dev` against the earlier scope and is being revised to the updated one. Module 1 is revised: the admin's one-time activation code, the offline six-digit PIN with progressive delays, PIN reset with the supervisor's reply code, the lock-screen emergency call and the Keystore-wrapped database key; voice guidance is removed (LI-6). Also in place: supervisor and admin accounts and the admin panel; registration of pregnant women with GPS and the patient list; the encrypted visit form with range checks and automatic sync with the supervisor conflict queue; the dashboard, household map and audit log. Still to come in the revision: the registration wizard and obstetric flags (M2), the visit form's pulse counter, blood sugar details and danger-sign checklist (M3), and the final design of the remaining screens.
>
> **Data notice:** MediQore is developed and demonstrated on synthetic data only. No real patient data is used before IEC approval (LI-10). AI results are decision support, not a clinical diagnosis (LI-5).

## Components

| Part | Folder | Stack | Status |
|---|---|---|---|
| LHW Android app (Modules 1–9) | [`mobile/`](mobile/) | Flutter 3.x, Drift + SQLite3MultipleCiphers, ONNX Runtime | Urdu and English shell, widget kit in the final design (P0-2); local database, outbox and sync (P0-6); activation code, offline PIN with progressive delays, PIN reset, emergency call, Keystore-wrapped database key and auto-lock (M1); registration, patient list and pregnancy file (M2); encrypted database, visit form and automatic sync (M3) |
| REST API | [`api/`](api/) | Node.js 24 LTS + Express 5, JWT, Joi | Skeleton (P0-3); `/sync` push/pull (P0-6); activation codes, re-sign-in, refresh tokens, LHW accounts, PIN-reset reply codes (M1); registrations through `/sync` and `GET /women` (M2); visits through `/sync`, the same-day conflict queue and the dashboard summary (M3); role permissions, admin panel, audit log, LHW activity and map filters (M10 base) |
| Database | [`db/`](db/) | PostgreSQL 15 migrations and synthetic seed scripts | Schema v1 for all ten modules, brought up to the final scope (P0-4); Clinical Rules Table loader (P0-11); demo seed; synthetic data generator (P0-8); LHW ID numbering and the previous area after a reassignment (M1); held conflicts and hospitals in the synthetic data (M3, M10) |
| Supervisor and admin portal (Module 10) | [`web/`](web/) | React 18 + Leaflet.js, installable web app | Login, auth guard, sidebar layout, map dashboard, manifest and service worker ready for web push (P0-5); LHW accounts with activation codes, PIN reset codes (M1); registered women (M2); sync conflict review queue, visits on the dashboard (M3); LHW activity, map filters and auto-refresh, admin panel and audit log (M10 base) |
| ML training | [`ml/`](ml/) | Python 3.11, scikit-learn, imbalanced-learn, SHAP, skl2onnx | Dataset download and exploratory notebook (P0-10); training of the five- and six-feature models in Phase 2 |
| Clinical Rules Table | [`clinical-rules/`](clinical-rules/) | Versioned JSON, read by the app and the API | v0 with WHO-referenced defaults, pending clinical review (P0-11) |

## Repository layout

```
mediqore/
├── mobile/          Flutter app (LHW)
├── api/             Node.js + Express REST API
├── web/             React supervisor and admin portal (installable web app)
├── ml/              Python training, SHAP lookup, ONNX export
├── clinical-rules/  Versioned Clinical Rules Table (JSON), shared by app and API
├── db/              PostgreSQL migrations and synthetic seed scripts
├── docs/            Scope, roadmap, OpenAPI contract; later the ERD and test reports
└── .github/         CI workflow, issue and pull request templates, labels
```

## Documentation

- [Scope](docs/scope.md): the updated final scope with modules M1–M10, features (FE-n) and limitations LI-1 to LI-12.
- [Implementation roadmap](docs/roadmap.md) (10 Oct 2026): phases, tasks, architecture rules, data model and definition of done. The original is [roadmap.pdf](docs/roadmap.pdf).
- [Clinical Rules Table](clinical-rules/README.md): every clinical rule, pending clinical review, and how the Clinical Advisor signs it (P0-11).
- [Schema v1](docs/schema-v1.md): the database, how sync works in it, and the decisions to review.
- [API contract](docs/openapi.yaml): OpenAPI 3.1.
- [Phase 1 screens](docs/design/phase1-screens.md): the final screen design (Clinical Teal) and screen spec (P0-7).
- [IEC application draft](docs/iec/README.md): the ethics application for the usability evaluation with LHWs (P0-9), ready to copy into the committee's form.
- [Decision records](docs/decisions/README.md): the earlier roadmap's open items (model inputs, OTP channel, Urdu PDF method, Urdu voice, language switch, encryption library), with evidence and how the updated scope settled each.
- [CLAUDE.md](CLAUDE.md): permanent project rules for contributors and AI coding sessions.

## Getting started (Windows)

> **Quickest way to run and test everything:** [docs/local-setup.md](docs/local-setup.md). It uses ready-made VS Code tasks (first-time setup, start API + portal, run all tests) and a launch configuration for the phone. The test APK installs on any Android phone, and [docs/staging.md](docs/staging.md) puts the API and portal online (Render + Neon).

Both team members develop on Windows. Install:

| Tool | Version | Used by |
|---|---|---|
| Git for Windows | latest | everything |
| VS Code + EditorConfig extension | latest | everything |
| Node.js | 24 LTS | `api/`, `web/`, `db/`, `clinical-rules/` |
| PostgreSQL | 15 | `db/`, `api/` |
| Python | 3.11 | `ml/` |
| Flutter SDK (stable) + Android Studio / Android SDK | 3.47 or newer | `mobile/` |

Clone the repository and work from `dev`:

```powershell
git clone https://github.com/ZainAbbas-dev/MediQore.git
cd MediQore
git checkout dev
```

Each part reads its settings from a local `.env` file that you create from the committed example, for example `Copy-Item api\.env.example api\.env`. The `.env` files are git-ignored; never commit them.

### How to run each part

Each part's `CLAUDE.md` lists its full set of commands.

- **Database (`db/`):** needs a local PostgreSQL 15 database.
  ```powershell
  cd db; npm install; Copy-Item .env.example .env   # set DATABASE_URL
  npm run migrate:up                                  # create or upgrade the schema
  npm run rules:load                                  # load the Clinical Rules Table (P0-11)
  npm test                                            # schema, generator and rules-loader checks
  npm run seed:synthetic                              # synthetic districts, LHWs, households, pregnancies and visits
  ```
  - Schema overview and design decisions: [docs/schema-v1.md](docs/schema-v1.md).
  - The generator signs in as `syn.admin`, `syn.sup.01` or `syn.lhw.001` (password `demo-password`); `npm run seed:synthetic -- --help` lists the options.
- **API (`api/`):**
  ```powershell
  cd api; npm install; Copy-Item .env.example .env
  npm run dev                                         # http://localhost:3000/api/v1/health
  npm test
  ```
  API contract: [docs/openapi.yaml](docs/openapi.yaml).
- **Mobile app (`mobile/`):** connect an Android phone with USB debugging, or start an emulator.
  ```powershell
  cd mobile; flutter pub get
  flutter run
  flutter test
  ```
  To sync with the API on your laptop from a real phone, add `--dart-define=API_BASE_URL=http://<laptop-ip>:3000/api/v1`.
- **Portal (`web/`):** start the API first.
  ```powershell
  cd web; npm install
  npm run dev                                         # http://localhost:5173, forwards /api to the API
  npm test
  ```
- **ML (`ml/`):** Python 3.11.
  ```powershell
  cd ml; py -3.11 -m venv .venv; .venv\Scripts\Activate.ps1
  pip install -r requirements-dev.txt
  python scripts/download_uci.py                      # UCI dataset into ml/data/raw/ (git-ignored)
  pytest
  ```
  Findings so far: [notebooks/01_uci_exploration.ipynb](ml/notebooks/01_uci_exploration.ipynb).

### Phase 0 end-to-end check

The Phase 0 exit gate says: "One test record created on the phone offline, synced, stored in PostgreSQL and visible on the React portal."

1. **Database:**
   ```powershell
   cd db; npm run migrate:up; npm run seed:demo
   ```
   This creates `lhw.demo`, `supervisor.demo` and `admin.demo` with the password `demo-password`.
2. **API:**
   ```powershell
   cd api; npm run dev
   ```
3. **Phone:**
   - Connect the phone to the same Wi-Fi as the laptop, then run:
     ```powershell
     cd mobile; flutter run --dart-define=API_BASE_URL=http://<laptop-ip>:3000/api/v1
     ```
   - Activate the phone as `lhw.demo`: in the portal (step 4), sign in as `admin.demo`, open **LHW accounts**, click **New activation code** for `LHW-DEMO-001`, type it in the app with the password, then create a six-digit PIN.
   - Open **سیٹنگز** (Settings, the gear icon at the top of the home screen), then **فیز 0 کی جانچ** (Phase 0 checks, shown in debug builds and the test APK) and **ڈیٹا سنک کی جانچ** (Sync test).
   - Turn on airplane mode and tap **ٹیسٹ گھرانہ بنائیں** (create test household).
   - Turn airplane mode off and tap **ابھی سنک کریں** (sync now).
4. **Portal:**
   ```powershell
   cd web; npm run dev
   ```
   Open http://localhost:5173 and sign in as `supervisor.demo`. The household appears in the count, on the map and in the table.

Without a phone, `flutter test test/e2e/sync_e2e_test.dart --dart-define=E2E_API_BASE_URL=http://localhost:3000/api/v1` runs the same app code against the API, including activation (it issues the code as `admin.demo`) and a PIN-reset reply code from `supervisor.demo`.

[docs/local-setup.md](docs/local-setup.md) step 7 also walks through the Module 1 and 2 checks on the phone: activation, offline PIN unlock, the wrong-PIN wait, PIN reset, the emergency call, auto-lock, deactivation, and registering a woman in airplane mode.

## Branches and pull requests

| Branch | Purpose |
|---|---|
| `main` | Always demo-ready and protected. Updated only by merging `dev` after review (by Muhammad Zain Abbas). |
| `dev` | Integration branch; all work lands here first. |
| `feature/m<module>-fe<n>-<slug>` | One branch per scope feature, e.g. `feature/m3-fe1-visit-form`, branched from `dev` and merged back into `dev` by pull request. |

- Every pull request title starts with its scope ID (for example `M3 FE-2: ...`).
- Every pull request is reviewed by the other team member and must pass CI.
- CI runs lint and tests for each part that exists.
- Use the [feature issue template](.github/ISSUE_TEMPLATE/feature.yml) for new work.

### Protecting `main` (P0-1, repository owner only)

Branch protection is a GitHub setting, not a file, so the repository owner turns it on once: **Settings → Branches → Add branch ruleset** (or **Add classic branch protection rule**) for `main`:

1. **Require a pull request before merging**, with **1 approval** (the other team member).
2. **Require status checks to pass**, and pick the CI jobs: `web (Node.js 24)`, `api (Node.js 24 + PostgreSQL 15)`, `db (PostgreSQL 15 migrations)`, `clinical-rules (Node.js 24)`, `ml (Python 3.11)` and `mobile (Flutter stable)`. GitHub lists them after they have run once.
3. **Block force pushes** and **restrict deletions**.
4. Save. `dev` can stay unprotected so work can land, but every merge into `main` then goes through review and green CI.

## Team

- **Muhammad Zain Abbas** ([@ZainAbbas-dev](https://github.com/ZainAbbas-dev))
- **Zain Ali**
- **Supervisor:** Ma'am Sajida Kalsoom
