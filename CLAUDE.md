# MediQore: rules for every session

## Project

MediQore is the final-year project (BS Computer Science, COMSATS University Islamabad) of Muhammad Zain Abbas and Zain Ali: an offline-first digital health platform for Pakistan's Lady Health Workers (LHWs). LHWs use an Android app, in Urdu by default with an English option, that works fully offline to register pregnant women, record home visits with a danger-sign checklist, get an on-device AI maternal risk result with an Urdu or English explanation, raise emergency alerts by internet, SMS or call, and run polio, EPI immunisation and child nutrition work (Modules 1–9). The app syncs to a central server whenever it has a connection, and supervisors and admins use a web portal for the dashboard, map, alerts, reports and administration (Module 10). The phone owns the field workflow and never needs the server to do its job; the server only collects, analyses and reports.

One monorepo:

| Folder | Component | Stack |
|---|---|---|
| `mobile/` | LHW Android app | Flutter 3.x |
| `api/` | REST API | Node.js 24 LTS + Express 5 |
| `db/` | PostgreSQL migrations and synthetic seed scripts | PostgreSQL 15 |
| `web/` | Supervisor and admin portal | React 18 + Leaflet.js |
| `ml/` | Model training (five- and six-feature models), SHAP lookup, ONNX export | Python 3.11 |
| `clinical-rules/` | The versioned Clinical Rules Table, read by the app and the API | JSON + Node.js 24 tests |

`docs/` holds the scope, roadmap and, later, the OpenAPI contract, ERD and test reports. Each part has its own `CLAUDE.md` with its stack and versions.

## Source of truth

- `docs/scope.md`: the approved scope, updated final version. It defines the module and feature IDs (M1–M10, FE-n), objectives BO-1 to BO-6, limitations LI-1 to LI-12 and the Tools table. It is a Markdown copy of `MediQore_FYP-1_Final_Scope_Fall_2026_Updated.docx`.
- `docs/roadmap.md`: the implementation plan of 10 Oct 2026 (phases 0–5 with dates, task IDs such as P0-3, architecture, data model, risks, definition of done). It is a Markdown copy of `docs/roadmap.pdf`.
- `clinical-rules/clinical-rules.json`: the Clinical Rules Table (P0-11). Every clinical rule comes from it.
- `docs/decisions/`: decision records for the earlier roadmap's open items; each says how the updated scope settled it.
  - An **Accepted** record binds like the roadmap.
  - A **Proposed** record is not decided yet: ask before building on it.
  - A **Superseded** or **Withdrawn** record is history only.
- The earlier scope amendment A1 (the language switch) is now part of the scope (M3 FE-3). Any new amendment is listed at the top of `docs/scope.md` and `docs/roadmap.md` ("Amendments after approval") and marked in the text, for example *(A2)*, until the Word document and `roadmap.pdf` are updated.
- Build only what the scope and roadmap describe. Do not add features, tables, endpoints or libraries they do not call for. If something is ambiguous or the documents disagree, ask instead of guessing.
- Respect the limitations, for example: Android only (LI-1); the prototype sends SMS and places calls from the LHW's phone, with no server SMS gateway (LI-4); AI output is decision support only, and the app says so (LI-5); Urdu and English only, with no audio guidance (LI-6); clinical rules stay "pending clinical review" and are used only on synthetic data until the Clinical Advisor signs the table (LI-10, LI-12).

## Architecture and conventions

These rules come from the roadmap's "Architecture and conventions" table. Changing them after Phase 1 means rewriting synced data.

- **Record IDs:** every record made on the device gets a UUID v4 generated on the device; the server adds a sequence number (`server_seq`) when it accepts the record. Never order or resolve records by device clock (LI-7).
- **Deletes and audit:** soft deletes only (`deleted_at`), never hard deletes. Every create, edit, delete, referral, alert and login writes an audit row with user and timestamp (M10 FE-3).
- **API and login:** REST under `/api/v1`, JSON, Joi validation on every request body, JWT access token plus refresh token, HTTPS only. The first login on a phone is online with username, password and a one-time admin activation code; after that the LHW unlocks offline with a six-digit PIN, never a JWT check (M1 FE-2).
- **Encryption keys:** the local database key is a random 256-bit key generated on the phone, stored wrapped by a non-exportable Android Keystore key (flutter_secure_storage) and unwrapped in memory only when the database opens; never derived from the password or PIN (M3 FE-2, LI-8).
- **Units:** store exactly one unit per value: BP in mmHg, pulse in bpm, temperature in °C, blood sugar in mmol/L, Hb in g/dL, weight in kg, MUAC in mm. Convert only at the model input or display layer.
- **Clinical rules:** every clinical rule (danger signs, BP and Hb levels, obstetric history flags, MUAC, IMCI, EPI timings, typing-error ranges) lives in the versioned Clinical Rules Table in `clinical-rules/`, never in code. Its defaults are marked "pending clinical review" until the Clinical Advisor signs it. Store the rules version on every result (M4 FE-4, LI-12).
- **Urdu and English text:** no visible string in Dart code. Every label goes into the Flutter ARB localisation files, with an Urdu and an English entry; Settings → Language switches the whole app at runtime and the choice is saved (M3 FE-3).
  - Urdu is the default and is rendered in Jameel Noori Nastaleeq inside RTL `Directionality`.
  - English is rendered left to right in the standard Latin font.
  - Numeric values such as vitals stay left to right in both.
  - The app has no audio guidance (LI-6): it relies on written labels, large icons, pictures and colour-coded results.
