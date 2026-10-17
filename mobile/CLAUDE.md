# mobile/: LHW Android app

Flutter app with Modules 1–9, fully offline, in Urdu by default with an English option (M3 FE-3). Supervisors get emergency alerts through the portal's web push, SMS and calls; there is no separate supervisor app (M5 FE-2). Follow the root `CLAUDE.md` first; this file only adds what is specific to `mobile/`.

> **Phase 1 revision.** Modules 1–3 follow the updated scope: activation code, offline six-digit PIN with progressive delays and supervisor reply-code reset, lock-screen emergency call, a random database key wrapped by the Android Keystore; the four-step registration wizard, obstetric risk-factor flags from the Clinical Rules Table, nearest-first sorting, and the final design of the home, list and file; the three-step visit with the pulse counter, blood sugar unit, date and source, and the danger-sign checklist. Voice guidance is removed (LI-6).

## Stack (updated scope Tools table)

| Tool | Version | Purpose |
|---|---|---|
| Flutter | 3.x; this project needs 3.47 or newer (`pubspec.yaml`) | Android app with Urdu and English UI and offline support (Android only, LI-1) |
| SQLite via Drift | Latest | Offline local storage |
| SQLite3MultipleCiphers via Drift NativeDatabase (`sqlite3` package) | Latest | AES-256 encryption (SQLCipher-compatible cipher) of the local database (M3 FE-2, decision 0006) |
| flutter_secure_storage (Android Keystore) | Latest (11.x) | Keeps the random database key, the activation secret, the refresh token and the PIN check wrapped by a non-exportable Keystore key; the database key is never derived from the password or PIN (M1 FE-2, M3 FE-2, LI-8) |
| flutter_localizations + intl | Latest | Urdu and English ARB files, the language switch in Settings, RTL for Urdu and LTR for English, bidirectional text |
| Jameel Noori Nastaleeq (bundled asset) | N/A | Urdu Nastaliq font for all Urdu text |
| Flutter Directionality widget | N/A | RTL context for Urdu, with numeric vitals left to right |
| onnxruntime | Latest | On-device inference of the five- and six-feature risk models |
| JSON lookup table (asset) | N/A | SHAP-derived explanations in Urdu and English, bundled at build time |
| fl_chart | Latest | Vital trend graphs |
| Dart (on-device) | - | Trend slope of each vital over the last three visits against the Clinical Rules Table (M6 FE-3) |
| google_mlkit_text_recognition | Latest | Offline OCR of printed Latin-script hospital reports (LI-9) |
| camera + image_picker | Latest | Report capture from camera or gallery |
| image | Latest | Grayscale and contrast preprocessing before OCR |
| Custom Dart regex engine | - | Clinical value extraction from OCR text |
| flutter_local_notifications | Latest | Local emergency notifications on the LHW app (Layer 1 web push belongs to the portal) |
| another_telephony + flutter_phone_direct_caller + permission_handler + url_launcher | Latest | Layer 2 SMS and Layer 3 call without internet; url_launcher opens the SMS app pre-filled if the SMS permission is denied (LI-4) |
| connectivity_plus + workmanager | Latest (7.3.1, 0.10.x) | Emergency alert record sync in the background; in Phase 1 all records sync in the background (M3 FE-2), and the open app syncs as soon as the network returns |

In the app but not in the Tools table:

| Tool | Purpose |
|---|---|
| shared_preferences | Device settings readable before sign-in: the language (decision 0005), the installation ID and the saved account; never patient data |
| geolocator | Household GPS (roadmap M2 FE-3) |
| crypto (dart.dev) | HMAC-SHA256: the PIN's slow hash (PBKDF2), the PIN-reset reply code, and the earlier versions' password key (read once to move an old database to the new key) |

From the roadmap:

- url_launcher (in the Tools table for Layer 2 and 3 alerts) already opens the dialer for the lock screen's emergency call (M1 FE-2).
- geolocator is used for household GPS (M2 FE-3), behind `LocationService` (`lib/location/location_service.dart`). It needs the location permissions in `AndroidManifest.xml`; GPS works without the internet, but a first fix can take a minute.
- Tests use flutter_test (unit and widget).
- The app is distributed as a signed APK, not through the Play Store.

## Key rules

