# MediQore

**An AI-assisted, offline-ready digital health platform for Lady Health Workers (LHWs) in Pakistan.**

Final-year project, BS Computer Science, COMSATS University Islamabad (2023–2027).

MediQore replaces the LHW's paper registers with an Android app, in Urdu by default with an English option, that works fully offline. LHWs can:

- register pregnant women and record home visits;
- get an on-device AI maternal risk result (Green / Yellow / Red) with an Urdu explanation;
- raise emergency alerts by internet, SMS or call;
- cover polio campaigns, EPI child immunisation and child nutrition screening.

The app syncs with a central server whenever a connection is available. Supervisors and admins use a web portal for a live dashboard and map, alerts, PDF/Excel reports and administration.

> **Status:** Phase 0 (Foundation). Done so far:
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
> **Data notice:** MediQore is developed and demonstrated on synthetic data only. No real patient data is used before IEC approval (LI-10). AI results are decision support, not a clinical diagnosis (LI-5).

## Components

| Part | Folder | Stack | Status |
|---|---|---|---|
| LHW Android app (Modules 1–9) | [`mobile/`](mobile/) | Flutter 3.x, Drift + SQLCipher, ONNX Runtime | Urdu shell and widget kit (P0-2); local database, outbox and sync (P0-6) |
| REST API | [`api/`](api/) | Node.js 20 + Express, JWT, Joi | Skeleton (P0-3); login and `/sync` push/pull (P0-6) |
| Database | [`db/`](db/) | PostgreSQL 15 migrations and synthetic seed scripts | Schema v1 for all ten modules (P0-4); demo seed; synthetic data generator (P0-8) |
| Supervisor and admin portal (Module 10) | [`web/`](web/) | React 18 + Leaflet.js | Login, auth guard, sidebar layout, map dashboard (P0-5) |
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

> **Quickest way to run and test everything:** [docs/local-setup.md](docs/local-setup.md). It uses ready-made VS Code tasks (first-time setup, start API + portal, run all tests) and a launch configuration for the phone.

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
  npm test                                            # schema and generator checks
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
   - Open **ڈیٹا سنک کی جانچ** (Sync test).
   - Turn on airplane mode and tap **ٹیسٹ گھرانہ بنائیں** (create test household).
   - Turn airplane mode off, sign in as `lhw.demo` and tap **ابھی سنک کریں** (sync now).
4. **Portal:**
   ```powershell
   cd web; npm run dev
   ```
   Open http://localhost:5173 and sign in as `supervisor.demo`. The household appears in the count, on the map and in the table.

Without a phone, `flutter test test/e2e/sync_e2e_test.dart --dart-define=E2E_API_BASE_URL=http://localhost:3000/api/v1` runs the same app code against the API.

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
