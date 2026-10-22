# MediQore user guide

Short notes for the people who use MediQore, written module by module as each one is finished (roadmap, Definition of done: "Short note added to the user guide"). Phase 1 covers Modules 1, 2 and 3 on the LHW app and the Module 10 base on the portal. All examples use synthetic data (LI-10).

The app is in Urdu by default; the Urdu button labels are given with their English meaning. The language can be changed at any time in the settings (gear icon → **زبان · Language** → choose **اردو / Urdu** or **English / انگریزی** → **محفوظ کریں** (Save)), and the choice is kept.

## LHW app

### Module 1: activation, PIN and emergency call

- **First time on a phone (needs the internet):** type your LHW ID, your password and the activation code your admin gave you, then tap **فون فعال کریں** (activate phone). The code works once, on one phone, for 48 hours. Then choose a six-digit PIN and type it again. The app downloads your area's records.
- **Every day:** type your PIN. It works without the internet.
- **Wrong PIN:** the app makes you wait 30 seconds, then 1 minute, 5 minutes and 15 minutes after more wrong PINs. The emergency call still works while you wait.
- **Forgot your PIN:** tap **پن بھول گئیں؟**. Read the 6-digit code on the screen to your supervisor; she types it on the portal and reads back an 8-digit reply code. Type it, then choose a new PIN. Your records stay on the phone. No internet is needed.
- **Emergency:** the lock screen always has **ایمرجنسی: سپروائزر کو کال** (call the supervisor), even when the app is locked or waiting after a wrong PIN.
- **Auto-lock:** after 5 minutes without a touch the app locks; type the PIN again.
- **Sign in again:** after your admin resets your password, the app asks for the new password once, at the next sync. Your PIN and records stay.
- **Deactivated account:** at the next connection the app locks and explains why. Ask your admin.

### Module 2: registering a pregnant woman

- On the home screen tap **نیا اندراج** (new registration). The form has four steps; **اگلا قدم** (next step) checks each one.
  1. Her name, age, husband's name and contact number.
  2. The pregnancy month (tap a number from 1 to 9).
  3. Her home: the same home as a woman already registered, or the village and address. Outdoors, tap **مقام محفوظ کریں** (record location) for GPS; it can be added later from her file.
  4. Earlier pregnancies, C-sections and stillbirths (the − and + buttons), and any known illness.
- **اندراج محفوظ کریں** (save registration) gives her patient ID, for example `LHW-00001-03-0007` (her LHW ID, the phone's activation number, then her number). It works without the internet. Then open her file, register another woman, or **ہوم پر جائیں** (go to home).
- The X at the top of the form closes it without saving.
- Her file shows the risk factors from her history, for example "Previous C-section". They are for information and do not change a risk colour.
- **رجسٹرڈ خواتین** (registered women) lists them by village, or **قریب ترین پہلے** (nearest first) by distance from where you stand; search by name, ID or village.

### Module 3: a home visit

- In her file tap **نیا وزٹ** (new visit). The visit has three steps.
  1. **Measurements:** BP, weight, temperature and pulse are required. If the BP machine shows no pulse, tap **30 سیکنڈ گنیں** (count for 30 seconds) and press **دھڑکن** (beat) at every beat; the app doubles the count. Blood sugar is optional; if you enter it, choose mmol/L or mg/dL, glucometer or lab report, and the day it was measured.
  2. **Signs:** fetal movement, anaemia signs, swelling, bleeding, fever and urine symptoms.
  3. **Danger signs:** answer yes or no for each of the six pictures. A yes turns the card red. The result is decision support only; follow the emergency protocol and your supervisor's advice.
- An unusual value (for example a very high BP) asks you to check it: **درست کریں** (correct it) or **جی ہاں، محفوظ کریں** (yes, save).
- **وزٹ محفوظ کریں** (save visit). It works without the internet.

### Sync: sending records to the server

- Records are saved on the phone first, encrypted. They are sent on their own when there is internet: while the app is open, as soon as the network returns, and in the background when the app is locked or closed.
- The card on the home screen shows whether the phone is online, how many records wait, and when it last synced. **ابھی سنک کریں** (sync now) sends at once.
- If records have waited for a day, the home screen reminds you to sync today. Records only on the phone are lost if the phone is lost, so sync every day (LI-8).
- A visit marked "waiting for the supervisor" was held because the woman already had a visit that day; your supervisor decides, and the phone shows the decision after the next sync.
- If the server refused a record, the home screen says so. The record stays on the phone and is sent again at every sync; tell your supervisor.

## Supervisor and admin portal

Open the portal address in a browser (it can be installed as an app from the browser menu) and sign in with your username and password.

### Supervisors

- **Dashboard:** registered women, visits this week, LHWs synced today and sync conflicts to review; the households with GPS on the map; and each LHW's activity (last sync, women, visits, last visit, last sign-in). An LHW who has not synced for 2 days or more is highlighted. Filter by district, Union Council, LHW and period; the page refreshes every 5 minutes, or press **Reload**.
- **Registered women:** the women in your areas with their pregnancy file and history. Click the visit count to see her visits.
- **Sync conflicts:** a visit held because the same woman already had a visit that day, next to the stored one with the differences highlighted. Keep both, keep the stored visit, or keep the new one.
- **PIN reset codes:** choose the LHW, type the 6-digit code from her phone and read her the 8-digit reply code.

### Admins

Everything above, and under **Administration**:

- **LHW accounts:** add an LHW (the LHW ID and a password are shown once); **New activation code** for her phone (shown once, 48 hours); **Edit** to change her name, phone or area, reset her password or deactivate her.
- **Supervisors and admins**, **Geography** (districts, tehsils, Union Councils and areas), **Hospitals** (hospitals and referral centres), **Roles** (what each role may do) and **Audit log** (every change, sign-in and sync conflict, with who and when).
