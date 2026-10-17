# MediQore test report

Short notes per module, as the roadmap's Definition of done asks ("Short note added to the user guide and test report"). Every run uses synthetic data only (LI-10). The full regression run and the field tests of Phase 4 are added later.

## How the tests run

| Part | Tool | Command | Where it runs |
|---|---|---|---|
| `mobile/` | flutter_test (unit and widget) | `flutter analyze`, `flutter test` | CI on every pull request and push |
| `mobile/` end to end | flutter_test against a real API | `flutter test test/e2e/sync_e2e_test.dart --dart-define=E2E_API_BASE_URL=…` | By hand, against a local API with `seed:demo` |
| `api/` | Jest + Supertest | `npm run lint`, `npm test` | CI, against a migrated `*_test` database |
| `web/` | Jest + Testing Library | `npm run lint`, `npm test`, `npm run build` | CI |
| `db/` | node:test | migrations up, down and up; `npm test` | CI |
| `clinical-rules/` | node:test | `node --test` | CI |

## Phase 1 run, 16 October 2026 (`dev`)

| Suite | Result |
|---|---|
| Mobile unit and widget tests | 205 passed, 5 skipped (the end-to-end tests, which need a real API); `flutter analyze` clean. Rerun after the design pass and the motion of 17 October: 208 passed (3 new motion tests: entrance off with "Remove animations", wizard steps mirrored in Urdu, wrong-PIN shake), every screen on a 320 × 640 phone in Urdu and English |
| Mobile end to end against the local API | 5 passed: Phase 0 record path, M1 activation and PIN-reset reply code, M2 registration, M3 visit with a same-day conflict decided on the portal, background sync |
| API | 191 passed; lint clean |
| Portal | 66 passed; lint and production build clean |
| Database | 32 passed; every migration up, down and up again |
| Clinical Rules Table | 84 passed |

### Module 1: activation and access

- Covered by tests: activation code (format, 48 hours, single use, stored hashed, revoked by a new code or a deactivation), sign-in rate limiting, refresh tokens (rotation; a token whose answer was lost on a weak network accepted once more while its replacement is unused; refused after sign-out, deactivation, password reset or 30 minutes), the PIN delays of 30 s, 1 min, 5 min and 15 min (also after a restart and with the clock set back), PIN reset with the reply code (shared test vector between the API and the app), the lock-screen emergency call, auto-lock, deactivation at the next connection, sign-in again after a password reset with the records and PIN kept, area reassignment, and every screen on a 320 × 640 phone in Urdu and English.
- On a real phone: a test APK was activated on the staging server with an activation code from the portal (October 2026).

### Module 2: registration

- Covered by tests: the four-step wizard with its checks, the offline patient ID, the pregnancy file, the obstetric history and its risk-factor flags from the Clinical Rules Table, GPS capture and the nearest-first list, sync of the whole registration (parents first, a resend is harmless, refusals such as a patient ID already used), and the portal's **Registered women** page.

### Module 3: visits and sync

- Covered by tests: the three-step visit (required pulse, the 30-second pulse counter, blood sugar with unit, date and source and its mg/dL conversion, the six danger-sign questions, range checks from the Clinical Rules Table), the encrypted database (wrong key refused, older databases moved to the random key), and sync:
  - outbox push in batches with priority, pull by server number, idempotent resend;
  - same-day conflicts held for the supervisor and the decision reaching the phone;
  - refused records kept on the phone, counted on the home screen and sent again at every sync;
  - tokens refreshed at every sync, with the newest stored token;
  - the open app syncing after a save, when the network returns, while records wait and every 10 minutes otherwise;
  - background sync with the app locked or closed: records sent with the Keystore key, skipped while the app is open, retried later without a network, stopping when the sign-in has expired, and only pushing after an area change;
  - the daily sync reminder and the last-sync time on the home screen (LI-8).
- To check on a real phone in airplane mode: background sync on Android after the network returns (Android picks the moment, usually within minutes), with the app locked and with it closed.

### Module 10 base: the portal

- Covered by tests: dashboard cards (registered women, visits this week, LHWs synced today, conflicts) and LHW activity, all filtered by district, Union Council and LHW, an LHW whose last sync is 2 days old highlighted, the map and its period filter, the 5-minute refresh, a woman's visits, LHW accounts with the activation code banner, supervisor and admin accounts, geography, hospitals and referral centres, roles and the audit log, role checks and area scoping on every route.
- Checked in a browser at desktop and phone width (no sideways scroll), on synthetic data.

## Open items

- Real-phone checks in airplane mode for every Phase 1 FE, in both languages, before Phase 1 is signed off (Definition of done).
- Review and merge by the other team member.
