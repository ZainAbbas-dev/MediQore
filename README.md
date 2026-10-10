# MediQore

**An AI-assisted, offline-ready digital health platform for Lady Health Workers (LHWs) in Pakistan.**

Final-year project, BS Computer Science, COMSATS University Islamabad (2023–2027).

MediQore replaces the LHW's paper registers with an Android app, in Urdu by default with an English option, that works fully offline. LHWs can:

- register pregnant women and record home visits;
- get an on-device AI maternal risk result (Green / Yellow / Red) with an Urdu explanation;
- raise emergency alerts by internet, SMS or call;
- cover polio campaigns, EPI child immunisation and child nutrition screening.

The app syncs with a central server whenever a connection is available. Supervisors and admins use a web portal for a live dashboard and map, alerts, PDF/Excel reports and administration.

> **Status:** Phase 0 (Foundation) is built; Phase 1 has Modules 1 and 2 built (below). Phase 0 work:
> - the Flutter app shell with its Urdu widget kit and font (P0-2);
> - the API skeleton (P0-3);
> - database schema v1 (P0-4);
> - the portal skeleton (P0-5);
> - the offline sync skeleton (P0-6);
> - the Phase 1 screen spec and wireframes (P0-7);
> - the synthetic data generator (P0-8);
> - the start of the ML track: UCI dataset download and exploratory notebook (P0-10);
> - proposed decisions with evidence for the P0-11 open items, including an Urdu PDF test and a voice check screen in the app;
> - the IEC application draft (P0-9), ready for the team to submit;
> - an Urdu/English language switch in the app (scope amendment A1, M1 FE-4), with voice guidance only in Urdu.
>
> One test record now runs end to end: created on the phone, synced, stored in PostgreSQL and shown on the portal.
>
> **Phase 1, Module 1 (user management and authentication), built on `dev` and waiting for review and real-phone testing:**
> - admins create LHW accounts on the portal (system-issued LHW ID and password), edit, reassign, deactivate and reset passwords with a "sync before reset" warning (FE-1, FE-3); records a phone made before a reassignment keep their old area when they sync;
> - the app's first sign-in on a phone needs a one-time code issued on the portal's **Phone approvals** page (FE-2, proposed decision 0002), then downloads the LHW's area;
> - later sign-ins work offline with a PBKDF2 password key (LI-8); the app locks after 5 minutes without use;
> - short-lived access tokens with rotating refresh tokens, login rate limiting, HTTPS enforcement outside development; a deactivated account is refused at its next sync (FE-2, FE-3);
> - the language switch on the sign-in screen (FE-4).
>
> **Phase 1, Module 2 (expecting woman registration), built on `dev` and waiting for review and real-phone testing:**
> - the app registers a pregnant woman without the internet: name, age, husband, contact, pregnancy month, village, address and obstetric history on one form, saved in one step (FE-1, FE-2);
> - each woman gets a patient ID that is unique offline, the LHW code plus the phone's counter (for example `LHW-00001-0007`), and a pregnancy file;
> - the home's GPS position with the geolocator package, or later from her file; a second woman can share a registered woman's home (FE-3);
> - the patient list searches by name, ID or village and is grouped by village (FE-3);
> - the portal's **Registered women** page and a dashboard count show what the phones have synced.
>
> **Phase 1, Module 3 (field visit and vitals), built on `dev` and waiting for review and real-phone testing:**
> - the visit form from the woman's file, offline: BP, weight, temperature, pulse, optional blood sugar, fetal movement, swelling, bleeding, fever, anaemia signs and urine symptoms (FE-1);
> - impossible values are refused, and values outside the usual range (for example systolic BP outside 60–250) are saved only after the LHW confirms them; the ranges are in a versioned config file for clinical advisor review;
> - the phone's database is encrypted with AES-256 and opens only with the LHW's password (FE-2, proposed decision 0006);
> - records sync on their own while the app is open and online; a second visit to the same pregnancy on the same day is held for the supervisor instead of being stored, and the portal's **Sync conflicts** page decides (FE-2, LI-7);
> - in Urdu, each field's label is read aloud when it gets focus, with a mute switch; off in English (FE-3);
> - the dashboard shows visits this week and the conflicts waiting for review.
>
> **Phase 1, Module 10 base (supervisor portal and admin panel), built on `dev` and waiting for review:**
> - dashboard: registered women, visits this week, conflicts to review and households; each LHW's visits, registrations, last sync and last sign-in; the household map filtered by district, Union Council, LHW and period, refreshing every 5 minutes (FE-1);
> - admin panel: the district, tehsil, Union Council and area structure; LHW, supervisor and admin accounts; hospitals and referral centres; the roles and what each may do (FE-3);
> - audit log viewer: every create, edit, delete, sign-in and sync conflict with who and when, filtered by user, action, record and date (FE-3);
> - supervisors see only their areas everywhere; administration is for admins only.
>
> **Data notice:** MediQore is developed and demonstrated on synthetic data only. No real patient data is used before IEC approval (LI-10). AI results are decision support, not a clinical diagnosis (LI-5).

## Components

