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

- Pages talk to the API through `request(path, options)` from `useAuth()`.
  - It adds the access token. On a 401 it swaps the refresh token for a new pair once (M1 FE-2) and retries.
  - It is built on `apiRequest()` in `src/api/client.js`, which turns error answers into `ApiError(status, code, message)`.
  - In development the portal calls `/api/v1` on its own origin; Vite forwards `/api` to the API (`vite.config.mjs`, default `http://localhost:3000`).
  - Builds for another host set `VITE_API_BASE_URL`.
  - Use HTTPS outside local development (M1 FE-2).
- The portal is for supervisors and admins only (`PORTAL_ROLES` in `src/auth/context.js`); an LHW who signs in is turned away.
- A failed refresh, or 403 `ACCOUNT_INACTIVE`, signs the user out. Sign-out revokes the refresh token.
- Every page except `/login` sits behind `RequireAuth` and inside `AppLayout`. Add each new Module 10 screen as a route in `src/App.jsx` and as a sidebar link in `src/layout/AppLayout.jsx`.
  - Wrap role-specific routes in `RequireRole roles={[...]}`, and hide their sidebar links from other roles. The API checks roles too.
- Show passwords and one-time codes only once, right after the API returns them. Never store them in state that outlives the dialog or notice.
- The dashboard map auto-refreshes every 5 minutes and can be filtered by district, Union Council, LHW and time period (M10 FE-1, Phase 1).
- Admin actions must show up in the audit log viewer (M10 FE-3).

## Layout

- `src/main.jsx`: entry point: router, `AuthProvider`, global CSS and Leaflet CSS.
- `src/App.jsx`: routes (`/login`, then the guarded layout with the dashboard and a not-found page).
- `src/auth/`:
  - `AuthProvider.jsx`: sign-in state and `request()`. The access and refresh tokens are kept in `sessionStorage`, for this tab only.
  - `RequireRole.jsx`: shows a route only to the given roles.
  - `context.js`: `useAuth()` and `PORTAL_ROLES`.
  - `RequireAuth.jsx`: the auth guard.
- `src/layout/AppLayout.jsx`: sidebar with navigation, the signed-in user and Sign out.
- `src/pages/`:
  - `LoginPage`, `NotFoundPage`.
  - `DashboardPage`: cards for registered women (M2) and households, then the households on a map and in a table (the portal end of the Phase 0 end-to-end check).
  - `WomenPage` (`/women`, admins and supervisors, M2 FE-1–3): registered women with their pregnancy file in short, from `GET /women`, with search. Wide tables go inside `.table-scroll`.
  - `DevicesPage` (`/devices`, admins and supervisors, M1 FE-2): phones waiting for approval. **Issue code** shows a 6-digit one-time code once.
  - `LhwsPage` (`/admin/lhws`, admins, M1 FE-1, FE-3):
    - lists LHW accounts;
    - creates an LHW and shows the issued LHW ID and password once;
    - edits and reassigns; the note says the phone's unsynced records keep the old area (M1 FE-3);
    - deactivates or activates;
    - resets the password after the LI-8 "sync before reset" warning.
- `src/components/AreaMap.jsx`: Leaflet map centred on Pakistan that draws households with GPS.
- `src/runtime-config.js`: the API base URL from `import.meta.env`. Jest swaps it for `tests/runtime-config-stub.js`.
- `tests/`: Jest + Testing Library.
  - `tests/helpers.jsx` has `renderApp(path, { session })`, `supervisorSession`, `adminSession` and `mockApi({ 'GET /path': [status, body] })`. A route can also map to a function `(options) => [status, body]`. The key includes the query string, for example `GET /women?limit=1` (the dashboard's count).
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

Demo sign-in after `npm run seed:demo` in `db/`: `supervisor.demo` or `admin.demo`, password `demo-password`. `admin.demo` sees **LHW accounts**; both see **Phone approvals**.
