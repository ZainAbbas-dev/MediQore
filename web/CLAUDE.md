# web/: supervisor and admin portal

React portal for Module 10: dashboard, map, alerts, reports and admin panel. Follow the root `CLAUDE.md` first; this file only adds what is specific to `web/`.

## Stack

| Tool | Version | Purpose |
|---|---|---|
| React.js | 18.x (scope Tools table) | Supervisor web dashboard with charts, heatmaps and analytics |
| Leaflet.js + react-leaflet | 1.9 + 4.x | Geographic map (M10 FE-1). react-leaflet 4 is the last major that supports React 18. |
| react-router-dom | 7.x | Routing. Version 8 needs React 19 and Node 22. |
| Vite | 8.x | Dev server and production build |
| Jest + Testing Library | 30 / 16 | Unit and component tests (roadmap: Jest). Babel 7 is used only to let Jest read JSX. |
| ESLint | 10 | Lint, with react-hooks and react-refresh rules |

## Key rules

- Talk to the API only through `apiRequest()` in `src/api/client.js`. It sends the token and turns error answers into `ApiError(status, code, message)`.
  - In development the portal calls `/api/v1` on its own origin; Vite forwards `/api` to the API (`vite.config.mjs`, default `http://localhost:3000`).
  - Builds for another host set `VITE_API_BASE_URL`.
  - Use HTTPS outside local development (M1 FE-2).
- The portal is for supervisors and admins only (`PORTAL_ROLES` in `src/auth/context.js`); an LHW who signs in is turned away.
- A 401 from the API signs the user out.
- Every page except `/login` sits behind `RequireAuth` and inside `AppLayout`. Add each new Module 10 screen as a route in `src/App.jsx` and as a sidebar link in `src/layout/AppLayout.jsx`.
- The dashboard map auto-refreshes every 5 minutes and can be filtered by district, Union Council, LHW and time period (M10 FE-1, Phase 1).
- Admin actions must show up in the audit log viewer (M10 FE-3).

## Layout

- `src/main.jsx`: entry point: router, `AuthProvider`, global CSS and Leaflet CSS.
- `src/App.jsx`: routes (`/login`, then the guarded layout with the dashboard and a not-found page).
- `src/auth/`:
  - `AuthProvider.jsx`: sign-in state; the access token is kept in `sessionStorage` for this tab only.
  - `context.js`: `useAuth()` and `PORTAL_ROLES`.
  - `RequireAuth.jsx`: the auth guard.
- `src/layout/AppLayout.jsx`: sidebar with navigation, the signed-in user and Sign out.
- `src/pages/`: `LoginPage`, `DashboardPage` and `NotFoundPage`.
  - For now `DashboardPage` shows the synced households as a count, a map and a table: the portal end of the Phase 0 end-to-end check.
- `src/components/AreaMap.jsx`: Leaflet map centred on Pakistan that draws households with GPS.
- `src/runtime-config.js`: the API base URL from `import.meta.env`. Jest swaps it for `tests/runtime-config-stub.js`.
- `tests/`: Jest + Testing Library.
  - `tests/helpers.jsx` has `renderApp(path, { session })` and `mockApi({ 'GET /path': [status, body] })`.
  - Mock `AreaMap` in page tests; `tests/area-map.test.jsx` covers the real Leaflet map.

## Commands

Run from `web/` (start the API first, see `api/CLAUDE.md`):

```powershell
npm install
npm run dev        # http://localhost:5173 ; forwards /api to http://localhost:3000
npm run lint       # ESLint
npm test           # Jest
npm run build      # production build in dist/
```

Demo sign-in after `npm run seed:demo` in `db/`: `supervisor.demo` or `admin.demo`, password `demo-password`.
