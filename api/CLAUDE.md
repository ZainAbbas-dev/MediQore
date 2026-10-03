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

## Commands

<!-- Fill in when P0-3 creates the project. -->
