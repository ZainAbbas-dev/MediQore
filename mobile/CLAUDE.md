# mobile/: LHW Android app

Flutter app with Modules 1–9, fully offline, in Urdu by default with an English option (M1 FE-4), plus the supervisor alert role. Follow the root `CLAUDE.md` first; this file only adds what is specific to `mobile/`.

## Stack (scope Tools table)

| Tool | Version | Purpose |
|---|---|---|
| Flutter | 3.x; this project needs 3.47 or newer (`pubspec.yaml`) | Android app with Urdu UI (English selectable), voice guidance and offline support (Android only, LI-1) |
| SQLite via Drift | Latest | Offline local storage |
| sqflite_sqlcipher | Latest | AES-256 encryption of the local database. Built instead with the SQLite3 Multiple Ciphers build of `package:sqlite3` (SQLCipher format, AES-256), because sqflite_sqlcipher cannot back Drift: proposed decision 0006 |
| flutter_localizations + intl | Latest | RTL locale, Urdu support, bidirectional text; English left to right (A1) |
| shared_preferences | Latest | Keeps the chosen interface language (scope amendment A1), the installation ID and the saved account for offline sign-in, all readable before login; never patient data |
| crypto (dart.dev) | Latest | HMAC-SHA256 for the PBKDF2 password key behind offline sign-in (roadmap M1 FE-2, LI-8) |
| Jameel Noori Nastaleeq (bundled asset) | N/A | Urdu Nastaliq font for all Urdu text |
| Flutter Directionality widget | N/A | RTL context for Urdu, with numeric vitals left to right |
| flutter_tts | Latest | Urdu voice guidance for field labels |
| onnxruntime | Latest | On-device inference of the exported risk model |
| JSON lookup table (asset) | N/A | SHAP-derived Urdu explanations, bundled at build time |
| fl_chart | Latest | Vital trend graphs |
| google_mlkit_text_recognition | Latest | Offline OCR of hospital reports |
| camera + image_picker | Latest | Report capture from camera or gallery |
| image | Latest | Grayscale and contrast preprocessing before OCR |
| Custom Dart regex engine | - | Clinical value extraction from OCR text |
| Firebase Cloud Messaging + flutter_local_notifications | Latest | Layer 1 emergency push and local notifications |
| another_telephony + flutter_phone_direct_caller + permission_handler | Latest | Layer 2 SMS and Layer 3 call, without internet |
| connectivity_plus + workmanager | Latest | Emergency alert record sync in the background |

From the roadmap:

- geolocator is used for household GPS (M2 FE-3), behind `LocationService` (`lib/location/location_service.dart`). It needs the location permissions in `AndroidManifest.xml`; GPS works without the internet, but a first fix can take a minute.
- Tests use flutter_test (unit and widget).
- The app is distributed as a signed APK, not through the Play Store.

## Key rules

- No visible string in Dart code: every label goes in the ARB files, with an Urdu and an English entry. Users see both (M1 FE-4).
- The language comes from `AppSettings` (`services.settings`): Urdu by default, English selectable.
  - Test every new screen in both languages, including on a 320 × 640 phone.
  - Don't hard-code a font family or text direction; the theme and locale set them. The exception is text that must stay in one script, such as اردو on the language switch, and numbers, which stay left to right.
