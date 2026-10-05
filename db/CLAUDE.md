# db/: PostgreSQL migrations and seed scripts

PostgreSQL 15 schema for all ten modules (roadmap P0-4), managed with node-pg-migrate, and the synthetic data generator (P0-8). Follow the root `CLAUDE.md` first; this file only adds what is specific to `db/`.

## Stack

| Tool | Version | Purpose |
|---|---|---|
| PostgreSQL | 15.x (scope Tools table) | Central relational database |
| node-pg-migrate | 9.x | Migration tool chosen in P0-4 (the roadmap allows Knex or node-pg-migrate) |
| pg | 8.x | PostgreSQL client for migrations and tests |
| node:test | built into Node.js 20 | Schema and generator tests |

## Layout

- `migrations/`: plain SQL migrations, one file per table group of the roadmap's data model. Each file has an `-- Up Migration` section and an `-- Down Migration` section.
- `tests/`: run against `DATABASE_URL` after the migrations, and every test rolls back its data.
  - `schema.test.js`: checks the schema against the rules below.
  - `synthetic.test.js`: checks the generator (same seed gives the same data, area and date consistency, units and ranges, held conflicts, hospitals) and loads it into the schema.
- `seeds/demo.js` (`npm run seed:demo`): minimal synthetic accounts for local end-to-end testing.
  - It creates one area, `admin.demo`, `supervisor.demo` (assigned to the area) and `lhw.demo` (in the area).
  - The password is `demo-password` unless you set `DEMO_PASSWORD`. It is for local development only.
  - Safe to re-run.
- `seeds/synthetic/` (`npm run seed:synthetic`): the synthetic data generator (P0-8, LI-10).
  - It builds districts, tehsils, Union Councils and areas; an admin, one supervisor per tehsil and one LHW per area; households with GPS; pregnant women with obstetric history; and home visits with vitals and symptoms.
  - Defaults: 2 districts, 16 areas and LHWs, 400 households, about 160 pregnancies and 460 visits. `--help` lists the options.
  - Every name and username carries a prefix (`syn` by default), for example `syn.sup.01` and `syn.lhw.001`. Contact numbers start with `0000-`, so none is a real number.
  - The same `--seed` always gives the same rows (seeded random numbers and UUIDs).
  - The password is `demo-password` unless you set `SYNTHETIC_PASSWORD`.
  - Safety: it refuses a `DATABASE_URL` that is not on this computer unless you add `--allow-remote` (for example for the staging server). It also refuses to load the same prefix twice. `--reset` empties every table first (local only); run `npm run seed:demo` again afterwards if you need the demo accounts.
  - Layout:
    - `generate.js`: `buildSynthetic()` makes the rows in memory, and `generateSynthetic(client)` inserts them.
    - `steps/`: one file per data group (`geography`, `accounts`, `households`, `maternal`).
    - `names.js`: the made-up names and the district centres.
    - `random.js`: the seeded random numbers.
  - **Each module adds its own step** (definition of done: "synthetic data for the module added to the seed script"). Add a file in `steps/`, call it from `buildSynthetic()` and add its tables to the insert list in parent-before-child order.
- `docs/schema-v1.md`: overview of schema v1 and the design decisions to review.

## Key rules

- **Never edit a migration that has been merged.** Add a new one with `npm run migrate:create -- <name>`.
- Every down section must undo its up section exactly. CI runs all migrations up, then down, then up again.
- A synced table (anything a device pushes or pulls) has:
  - the base columns `id`, `server_seq`, `area_id`, `created_by`, `created_on_device`, `synced_at`, `deleted_at`;
  - the `assign_server_seq` and `prevent_hard_delete` triggers;
  - a unique index on `server_seq` and an index on `(area_id, server_seq)`.
  
  Add the new table to `SYNCED_TABLES` in `tests/schema.test.js`.
- `server_seq` and `synced_at` come only from the trigger. Whatever a device sends is overwritten.
- The trigger also takes a transaction-level advisory lock, so concurrent writers to synced tables are numbered in commit order. Without it, a pull could skip a row that commits late. Keep transactions that write synced rows short.
- Store vitals in the unit named by the column (`_mmhg`, `_kg`, `_c`, `_mmol_l`, `_mm`, `_cm`, `_bpm`).
- `audit_log` is append-only. Rows elsewhere are soft-deleted with `deleted_at`. `TRUNCATE` is the only way to empty a table, for example in a local seed reset.

## Commands

Run from `db/` with a local PostgreSQL 15 and `db/.env` (copy it from `.env.example`):

```powershell
npm install
Copy-Item .env.example .env          # then set DATABASE_URL
npm run migrate:up                   # apply all pending migrations
npm run migrate:down                 # roll back the latest migration
npm run migrate:test                 # apply the migrations to TEST_DATABASE_URL (the API's test database)
npm run migrate:create -- add-thing  # new SQL migration in migrations/
npm test                             # schema and generator tests (needs the migrations applied)
npm run seed:demo                    # demo accounts for local end-to-end testing
npm run seed:synthetic               # full synthetic data set (P0-8); add -- --help for options
```
