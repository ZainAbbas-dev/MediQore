# mobile/: LHW Android app

Flutter app with Modules 1–9, in Urdu and fully offline, plus the supervisor alert role. Follow the root `CLAUDE.md` first; this file only adds what is specific to `mobile/`.

## Stack (scope Tools table)

| Tool | Version | Purpose |
|---|---|---|
| Flutter | 3.x | Android app with Urdu UI, voice guidance and offline support (Android only, LI-1) |
| SQLite via Drift | Latest | Offline local storage |
| sqflite_sqlcipher | Latest | AES-256 encryption of the local database |
| flutter_localizations + intl | Latest | RTL locale, Urdu support, bidirectional text |
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

- No visible string in Dart code: every label goes in the ARB files, with an Urdu and an English entry.
- Every write goes to its local table and to the outbox in the same transaction.
- Generate record IDs as UUID v4 on the device; order by `server_seq`, never by device clock.
- Read clinical thresholds (danger signs, EPI, MUAC, IMCI) from versioned JSON config, never hard-code them.

## Commands

<!-- Fill in when P0-2 creates the project. -->
