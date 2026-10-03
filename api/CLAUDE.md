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
- The migration tool (Knex or node-pg-migrate) is chosen in P0-4.
- Urdu PDF rendering is tested in P0-11; if pdfkit breaks Nastaliq, the fallback is HTML printed to PDF with headless Chrome (Puppeteer).

## Key rules

- All routes live under `/api/v1`. Validate every request body with Joi, run role-check middleware on every route, and scope every query by area.
- Parameterised SQL only. Hash passwords with bcrypt.
- Assign `server_seq` on accept and never trust device clocks. Soft deletes only. Write an audit row for every create, edit, delete, referral, alert and login.

## Layout

- `src/app.js` builds the Express app. `src/server.js` starts it.
- Each request flows route → controller → service:
  - `src/routes/<name>.routes.js` holds the paths and the `validate(...)` call. Mount it in `src/routes/index.js`.
  - `src/controllers/` reads `req` and writes `res`. Keep controllers thin.
  - `src/services/` holds the business logic and database calls.
- `src/middleware/`:
  - `validate.js`: Joi middleware. It replaces `req.body`, `req.query` and `req.params` with the validated values, or answers 400 `VALIDATION_ERROR`.
  - `error-handler.js`: 404 and the central error handler. Throw `AppError(status, code, message, details)` from `src/utils/app-error.js` for expected errors; anything else becomes a generic 500.
  - `request-logger.js`: one JSON log line per request, path only (no query string or body).
- Error shape: `{ "error": { "code", "message", "details"? } }`.
- `docs/openapi.yaml` is the API contract. Update it in the same pull request as any route change.
- `tests/` holds the Jest + Supertest tests. Import `createApp()`; never start a real server in tests.

## Commands

Run from `api/`:

```powershell
npm install                     # first time (CI uses npm ci with package-lock.json)
Copy-Item .env.example .env     # then edit values
npm run dev                     # start with auto-reload at http://localhost:3000/api/v1
npm start                       # start without reload
npm run lint                    # ESLint
npm test                        # Jest + Supertest
```