- No visible string in Dart code: every label goes in the ARB files, with an Urdu and an English entry. Users see both (M1 FE-4).
- The language comes from `AppSettings` (`services.settings`): Urdu by default, English selectable.
  - Test every new screen in both languages, including on a 320 × 640 phone.
  - Don't hard-code a font family or text direction; the theme and locale set them. The exception is text that must stay in one script, such as اردو on the language switch, and numbers, which stay left to right.
- No audio guidance (LI-6): the app relies on written labels, large icons, pictures and colours.
- shared_preferences holds device settings only: the language, the installation ID, the number of waiting records and the account the phone is activated for (profile and area supervisors' names and numbers; never a password, token, key or patient data).
- Secrets go only in the Keystore-backed `SecureStore` (`SecureKeys`): the database key, the activation secret, the refresh token, the PIN verifier and the wrong-PIN count. The access token stays in memory; a locked app forgets it and closes the database.
- The database is encrypted and the app opens it only when the PIN unlocks it (M3 FE-2): use `services.db`, `services.patients` and so on only while the app is unlocked; they throw while it is locked. Background sync opens it briefly on its own, with the same Keystore key, while the app is locked or closed.
- Every write goes to its local table and to the outbox in the same transaction.
- Generate record IDs as UUID v4 on the device; order by `server_seq`, never by device clock.
- Read every clinical rule (ranges, danger signs, flags, EPI, MUAC, IMCI) from the Clinical Rules Table, never hard-code it. The app bundles an exact copy of `clinical-rules/clinical-rules.json` as `assets/clinical/clinical-rules.json` (`test/clinical_rules_test.dart` checks the copy); store the table's `version` with each result. The server reads the same file, so its vital bounds match the app's `allowed` ranges.
- Records sync on their own while the app is unlocked and holds a working refresh token (`AutoSync`), and in the background with WorkManager while it is locked or closed (`BackgroundSync`): every 15 minutes with a network, and as soon as the network returns when records were left waiting. The app and background sync never sync at the same time (`SyncGate`).
- The server address is fixed at build time (`API_BASE_URL`), and release builds are HTTPS-only (M1 FE-2). The one exception is the test APK (`testBuild` in `lib/build_flags.dart`, set with `--dart-define=MEDIQORE_TEST_BUILD=true` by `.github/workflows/apk.yml`):
  - pressing and holding the logo on its activation screen changes the server address (`ActivationScreen.showServerSetting`, saved as `AppSettings.serverAddress`); nothing about the server shows on that screen, and the settings show the address in use;
  - it allows plain HTTP, because the workflow sets `MEDIQORE_ALLOW_HTTP=true` for `android/app/build.gradle.kts`;
  - it shows the Phase 0 checks in the settings.
  Never ship a test build to LHWs.
- Layout: build screens from the shared pieces (`lib/widgets/app_cards.dart`, `curved_header.dart`, the theme) so every screen looks like the final design (`docs/design/phase1-screens.md`): a teal header, white `SectionCard`s on the light teal background, `InfoRow` for label and value, `SyncStatusChip` for a record's sync state, `NoticeCard` for messages. Data entry screens have `LiveStatusBar` at the top.

## Layout

- `lib/main.dart` → `lib/app.dart`:
  - `main()` reads the saved settings (`AppSettings.load()`) and the Clinical Rules Table (`ClinicalRules.load()`) before the first frame.
  - `MediQoreApp` rebuilds `MaterialApp` whenever the language changes. Its locale and theme follow `AppSettings`: Urdu right to left, English left to right.
  - It shows the screen for `Session.stage`: `ActivationScreen`, then `PinCreateScreen` (after activation), `LockScreen` while locked and `HomeScreen` while open. Every change of stage closes the screens opened on top.
  - `InactivityLock` (`lib/widgets/inactivity_lock.dart`) wraps every screen and locks the session after `autoLockAfter` (5 minutes) without a touch (M1 FE-2).
- `lib/settings/app_settings.dart`: `AppSettings` (M3 FE-3, M1 FE-2), with the language, the saved choice and the installation ID (`deviceId`, a UUID v4; sign-out makes a new one with `newDeviceId()`, because the server ties each ID to one account).
  - Saved through `SharedPreferencesStore`; only the keys in `AppSettings.storedKeys`.
  - Tests use `MemorySettingsStore`.
- `lib/auth/` (M1 FE-2, FE-3):
  - `session.dart`: `Session` and its `stage` (activation, createPin, locked, unlocked).
    - `activate(username, password, code)` calls `POST /auth/activate`; nothing is saved until `completeActivation(pin)`, which makes a random 256-bit database key, saves it with the activation secret, the refresh token and the PIN verifier in the `SecureStore`, saves the account, opens the database and syncs (`syncNow`: sends what an earlier version left, downloads the area and records the time, so the home screen shows it as the last sync).
    - `unlock(pin)` works offline. Wrong PINs wait 30 s, 1 min, 5 min, then 15 min each (`pin.dart`, `pinWait()`); the count and the time are in the secure store, and a clock set back restarts the wait.
    - PIN reset: `newResetChallenge()`, `checkResetReply(challenge, reply)` with the activation secret, then `resetPin(pin)`, which opens the app. `changePin(current, pin)` for Settings.
    - `sync()` refreshes the tokens at every sync (M1 FE-2), reading the newest refresh token from the secure store (background sync may have replaced it), and saves the new one with the profile and supervisors that come with it; so a new area or a deactivation arrives at the next sync. It refreshes again once on 401. An area change (M1 FE-3) pushes what waits, clears the old area and pulls the new one (`LocalAccount.dataAreaId`). A refresh token that no longer works throws `NeedsOnlineSignIn`: `signInAgain(password)` (`POST /auth/login`) fixes it, the PIN and records unchanged. `ACCOUNT_INACTIVE` marks the account deactivated and locks: the PIN is refused until `signInAgain` succeeds.
    - `lock()`; `signOut()` only when nothing is waiting: it removes the records, the keys and the account and makes a new installation ID.
    - An earlier version's database (password key, `LegacyAccount`) of the same LHW is moved to the new key with `DatabaseOpener.rekey` at activation; otherwise it is replaced, and `lostUnsyncedRecords` tells the home screen if unsynced records were lost. Another LHW cannot activate while the earlier one's records wait (`AppSettings.pendingRecords`).
  - `secure_store.dart`: `SecureStore`, `KeystoreSecureStore` (flutter_secure_storage, `resetOnError` off) and `MemorySecureStore` for tests.
  - `pin.dart`: `PinVerifier` (PBKDF2-HMAC-SHA256, 60,000 iterations in an isolate, salt and verifier only) and `PinAttempts` with `pinDelays`.
  - `pin_reset.dart`: the reply-code formula shared with the API; `test/auth/pin_reset_test.dart` checks the API's test vector.
  - `local_account.dart`: `SessionUser`, `Supervisor`, `LocalAccount` (the activated account) and `LegacyAccount`.
  - `password_key.dart`: PBKDF2 itself, and the earlier versions' password key.
- `lib/phone/phone_dialer.dart`: `PhoneDialer`; `UrlLauncherDialer` opens the dialer with a `tel:` link.
- `lib/widgets/language_switch.dart`: `LanguageToggle`, the button at the top of the sign-in screen that shows the other language, and `LanguageChoice`, the two-way selector in the settings (اردو | English, the current one filled). Each language name is written in its own script.
- `lib/l10n/app_en.arb` (template, with descriptions) and `lib/l10n/app_ur.arb` hold every visible string. Add new keys to both files.
  - `AppLocalizations` is generated from them by `flutter pub get` into `lib/l10n/app_localizations*.dart`, which is git-ignored.
  - Use it as `AppLocalizations.of(context).key`.
- `lib/theme/`:
  - `AppTheme.light(urdu: …)`, in the final design (P0-7, Clinical Teal): 60 dp pill buttons in both languages, a teal app bar with rounded bottom corners, white cards (radius 20) with a soft shadow on the light teal background, white fields (radius 18), rounded bottom sheets and dialogs. In Urdu the font is the phone's Latin font (`sans-serif`) with Nastaleeq as the fallback, so Urdu letters are Nastaliq and Latin text and digits keep the standard font; the line height is taller. English uses the standard Latin font, also with the Nastaleeq fallback, so names typed in Urdu show in Nastaliq on English screens.
  - `AppColors`: Clinical Teal (`primary` #00695C, `primaryDark`, `primaryLight`, `primarySoft`), the background, text, border, field border, muted text and shadow colours, the status colours (offline, waiting, synced, problem) and the Green/Yellow/Red risk colours.
- `lib/widgets/`: the shared kit.
  - `LargeButton`
  - `AppTextField` (optional leading `icon`; `obscureText` adds the show/hide eye; `code` for an activation or reply code: large, spaced, centred; `maxLength` without a counter; Latin text lines up on the right in Urdu), `VitalField` (numbers and unit always left to right; digits and up to `decimals` decimals; a keystroke that does not fit is ignored; `card: true` is the final design's vital card with the label inside, a large number, `headerTrailing` and `footer`, and a teal border while typing), `CheckboxField`, `DropdownField`.
  - `NumberField` (whole numbers without a unit, digits only, left to right, optional `icon`)
  - `RiskChip` with `RiskLevel`
  - `CurvedHeader` and `HeaderIconButton` (`curved_header.dart`): the final design's teal header with rounded bottom corners, back button (or a close button with `close`, for the wizards and the pulse counter), title, subtitle, actions (the settings gear) and room for a card that overlaps it. Every screen uses it; there are no plain app bars outside the Phase 0 checks.
  - `OfflineStatusBar`, and `LiveStatusBar`, which follows `AutoSync` and counts the waiting records itself; `compact: true` is the small chip in a wizard's header
  - `app_cards.dart`: `SectionCard`, `InfoRow`, `SyncStatusChip`, `StatusPill`, `NoticeCard` (`NoticeTone`: info grey, attention amber, problem red, success green), `InfoPanel` (soft teal explanation under a form), `EmptyNote` (an empty list), `InitialAvatar`
  - `pin_pad.dart`: `PinDots`, `PinKeypad` and `PinEntry` (six digits, left to right in both languages)
  - `emergency_call_button.dart`: "Emergency: call supervisor"; a list when the area has several supervisors
  - `GpsCapture` (M2 FE-3): records a position with its status and the reason it failed
  - `syncStatusText()`: the words for waiting, refused and held records
- `lib/app_services.dart`: the settings, secure store, dialer, database, API client, repositories, sync service, session, automatic sync and the Clinical Rules Table, created once in `main()`. Tests build them with an in-memory database and secure store, Urdu settings kept in memory, a fast PIN hash, a fake dialer and no automatic sync (`testServices()` in `test/helpers.dart`).
- `lib/clinical/` (P0-11): the bundled Clinical Rules Table.
  - `clinical_rules.dart`: `ClinicalRules` (`version`, `status`, `visitRanges`, `obstetricFlags(history)` for M2 FE-2), loaded once in `main()` and kept in `AppServices.clinicalRules`.
  - `conditions.dart`: `conditionHolds`, the table's condition language (all, any, comparisons, in, present), the Dart twin of `clinical-rules/conditions.js`; `test/clinical_rules_test.dart` runs it on the shared `test-cases.json`.
- `lib/clinical/visit_ranges.dart` (M3 FE-1, P0-11): `VisitRanges` from the `visit_entry_checks` section of the bundled Clinical Rules Table, with the table's `version`. Per vital: `allowed` (outside it the value is impossible and cannot be saved), `plausible` (outside it the LHW confirms the value) and `decimals`. Also the pulse counter's `pulseCountSeconds` and `pulseMultiplier`, and `mmolLFromMgDl` (the table's `blood_sugar_conversion`, rounded to one decimal). The table is marked "pending clinical review" until the Clinical Advisor signs it (`clinical-rules/README.md`).
- `lib/data/`:
  - `app_database.dart`: the Drift database (schema version 4) with `households`, `women`, `pregnancies`, `obstetric_history` (M2), `visits` (M3), `outbox` and `sync_state`.
    - Every synced table has the base columns, including `areaId` (the area the record was made in, M1 FE-3) and `createdBy`.
    - No foreign keys between synced tables: a pulled woman can arrive before her household.
    - `enqueue(payload)` adds or replaces a record's outbox entry; `setServerSeq`, `clearAreaData` and `clearAllData` work on every synced table.
    - The patient counter: `raisePatientCounter` (from the server's `lastPatientNumber` at sign-in) and `takePatientNumber`.
    - `app_database.g.dart` is generated and committed. After changing tables, run `dart run build_runner build`, bump `schemaVersion` and add the step to `migration` (see `test/data/migration_test.dart`).
    - On the phone it is opened only through `database_opener.dart` (M3 FE-2, decision 0006): `EncryptedDatabaseOpener` sets AES-256 in the SQLCipher format with the raw random key, refuses a wrong key (`WrongDatabaseKey`), encrypts an older unencrypted database in place and `rekey`s an earlier version's database to the new key.
    - `local_data.dart`: the open database with its repositories and sync service, which exist only while the app is unlocked.
  - `household_repository.dart`: every write saves the record and its outbox entry in one transaction, with a UUID v4 made on the device. `setLocation` adds GPS later.
  - `patient_repository.dart` (M2 FE-1–3):
    - `register` saves the household (or reuses a registered woman's home), the woman, her pregnancy file and her obstetric history with their outbox entries in one transaction, parents first.
    - The patient ID is the LHW code plus the phone's counter, for example `LHW-00001-0007`, the same form as the synthetic data.
    - `list(search:, near:)` sorts by village, then name; with `near` (the LHW's position) by the estimated straight-line distance to the home (`lib/location/distance.dart`, haversine), homes without GPS last, each with `distanceKm` (M2 FE-3). `file(id)` gives the whole pregnancy file. Both report whether the woman is synced, waiting or refused.
  - `visit_repository.dart` (M3 FE-1): `record` saves a visit and its outbox entry in one transaction; `recent(limit)` gives the home screen's latest visits with their woman; `forPregnancy` lists the visits, latest first by server number, then the unsynced ones in the order saved (never by phone clock), each with its `SyncStatus` (synced, waiting, refused or held). Vitals are stored in one unit each: mmHg, kg, °C, beats per minute, mmol/L.
- `lib/sync/`:
  - `sync_api.dart`: the `/auth` (activate, login, refresh, logout) and `/sync` client. `AuthTokens` carries the supervisors and, from activation only, the activation secret. Responses are always decoded as UTF-8.
  - `sync_service.dart`:
    - push sends the outbox in batches of up to 100, highest priority first, then stores each `serverSeq`;
    - pull fetches everything after the last server number seen;
    - records the server refuses stay on the phone, marked with `lastError`, and are sent once more at every later sync (the outbox's retry: a parent that arrives later, an area an admin fixes), in the same order as the rest;
    - `syncNow` saves when it finished (`AppDatabase.lastSyncKey`, phone clock, shown on the home screen and used for the daily reminder only);
    - a visit the server holds for supervisor review (status `conflict`, M3 FE-2) leaves the outbox and gets `conflictId`; the decision arrives by pull, which clears it (a duplicate arrives deleted). `SyncReport.held` counts them.
  - `auto_sync.dart` (M3 FE-2): `AutoSync` syncs while the app is unlocked and `Session.canSync`: a few seconds after a save, as soon as the network comes back (connectivity_plus), every two minutes while records wait or the last attempt failed (the retry), otherwise every `pullEvery` (10 minutes), and when the app returns to the foreground. `run()` is also the Sync button; it waits for a running background sync, and `Session.sync()` joins a sync that is already running, so the refresh token is never used twice. While unlocked it marks the app open in the `SyncGate`; when the app locks or goes to the background with records waiting, it asks for a background sync (`BackgroundScheduler.syncWhenOnline`).
  - `background_sync.dart` (M3 FE-2): `BackgroundSync.run()` opens the database with the Keystore key (never PIN-derived, LI-8), refreshes the tokens, pushes and pulls, saves the waiting count and closes it. It skips while the app is open or another background sync runs, only pushes after an area change, and stops on 401 or a deactivation, which the app handles at its next sync. `BackgroundScheduler` (`NoBackgroundScheduler` in tests).
  - `background_tasks.dart`: WorkManager on Android: `backgroundTaskDispatcher` (the entry point Android calls) and `WorkmanagerScheduler` (`start()` in `main()`: a periodic task every 15 minutes with a network; `syncWhenOnline()`: a one-off task as soon as there is a network; both retry with a growing delay).
  - `sync_gate.dart`: `SyncGate` marks (`FileSyncGate`: two small files in the app's support folder, ignored after 3 minutes; `MemorySyncGate` for tests).
  - `database_opener.dart` sets `busy_timeout`, because background sync can have the file open at the same moment as the app.
- `lib/screens/`:
  - M1 FE-2 (final design screens 1–5): `activation_screen.dart` (the rounded teal header with the language button and the form card over its edge: LHW ID, password and the activation code as a large code field, then the note in an `InfoPanel`; `signInMessage()` turns each `SignInResult` into its text), `pin_create_screen.dart` (`PinCreateMode.activation`, `reset` or `change`; typed twice), `lock_screen.dart` (greeting, keypad, wrong-PIN countdown, **Forgot PIN?**, emergency call; the deactivation notice with **Sign in again**), `pin_reset_screen.dart` (two numbered step cards: the 6-digit code, then the 8-digit reply as a code field; the check button, the note and the emergency call) and `sign_in_again_screen.dart` (password only).
  - `home_screen.dart` (final design screen 6): the teal header with the greeting, name, area and LHW ID and the settings gear; the sync card over its edge (online or offline, records waiting or refused, when the phone last synced, and **Sync now** under them, following `AutoSync`); a red notice for records the server refused, and the amber daily reminder when records have waited a day without a sync (`syncReminderAfter`, LI-8); **Sign in again** when the sign-in has expired; today's work (new registration, registered women with their count) and the recent visits with their sync state (LHWs only).
  - `settings_screen.dart` (M3 FE-3, M1 FE-2, final design screen 7): the teal header with the profile card over its edge (name, LHW ID, area), the language selector, the account actions as a list (**Change PIN**, **Lock the app**, **Sign out** in red: refused while records wait, then confirmed), and in debug builds and test APKs the server address and the Phase 0 checks.
  - `register_screen.dart` (M2 FE-1–3, final design screens 8–11): a four-step wizard in `StepScaffold` (`lib/widgets/step_scaffold.dart`: the teal header with the close button, the title, the compact sync chip, the step line and progress bar; Back / Next at the bottom; also `ChoiceButtons` and `CounterField`), fields with icons: the woman; the pregnancy month (a 1–9 grid); the home (same home as a registered woman, or village, address and GPS); the earlier pregnancies (counters) and known illness. Each step has its own `Form`, checked on **Next**; answers survive going back. Each step's fields sit in a `Column` in a `SingleChildScrollView`, not a `ListView`, so every field is built and validated. Then `registration_saved_screen.dart` (screen 12) shows the teal success header and the new patient ID on one line, with **Open her file**, **Register another woman** and **Go to home**.
  - `patient_list_screen.dart` (M2 FE-3, screen 13): the header with the counts and search, **By village** (village groups) or **Nearest first** (asks the GPS, then sorts by distance and shows it; says why if no position). `patient_file_screen.dart` (screen 14): the header with her name and ID, the stats card (age, month, visits), **New visit** for an active pregnancy, her visits right under it (each reading as an icon chip; a visit with a danger sign answered yes has a red border and notice), the risk factors from her history (`ClinicalRules.obstetricFlags`, `obstetricFlagText`), "record home location" when GPS is missing, and the visits with their sync state (M3).
  - `visit_screen.dart` (M3 FE-1, final design screens 15–18): a three-step wizard in `StepScaffold`.
    - Measurements, as vital cards (`VitalField(card: true)`): BP, weight, temperature and pulse are required. **Count for 30 seconds**, in the pulse card, opens `pulse_counter_screen.dart` (screen 16: the big button in a light teal ring, one tap per beat, the time starts at the first tap, the explanation under the button so it stays in sight on a small phone, then the result card count × multiplier). Blood sugar is optional (light teal border); the unit switch (mmol/L or mg/dL, stored in mmol/L) sits beside its label, and with a value its source (glucometer or lab report) and the day it was measured are required. Impossible values show the allowed range; values outside the usual range open a dialog that lists them ("correct them" or "yes, save").
    - Signs: fetal movement, anaemia and four yes/no questions, as `ChoiceButtons` (`step_scaffold.dart`).
    - Danger signs: the six checklist questions (`dangerSigns`, `dangerSignLabel`), each answered yes or no before saving; a yes turns its card red. The decision-support note is under them in an `InfoPanel` (LI-5).
    - The status bar is at the top. It closes with the saved visit; the file shows "saved on the phone", the sugar details and any danger sign answered yes.
  - Phase 0 checks, reached from the settings in debug builds and test APKs only:
    - `dev_home_screen.dart`: the list of checks.
    - `widget_kit_screen.dart`: the P0-2 kit preview.
    - `sync_test_screen.dart`: the P0-6 end-to-end check (create a synthetic household offline, sync with the session).
- `android/app/build.gradle.kts` sets the manifest's `usesCleartextTraffic` placeholder: plain HTTP to a development server in debug builds, and in a release build only when `MEDIQORE_ALLOW_HTTP=true` (the test APK). Other release builds are HTTPS-only.
- `.github/workflows/apk.yml` builds the test APK after each push to `dev` that changes `mobile/`, or on **Run workflow** with a starting server address, and attaches it to the run.
- `android/app/src/main/AndroidManifest.xml` declares the `tel:` dialer query for the emergency call on Android 11 and later, and turns Android backup off so the encrypted database and the Keystore-wrapped keys never go into a cloud backup.
- `assets/fonts/JameelNooriNastaleeq.ttf`: the bundled Urdu font, declared in `pubspec.yaml` as family `JameelNooriNastaleeq`.
- `test/`: unit and widget tests.
  - `test/helpers.dart`: `wrapInApp(widget, locale: …)` wraps a widget in the app theme and locale (Urdu by default); `testServices(server, settings, autoLockAfter, location, dialer, clock, secure)` builds the services (no automatic sync; `test/sync/auto_sync_test.dart` starts its own `AutoSync` with short intervals); `activateApp(services, server, pin:)` activates the phone with `testPin` and opens the app; `dbOf(services)` reaches the test database while the app is locked. Call `services.dispose()` in `tearDown`.
  - `test/support/memory_database_opener.dart`: an in-memory database that behaves like the encrypted file (it refuses another key and survives a lock). `test/data/encrypted_database_test.dart` checks the real encrypted file.
  - `test/support/fake_sync_server.dart` imitates the API's `/auth` (activation with `issueActivationCode()`, sign-in again, refresh tokens, supervisors; `replyCodeFor(challenge)` plays the portal's PIN-reset page) and `/sync` endpoints.
  - `test/screens/activation_flow_test.dart` runs the whole app through activation, the PIN, the lock screen and its countdown, PIN reset, the emergency call, deactivation, sign-in again, Change PIN and sign-out; `test/screens/registration_flow_test.dart` registers women offline through the four wizard steps, checks the risk factors on the file, and sorts the list nearest first.
  - `test/support/fake_location_service.dart` replaces the GPS and `test/support/fake_dialer.dart` the dialer; `testServices` uses both by default. `FakeSyncServer.holdIds` makes the server hold records as same-day conflicts, and `resolveHeld` plays the supervisor's decision.
  - `test/screens/server_setting_test.dart` changes the test build's server address (long press on the logo) on a small phone in both languages.
  - `test/screens/visit_flow_test.dart` records visits through the screens: required and impossible values, the range dialog and a held visit.
  - Change PIN, Lock, Sign out, the language list and the Phase 0 checks are in the settings: tests open them with `find.byTooltip(l10n.homeSettingsSection)`.
  - Drift, the PIN hash isolate and the fake HTTP client run outside the widget test clock: wrap those actions in `tester.runAsync`. To test the auto-lock timer, activate before `pumpWidget`, so the timer starts on the test clock; to test the wrong-PIN countdown, type the PIN on the test clock (`activation_flow_test.dart`).
  - `test/e2e/sync_e2e_test.dart` runs against a real API when given `--dart-define=E2E_API_BASE_URL=...`; it activates its test phones with codes from `admin.demo`, checks a PIN-reset reply code from `supervisor.demo`, registers synthetic women, records visits and makes one same-day conflict, which it decides as the admin.

## Commands

Run from `mobile/`:

```powershell
flutter pub get             # also generates AppLocalizations from the ARB files
dart run build_runner build # regenerate Drift code after changing lib/data tables
flutter analyze             # lint (CI)
flutter test                # unit and widget tests (CI)

# Run against the API on your laptop (find its Wi-Fi address with ipconfig):
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000/api/v1   # real phone, same Wi-Fi
flutter run                                                              # emulator: defaults to http://10.0.2.2:3000/api/v1

# The test APK, as .github/workflows/apk.yml builds it (needs the Android SDK; bash):
MEDIQORE_ALLOW_HTTP=true flutter build apk --release --dart-define=MEDIQORE_TEST_BUILD=true --dart-define=API_BASE_URL=http://192.168.1.10:3000/api/v1
```