- Voice guidance (M3 FE-3) speaks only when `AppSettings.voiceGuidanceAvailable` is true (Urdu) and the LHW has not muted it (`voiceMuted`). In English, show `voiceGuidanceUrduOnly` instead. Fields are read aloud only inside a `VoiceScope`.
- shared_preferences holds device settings only: the language, the installation ID and the saved account (user profile, PBKDF2 salt and verifier; never the password or a token). Patient data goes in the encrypted database.
- Tokens stay in memory (`Session`). A locked app forgets them and the password key, and closes the database.
- The database is encrypted and opens only after sign-in (M3 FE-2): use `services.db`, `services.patients` and so on only while the app is unlocked; they throw while it is locked.
- Every write goes to its local table and to the outbox in the same transaction.
- Generate record IDs as UUID v4 on the device; order by `server_seq`, never by device clock.
- Read clinical thresholds (danger signs, EPI, MUAC, IMCI) from versioned JSON config, never hard-code them. The visit form's ranges are in `assets/clinical/visit_ranges.json`; its `allowed` ranges must equal the server's bounds in `api/src/sync/tables.js` (`api/tests/visit-ranges.test.js` checks this).
- Records sync on their own while the app is unlocked after an online sign-in (`AutoSync`); nothing syncs while it is locked, because the database is closed.
- The server address is fixed at build time (`API_BASE_URL`), and release builds are HTTPS-only (M1 FE-2). The one exception is the test APK (`testBuild` in `lib/build_flags.dart`, set with `--dart-define=MEDIQORE_TEST_BUILD=true` by `.github/workflows/apk.yml`):
  - its sign-in screen shows the server address with **Change server** (`LoginScreen.showServerSetting`, saved as `AppSettings.serverAddress`);
  - it allows plain HTTP, because the workflow sets `MEDIQORE_ALLOW_HTTP=true` for `android/app/build.gradle.kts`;
  - it shows the Phase 0 checks in the settings.
  Never ship a test build to LHWs.
- Layout: build screens from the shared pieces (`lib/widgets/app_cards.dart`, the theme) so every screen looks the same: a teal app bar, white `SectionCard`s on the grey background, `InfoRow` for label and value, `SyncStatusChip` for a record's sync state, `NoticeCard` for messages. Data entry screens have `LiveStatusBar` at the top, a `VoiceScope` around the form and `VoiceMuteButton` in the app bar.

## Layout

- `lib/main.dart` → `lib/app.dart`:
  - `main()` reads the saved settings (`AppSettings.load()`) and the visit ranges (`VisitRanges.load()`) before the first frame.
  - `MediQoreApp` rebuilds `MaterialApp` whenever the language changes. Its locale and theme follow `AppSettings`: Urdu right to left, English left to right.
  - It shows `LoginScreen` until someone signs in, then `HomeScreen`. When the session locks, it closes every open screen.
  - `InactivityLock` (`lib/widgets/inactivity_lock.dart`) wraps every screen and locks the session after `autoLockAfter` (5 minutes) without a touch (M1 FE-2).
- `lib/settings/app_settings.dart`: `AppSettings` (M1 FE-4, FE-2), with the language, the saved choice, the voice rule, the voice guidance mute (`voiceMuted`, M3 FE-3) and the installation ID (`deviceId`, a UUID v4 made once).
  - Saved through `SharedPreferencesStore`; only the keys in `AppSettings.storedKeys`.
  - Tests use `MemorySettingsStore`.
- `lib/auth/` (M1 FE-2, FE-3):
  - `session.dart`: `Session`, who is signed in.
    - `signIn` tries the server first. A new phone gets `needsCode`, then `verifyCode`. Without a connection (or on a server error) it checks the password against the saved key instead.
    - The first online sign-in, or one after an admin moved the LHW to another area, downloads the area's records.
    - Another LHW cannot sign in while the phone holds unsynced records of the previous one.
    - `sync()` uses the session's tokens and refreshes them once on 401. `ACCOUNT_INACTIVE` marks the saved account deactivated and locks the app; offline sign-in is refused from then on.
    - `lock()` and `signOut()` (which also revokes the refresh token).
  - `password_key.dart`: PBKDF2-HMAC-SHA256 (120,000 iterations, in a background isolate). The phone keeps the salt and a verifier, never the password. The derived key opens the encrypted database (M3 FE-2).
  - `Session` opens the database at sign-in (`data`, a `LocalData`) and closes it at lock. A new password means a new key: the old database is deleted and downloaded again, and `lostUnsyncedRecords` tells the home screen if unsynced records were lost (LI-8). The number of waiting records is kept in `AppSettings.pendingRecords` for the checks before sign-in.
  - `local_account.dart`: the signed-in user's profile and password key, saved for offline sign-in.
