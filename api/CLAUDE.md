# api/: REST API

Node.js + Express REST API: auth and activation codes, sync endpoints, conflict detection, emergency alerts (web push, re-send at the time limit, alert status for the phone), reports and audit log. Follow the root `CLAUDE.md` first; this file only adds what is specific to `api/`.

## Stack (scope Tools table)

| Tool | Version | Purpose |
|---|---|---|
| Node.js | 24.x LTS | Server runtime for the REST API |
| Express.js | 5.x | REST API server for mobile and web communication |
| jsonwebtoken | Latest | JWT access and refresh token generation and verification for all API endpoints |
| Joi | Latest | Request body validation and sanitisation before any database operation |
| TLS via HTTPS | N/A | All client-server traffic encrypted; plain HTTP rejected at server level |
| PostgreSQL | 15.x | Central relational database (migrations live in `db/`) |
| Puppeteer (headless Chromium) + ExcelJS | Latest | Automated PDF and Excel report generation; PDFs are rendered from HTML with the bundled Jameel Noori Nastaleeq font |

From the roadmap:

- Tests use Jest + Supertest.
- Migrations use node-pg-migrate, chosen in P0-4, and live in `db/` (see `db/CLAUDE.md` and `docs/schema-v1.md`). The API never changes the schema itself.
- P0-12 checks a bilingual report page rendered to PDF with Puppeteer on the staging server. See `docs/decisions/0003-urdu-pdf-method.md`.

## Key rules

- All routes live under `/api/v1`. Validate every request body with Joi, check a permission on every route (`requirePermission`), and scope every query by area.
- Parameterised SQL only. Hash passwords with bcrypt.
- Assign `server_seq` on accept and never trust device clocks. Soft deletes only. Write an audit row for every create, edit, delete, referral, alert and login.

## Layout

- `src/app.js` builds the Express app. `src/server.js` starts it and exits if `DATABASE_URL` or `JWT_ACCESS_SECRET` is missing.
  - With `PORTAL_DIR` set (staging only, `render.yaml` and `docs/staging.md`), the app also serves the built portal: its files, and `index.html` for any other GET address outside `/api`. Unset in development.
- Each request flows route → controller → service:
  - `src/routes/<name>.routes.js` holds the paths, auth, role checks and the `validate(...)` call. Mount it in `src/routes/index.js`.
  - `src/controllers/` reads `req` and writes `res`. Keep controllers thin.
  - `src/services/` holds the business logic and database calls.
- `src/db/pool.js`: `query(text, params)` and `withTransaction(fn)`. Every query is parameterised. Table and column names come only from code, never from input. An idle connection closed by the server (for example a paused hosted database) is logged, not fatal.
- `src/middleware/`:
  - `auth.js`: `authenticate` checks the JWT access token and that the account still exists, then sets `req.user = { id, role, fullName, deviceId }`. A deactivated account gets 403 `ACCOUNT_INACTIVE`. Use `requirePermission('name')` after it.
  - `require-https.js`: refuses plain HTTP with 403 `HTTPS_REQUIRED` when `REQUIRE_HTTPS` is on (default in production). Set `TRUST_PROXY` behind a TLS proxy.
  - `validate.js`: Joi middleware. It replaces `req.body`, `req.query` and `req.params` with the validated values, or answers 400 `VALIDATION_ERROR`.
  - `error-handler.js`: 404 and the central error handler. Throw `AppError(status, code, message, details)` from `src/utils/app-error.js` for expected errors; anything else becomes a generic 500.
  - `request-logger.js`: one JSON log line per request, path only (no query string or body).
