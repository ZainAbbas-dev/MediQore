# Phase 1 screens: final design (P0-7)

Roadmap task P0-7 asks for the Phase 1 screens: activation and PIN unlock, LHW home, registration, the visit form with the danger-sign checklist, Settings with the language switch, the dashboard home and the admin lists (scope Mockups 1, 2 and 6). The team chose the final design in October 2026: the **Option B layout in Clinical Teal, with the Option A settings gear**. This document is the brief for building the screens; the pictures in [`screens/`](screens/) are exported from the design canvas.

- **Design canvas:** "MediQore app design options" on claude.ai, page **Final design (Clinical Teal)**. It is private to the owner, who can share it from its Share menu. The page "Options A–D" keeps the four options the team compared.
- Everything here follows the updated scope and the roadmap of 10 Oct 2026. Names and numbers in the pictures are made up (LI-10).

## Design system

| Token | Value | Use |
|---|---|---|
| Clinical Teal | `#00695C` | Headers, primary buttons, selected states |
| Dark teal | `#004D40` | Text on light teal, pressed states |
| Light teal | `#C8EDE6` | Avatars, icon buttons, selected chips |
| Soft teal | `#E3F2EF` | Information panels |
| Background | `#F1F7F6` | Screen background |
| Text / muted text | `#17312D` / `#4F5E5B` | Body text / labels and hints |
| Field border / divider | `#B9C9C5` / `#E4ECEA` | Inputs / lines inside cards |
| Waiting / synced | `#8A4B08` on `#FFF1DC` / `#1E6B3A` on `#E3F4E8` | Sync state chips |
| Danger | `#B3261E` | Emergency call, a "yes" danger sign |