| Part | Folder | Stack | Status |
|---|---|---|---|
| LHW Android app (Modules 1–9) | [`mobile/`](mobile/) | Flutter 3.x, Drift + SQLCipher, ONNX Runtime | Urdu shell and widget kit (P0-2); local database, outbox and sync (P0-6); sign-in, phone approval, offline sign-in and auto-lock (M1); registration, patient list and pregnancy file (M2); encrypted database, visit form, automatic sync and voice guidance (M3) |
| REST API | [`api/`](api/) | Node.js 24 LTS + Express 5, JWT, Joi | Skeleton (P0-3); `/sync` push/pull (P0-6); login with phone approval, refresh tokens, LHW accounts, phone approvals (M1); registrations through `/sync` and `GET /women` (M2); visits through `/sync`, the same-day conflict queue and the dashboard summary (M3); role permissions, admin panel, audit log, LHW activity and map filters (M10 base) |
| Database | [`db/`](db/) | PostgreSQL 15 migrations and synthetic seed scripts | Schema v1 for all ten modules (P0-4); demo seed; synthetic data generator (P0-8); LHW ID numbering and the previous area after a reassignment (M1); held conflicts and hospitals in the synthetic data (M3, M10) |
| Supervisor and admin portal (Module 10) | [`web/`](web/) | React 18 + Leaflet.js | Login, auth guard, sidebar layout, map dashboard (P0-5); LHW accounts and phone approvals (M1); registered women (M2); sync conflict review queue, visits on the dashboard (M3); LHW activity, map filters and auto-refresh, admin panel and audit log (M10 base) |
| ML pipeline and analytics worker | [`ml/`](ml/) | Python 3.11, scikit-learn, SHAP, sklearn2onnx | Dataset download and exploratory notebook (P0-10); training in Phase 2 |

## Repository layout

```
mediqore/
├── mobile/   Flutter app (LHW role + supervisor alert role)
├── api/      Node.js + Express REST API
├── web/      React supervisor and admin portal
├── ml/       Python training, SHAP lookup, ONNX export, analytics worker
├── db/       PostgreSQL migrations and synthetic seed scripts
├── docs/     Scope, roadmap; later the OpenAPI contract, ERD and test reports
└── .github/  CI workflow, issue and pull request templates, labels
```

## Documentation

- [Scope](docs/scope.md): approved scope with modules M1–M10, features (FE-n) and limitations LI-1 to LI-12, plus the amendments approved since (for example A1, the language switch).
- [Implementation roadmap](docs/roadmap.md): phases, tasks, architecture rules and definition of done. The original is [roadmap.pdf](docs/roadmap.pdf).
- [Schema v1](docs/schema-v1.md): the database, how sync works in it, and the decisions to review.
- [API contract](docs/openapi.yaml): OpenAPI 3.1.
- [Phase 1 screens](docs/design/phase1-screens.md): screen spec and Figma-ready wireframes (P0-7).
- [IEC application draft](docs/iec/README.md): the ethics application for the usability evaluation with LHWs (P0-9), ready to copy into the committee's form.
- [Decision records](docs/decisions/README.md): the P0-11 open items (model inputs, OTP channel, Urdu PDF method, Urdu voice), with evidence; awaiting team sign-off.
- [CLAUDE.md](CLAUDE.md): permanent project rules for contributors and AI coding sessions.

## Getting started (Windows)

> **Quickest way to run and test everything:** [docs/local-setup.md](docs/local-setup.md). It uses ready-made VS Code tasks (first-time setup, start API + portal, run all tests) and a launch configuration for the phone. The test APK installs on any Android phone, and [docs/staging.md](docs/staging.md) puts the API and portal online (Render + Neon).

Both team members develop on Windows. Install:

| Tool | Version | Used by |
|---|---|---|
| Git for Windows | latest | everything |
| VS Code + EditorConfig extension | latest | everything |
| Node.js | 20 LTS | `api/`, `web/` |
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
   - Sign in as `lhw.demo`. The first sign-in on a phone asks for a one-time code (M1 FE-2, decision 0002): in the portal (step 4), sign in as `supervisor.demo`, open **Phone approvals**, click **Issue code** and type the code in the app.
   - On the home screen open **فیز 0 کی جانچ** (Phase 0 checks), then **ڈیٹا سنک کی جانچ** (Sync test).
   - Turn on airplane mode and tap **ٹیسٹ گھرانہ بنائیں** (create test household).
   - Turn airplane mode off and tap **ابھی سنک کریں** (sync now).
4. **Portal:**
   ```powershell
   cd web; npm run dev
   ```
   Open http://localhost:5173 and sign in as `supervisor.demo`. The household appears in the count, on the map and in the table.

Without a phone, `flutter test test/e2e/sync_e2e_test.dart --dart-define=E2E_API_BASE_URL=http://localhost:3000/api/v1` runs the same app code against the API, including the phone approval (it issues the code as `admin.demo`).

[docs/local-setup.md](docs/local-setup.md) step 7 also walks through the Module 1 and 2 checks on the phone: offline sign-in, auto-lock, deactivation, and registering a woman in airplane mode.

## Branches and pull requests

| Branch | Purpose |
|---|---|
| `main` | Always demo-ready and protected. Updated only by merging `dev` after review. |
| `dev` | Integration branch; all work lands here first. |
| `feature/m<module>-fe<n>-<slug>` | One branch per scope feature, e.g. `feature/m3-fe1-visit-form`, branched from `dev` and merged back into `dev` by pull request. |

- Every pull request title starts with its scope ID (for example `M3 FE-2: ...`).
- Every pull request is reviewed by the other team member and must pass CI.
- CI runs lint and tests for each part that exists.
- Use the [feature issue template](.github/ISSUE_TEMPLATE/feature.yml) for new work.

## Team

- **Muhammad Zain Abbas** ([@ZainAbbas-dev](https://github.com/ZainAbbas-dev))
- **Zain Ali**
- **Supervisor:** Ma'am Sajida Kalsoom
