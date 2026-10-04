# 0005. Urdu/English language switch, with voice guidance in Urdu only

- **Status:** Accepted (scope amendment A1)
- **Date:** 2026-10-04
- **Approved by:** Ma'am Sajida Kalsoom (supervisor), as reported by the team on 2026-10-04
- **Scope:** new M1 FE-4; amends M3 FE-3, LI-6 and the Tools table
- **Roadmap:** amendment A1 (Phase 1 task under Module 1, conventions, exit gate, testing, definition of done)

## Decision

The LHW app can be used in **Urdu (default)** or **English**.

1. **Choosing the language.**
   - The LHW chooses it with a switch that shows **اردو** and **English**, each in its own script, so a reader of either language can find it.
   - In Phase 0 the switch is on the Phase 0 home screen. Phase 1 puts it on the login screen and in settings.
2. **Effect.** Changing the language switches every screen at once:
   - Urdu: Jameel Noori Nastaleeq, right to left;
   - English: the phone's standard Latin font, left to right;
   - numeric vitals stay left to right in both.
3. **Saving.** The choice is kept on the phone and used again at the next start.
4. **Voice guidance** (M3 FE-3) **works only in Urdu.** While the app is in English it is switched off, and screens that offer it say so. The spoken labels exist in Urdu only (LI-6).

## Where the choice is stored, and why

The language is stored with **shared_preferences** (Flutter team package), not in the app's Drift database.

- From Phase 1 the local database is encrypted with a key derived from the LHW's password (LI-8). The login screen must show the right language **before** that password is entered, so the setting has to live outside the encrypted database.
- shared_preferences is plain app storage, so it holds **device settings only, never patient data** (roadmap: "nothing patient-related in plain shared storage").
- It was not in the scope's Tools table. Amendment A1 adds it.

## What was built (end of Phase 0)

| Part | File |
|---|---|
| Settings: language, saved choice, voice rule (`voiceGuidanceAvailable`) | `mobile/lib/settings/app_settings.dart` |
| Switch widget | `mobile/lib/widgets/language_switch.dart` |
| App follows the setting (locale, direction, theme) | `mobile/lib/app.dart`, `mobile/lib/theme/app_theme.dart` |
| Saved choice read before the first frame | `mobile/lib/main.dart` |
| Voice check speaks only in Urdu | `mobile/lib/screens/voice_check_screen.dart` |
| Tests: settings, switch, English theme, voice off in English, small phone in English | `mobile/test/` |

Building this also fixed a font bug from P0-2: the large buttons' text style had no font family, so their Urdu labels would have fallen back to the system font instead of Nastaleeq.

## Still open

- **The emergency screen's Urdu voice announcement** (M5 FE-4, Phase 2) is not voice *guidance*. Should it also be silent in English? It is a safety feature, so this needs a team decision; until then the amendment covers voice guidance only.
- **The Word scope document and `roadmap.pdf`** need the same changes before final submission. The Markdown copies list them under "Amendments after approval".
- **Phase 1 screens** (P0-7) need the switch on the login screen and in LHW home settings. `docs/design/phase1-screens.md` now says so; update the Figma frames to match.

## Sign-off

| Name | Role | Decision | Date |
|---|---|---|---|
| Ma'am Sajida Kalsoom | Supervisor | Approved (as reported) | 2026-10-04 |
| Muhammad Zain Abbas | Team (mobile) | | |
| Zain Ali | Team | | |
