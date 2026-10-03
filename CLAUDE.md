# MediQore: rules for every session

## Project

MediQore is the final-year project (BS Computer Science, COMSATS University Islamabad) of Muhammad Zain Abbas and Zain Ali: an offline-first digital health platform for Pakistan's Lady Health Workers (LHWs). LHWs use an Urdu Android app that works fully offline to register pregnant women, record home visits, get an on-device AI maternal risk result with an Urdu explanation, raise emergency alerts by internet, SMS or call, and run polio, EPI immunisation and child nutrition work (Modules 1–9). The app syncs to a central server whenever it has a connection, and supervisors and admins use a web portal for the dashboard, map, alerts, reports and administration (Module 10). The phone owns the field workflow and never needs the server to do its job; the server only collects, analyses and reports.

Five components, one monorepo:

| Folder | Component | Stack |
|---|---|---|
| `mobile/` | LHW Android app (LHW role + supervisor alert role) | Flutter 3.x |
| `api/` | REST API | Node.js 20 + Express |
| `db/` | PostgreSQL migrations and synthetic seed scripts | PostgreSQL 15 |
| `web/` | Supervisor and admin portal | React 18 + Leaflet.js |
| `ml/` | Model training, SHAP lookup, ONNX export, Module 6 analytics worker | Python 3.11 |

`docs/` holds the scope, roadmap and, later, the OpenAPI contract, ERD and test reports. Each part has its own `CLAUDE.md` with its stack and versions.

## Source of truth

- `docs/scope.md`: the approved scope. It defines the module and feature IDs (M1–M10, FE-n), objectives BO-1 to BO-6, limitations LI-1 to LI-12 and the Tools table. It is a Markdown copy of the Word document.
- `docs/roadmap.md`: the implementation plan (phases 0–4, task IDs such as P0-3, architecture, data model, risks, definition of done). It is a Markdown copy of `docs/roadmap.pdf`.
- Build only what these two documents describe. Do not add features, tables, endpoints or libraries they do not call for. If something is ambiguous or the documents disagree, ask instead of guessing.
- Respect the limitations, for example: Android only (LI-1); the prototype sends SMS and places calls from the LHW's phone, with no server SMS gateway (LI-4); AI output is decision support only, and the app says so (LI-5).

## Architecture and conventions

These rules come from the roadmap's "Architecture and conventions" table. Changing them after Phase 1 means rewriting synced data.

- **Record IDs:** every record made on the device gets a UUID v4 generated on the device; the server adds a sequence number (`server_seq`) when it accepts the record. Never order or resolve records by device clock (LI-7).
- **Deletes and audit:** soft deletes only (`deleted_at`), never hard deletes. Every create, edit, delete, referral, alert and login writes an audit row with user and timestamp (M10 FE-3).
- **API:** REST under `/api/v1`, JSON, Joi validation on every request body, JWT access token plus refresh token, HTTPS only (M1 FE-2).
- **Units:** store exactly one unit per vital: BP in mmHg, temperature in °C, blood sugar in mmol/L, weight in kg, MUAC in mm. Convert only at the model input or display layer.
- **Clinical rules:** danger-sign thresholds, EPI schedule, MUAC cut-offs and IMCI rules live in versioned JSON config files, never hard-coded, so clinical advisors can review them (M4 FE-4).
- **Urdu text:** no visible string in Dart code. Every label goes into the Flutter ARB localisation files, with an Urdu and an English entry. Text is rendered in Jameel Noori Nastaleeq inside RTL `Directionality`; numeric values such as vitals stay left to right.
- **Environments:** local PostgreSQL for development; one HTTPS staging server for supervisor reviews and demos.
- **Data model:** the same tables exist in PostgreSQL and, for field data, in the device's Drift database. Every synced table carries the base columns `id` (UUID), `server_seq`, `area_id`, `created_by`, `created_on_device`, `synced_at` and `deleted_at`. Store the model version on every risk assessment (LI-2).

Cross-cutting rules from the roadmap, which every module follows instead of inventing its own:

- **Offline sync:** every device write goes to its local table and to an outbox in the same transaction. Push sends outbox rows in batches of about 100; the server replies with the sequence number it assigned to each UUID. Pull uses the last sequence number the device has seen. Emergency alert records go first in the push order (M5 FE-4). Report images upload after the data rows. Resending the same UUID is harmless; a different record for the same woman on the same day goes to the supervisor conflict queue (M3 FE-2).
- **Security and access:** bcrypt password hashes; short-lived access token and longer refresh token, both revocable on deactivation; role-check middleware on every route (LHW, supervisor, admin); area scoping in every query; parameterised SQL only, with Joi validation before any database call; local database AES-256 encrypted, report images stored encrypted, nothing patient-related in plain shared storage.
- **Urdu screens:** test every screen on a small phone, because Nastaliq text is taller than Latin text and overflows easily.
- **Testing tools:** flutter_test (unit and widget), Jest + Supertest (API), pytest (ML, including the model recall threshold and ONNX parity).

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

## Definition of done

From the roadmap: a module counts as finished only when every item below is true.

- [ ] Every FE in the scope document for that module works on a real Android phone
- [ ] Works fully offline where the scope says so, and syncs correctly afterwards
- [ ] All screens in Urdu with no text overflow; numeric values display left to right
- [ ] API routes validated with Joi, role-checked and area-scoped
- [ ] Every create, edit and delete writes an audit row
- [ ] Unit and API tests written and passing in CI
- [ ] Module 10 shows the module's data (dashboard, map or report, as the scope says)
- [ ] Synthetic data for the module added to the seed script
- [ ] Reviewed and merged by the other team member
- [ ] Short note added to the user guide and test report

Each FE is done only when its tests pass in CI and it works on a real phone in airplane mode.

## Commands

Run each from its folder; the part's own `CLAUDE.md` has details. Parts not listed are not built yet.

| Part | Install | Run | Lint | Test |
|---|---|---|---|---|
| `api/` | `npm install` | `npm run dev` | `npm run lint` | `npm test` |
| `db/` | `npm install` | `npm run migrate:up` / `npm run migrate:down` | — | `npm test` (after `migrate:up`) |
| `mobile/` | `flutter pub get` | `flutter run` | `flutter analyze` | `flutter test` |

<!-- Add web/ (P0-5) and ml/ (P0-10) rows when they are built. -->
