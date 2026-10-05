# Phase 1 screens: specification and wireframes (P0-7)

Roadmap task P0-7 asks for Figma screens for Phase 1: login, LHW home, registration, visit form, dashboard home and admin lists (scope Mockups 1, 2, 6). This document is the brief for that Figma work, and [`wireframes/`](wireframes) has a low-fidelity starting point for each screen.

Everything here comes from the scope and roadmap. Where they leave a choice open, it is marked **Decide**.

## Using the wireframes in Figma

1. Install the Jameel Noori Nastaleeq font on your computer (`mobile/assets/fonts/JameelNooriNastaleeq.ttf`) so the Urdu text renders correctly.
2. In Figma, drag the `.svg` files from `docs/design/wireframes/` onto the canvas, or use **File → Import**. Each one becomes a frame with editable shapes and text layers.
3. Build the real designs on top, using the components below. Export the final mockups for Appendix A of the final report (roadmap, Phase 4).

## Design rules for every screen

From `CLAUDE.md` and the roadmap:

- **Mobile app (LHW): Urdu by default, English selectable** (M1 FE-4, scope amendment A1).
  - Urdu text in Jameel Noori Nastaleeq, laid out right to left.
  - English text in the standard Latin font, laid out left to right.
  - Numbers and units read left to right in both, for example `120 mmHg`.
  - Design each screen in Urdu first, then check the English version for length and layout.
  - The language switch shows **اردو** and **English**, each in its own script.
- **Large controls.** Buttons are at least 64 dp tall and full width. Field labels sit above the field, not inside it. Use checkboxes and dropdowns instead of typing wherever possible (M3 FE-1).
- **Offline is normal.** The offline status bar is always visible on field screens and shows how many records are waiting to sync. Saving never needs the internet.
- **Small phones.** Design at 360 × 780 and check every screen at 320 × 640 in both languages, because Nastaliq text is tall and overflows easily.
- **Risk colours** (Phase 2 screens): Green / Yellow / Red, always with an icon and a text label, never colour alone.
- **Portal (supervisor/admin): English**, desktop first (1440 × 900), with a sidebar layout as built in P0-5.
- **No real patient data** in any mockup (LI-10). Use made-up names.

**Components that already exist** (P0-2, in `mobile/lib/widgets/`). Reuse them in the designs so the screens can be built directly:

- `LargeButton` (primary / secondary)
- `AppTextField`
- `VitalField` (number + unit, left to right)
- `CheckboxField`
- `DropdownField`
- `RiskChip`
- `OfflineStatusBar`

## Screens

| # | Screen | Platform | Scope | Scope mockup | Wireframe |
|---|---|---|---|---|---|
| 1 | Login | Mobile | M1 FE-2, FE-4 | – | [`01-login.svg`](wireframes/01-login.svg) |
| 2 | LHW home | Mobile | M2 FE-3, M3 FE-2, FE-3 | – | [`02-lhw-home.svg`](wireframes/02-lhw-home.svg) |
| 3 | Registration | Mobile | M2 FE-1, FE-2, FE-3 | Mockup 1 | [`03-registration.svg`](wireframes/03-registration.svg) |
| 4 | Visit form | Mobile | M3 FE-1, FE-3 | Mockup 2 | [`04-visit-form.svg`](wireframes/04-visit-form.svg) |
| 5 | Dashboard home | Web | M10 FE-1 (Phase 1 base) | Mockup 6 | [`05-dashboard-home.svg`](wireframes/05-dashboard-home.svg) |
| 6 | Admin lists | Web | M10 FE-3, M1 FE-1, FE-3 | – | [`06-admin-lists.svg`](wireframes/06-admin-lists.svg) |

### 1. Login (mobile)

The LHW signs in with the ID and password the admin issued (M1 FE-1, FE-2).

- **Fields:** username (LHW ID), password. **Button:** sign in.
- **Language switch** (M1 FE-4) at the top: اردو / English. It works before sign-in and is remembered on the phone.
- **First login** needs internet:
  - the server checks the password;
  - OTP verification follows on first login and on a new device (M1 FE-2);
  - the app then downloads only that LHW's area data (roadmap, Module 1).
- **Later logins work offline:** the password unlocks the encrypted local database (M1 FE-2, LI-8).
- **States to design:**
  - wrong password;
  - first login while offline ("internet needed the first time");
  - account deactivated (refused at next sync, M1 FE-3);
  - loading.
- **OTP step:** a separate screen with a code field and resend.
  - **Built (Module 1, proposed decision 0002):** the code is issued by an admin or supervisor on the portal's **Phone approvals** page, so the screen has no resend button. It shows the last six characters of the phone's ID (the portal shows the same six), the 6-digit code field, **approve and sign in** and **back to sign-in**, with messages for a wrong code, too many wrong codes, no code issued yet and no internet.
- **Session:** auto-lock after inactivity returns here (M1 FE-2).

### 2. LHW home (mobile)

The starting point after login.

- **Top:** offline status bar with pending count, then the LHW's name and area.
- **Main actions** (large buttons):
  - Register a pregnant woman (screen 3).
  - Patient list / search, by area and sorted by village (M2 FE-3). Opening a patient leads to a new visit (screen 4).
  - Sync now. Sync also runs in the background when online (M3 FE-2).
- **Settings:**
  - language switch (M1 FE-4);
  - voice guidance mute toggle (M3 FE-3). It is shown only in Urdu; in English, show a note instead: voice guidance works only in Urdu.