- `lib/widgets/language_switch.dart`: `LanguageToggle`, the button at the top of the sign-in screen that shows the other language, and `LanguageChoice`, the list in the settings. Each language name is written in its own script.
- `lib/l10n/app_en.arb` (template, with descriptions) and `lib/l10n/app_ur.arb` hold every visible string. Add new keys to both files.
  - `AppLocalizations` is generated from them by `flutter pub get` into `lib/l10n/app_localizations*.dart`, which is git-ignored.
  - Use it as `AppLocalizations.of(context).key`.
- `lib/theme/`:
  - `AppTheme.light(urdu: …)`: 64 dp buttons in both languages, a teal app bar, white cards with a thin border, white fields. In Urdu the font is the phone's Latin font (`sans-serif`) with Nastaleeq as the fallback, so Urdu letters are Nastaliq and Latin text and digits keep the standard font; the line height is taller. English uses the standard Latin font.
  - `AppColors`: the brand teal, background, border and muted text colours, the status colours (offline, waiting, synced, problem) and the Green/Yellow/Red risk colours.
- `lib/widgets/`: the shared kit.
  - `LargeButton`
  - `AppTextField`, `VitalField` (numbers and unit always left to right; digits and up to `decimals` decimals; a keystroke that does not fit is ignored), `CheckboxField`, `DropdownField`. Inside a `VoiceScope` each reads its label aloud on focus (a checkbox or dropdown on tap) and shows a speaker while focused (M3 FE-3).
  - `NumberField` (whole numbers without a unit, digits only, left to right)
  - `RiskChip` with `RiskLevel`
  - `OfflineStatusBar`, and `LiveStatusBar`, which follows `AutoSync` and counts the waiting records itself
  - `app_cards.dart`: `SectionCard`, `InfoRow`, `SyncStatusChip`, `StatusPill`, `NoticeCard`, `InitialAvatar`, `VoiceMuteButton`
  - `GpsCapture` (M2 FE-3): records a position with its status and the reason it failed
  - `VoiceSetting` (M3 FE-3): the voice guidance switch and **Test the voice** in the settings (with install steps when the phone has no Urdu voice), or the Urdu-only note in English
  - `syncStatusText()`: the words for waiting, refused and held records
