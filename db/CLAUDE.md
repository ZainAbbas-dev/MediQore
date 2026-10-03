# db/: PostgreSQL migrations and seed scripts

PostgreSQL 15 schema for all ten modules (roadmap P0-4), managed with node-pg-migrate. The synthetic data seed script (P0-8) will also live here. Follow the root `CLAUDE.md` first; this file only adds what is specific to `db/`.

## Stack

| Tool | Version | Purpose |
|---|---|---|
| PostgreSQL | 15.x (scope Tools table) | Central relational database |
| node-pg-migrate | 9.x | Migration tool chosen in P0-4 (the roadmap allows Knex or node-pg-migrate) |
| pg | 8.x | PostgreSQL client for migrations and tests |
| node:test | built into Node.js 20 | Schema tests |

## Layout

- `migrations/`: plain SQL migrations, one file per table group of the roadmap's data model. Each file has an `-- Up Migration` section and an `-- Down Migration` section.
- `tests/schema.test.js`: checks the schema against the rules below. It runs against `DATABASE_URL` after the migrations, and every test rolls back its data.
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
- Store vitals in the unit named by the column (`_mmhg`, `_kg`, `_c`, `_mmol_l`, `_mm`, `_cm`, `_bpm`).
- `audit_log` is append-only. Rows elsewhere are soft-deleted with `deleted_at`. `TRUNCATE` is the only way to empty a table, for example in a local seed reset.

## Commands

Run from `db/` with a local PostgreSQL 15 and `db/.env` (copy it from `.env.example`):

```powershell
npm install
Copy-Item .env.example .env          # then set DATABASE_URL
npm run migrate:up                   # apply all pending migrations
npm run migrate:down                 # roll back the latest migration
npm run migrate:create -- add-thing  # new SQL migration in migrations/
npm test                             # schema tests (needs the migrations applied)
```
