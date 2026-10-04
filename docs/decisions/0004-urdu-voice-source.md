# 0004. Source of the Urdu voice

- **Status:** Proposed, waiting for the phone results below
- **Date:** 2026-10-03
- **Scope:** M3 FE-3 (voice guidance reads Urdu field labels), LI-6; Tools table: flutter_tts
- **Roadmap:** Risks and decisions, row 4: "Check the test phones; if missing, record short Urdu clips for the fixed field labels and play those instead"; "Urdu and voice": "check whether the test phones have an Urdu text-to-speech voice in Phase 0"

## Context

Voice guidance (M3 FE-3) reads each field's Urdu label aloud when it gets focus, through flutter_tts and the phone's text-to-speech engine. Many Android phones have no Urdu voice installed. LHWs work offline, so the voice must also work without internet.

This can only be settled on the real test phones. The deciding check is therefore a human task. The app now includes a tool for it.

## The voice check screen

From the app's Phase 0 home, open **اردو آواز کی جانچ** (Urdu voice check), in `mobile/lib/screens/voice_check_screen.dart`. It asks the phone's text-to-speech engine for:

| Line on screen | Question |
|---|---|
| آواز کا انجن اردو (ur-PK) کو سپورٹ کرتا ہے | Does the engine support Urdu (`ur-PK`)? |
| اردو آواز کا ڈیٹا فون پر موجود ہے (آف لائن چلتا ہے) | Is the Urdu voice data installed on the phone, so it works offline? |
| اردو آوازیں | Which Urdu voices are installed? |
| بنیادی آواز کا انجن / فون پر موجود آواز کے انجن | The default engine and the installed engines |

The **نمونے کا لیبل سنائیں** button (speak a sample label) reads a real field label, اوپر والا بلڈ پریشر (systolic blood pressure), the way voice guidance will.

## Procedure for each test phone

1. Install the debug build:
   ```powershell
   cd mobile
   flutter run
   ```
2. Keep the app in **Urdu** (the voice check speaks only in Urdu, decision 0005). Turn on **airplane mode**, the LHW's normal condition, and open the voice check.
3. Write the results in the table below, then tap the sample button and note whether you heard clear, understandable Urdu.
4. If Urdu is not installed, install it while online:
   1. Open Android **Settings → System → Languages → Text-to-speech output**. The path differs between brands.
   2. Open the engine's settings, then **Install voice data**, and look for **Urdu**.
   3. Turn airplane mode on again and run the check again. Note the result as a second row for the phone, "after install".
5. Add the phone's model and Android version. Test at least one low-cost phone like those LHWs use.

## Results

| Phone model | Android | Default engine | Supports Urdu | Installed (offline) | Urdu voices | Heard clear Urdu offline? | Notes |
|---|---|---|---|---|---|---|---|
| | | | | | | | |
| | | | | | | | |

## Options

1. **Phone text-to-speech (flutter_tts, Tools table).** No audio files and no new library; any label can be read. It depends on each phone's voice data, which LHW device setup could install once.
2. **Recorded clips** for the fixed field labels, played offline.
   - The team records each label in Urdu (native speakers) and bundles the clips as app assets.
   - This needs an audio player package, which is **not in the Tools table** (for example `audioplayers` or `just_audio`), and a clip for every label that is read aloud.
3. **Both:** text-to-speech when the check passes on the phone, clips otherwise. This needs the most work.

## Proposed decision rule

- **If every test phone speaks clear Urdu offline** (after the one-time voice data install, if needed): choose option 1.
  - Add "install Urdu voice data" to the LHW device setup steps in the user guide.
  - The app checks for the Urdu voice at start-up. Without it, the app keeps working without sound and shows a notice.
- **If any phone cannot:** choose option 2, and ask the supervisor to approve the audio player package.
- In both cases, LI-6 still applies: the guidance is in Urdu only.

## Sign-off

| Name | Role | Decision | Date |
|---|---|---|---|
| Muhammad Zain Abbas | Team (M3 FE-3 owner) | | |
| Zain Ali | Team | | |