- `lib/app_services.dart`: the settings, database, API client, repositories, sync service, session, automatic sync, voice guidance and visit ranges, created once in `main()`. Tests build them with an in-memory database, Urdu settings kept in memory, a fast password key, a fake voice and no automatic sync (`testServices()` in `test/helpers.dart`).
- `lib/clinical/visit_ranges.dart` (M3 FE-1): `VisitRanges` from `assets/clinical/visit_ranges.json`. Per vital: `allowed` (outside it the value is impossible and cannot be saved), `plausible` (outside it the LHW confirms the value) and `decimals`. The file is versioned and marked as a draft for clinical advisor review.
- `lib/voice/voice_guide.dart` (M3 FE-3): `Voice` (`TtsVoice` with flutter_tts: it asks for `ur-PK`, then any Urdu; when the default engine has none it tries the phone's other engines, such as Google's; a failure is retried at the next label; it stays silent when no engine has Urdu), `VoiceGuidance` (speaks only in Urdu and unmuted; muting stops it; `test()` speaks a sample for the settings) and `VoiceScope`.
- `lib/data/`:
  - `app_database.dart`: the Drift database (schema version 3) with `households`, `women`, `pregnancies`, `obstetric_history` (M2), `visits` (M3), `outbox` and `sync_state`.
    - Every synced table has the base columns, including `areaId` (the area the record was made in, M1 FE-3) and `createdBy`.
    - No foreign keys between synced tables: a pulled woman can arrive before her household.
    - `enqueue(payload)` adds or replaces a record's outbox entry; `setServerSeq`, `clearAreaData` and `clearAllData` work on every synced table.
    - The patient counter: `raisePatientCounter` (from the server's `lastPatientNumber` at sign-in) and `takePatientNumber`.
    - `app_database.g.dart` is generated and committed. After changing tables, run `dart run build_runner build`, bump `schemaVersion` and add the step to `migration` (see `test/data/migration_test.dart`).
    - On the phone it is opened only through `database_opener.dart` (M3 FE-2, decision 0006): `EncryptedDatabaseOpener` sets AES-256 in the SQLCipher format with the raw password key, refuses a wrong key (`WrongDatabaseKey`) and encrypts an older unencrypted database in place.
    - `local_data.dart`: the open database with its repositories and sync service, which exist only while the app is unlocked.
  - `household_repository.dart`: every write saves the record and its outbox entry in one transaction, with a UUID v4 made on the device. `setLocation` adds GPS later.
  - `patient_repository.dart` (M2 FE-1–3):
    - `register` saves the household (or reuses a registered woman's home), the woman, her pregnancy file and her obstetric history with their outbox entries in one transaction, parents first.
    - The patient ID is the LHW code plus the phone's counter, for example `LHW-00001-0007`, the same form as the synthetic data.
    - `list(search:)` sorts by village, then name; `file(id)` gives the whole pregnancy file. Both report whether the woman is synced, waiting or refused.
  - `visit_repository.dart` (M3 FE-1): `record` saves a visit and its outbox entry in one transaction; `forPregnancy` lists the visits, latest first by server number, then the unsynced ones in the order saved (never by phone clock), each with its `SyncStatus` (synced, waiting, refused or held). Vitals are stored in one unit each: mmHg, kg, °C, beats per minute, mmol/L.
- `lib/sync/`:
  - `sync_api.dart`: the `/auth` (login, code check, refresh, logout) and `/sync` client. Responses are always decoded as UTF-8.
  - `sync_service.dart`:
    - push sends the outbox in batches of up to 100, highest priority first, then stores each `serverSeq`;
    - pull fetches everything after the last server number seen;
    - records the server refuses stay on the phone, marked with `lastError`;
    - a visit the server holds for supervisor review (status `conflict`, M3 FE-2) leaves the outbox and gets `conflictId`; the decision arrives by pull, which clears it (a duplicate arrives deleted). `SyncReport.held` counts them.
  - `auto_sync.dart` (M3 FE-2): `AutoSync` syncs while the app is unlocked after an online sign-in: a few seconds after a save, every two minutes (the retry) and when the app returns to the foreground. `run()` is also the Sync button; `Session.sync()` joins a sync that is already running, so the refresh token is never used twice. True background sync with the app closed is not possible: the database key exists only while the app is unlocked (LI-8).
- `lib/screens/`:
  - `login_screen.dart` (M1 FE-2, FE-4): a teal header with the app's name and the language button, then LHW ID and password in a card. `signInMessage()` turns each `SignInResult` into its text.
  - `otp_screen.dart` (M1 FE-2, decision 0002): the 6-digit code for a new phone, with the last six characters of the installation ID so the portal user can match the phone.
  - `home_screen.dart`: the status strip, who is signed in, the task cards for registration and the patient list (LHWs only) and the Sync card (the status strip follows `AutoSync`). The gear icon in the app bar opens the settings.
  - `settings_screen.dart` (M1 FE-4, M3 FE-3, M1 FE-2): the language, voice guidance (LHWs), the account with Lock and Sign out, and in debug builds and test APKs the server address and the Phase 0 checks.
  - `register_screen.dart` (M2 FE-1–3, M3 FE-3): the registration form on one page, a card per section, with voice guidance and the mute button. It uses a `Column` in a `SingleChildScrollView`, not a `ListView`, so every field is built and validated. Then `registration_saved_screen.dart` shows the new patient ID.
  - `patient_list_screen.dart` (M2 FE-3): search and village groups. `patient_file_screen.dart`: the pregnancy file, with "record home location" when GPS is missing, the **New visit** button for an active pregnancy and the visits with their sync state (M3).
  - `visit_screen.dart` (M3 FE-1, FE-3, P0-7 screen 4): the visit form in one `Column` in a `SingleChildScrollView`. Every vital but blood sugar is required; impossible values show the allowed range; values outside the usual range open a dialog that lists them ("correct them" or "yes, save"). The status bar is at the top and the mute toggle in the app bar (Urdu only). It closes with the saved visit, and the file shows "saved on the phone".
  - Phase 0 checks, reached from the settings in debug builds and test APKs only:
    - `dev_home_screen.dart`: the list of checks.
    - `widget_kit_screen.dart`: the P0-2 kit preview.
    - `sync_test_screen.dart`: the P0-6 end-to-end check (create a synthetic household offline, sync with the session).
    - `voice_check_screen.dart`: the P0-11 Urdu voice check (flutter_tts).
      - It reports whether the phone's text-to-speech supports Urdu offline and speaks a sample label, only while the app is in Urdu.
      - Results go in `docs/decisions/0004-urdu-voice-source.md`.
- `android/app/build.gradle.kts` sets the manifest's `usesCleartextTraffic` placeholder: plain HTTP to a development server in debug builds, and in a release build only when `MEDIQORE_ALLOW_HTTP=true` (the test APK). Other release builds are HTTPS-only.
- `.github/workflows/apk.yml` builds the test APK after each push to `dev` that changes `mobile/`, or on **Run workflow** with a starting server address, and attaches it to the run.
- `android/app/src/main/AndroidManifest.xml` declares the `TTS_SERVICE` query, so flutter_tts can find the phone's text-to-speech engines on Android 11 and later.
- `assets/fonts/JameelNooriNastaleeq.ttf`: the bundled Urdu font, declared in `pubspec.yaml` as family `JameelNooriNastaleeq`.
- `test/`: unit and widget tests.
  - `test/helpers.dart`: `wrapInApp(widget, locale: …)` wraps a widget in the app theme and locale (Urdu by default); `testServices(server, settings, autoLockAfter, location, voice)` builds the services (no automatic sync; `test/sync/auto_sync_test.dart` starts its own `AutoSync` with short intervals); `signInApproved(services, server)` signs in on an already approved phone; `dbOf(services)` reaches the test database while the app is locked. Call `services.dispose()` in `tearDown`.
  - `test/support/memory_database_opener.dart`: an in-memory database that behaves like the encrypted file (it refuses another key and survives a lock). `test/data/encrypted_database_test.dart` checks the real encrypted file.
  - `test/support/fake_sync_server.dart` imitates the API's `/auth` (with phone approval and refresh tokens) and `/sync` endpoints.
  - `test/screens/login_flow_test.dart` runs the whole app from sign-in to home and back; `test/screens/registration_flow_test.dart` registers women offline through the screens.
  - `test/support/fake_location_service.dart` replaces the GPS and `test/support/fake_voice.dart` the text-to-speech (it records what would be spoken); `testServices` uses both by default. `FakeSyncServer.holdIds` makes the server hold records as same-day conflicts, and `resolveHeld` plays the supervisor's decision.
  - `test/screens/server_setting_test.dart` changes the test build's server address on a small phone in both languages.
  - `test/screens/visit_flow_test.dart` records visits through the screens: required and impossible values, the range dialog, voice guidance on focus (also on the registration form), mute and English, the voice settings and **Test the voice**, and a held visit.
  - Lock, Sign out, the language list, voice guidance and the Phase 0 checks are in the settings: tests open them with `find.byTooltip(l10n.homeSettingsSection)`.
  - Drift, the password key isolate and the fake HTTP client run outside the widget test clock: wrap those actions in `tester.runAsync`. To test the auto-lock timer, sign in before `pumpWidget`, so the timer starts on the test clock.
  - `test/e2e/sync_e2e_test.dart` runs against a real API when given `--dart-define=E2E_API_BASE_URL=...`; it approves its test phones as `admin.demo`, registers synthetic women, records visits and makes one same-day conflict, which it decides as the admin.
  - Plugins are faked at their method channel, for example the `flutter_tts` channel in `test/screens/voice_check_screen_test.dart`.

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