- **Not in Phase 1:** risk alerts, ANC reminders, polio and child modules. Leave room for them, but do not design them now.
- **Built (Module 3):** a **Settings** heading holds the language switch and the voice guidance switch (or, in English, the note). A visit starts from the woman's file; a short line under **Registered women** says so. The status bar follows the automatic sync.

### 3. Registration (mobile, scope Mockup 1)

M2 FE-1, FE-2, FE-3.

- **Woman** (M2 FE-1):
  - name;
  - age;
  - husband's name;
  - contact number (left to right);
  - address;
  - village;
  - pregnancy month (dropdown 1–9).
- **Obstetric history** (M2 FE-2; baseline risk profile):
  - previous pregnancies;
  - previous C-sections;
  - stillbirths;
  - known medical conditions.
- **Household location** (M2 FE-3): "capture GPS" button, with status (capturing / captured / not available).
- **After saving:**
  - show the generated Patient ID: LHW code + local counter, unique offline (M2 FE-1);
  - confirm that the record is saved on the phone and will sync later.
- **States to design:** validation errors under each field, GPS unavailable, saved offline.
- **Decide:** whether obstetric history is a second step or the same scrolling page. The scope says it is captured "at the time of registration".
  - **Built (Module 2):** one scrolling page with four sections (woman, pregnancy, home, obstetric history) and one Save button, so nothing is half-saved. The home section also offers "same home as a registered woman", for a second woman in one household. After saving, a screen shows the patient ID and that the record is on the phone.

### 4. Visit form (mobile, scope Mockup 2)

M3 FE-1, FE-3.

- **Vitals:** use `VitalField`, number + unit, left to right.
  - BP systolic and diastolic (mmHg)
  - weight (kg)
  - temperature (°C)
  - pulse (beats/min)
  - blood sugar (mmol/L, optional)

  Pulse and blood sugar were added for the Phase 2 model (roadmap, Risks).
- **Symptoms:** checkboxes and a dropdown.
  - fetal movement (normal / reduced / absent)
  - swelling
  - bleeding
  - fever
  - anaemia signs
  - urine symptoms
- **Voice guidance** (M3 FE-3): when a field gets focus, its Urdu label is read aloud. Show a speaker indicator on the focused field, and a mute toggle. In English there is no voice guidance (M1 FE-4), so no speaker indicator.
- **Range check:** a value outside the plausible range asks for confirmation instead of blocking. Example from the roadmap: systolic BP outside 60–250. Design this dialog.
- **Offline status bar** at the top, "saved on the phone" confirmation after saving.
- **Not in Phase 1:** the risk result screen (M4, Phase 2) follows this form later. Keep the Save button's position stable so that flow can be added.
- **Built (Module 3):** the form opens from the woman's file (**New visit**, active pregnancy only) and is one scrolling page with two sections, measurements and signs. Every vital except blood sugar is required. A value the server cannot accept (for example `98.6` as °C) is refused under its field with the allowed range; values outside the usual range are listed together in one dialog with their usual range, with "correct them" and "yes, save". The ranges are in `mobile/assets/clinical/visit_ranges.json`. The mute toggle is in the app bar, in Urdu only. After saving, the file lists the visit with its sync state, including "waiting for the supervisor" when the server held it as a same-day duplicate.

### 5. Dashboard home (web, scope Mockup 6, Phase 1 base)

M10 FE-1. This is the base version; Phase 2 adds the risk distribution chart, referral rate and the alerts panel.

- **Cards** (roadmap, Module 10 base):
  - registered patients;
  - visits this week;
  - LHW visit counts;
  - last login.
- **Map:**
  - Leaflet map of registered households from Module 2 GPS;
  - filters: district, Union Council, LHW, time period;
  - auto-refresh every 5 minutes, plus a manual reload button.
- **Layout:** sidebar and header as in the P0-5 portal; the signed-in supervisor and their areas.
- **States to design:** no data yet, loading, API unreachable.
- **Built (Module 10 base):** cards for registered women, visits this week, sync conflicts to review and households. The LHW visit counts and last login are a table under the map, one row per LHW: visits this week and in total, women registered, last visit, last sync and last sign-in. The filters (district, Union Council, LHW, period) sit above the map; district and Union Council also narrow the LHW table. "Updated … ; refreshes every 5 minutes" and a Reload button are at the top right. If one part fails to load, the others still show, with the error above.

### 6. Admin lists (web)

M10 FE-3, M1 FE-1, FE-3. One screen with tabs; each tab is a filterable table with Add and Edit.

- **Areas:** district → tehsil → Union Council → area hierarchy.
- **Accounts:**
  - LHW and supervisor accounts: name, role, area, active / inactive, last login;
  - actions: create (issues LHW ID and credentials), reassign area, activate / deactivate;
  - reset password, with a **"sync before reset"** warning: unsynced data on the phone becomes unreadable (LI-8).
- **Hospitals and referral centres:** name, type, district, phone, location.
- **Audit log:** filters by user, action and date (roadmap, Module 10 base).
- **Related supervisor screen, not in the P0-7 list:** the sync conflict review queue (M3 FE-2). Plan where it sits in the navigation.
- **Built (Module 10 base):** separate pages instead of tabs, under an **Administration** heading in the sidebar that only admins see: LHW accounts, Supervisors and admins, Areas (four columns: district, tehsil, Union Council, area), Hospitals (hospitals and referral centres as two tabs), Roles (what each fixed role may do) and Audit log. The sync conflict queue is in the main navigation, after Registered women.