- **Shapes:** pill buttons 60 dp tall (radius 30); cards radius 20–24 with a soft teal shadow; fields radius 16–18; the teal header has rounded bottom corners (32–36).
- **Type:** Urdu in Jameel Noori Nastaleeq (the mock-ups on the canvas use Noto Nastaliq Urdu, the closest web font) with tall line height; Latin text and digits in the standard Latin font (Figtree on the canvas, the phone's font in the app). Numbers, IDs and units always read left to right.
- **Languages:** every screen is drawn in Urdu (right to left); the English version mirrors it left to right (M3 FE-3). The language switch lives in **Settings → Language**; the activation screen also has a language button so the first sign-in can happen in either language. Check each screen in both languages on a 320 × 640 phone.
- **No audio guidance** (LI-6): the app relies on written labels, large icons, pictures and colours.
- **In the app:** `AppTheme` and `AppColors` (`mobile/lib/theme/`) carry these tokens; `CurvedHeader`, `SectionCard`, `LargeButton`, `RiskChip`, `OfflineStatusBar` and the form fields (`mobile/lib/widgets/`) are the pieces to build with (P0-2). The portal uses the same teal (`web/src/styles.css`).

## Screens

| # | Screen | Picture | Scope |
|---|---|---|---|
| 1 | Activate this phone (first sign-in) | [01](screens/01-activate-this-phone-first-sign-in.png) | M1 FE-2 |
| 2 | Create a PIN | [02](screens/02-create-a-pin.png) | M1 FE-2 |
| 3 | Unlock with PIN (offline) | [03](screens/03-unlock-with-pin-offline.png) | M1 FE-2 |
| 4 | Wrong PIN: wait | [04](screens/04-wrong-pin-wait.png) | M1 FE-2 |
| 5 | Forgot PIN: supervisor reply code | [05](screens/05-forgot-pin-supervisor-reply-code.png) | M1 FE-2 |
| 6 | Home | [06](screens/06-home.png) | M2, M3 FE-2 |
| 7 | Settings (language) | [07](screens/07-settings-language.png) | M3 FE-3, M1 FE-2 |
| 8–11 | Registration, steps 1–4 | [08](screens/08-registration-step-1-woman.png), [09](screens/09-registration-step-2-pregnancy.png), [10](screens/10-registration-step-3-home.png), [11](screens/11-registration-step-4-history.png) | M2 FE-1–3, Mockup 1 |
| 12 | Registration saved | [12](screens/12-registration-saved.png) | M2 FE-1 |
| 13 | Registered women | [13](screens/13-registered-women.png) | M2 FE-3 |
| 14 | Pregnancy file | [14](screens/14-pregnancy-file.png) | M2 FE-1, FE-2 |
| 15 | Visit, step 1: measurements | [15](screens/15-visit-step-1-measurements.png) | M3 FE-1, Mockup 2 |
| 16 | 30-second pulse counter | [16](screens/16-30-second-pulse-counter.png) | M3 FE-1 |
| 17 | Visit, step 2: signs | [17](screens/17-visit-step-2-signs.png) | M3 FE-1 |
| 18 | Visit, step 3: danger-sign checklist | [18](screens/18-visit-step-3-danger-sign-checklist.png) | M3 FE-1, M4 FE-4, Mockup 2 |
| 19 | Unusual value check | [19](screens/19-unusual-value-check.png) | M3 FE-1 |
| 20 | Portal: dashboard home | [20](screens/20-portal-dashboard-home.png) | M10 FE-1, Mockup 6 |
| 21 | Portal: LHW accounts and activation code | [21](screens/21-portal-lhw-accounts-and-activation-code.png) | M10 FE-3, M1 FE-1–3 |

### Activation, PIN unlock and PIN reset (screens 1–5)

- **Activation (1)** happens once per phone, online: LHW ID, password and the one-time activation code the admin generated (about eight characters, valid 48 hours, single use). The note says the internet is needed only this once.
- **Create a PIN (2):** six digits, typed twice, on a large left-to-right keypad. The note says the PIN can be reset offline with a supervisor reply code.
- **Unlock (3)** is fully offline: the LHW's name, six dots, the keypad, **Forgot PIN?** and, always at the bottom, **Emergency: call supervisor**, so a lock never blocks an escalation.
- **Wrong PIN (4):** progressive delays of 30 seconds, 1 minute, 5 minutes and 15 minutes with a countdown; the keypad is disabled, but the emergency call and **Forgot PIN?** stay usable. There is never a lockout that needs internet.
- **PIN reset (5):** step 1 shows a short code to read to the supervisor; step 2 takes the reply code the supervisor reads back from the portal. The phone checks it with the secret it received at activation, without internet; the local data is kept.

### Home, settings and registration (screens 6–14)

- **Home (6):** teal header with the greeting, the LHW's name and ID and the settings gear; a sync card over the header's edge with the connection state, the number of records waiting to sync and **Sync now**; task cards for a new registration and the registered women; recent visits with their sync state.
- **Settings (7):** the account, **Language** (اردو / English, each in its own script, saved on the phone), and the account actions: **Change PIN**, lock and sign out.
- **Registration (8–11):** a four-step wizard with a progress bar: the woman (name, age, husband's name, contact), the pregnancy (month, chosen from a 1–9 grid), the home (village, address, GPS) and the obstetric history (previous pregnancies, C-sections, stillbirths with − and + counters, known conditions). **Saved (12)** shows the offline patient ID (LHW code plus the phone's counter).
- **Registered women (13)** are grouped by village with search, or sorted **nearest first** by the estimated distance from the LHW's GPS position (M2 FE-3); **the pregnancy file (14)** shows age, month, visits, the visit history with sync state, **New visit** and, under it, the risk factors the Clinical Rules Table finds in her history (M2 FE-2; they never change the risk colour).

### Home visit (screens 15–19)

- **Step 1, measurements (15):** BP (upper and lower), weight, temperature and pulse, each with its unit. Pulse is required: it is read from the BP device, or **Count for 30 seconds** opens the counter. Blood sugar is optional and, when entered, takes its unit (mmol/L or mg/dL; stored in mmol/L), its source (glucometer or lab report) and its date.
- **Pulse counter (16):** the LHW taps the large button once per beat for 30 seconds; the app doubles the count and offers **Use this pulse**.
- **Step 2, signs (17):** fetal movement (normal, markedly reduced, absent), anaemia signs (none, some, severe), and yes/no for swelling, bleeding, fever and urine symptoms.
- **Step 3, danger-sign checklist (18):** a yes/no answer with a picture for each of convulsions or fits, severe headache, blurred vision, severe or upper abdominal pain, fast or difficult breathing, and fever with weakness. A "yes" turns the card red. The screen ends with the decision-support note (LI-5) and **Save visit**. The rules that act on the answers come from the Clinical Rules Table (Phase 2, M4 FE-4).
- **Unusual value check (19):** a value outside the plausible range from the Clinical Rules Table (for example systolic BP outside 60–250) asks "correct it" or "yes, it is right, save".
- The offline chip is in the header of every visit step; saving never needs the internet.

### Portal (screens 20–21)

- **Dashboard home (20):** filters (district, Union Council, LHW, period) and **Reload**, refresh every 5 minutes; cards for registered women, visits this week, LHWs synced today and sync conflicts to review; the household map (Leaflet); the LHW activity table with last sync, women, visits this week and last sign-in, an LHW who has not synced for days highlighted.
- **LHW accounts (21):** the list with status (active, waiting to activate, deactivated) and actions; **New activation code** shows the code once, with its expiry, and says only its hash is kept. Every change is written to the audit log.
- The sidebar also links the Phase 1 pages **Registered women**, **Sync conflicts**, **PIN reset codes**, **Geography**, **Hospitals** and **Audit log**.

## Built in the app so far

The Phase 1 revision rebuilds the screens in `mobile/` to this document. Done: screens 1–14 (activation, PIN, unlock, wrong-PIN wait, PIN reset, home, settings, the registration wizard, saved, the list and the file), with no voice guidance; screens 15–19 (the three-step visit, the pulse counter, blood sugar unit, source and date, the danger-sign checklist and the unusual value check; the danger-sign pictures are Material icons for now); and the portal in the final design: screen 20 (dashboard home with LHWs synced today, the map panel and LHW activity with a stale sync highlighted) and screen 21 (LHW accounts with the activation code banner), the same look on every other portal page, the **PIN reset codes** page, and the sync conflict queue and a woman's visits with the new visit fields. The portal works at phone width (the sidebar becomes a top bar). Not built from the canvas: the Figtree font (the portal uses the system font).

Design pass of 17 October 2026 (app, screens 1–19), so every screen follows the same pieces:

- **One header everywhere:** the teal `CurvedHeader` on every screen, also the settings, the wizards, the saved screen and the pulse counter (the canvas draws the wizards with a light header; the app keeps them teal so the whole app reads as one). The wizards and the pulse counter have the close (X) button of the canvas, the step line and progress bar in the header, and the offline/sync state as a small chip in the header (screen 15).
- **Cards over the header's edge:** activation (1), home (6), settings profile (7), saved (12) and the file (14).
- **Settings (7):** the profile card, the two-way language selector and the account actions as a list with icons, sign out in red.
- **Forms:** fields with icons (LI-6), the show/hide eye on passwords, activation and reply codes as large spaced code fields without a character counter; Latin text and numbers line up on the right in Urdu.
- **Visit step 1 (15):** each vital in its own card with the label inside and a large number; the pulse card holds the 30-second button; blood sugar has a light teal border and the unit switch beside its label.
- **Pulse counter (16):** the big button in a light teal ring, the result card "41 × 2 = 82 /min", the explanation under the button so the button is always in sight on a small phone.
- **Saved (12):** the teal success header, the patient ID on one line, **Go to home** as a text button.
- **File (14):** the visits right under **New visit**, each reading as an icon chip; a visit with a danger sign answered yes has a red border and a red notice.
- **Notices in four tones:** information grey, attention amber (the daily sync reminder), problem red (refused records, errors), success green (saved on the phone, month chosen); explanations under a form in a soft teal panel (activation, PIN reset, sign in again, the pulse counter, the decision-support note, LI-5); empty lists with an icon.
- **Review of 17 October (later the same day):** one icon style (outlined) for section headings, fields and lists; dark section headings without icons above groups of cards (home, settings); Urdu text 10% larger than English, because Nastaliq looks smaller at the same size; error messages as large as body text, and a vital card's border turns red when its value is missing or impossible; the unusual-value dialog (19) with a warning icon and two full-width buttons; visit times in 24-hour form, as on the home screen. Portal: outlined icons beside every sidebar link, the LHW accounts table fits the page, and a sign-out reads **Sign-out** in the audit log.
- **English screens** show names written in Urdu in Nastaliq (font fallback), and the phone records the activation as its first sync, so the home screen shows "Last synced" instead of the daily reminder right after activation.
