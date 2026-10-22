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
  - Wrap each route in `RequirePermission permission="..."` (`src/auth/RequirePermission.jsx`) and show its sidebar link only when `can(user, permission)` (`src/auth/context.js`). The session's `user.permissions` comes from the API (the admin's choices on the Roles page); an older stored session falls back to the role's defaults. The API checks the same permission.
- Show passwords and one-time codes only once, right after the API returns them. Never store them in state that outlives the dialog or notice.
- The dashboard map auto-refreshes every 5 minutes and can be filtered by district, tehsil, Union Council, LHW and time period (M10 FE-1, Phase 1).
- Admin actions must show up in the audit log viewer (M10 FE-3); the API writes the audit rows.
- Admin pages sit under `admin/` routes, each behind its permission, with their links in the sidebar's **Administration** navigation (shown when the account holds any of them). Who holds what is decided by the API (`api/src/auth/permissions.js` defaults plus the admin's changes on the Roles page).

## Layout

- `src/main.jsx`: entry point: router, `AuthProvider`, global CSS and Leaflet CSS.
- `src/App.jsx`: routes (`/login`, then the guarded layout with the dashboard, the supervisor pages, the admin pages and a not-found page).
- `src/auth/`:
  - `AuthProvider.jsx`: sign-in state and `request()`. The access and refresh tokens are kept in `sessionStorage`, for this tab only.
  - `RequirePermission.jsx`: shows a route only to accounts holding its permission.
  - `context.js`: `useAuth()` and `PORTAL_ROLES`.
  - `RequireAuth.jsx`: the auth guard.
- `src/layout/AppLayout.jsx`: sidebar with the main navigation, the **Administration** navigation for admins, the signed-in user and Sign out. Each link has an outlined icon from `NavIcon.jsx` (inline SVG paths of the Material icons the app uses, no icon library).
- `src/pages/`:
  - `LoginPage`, `NotFoundPage`.
  - `DashboardPage` (M10 FE-1, final design screen 20):
    - the filters (district, Union Council, LHW, period) and **Reload** in the page header, from `GET /dashboard/filters`. District, Union Council and LHW apply to everything; the period applies to the map (`GET /households`);
    - cards from `GET /dashboard/summary`: registered women, visits this week, LHWs synced today ("13 of 16"), sync conflicts to review (amber when there are any);
    - **Households with GPS**: the map, with how many it shows;
    - **LHW activity** from `GET /dashboard/lhw-activity`: last sync, women, visits this week and in total, last visit, last sign-in. An active LHW whose last sync is `STALE_AFTER_DAYS` (2) days old or more, or who never synced, is highlighted; this is a display hint, not the FE-4 inactivity detection (Phase 2);
    - refreshes every 5 minutes and on **Reload**; each part loads on its own, so one failure does not hide the others.
  - `WomenPage` (`/women`, admins and supervisors, M2 FE-1–3): registered women with their pregnancy file in short (expected delivery date, weeks today and how it was dated) and their visit count and last visit (M3), from `GET /women`, with search. The visit count opens her visits (`GET /women/:id/visits`): vitals, blood sugar in its recorded unit, with source and date, symptoms and the danger signs answered yes, with the decision-support note (LI-5).
  - `ConflictsPage` (`/conflicts`, `conflicts.resolve`, M3 FE-2, M10 FE-3): the Conflict Review queue from `GET /conflicts?status=…`. Each conflict shows its kind and compares the two versions field by field for its table (differences highlighted): an edit made on an older version (server vs phone; **Keep the server's version** or **Use the phone's edit**), a possible duplicate woman (earlier vs new registration; **Different women: keep both** or **Same woman: merge**, which asks first), or a legacy same-day visit (keep both, the stored or the held visit). The buttons come from the conflict's `resolutions`; decided conflicts show who decided and when.
  - `PinResetPage` (`/pin-reset`, admins and supervisors, M1 FE-2): **PIN reset codes**. Pick the LHW (from `GET /dashboard/filters`, so a supervisor sees only their areas), type the 6-digit code on her phone, and read back the 8-digit reply from `POST /pin-reset/reply-code`, shown once.
  - `LhwsPage` (`/admin/lhws`, `accounts.manage`, M1 FE-1–3, final design screen 21; a supervisor given the permission sees and manages only the LHWs of their areas):
    - lists LHW accounts with the phone state (activated on a date, code issued, not activated), status (Active, Waiting to activate, Deactivated) and last sign-in, with search and a status filter in the header;
    - each row offers the next step for its state (**New activation code** while waiting, **Activate** when deactivated) and **Edit**; the Edit dialog also holds **New activation code**, **Reset password** and **Deactivate**;
    - creates an LHW and shows the issued LHW ID and password once;
    - **New activation code** (after a confirmation that warns if a phone is already activated) shows the `XXXX-XXXX` code once, with its expiry, in a banner above the list until **Done** (M1 FE-2);
    - edits and reassigns; the note says the phone's unsynced records keep the old area (M1 FE-3);
    - resets the password; the phone keeps its data and PIN (LI-8).
  - Admin panel (admins, M10 FE-3):
    - `StaffPage` (`/admin/staff`, `staff.manage`, admins only): supervisor and admin accounts. Create with a chosen username (password shown once), supervisor areas with `AreaChecklist`, role change (never for your own account). **Edit** also holds reset password and deactivate (never your own account); a deactivated account shows **Activate** in its row.
    - `GeographyPage` (`/admin/geography`, **Geography** in the sidebar): four columns (district, tehsil, Union Council, area); choosing a unit shows its children. Add, rename, delete; a unit in use is refused with the API's reason.
    - `FacilitiesPage` (`/admin/facilities`): hospitals and referral centres as two tabs, by district, with optional area and GPS.
    - `RolesPage` (`/admin/roles`, `roles.manage`): the permission table from `GET /admin/roles`; the cells the API marks editable are checkboxes, saved together with **Save changes** (`PUT /admin/roles/permissions`, audited); the fixed ones show ✓ or –.
    - `AuditPage` (`/admin/audit`): the audit log, filtered by user, action, record type and dates; changes read "field: from → to"; a sign-out (a login entry with the result `logout`) reads **Sign-out**; **Show older entries** pages back.
