# mobile/: LHW Android app

Flutter app with Modules 1–9, fully offline, in Urdu by default with an English option (M1 FE-4), plus the supervisor alert role. Follow the root `CLAUDE.md` first; this file only adds what is specific to `mobile/`.

## Stack (scope Tools table)

| Tool | Version | Purpose |
|---|---|---|
| Flutter | 3.x; this project needs 3.47 or newer (`pubspec.yaml`) | Android app with Urdu UI (English selectable), voice guidance and offline support (Android only, LI-1) |
| SQLite via Drift | Latest | Offline local storage |
| sqflite_sqlcipher | Latest | AES-256 encryption of the local database |
| flutter_localizations + intl | Latest | RTL locale, Urdu support, bidirectional text; English left to right (A1) |
| shared_preferences | Latest | Keeps the chosen interface language on the phone, readable before login (scope amendment A1); never patient data |
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

- geolocator is used for household GPS (M2 FE-3).
- Tests use flutter_test (unit and widget).
- The app is distributed as a signed APK, not through the Play Store.

## Key rules

- No visible string in Dart code: every label goes in the ARB files, with an Urdu and an English entry. Users see both (M1 FE-4).
- The language comes from `AppSettings` (`services.settings`): Urdu by default, English selectable.
  - Test every new screen in both languages, including on a 320 × 640 phone.
  - Don't hard-code a font family or text direction; the theme and locale set them. The exception is text that must stay in one script, such as اردو on the language switch, and numbers, which stay left to right.
- Voice guidance speaks only when `AppSettings.voiceGuidanceAvailable` is true (Urdu). In English, show `voiceGuidanceUrduOnly` instead.
- shared_preferences holds device settings only. Patient data goes in the encrypted database.
- Every write goes to its local table and to the outbox in the same transaction.
- Generate record IDs as UUID v4 on the device; order by `server_seq`, never by device clock.
- Read clinical thresholds (danger signs, EPI, MUAC, IMCI) from versioned JSON config, never hard-code them.

## Layout

- `lib/main.dart` → `lib/app.dart`:
  - `main()` reads the saved language (`AppSettings.load()`) before the first frame.
  - `MediQoreApp` rebuilds `MaterialApp` whenever the language changes. Its locale and theme follow `AppSettings`: Urdu right to left, English left to right.
- `lib/settings/app_settings.dart`: `AppSettings` (M1 FE-4), with the language, the saved choice and the voice rule.
  - Saved through `SharedPreferencesStore`.
  - Tests use `MemorySettingsStore`.
- `lib/widgets/language_switch.dart`: the اردو / English switch. It is on the Phase 0 home now; Phase 1 puts it on the login screen and in settings.
- `lib/l10n/app_en.arb` (template, with descriptions) and `lib/l10n/app_ur.arb` hold every visible string. Add new keys to both files.
  - `AppLocalizations` is generated from them by `flutter pub get` into `lib/l10n/app_localizations*.dart`, which is git-ignored.
  - Use it as `AppLocalizations.of(context).key`.
- `lib/theme/`:
  - `AppTheme.light(urdu: …)`: 64 dp controls in both languages. Urdu uses the Nastaleeq font with a taller line height; English uses the standard Latin font.
  - `AppColors`: the Green/Yellow/Red risk colours.
- `lib/widgets/`: the shared kit.
  - `LargeButton`
  - `AppTextField`, `VitalField` (numbers and unit always left to right, digits only), `CheckboxField`, `DropdownField`
  - `RiskChip` with `RiskLevel`
  - `OfflineStatusBar`
- `lib/app_services.dart`: the settings, database, API client, repositories and sync service, created once in `main()`. Tests build them with an in-memory database and Urdu settings kept in memory (`testServices()` in `test/helpers.dart`).
- `lib/data/`:
  - `app_database.dart`: the Drift database with `households`, `outbox` and `sync_state`.
    - `app_database.g.dart` is generated and committed. After changing tables, run `dart run build_runner build` and bump `schemaVersion` with a migration.
    - Encryption (sqflite_sqlcipher, M3 FE-2) comes in Phase 1.
  - `household_repository.dart`: every write saves the record and its outbox entry in one transaction, with a UUID v4 made on the device.
- `lib/sync/`:
  - `sync_api.dart`: the `/auth/login` and `/sync` client. Responses are always decoded as UTF-8.
  - `sync_service.dart`:
    - push sends the outbox in batches of up to 100, highest priority first, then stores each `serverSeq`;
    - pull fetches everything after the last server number seen;
    - records the server refuses stay on the phone, marked with `lastError`.
- `lib/screens/`: temporary Phase 0 screens. The Phase 1 login screen replaces `DevHomeScreen` as home.
  - `dev_home_screen.dart`: the Phase 0 home.
  - `widget_kit_screen.dart`: the P0-2 kit preview.
  - `sync_test_screen.dart`: the P0-6 end-to-end check (sign in as an LHW, create a synthetic household offline, sync).
  - `voice_check_screen.dart`: the P0-11 Urdu voice check (flutter_tts).
    - It reports whether the phone's text-to-speech supports Urdu offline and speaks a sample label, only while the app is in Urdu.
    - Results go in `docs/decisions/0004-urdu-voice-source.md`.
- `android/app/src/debug/AndroidManifest.xml` allows plain HTTP to a development server in debug builds only; release builds are HTTPS-only.
- `android/app/src/main/AndroidManifest.xml` declares the `TTS_SERVICE` query, so flutter_tts can find the phone's text-to-speech engines on Android 11 and later.
- `assets/fonts/JameelNooriNastaleeq.ttf`: the bundled Urdu font, declared in `pubspec.yaml` as family `JameelNooriNastaleeq`.
- `test/`: unit and widget tests.
  - `test/helpers.dart`: `wrapInApp(widget, locale: …)` wraps a widget in the app theme and locale (Urdu by default); `testServices(server, settings)` builds the services.
  - `test/support/fake_sync_server.dart` imitates the API's `/auth` and `/sync` endpoints.
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
```
