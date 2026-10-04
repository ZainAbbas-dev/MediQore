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

## Emergency voice announcement (M5 FE-4)

The emergency screen's voice announcement (M5 FE-4, Phase 2) is a safety alert, not voice *guidance*, so the A1 rule above does not switch it off. The project owner asked for the option that suits the app best (2026-10-04). Proposed:

- **It stays on in both languages.** Turning it off in English would weaken a safety feature for every LHW who chooses English.
- **It speaks the app's language:** Urdu while the app is in Urdu, from the source decision 0004 chooses; English while the app is in English, from the phone's English text-to-speech, which Android phones include and which works offline.
- **The screen, its checklist and the three alert options** do not depend on the voice, so the emergency workflow still works on a phone whose speech engine fails.

The scope text says "an Urdu voice announcement", so the English part needs the supervisor's agreement before Module 5 is built in Phase 2. Until then nothing is built; Module 5 starts from this proposal.

## Still open

- **Emergency announcement in English:** the supervisor's agreement to the proposal above, before Phase 2.
- **The Word scope document and `roadmap.pdf`** need the same changes before final submission. The Markdown copies list them under "Amendments after approval".
- **Phase 1 screens** (P0-7) need the switch on the login screen and in LHW home settings. `docs/design/phase1-screens.md` now says so; update the Figma frames to match.

## Sign-off

| Name | Role | Decision | Date |
|---|---|---|---|
| Ma'am Sajida Kalsoom | Supervisor | Approved (as reported) | 2026-10-04 |
| Muhammad Zain Abbas | Team (mobile) | | |
| Zain Ali | Team | | |