- `src/auth/permissions.js` (M10 FE-3): the three fixed roles and the default permissions of each (`sync`, `records.view`, `conflicts.resolve`, `pin_reset.reply`, `accounts.manage` (LHW accounts), `staff.manage` (supervisor and admin accounts), `geography.manage`, `facilities.manage`, `audit.view`, `roles.manage`); `editable(role, permission)` says which an admin may change: never an LHW's, never `sync`, and never `roles.manage`, `staff.manage` or `geography.manage`, which only admins hold. Routes check these names, never role lists. `services/role-permissions.service.js` keeps the admin's changes (`role_permissions`, `GET /admin/roles`, `PUT /admin/roles/permissions`, audited), `requirePermission` asks it (cached 10 s, cleared on a change), and portal sessions carry `user.permissions` so the portal shows only those pages. Administration permissions given to a supervisor work only on their own areas (`managedAreaIds` in `scope.service.js`): LHW accounts in their areas, hospitals and referral centres of their districts (and areas), and audit entries by them and their areas' LHWs; anything else is 404 or `OUT_OF_AREA` (`tests/admin-scope.test.js`).
- `src/services/`:
  - `scope.service.js`: area scoping, `lhwAreaId`, `lhwAreas` (current and previous area) and `supervisorAreaIds`. Use it in every query that returns records.
  - `audit.service.js`: `writeAudit(client, ...)`. Call it inside the same transaction as the change.
  - Sign-in (M1 FE-2):
    - `auth.service.js`: activation, login, refresh and sign-out. The rules:
      - LHWs sign in only from the app, with its installation ID. Supervisors and admins sign in on the portal without a device (`APP_FOR_LHWS` from the app).
      - `POST /auth/activate`: the first sign-in on a phone, with username, password and the admin's activation code. It sets `devices.activated_at` and a new `activation_secret_ref`, uses up the code, and returns the session plus `activationSecret` (once). A wrong code counts as a failed sign-in.
      - `POST /auth/login` on an activated phone signs in again with the password (after the refresh token stopped working); a phone that is not activated gets 403 `ACTIVATION_REQUIRED`.
      - An LHW's session body carries `supervisors` (area supervisors with a phone number) for the lock screen's emergency call.
      - After that the app unlocks offline with the PIN; the server never sees the PIN.
    - `activation.service.js`: activation codes and the PIN-reset formula.
      - Codes are 8 characters from `ABCDEFGHJKMNPQRSTUVWXYZ23456789` (shown `XXXX-XXXX`), valid `ACTIVATION_CODE_TTL_HOURS` (48), single use, bcrypt-hashed. A new code, or a deactivation, revokes the unused ones. Never log a code.
      - The phone's secret is never stored: it is HMAC-SHA256(server key, `mediqore/activation/<deviceId>/<activation_secret_ref>`). The server key is `PIN_RESET_SECRET`, or derived from `JWT_ACCESS_SECRET` with HKDF if unset. Changing either changes every phone's secret, so phones would need activating again.
      - Reply code: HMAC-SHA256(secret, `mediqore/pin-reset/<6-digit challenge>`), first 4 bytes big-endian modulo 10^8, 8 digits. `tests/activation.test.js` holds the test vector the app shares.
    - `pin-reset.service.js`: `POST /pin-reset/reply-code` for supervisors (LHWs in their areas) and admins; the reply for her latest activated phone, audited without the code.
    - `tokens.service.js`: JWT access tokens (claim `did` = the activated phone) and opaque refresh tokens. Refresh tokens are stored as SHA-256 hashes, rotated on every use (`replaced_by` links each to its replacement), and revoked on sign-out, deactivation and password reset.
      - The app refreshes at every sync. On a weak network the answer can be lost after the token was already replaced, so a replaced token is accepted again as long as its replacement has never been used (no time limit, only the token's own expiry: a phone may stay offline for days, and a sleeping staging server can answer after the phone gave up); that replacement is revoked instead. Once the replacement has been used, the old token is refused. Sign-out, deactivation and a password reset revoke the replacement too, so they still end the session.
    - `login-throttle.js`: in-memory rate limit on failed sign-ins per address and username (429 `TOO_MANY_ATTEMPTS` with `Retry-After`). It holds one process's memory, so tests call `loginThrottle.reset()`.
  - `lhws.service.js` (M1 FE-1, FE-3): LHW accounts.
    - The LHW ID comes from the `lhw_code_seq` sequence (`LHW-00001`) and is also the username.
    - Passwords are random, shown once and stored as bcrypt.
    - It also handles reassignment, deactivation, password reset and activation codes (`POST /admin/lhws/:id/activation-code`), with an audit row for each change.
    - Reassignment keeps the old area in `lhw_profiles.previous_area_id`. Push files a new record under the area the phone made it in (`areaId`), if that is the LHW's current or previous area, so records made before the move and synced after it stay in the old area (M1 FE-3).
- Sync accepts only an activated phone, and only the phone named in the token (`DEVICE_NOT_ALLOWED`).
- `src/sync/tables.js`: the tables devices may push and pull, with their fields. Add a table here when its module is built. `services/sync.service.js` implements `/sync/push` and `/sync/pull`.
  - Synced so far: `households` (M2 FE-3), `women`, `pregnancies` (M2 FE-1), `obstetric_history` (M2 FE-2) and `visits` (M3 FE-1).
  - Vital bounds in `tables.js` are the `allowed` ranges of the Clinical Rules Table (`clinical-rules/clinical-rules.json`, `visit_entry_checks`), the same table the app bundles. They refuse only impossible values; the app confirms implausible ones.
  - Visits (M3 FE-1): `pulseBpm` is required. Blood sugar is stored as typed: `bloodSugarValue` with `bloodSugarUnit` (`mmol_l` or `mg_dl`; the allowed range is checked in mmol/L after ÷ 18); `bloodSugarMeasuredOn` and `bloodSugarSource` (`glucometer` or `lab_report`) are required with a value and must be null without one. The six danger-sign answers (`convulsions` … `feverWithWeakness`) are `true`, `false` or `null` (not asked).
  - Pregnancies (M2 FE-1): `eddBasis` (`lmp`, `edd`, `month`) with `lmpDate`, `reportedEdd` and `estimatedDeliveryDate`; an older app that sends none gets the EDD worked out from the month (`gestational_age` in the Clinical Rules Table), and registration must fall within its `registration_weeks`.
  - Versions (M3 FE-2): every synced row has `version` (1 on insert, +1 on each accepted change, set by the `assign_server_seq` trigger); push results and pull records carry it. An edit sent with a `baseVersion` older than the server's is not applied: it is held in `sync_conflicts` (reason `outdated_edit`, status `conflict` with `conflictId` to the device, audit action `sync_conflict`); a resend returns the same conflict, and an identical resend is `unchanged`, never a conflict.
  - A table with `duplicateOf` (women): a new woman with the same name, husband's name and household as one in the area is stored and listed for review (reason `possible_duplicate`).
  - `GET /sync/config?have=` (M3 FE-2): the district's facilities, the area's escalation contact, current campaign rounds and the Clinical Rules Table (the newest in `clinical_rules_versions`, otherwise the bundled one), with a sha256 `configVersion`; `unchanged: true` when the phone has it.
  - The session of an LHW with a phone carries `activationNumber` (`devices.activation_number`, per user, issued at activation) for the Patient ID (M2 FE-1).
  - A table with a `parent` (a woman's household, a pregnancy's woman) needs that parent on the server and in the same area, or the record is refused with `MISSING_PARENT` or `OUT_OF_AREA`.
  - Each pushed record runs in a savepoint: a record that breaks a database rule is refused with a reason (`DUPLICATE_PATIENT_ID`, `ACTIVE_PREGNANCY_EXISTS`, `DUPLICATE_RECORD`) and the rest of the batch still applies.
  - `src/db/pool.js` reads DATE columns as `YYYY-MM-DD` text, never as a JavaScript Date.
- Portal reads, all area-scoped for supervisors (M10 FE-1):
  - `GET /households`: the map, filtered by `districtId`, `tehsilId`, `unionCouncilId`, `lhwId` and `days` (received by the server in the last so many days).
  - `GET /women`: registered women with household, latest pregnancy, obstetric history and visit count, search.
  - `GET /women/:id/visits`: one woman's visits over all her pregnancies, with every visit field, latest first by `server_seq` (404 outside a supervisor's areas).
  - `GET /dashboard/summary`: registered women, visits this week, pending conflicts, active LHWs and LHWs synced today, narrowed by `districtId`, `tehsilId`, `unionCouncilId` and `lhwId` (`placeConditions` in `dashboard.service.js`).
  - `GET /dashboard/lhw-activity`: per LHW, visits this week and in total, women registered, last visit, last sync and last login, with the same filters.
    - Last sync (`LAST_SYNC`): the latest push or pull from her phone (`devices.last_sync_at`, set by `requireActivatedDevice` in `sync.service.js`), or the latest record the server received from her. Pull checks the phone before its read-only snapshot, because the check writes the time.
  - `GET /dashboard/filters`: the districts, tehsils, Union Councils and LHWs the viewer may filter by.
