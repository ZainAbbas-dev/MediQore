# MediQore

**An AI-assisted, offline-ready digital health platform for Lady Health Workers (LHWs) in Pakistan.**

Final-year project, BS Computer Science, COMSATS University Islamabad (2023–2027).

MediQore replaces the LHW's paper registers with an Urdu Android app that works fully offline. LHWs can:

- register pregnant women and record home visits;
- get an on-device AI maternal risk result (Green / Yellow / Red) with an Urdu explanation;
- raise emergency alerts by internet, SMS or call;
- cover polio campaigns, EPI child immunisation and child nutrition screening.

The app syncs with a central server whenever a connection is available. Supervisors and admins use a web portal for a live dashboard and map, alerts, PDF/Excel reports and administration.

> **Status:** Phase 0 (Foundation). The repository skeleton is in place; the application parts below are **coming soon**.
>
> **Data notice:** MediQore is developed and demonstrated on synthetic data only. No real patient data is used before IEC approval (LI-10). AI results are decision support, not a clinical diagnosis (LI-5).

## Components

| Part | Folder | Stack | Status |
|---|---|---|---|
| LHW Android app (Modules 1–9) | [`mobile/`](mobile/) | Flutter 3.x, Drift + SQLCipher, ONNX Runtime | Coming soon (P0-2) |
| REST API | [`api/`](api/) | Node.js 20 + Express, JWT, Joi | Coming soon (P0-3) |
| Database | [`db/`](db/) | PostgreSQL 15 migrations and synthetic seed scripts | Coming soon (P0-4, P0-8) |
| Supervisor and admin portal (Module 10) | [`web/`](web/) | React 18 + Leaflet.js | Coming soon (P0-5) |
| ML pipeline and analytics worker | [`ml/`](ml/) | Python 3.11, scikit-learn, SHAP, sklearn2onnx | Coming soon (P0-10) |

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

- [Scope](docs/scope.md): approved scope with modules M1–M10, features (FE-n) and limitations LI-1 to LI-12.
- [Implementation roadmap](docs/roadmap.md): phases, tasks, architecture rules and definition of done. The original is [roadmap.pdf](docs/roadmap.pdf).
- [CLAUDE.md](CLAUDE.md): permanent project rules for contributors and AI coding sessions.

## Getting started (Windows)

Both team members develop on Windows. Install:

| Tool | Version | Used by |
|---|---|---|
| Git for Windows | latest | everything |
| VS Code + EditorConfig extension | latest | everything |
| Node.js | 20 LTS | `api/`, `web/` |
| PostgreSQL | 15 | `db/`, `api/` |
| Python | 3.11 | `ml/` |
| Flutter SDK (stable, 3.x) + Android Studio / Android SDK | latest stable | `mobile/` |

Clone the repository and work from `dev`:

```powershell
git clone https://github.com/ZainAbbas-dev/MediQore.git
cd MediQore
git checkout dev
```

Each part reads its settings from a local `.env` file that you create from the committed example, for example `Copy-Item api\.env.example api\.env`. The `.env` files are git-ignored; never commit them.

### How each part will run

The exact commands will be added to each part's `CLAUDE.md` and to this README as the part is built.

- **API (`api/`):** coming soon. It will be a Node.js 20 server installed and started with npm from `api/`, serving `/api/v1`. It needs a local PostgreSQL 15 database and `api/.env`.
- **Database (`db/`):** coming soon. Migrations (Knex or node-pg-migrate, chosen in P0-4) will create the schema in your local PostgreSQL. The synthetic data generator (P0-8) will seed it.
- **Portal (`web/`):** coming soon. It will be a React 18 app started with npm from `web/`, pointing at the API through `web/.env`.
- **Mobile app (`mobile/`):** coming soon. It will be started with `flutter run` on an Android phone or emulator, with the API address passed via `--dart-define` (see `mobile/.env.example`).
- **ML (`ml/`):** coming soon. It will be a Python 3.11 virtual environment with `pip install -r requirements.txt`, notebooks and scripts that export the ONNX model and Urdu SHAP lookup for the app.

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
