# api/: REST API

Node.js + Express REST API: auth, sync endpoints, conflict detection, alerts, reports and audit log. Follow the root `CLAUDE.md` first; this file only adds what is specific to `api/`.

## Stack (scope Tools table)

| Tool | Version | Purpose |
|---|---|---|
| Node.js + Express.js | 20.x | REST API server for mobile and web communication |
| jsonwebtoken | Latest | JWT access and refresh token generation and verification for all API endpoints |
| Joi | Latest | Request body validation and sanitisation before any database operation |
| TLS via HTTPS | N/A | All client-server traffic encrypted; plain HTTP rejected at server level |
| PostgreSQL | 15.x | Central relational database (migrations live in `db/`) |
| pdfkit + ExcelJS | Latest | Automated PDF and Excel report generation |

From the roadmap:

- Tests use Jest + Supertest.
- Migrations use node-pg-migrate, chosen in P0-4, and live in `db/` (see `db/CLAUDE.md` and `docs/schema-v1.md`). The API never changes the schema itself.
- Urdu PDF rendering is tested in P0-11; if pdfkit breaks Nastaliq, the fallback is HTML printed to PDF with headless Chrome (Puppeteer).

## Key rules

- All routes live under `/api/v1`. Validate every request body with Joi, run role-check middleware on every route, and scope every query by area.
- Parameterised SQL only. Hash passwords with bcrypt.
- Assign `server_seq` on accept and never trust device clocks. Soft deletes only. Write an audit row for every create, edit, delete, referral, alert and login.

## Layout

- `src/app.js` builds the Express app. `src/server.js` starts it and exits if `DATABASE_URL` or `JWT_ACCESS_SECRET` is missing.
- Each request flows route → controller → service:
  - `src/routes/<name>.routes.js` holds the paths, auth, role checks and the `validate(...)` call. Mount it in `src/routes/index.js`.
  - `src/controllers/` reads `req` and writes `res`. Keep controllers thin.
  - `src/services/` holds the business logic and database calls.
- `src/db/pool.js`: `query(text, params)` and `withTransaction(fn)`. Every query is parameterised. Table and column names come only from code, never from input.
- `src/middleware/`:
  - `auth.js`: `authenticate` checks the JWT access token and that the account still exists, then sets `req.user = { id, role, fullName, deviceId }`. A deactivated account gets 403 `ACCOUNT_INACTIVE`. Use `requireRole(...)` after it.
  - `require-https.js`: refuses plain HTTP with 403 `HTTPS_REQUIRED` when `REQUIRE_HTTPS` is on (default in production). Set `TRUST_PROXY` behind a TLS proxy.
  - `validate.js`: Joi middleware. It replaces `req.body`, `req.query` and `req.params` with the validated values, or answers 400 `VALIDATION_ERROR`.
  - `error-handler.js`: 404 and the central error handler. Throw `AppError(status, code, message, details)` from `src/utils/app-error.js` for expected errors; anything else becomes a generic 500.
  - `request-logger.js`: one JSON log line per request, path only (no query string or body).
- `src/services/`:
  - `scope.service.js`: area scoping, `lhwAreaId` and `supervisorAreaIds`. Use it in every query that returns records.
  - `audit.service.js`: `writeAudit(client, ...)`. Call it inside the same transaction as the change.
  - Sign-in (M1 FE-2):
    - `auth.service.js`: login, one-time code check, refresh and sign-out. The rules:
      - LHWs sign in only from the app, with its installation ID.
      - A new phone gets 202 `otp_required` until its code is verified.
      - Supervisors and admins sign in on the portal without a device.
    - `tokens.service.js`: JWT access tokens (claim `did` = the approved phone) and opaque refresh tokens. Refresh tokens are stored as SHA-256 hashes, rotated on every use, and revoked on sign-out, deactivation and password reset.
    - `otp.service.js`: the swappable one-time-code service (decision 0002). Only the `admin_issued` channel exists. Codes are 6 digits, bcrypt-hashed, valid 24 hours and void after 5 wrong tries. Never log a code.
    - `login-throttle.js`: in-memory rate limit on failed sign-ins per address and username (429 `TOO_MANY_ATTEMPTS` with `Retry-After`). It holds one process's memory, so tests call `loginThrottle.reset()`.
  - `devices.service.js`: pending phones and issuing their codes. Admins see all; supervisors see LHWs in their areas.
  - `lhws.service.js` (M1 FE-1, FE-3): LHW accounts.
    - The LHW ID comes from the `lhw_code_seq` sequence (`LHW-00001`) and is also the username.
    - Passwords are random, shown once and stored as bcrypt.
    - It also handles reassignment, deactivation and password reset, with an audit row for each change.
- Sync accepts only a phone approved by code, and only the phone named in the token (`DEVICE_NOT_ALLOWED`).
- `src/sync/tables.js`: the tables devices may push and pull, with their fields. Add a table here when its module is built. `services/sync.service.js` implements `/sync/push` and `/sync/pull`.
- Error shape: `{ "error": { "code", "message", "details"? } }`.
- `docs/openapi.yaml` is the API contract. Update it in the same pull request as any route change.
- `tests/`: Jest + Supertest.
  - Import `createApp()`; never start a real server in tests.
  - Database tests use `describeDb` from `tests/db.js`. They run only when `TEST_DATABASE_URL` points at a migrated database whose name ends in `_test`, and they empty it first.
  - `createFixtures()` gives each fixture LHW an approved phone (`deviceA`, `deviceB`). `tokenFor(userId, role, deviceId)` signs a token, and app tokens carry the phone.

## Commands

Run from `api/`:

```powershell
npm install                     # first time (CI uses npm ci with package-lock.json)
Copy-Item .env.example .env     # then set DATABASE_URL, TEST_DATABASE_URL, JWT_ACCESS_SECRET
npm run dev                     # start with auto-reload at http://localhost:3000/api/v1
npm start                       # start without reload
npm run lint                    # ESLint
npm test                        # Jest + Supertest; database tests need TEST_DATABASE_URL
```

One-time test database setup (PowerShell):

```powershell
psql -U postgres -c "CREATE DATABASE mediqore_test OWNER mediqore;"
cd ..\db; npm run migrate:test    # migrates TEST_DATABASE_URL from db/.env
```

Demo accounts for local testing: `cd ..\db; npm run seed:demo` creates `admin.demo`, `supervisor.demo` and `lhw.demo` (see `db/CLAUDE.md`). The first time `lhw.demo` signs in on a phone, approve the phone on the portal (**Device approvals**, issue a code) and type the code in the app.