- Admin panel (M10 FE-3, admins only), every change with an audit row:
  - `staff.service.js`: supervisor and admin accounts (`/admin/staff`). The admin picks the username; the password is random and shown once. Supervisors get areas (`supervisor_areas`). An admin cannot change their own role or deactivate themselves (`OWN_ACCOUNT`), and the last active admin stays (`LAST_ADMIN`).
  - `geography.service.js`: the district > tehsil > Union Council > area tree (`/admin/geography/:level`). Names are unique among siblings; deleting is soft and refused while anything uses the unit (`IN_USE`, with `details.uses`); re-creating a deleted name restores it with its ID.
  - `facilities.service.js`: hospitals and referral centres (`/admin/hospitals`, `/admin/referral-centres`), per district with optional area and GPS. They carry the sync columns, so phones can pull them in Phase 2 (M5 FE-1); the trigger numbers every change.
  - `audit.service.js` `list`: the audit log viewer (`/admin/audit`), filtered by user, action, record type and Pakistan-time dates, paged with `before`.
- `conflicts.service.js` (M3 FE-2, M10 FE-3): the Conflict Review page, `GET /conflicts` and `POST /conflicts/:id/resolve` for supervisors (their areas) and admins; each conflict lists its `resolutions`. `outdated_edit`: `keep_server` (the row gets a new number so the phone pulls the server's version) or `use_device` (the edit becomes a new version). `possible_duplicate`: `different_people` or `same_person` (the newer woman is merged into the earlier: her visits move to the earlier active pregnancy, or her pregnancy moves; the newer records are soft-deleted). Legacy `same_parent_same_day` visits keep `keep_both`, `keep_existing`, `keep_incoming`. Every step is audited; the phone learns the outcome at its next pull.
- Error shape: `{ "error": { "code", "message", "details"? } }`.
- `docs/openapi.yaml` is the API contract. Update it in the same pull request as any route change.
- `tests/`: Jest + Supertest.
  - Import `createApp()`; never start a real server in tests.
  - Database tests use `describeDb` from `tests/db.js`. They run only when `TEST_DATABASE_URL` points at a migrated database whose name ends in `_test`, and they empty it first.
  - `createFixtures()` gives each fixture LHW an activated phone (`deviceA`, `deviceB`). `tokenFor(userId, role, deviceId)` signs a token, and app tokens carry the phone.
  - The `server_seq` trigger stamps `synced_at` on every update; a test that needs an old `synced_at` disables the trigger for that one update (see `tests/dashboard-activity.test.js`).

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

Demo accounts for local testing: `cd ..\db; npm run seed:demo` creates `admin.demo`, `supervisor.demo` and `lhw.demo` (see `db/CLAUDE.md`). Before `lhw.demo` signs in on a phone, generate an activation code for her on the portal (**LHW accounts** as `admin.demo`, **New activation code**) and type it in the app with the password.