- `src/components/`:
  - `AreaMap.jsx`: Leaflet map centred on Pakistan that draws households with GPS. It fits to the households when they change, but keeps the user's zoom when an automatic refresh brings the same ones.
  - `Dialog.jsx`: the modal dialog of the admin pages.
  - `AreaChecklist.jsx`: picks several areas, with a search box.
- `src/format.js`: times as "Today 10:31", "Yesterday 17:40", "4 days ago" or "6 Oct" (`formatWhen`), and `isStale` for the dashboard.
- `src/styles.css`: the final design (Clinical Teal, `docs/design/phase1-screens.md`): tokens on `:root`, the teal sidebar with the active link in light teal, page headers with a subtitle and controls (`.page-header`, `.page-subtitle`, `.header-controls`, `.field`), white rounded panels (`.panel`; `.table-scroll` is one too), cards (`.card.attention` in amber), pill buttons and badges. Below 820 px the sidebar becomes a top bar with a scrolling row of links; the page never scrolls sideways (tables scroll inside their panel).
- `src/runtime-config.js`: the API base URL from `import.meta.env`. Jest swaps it for `tests/runtime-config-stub.js`.
- Installable web app (P0-5, M10 FE-1):
  - `public/manifest.webmanifest` and `public/icons/` (192 px, 512 px, maskable 512 px, Apple touch icon, SVG favicon; Clinical Teal `#00695C`). `index.html` links them.
  - `public/sw.js`: the service worker. It shows a push message (JSON `{ title, body, url, tag }`) as a notification that stays until tapped, and a tap opens or focuses the portal on `url`. Web push subscription through Firebase Cloud Messaging for web is added in Phase 2 (M10 update, M5 FE-2).
  - The service worker has **no fetch handler and caches nothing**: the portal shows patient data, which must never sit in browser storage.
  - `src/pwa/register-service-worker.js` registers it from `main.jsx`, in production builds only.
- `tests/`: Jest + Testing Library.
  - `tests/helpers.jsx` has `renderApp(path, { session })`, `supervisorSession`, `adminSession` and `mockApi({ 'GET /path': [status, body] })`. A route can also map to a function `(options) => [status, body]`. The key includes the query string, for example `GET /conflicts?status=pending`. The dashboard calls `GET /dashboard/filters`, `GET /dashboard/summary`, `GET /households` and `GET /dashboard/lhw-activity` (see `dashboardApi()` in `tests/dashboard.test.jsx`).
  - Mock `AreaMap` in page tests; `tests/area-map.test.jsx` covers the real Leaflet map.
  - `tests/pwa.test.js` checks the manifest and icon sizes, runs `public/sw.js` against a fake service worker global, and tests the registration.

## Commands

Run from `web/` (start the API first, see `api/CLAUDE.md`):

```powershell
npm install
npm run dev        # http://localhost:5173 ; forwards /api to http://localhost:3000
npm run lint       # ESLint
npm test           # Jest
npm run build      # production build in dist/
```

Demo sign-in after `npm run seed:demo` in `db/`: `supervisor.demo` or `admin.demo`, password `demo-password`. Both see the dashboard, **Registered women**, **Sync conflicts** and **PIN reset codes**; `admin.demo` also sees **Administration**, where **LHW accounts** generates the activation code for `lhw.demo`'s phone. The synthetic data (`npm run seed:synthetic`) includes a few possible duplicate women for the Conflict Review page, and DHQ and THQ hospitals.