- **Environments:** local PostgreSQL for development; one HTTPS staging server for supervisor reviews and demos (needed for web push).
- **Data model:** the same tables exist in PostgreSQL and, for field data, in the device's Drift database. Every synced table carries the base columns `id` (UUID), `server_seq`, `area_id`, `created_by`, `created_on_device`, `synced_at` and `deleted_at`. Store the model version, input set and rules version on every risk result (LI-2, LI-12).

Cross-cutting rules from the roadmap, which every module follows instead of inventing its own:

- **Offline sync:** every device write goes to its local table and to an outbox in the same transaction. Push sends outbox rows in batches of about 100; the server replies with the sequence number it assigned to each UUID. Pull uses the last sequence number the device has seen. Emergency alert records go first in the push order (M5 FE-4). Report images upload after the data rows. Resending the same UUID is harmless; a different record for the same woman on the same day goes to the supervisor conflict queue (M3 FE-2).
- **Security and access:** bcrypt password hashes; one-time activation codes that are random, expire in 48 hours, work once and are stored hashed; an offline PIN checked against a slow hash with progressive delays (30 s, 1 min, 5 min, 15 min), reset offline with a supervisor reply code, and an emergency call button on the lock screen; short-lived access token and longer refresh token, both revocable on deactivation; role-check middleware on every route (LHW, supervisor, admin); area scoping in every query; parameterised SQL only, with Joi validation before any database call; local database AES-256 encrypted (SQLite3MultipleCiphers) with the Keystore-wrapped key, report images stored encrypted, nothing patient-related in plain shared storage or in the portal's browser storage.
- **Urdu and English screens:** test every screen in both languages on a small phone, because Nastaliq text is taller than Latin text and overflows easily, and the layout direction flips between them.
- **Design:** the final screen design is Clinical Teal (`docs/design/phase1-screens.md`); build screens from the app's theme and widget kit.
- **Testing tools:** flutter_test (unit and widget), Jest + Supertest (API), node:test (database and Clinical Rules Table), pytest (ML, including the model recall threshold for both input sets and ONNX parity). Every rule in the Clinical Rules Table has a unit test.

## Git workflow

- `main` is always demo-ready and protected. Never push to `main` and never merge into it. Only Muhammad Zain Abbas merges `dev` into `main`, after reviewing it.
- `dev` is the integration branch. All work lands on `dev`.
- Feature branches are named `feature/m<module>-fe<n>-<slug>`, for example `feature/m3-fe1-visit-form`. Create them from `dev` and merge them back into `dev` through a pull request reviewed by the other team member.
- GitHub Actions (`.github/workflows/ci.yml`) runs lint and tests for every pull request; keep it green.

## Scope IDs in code

Every feature references its scope ID:

- in the pull request title, for example `M3 FE-2: outbox and sync push`;
- in a comment at the feature's main entry point (the screen, route, service or job where it starts), for example `// M3 FE-2: offline sync push` in Dart or JavaScript, or `# M4 FE-1: model training` in Python.

## Secrets and data

- Never commit secrets: no `.env` files, keys, keystores, signing configs or Firebase service-account files. Each part commits only a `.env.example` with placeholder values. This repository is public.
- Never use real patient data. Use synthetic data only (LI-10): no real data until IEC approval, and real patient data never goes into this repository. Seeds, test fixtures, screenshots and demo scripts all use the synthetic data generator (P0-8).
- Nothing collected from usability-study participants goes into this repository either: no consent forms, names, notes, answers or recordings (`docs/iec/`).
- The UCI training dataset is public, but it stays out of git too: `ml/scripts/download_uci.py` fetches it into the git-ignored `ml/data/`.

## Definition of done

From the roadmap: a module counts as finished only when every item below is true.

- [ ] Every FE in the scope document for that module works on a real Android phone
- [ ] Works fully offline where the scope says so, and syncs correctly afterwards
- [ ] All screens in Urdu and English with no text overflow; numeric values display left to right
- [ ] Every clinical rule it uses is read from the Clinical Rules Table and has a unit test
- [ ] API routes validated with Joi, role-checked and area-scoped
- [ ] Every create, edit and delete writes an audit row
- [ ] Unit and API tests written and passing in CI
- [ ] Module 10 shows the module's data (dashboard, map or report, as the scope says)
- [ ] Synthetic data for the module added to the seed script
- [ ] Reviewed and merged by the other team member
- [ ] Short note added to the user guide and test report

Each FE is done only when its tests pass in CI and it works on a real phone in airplane mode.

## Commands

Run each from its folder; the part's own `CLAUDE.md` has details.

| Part | Install | Run | Lint | Test |
|---|---|---|---|---|
| `db/` | `npm install` | `npm run migrate:up` / `npm run migrate:down` / `npm run migrate:test`; `npm run rules:load`; `npm run seed:demo`; `npm run seed:synthetic` | — | `npm test` (after `migrate:up`) |
| `clinical-rules/` | — | — | — | `node --test` |
| `api/` | `npm install` | `npm run dev` | `npm run lint` | `npm test` (database tests need `TEST_DATABASE_URL`, a migrated `*_test` database) |
| `web/` | `npm install` | `npm run dev` (needs the API) | `npm run lint` | `npm test`; `npm run build` |
| `ml/` | `pip install -r requirements-dev.txt` (Python 3.11 venv) | `python scripts/download_uci.py`; notebooks in `notebooks/` | `ruff check .` | `pytest` |
| `mobile/` | `flutter pub get` | `flutter run --dart-define=API_BASE_URL=...` | `flutter analyze` | `flutter test`; `dart run build_runner build` after changing Drift tables |
