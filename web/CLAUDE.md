# web/: supervisor and admin portal

React portal for Module 10: dashboard, map, alerts, reports and admin panel. Follow the root `CLAUDE.md` first; this file only adds what is specific to `web/`.

## Stack (scope Tools table)

| Tool | Version | Purpose |
|---|---|---|
| React.js | 18.x | Supervisor web dashboard with charts, heatmaps and analytics |
| Leaflet.js | (not versioned in scope) | Geographic risk map from Module 2 GPS data (M10 FE-1) |

From the roadmap: unit tests use Jest.

## Key rules

- Talk to the API at `/api/v1`, over HTTPS outside local development (M1 FE-2). The API base URL comes from `web/.env`; see `web/.env.example`.
- The dashboard map auto-refreshes every 5 minutes and can be filtered by district, Union Council, LHW and time period (M10 FE-1).
- Admin actions must show up in the audit log viewer (M10 FE-3).

## Commands

<!-- Fill in when P0-5 creates the project. -->
