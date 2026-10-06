# Run and test MediQore on your laptop (Windows)

Use this guide to set up a Windows laptop and test everything built so far, quickly, with VS Code. It is also the development setup for Phase 1, so the time is not wasted.

| Part | Time | Needed for |
|---|---|---|
| Steps 1–6: database, API, portal, tests | about 30 minutes | Everyone |
| Step 7: the app on a real phone | about 1 hour more, mostly downloads | The Phase 0 exit gate, Module 1 sign-in and the Urdu voice check |
| Step 8: ML notebook | 0 minutes to read it on GitHub | Optional |

## 1. Install once

| Tool | Where | Notes |
|---|---|---|
| Git for Windows | git-scm.com | Defaults are fine |
| VS Code | code.visualstudio.com | |
| Node.js **20 LTS** | nodejs.org | Check: `node -v` prints `v20…` |
| PostgreSQL **15** | postgresql.org → Download → Windows installer | Set a password for the `postgres` user and remember it. Keep port 5432. Untick Stack Builder at the end. |
| Flutter **3.47 or newer** (stable) + Android Studio | docs.flutter.dev → Get started → Windows → Android | **Only for step 7.** Finish when `flutter doctor` shows the Android toolchain in green. If Flutter is already installed, check `flutter --version` and run `flutter upgrade` if it is older than 3.47. |

## 2. Create the MediQore database user (2 minutes)

1. Open **SQL Shell (psql)** from the Start menu.
2. Press Enter at each prompt, then type the `postgres` password.
3. Paste:

```sql
CREATE ROLE mediqore LOGIN PASSWORD 'change-me';
CREATE DATABASE mediqore OWNER mediqore;
CREATE DATABASE mediqore_test OWNER mediqore;
```

These names and this password match the `.env.example` files, so the next step needs no editing. They are for this laptop only.

## 3. Get the code and open it in VS Code

In a terminal (PowerShell):

```powershell
git clone https://github.com/ZainAbbas-dev/MediQore.git
cd MediQore
git checkout dev
code .
```

- VS Code offers to install the recommended extensions (Flutter, ESLint, Python and others). Click **Install**.
- Then open a terminal inside VS Code (Ctrl+`) and copy the two settings files:

```powershell
Copy-Item db\.env.example db\.env
Copy-Item api\.env.example api\.env
```

If PowerShell says *running scripts is disabled on this system* when you run `npm`, run this once and try again:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

## 4. First-time setup: one task

Press Ctrl+Shift+P, choose **Tasks: Run Task**, then **MediQore: first-time setup**. It takes 3–5 minutes and:

1. installs the packages for `db/`, `api/` and `web/`;
2. creates the schema in `mediqore` and in `mediqore_test`;
3. loads the demo accounts and the synthetic data (P0-8).

## 5. Start the system and try the portal

Run the task **MediQore: start API + portal**. Two terminals open, one for the API and one for the portal.

- If Windows Firewall asks about Node.js, allow it on **Private networks**. The phone needs this in step 7.
- Open **http://localhost:5173**. Every account uses the password `demo-password`.

| Sign in as | What you should see |
|---|---|
| `syn.sup.01` | Dashboard with **100** households: map with four clusters near Rawalpindi, and the table |
| `syn.sup.03` | A **different** 100 households near Attock: each supervisor sees only their own areas |
| `syn.admin` | Households from every area. The Phase 0 list stops at 200. |
| `admin.demo` or `syn.admin` | Also **LHW accounts** (add an LHW, edit, deactivate, reset the password) and **Phone approvals** (M1) |
| `syn.sup.01` → **Registered women** | The synthetic pregnant women in that supervisor's areas, with their obstetric history and visit count (M2, M3) |
| `syn.sup.01` → **Dashboard** | Below the map, **LHW activity**: each LHW of the supervisor's areas with visits this week and in total, women registered, last visit, last sync and last sign-in. Choose a district, Union Council, LHW or period: the map and the households table follow. The page reloads itself every 5 minutes (M10) |
| `syn.admin` → **Administration** | **Supervisors and admins** (add a supervisor, tick their areas, the password is shown once), **Areas** (add, rename and delete districts, tehsils, Union Councils and areas; a district still in use cannot be deleted), **Hospitals** (a DHQ per district and a THQ per tehsil from the synthetic data; add one), **Roles** (what each role may do) and **Audit log** (everything you just did, with your username) (M10) |
| `syn.sup.01` → **Sync conflicts** | Visits held because the same pregnancy already had a visit that day, each next to the stored visit with the differences highlighted. Decide one: it moves to **Decided** and the dashboard count drops (M3) |
| `supervisor.demo` | No households yet, until the phone syncs one in step 7. **Phone approvals** lists phones of LHWs in the supervisor's areas. |
| `lhw.demo` | Refused: the portal is for supervisors and admins |
| any account, wrong password | An error message |

Also check:

- **http://localhost:3000/api/v1/health** should answer `{"status":"ok", …}`.
- The map's street tiles load from the internet; the household markers come from your database.

## 6. Run the tests

Run the task **MediQore: run all tests (db, api, web)**. You should see the same results as CI on GitHub:

| Part | Expected |
|---|---|
| `db` | 22 passed |
| `api` | lint clean, 169 passed |
| `web` | lint clean, 53 passed, build succeeds |

After step 7, the task **mobile: analyze and test** should show "No issues found" and 156 tests passed, with four skipped (the opt-in end-to-end tests).

## 7. The app on a real phone

This tries Module 1 sign-in (phone approval, offline sign-in, auto-lock), Module 2 registration and Module 3 visits, closes the Phase 0 exit gate ("one test record created on the phone offline, synced, stored in PostgreSQL and visible on the React portal") and runs the Urdu voice check (decision 0004).

1. **Get the app's packages:** run the task **mobile: get packages** (or `flutter pub get` in `mobile/`).
   - Until this has run, VS Code underlines almost every line in `mobile/` in red: the packages and the generated Urdu/English text class (`app_localizations.dart`) are missing.
   - The red lines disappear a few seconds after it succeeds. If some remain, press Ctrl+Shift+P and run **Dart: Restart Analysis Server**.
2. **On the phone:** turn on Developer options and **USB debugging**, connect the USB cable and allow this computer.
3. **Find the laptop's address:** run `ipconfig` and note the **IPv4 Address** of the Wi-Fi adapter, for example `192.168.1.10`.
   - The phone must be on the **same Wi-Fi**.
   - The API must be running (step 5).
4. **Start the app from VS Code:**
   1. Open **Run and Debug** (Ctrl+Shift+D).
   2. Choose **MediQore app: real phone (same Wi-Fi as this laptop)** and press **F5**.
   3. Type the IPv4 address when asked.
   4. The first build takes several minutes.
5. The app opens on the **سائن ان** (sign-in) screen (M1):
   - **Language:** the button at the top of the sign-in screen shows the other language. Tap **English** and the whole app switches to English, left to right; tap **اردو** to switch back. After sign-in, the language is in the settings (the gear icon at the top of the home screen). The app remembers the choice after it is closed.
   - **First sign-in on this phone** (needs the internet): type `lhw.demo` and `demo-password` and tap **سائن ان کریں**.
     1. The app asks for the phone's **6-digit code** and shows the last six characters of the phone's ID.
     2. In the portal, sign in as `supervisor.demo` (or `admin.demo`), open **Phone approvals** and check that the row shows the same six characters. Click **Issue code**.
     3. Type the code in the app and tap **منظور کریں اور سائن ان کریں** (approve and sign in). The app downloads the area's records and opens the home screen.
   - **Offline sign-in:** open the settings (gear icon) and tap **لاک کریں** (lock), turn on **airplane mode** and sign in again with the same password. It works without the internet. A wrong password is refused.
   - **Auto-lock:** leave the app untouched for 5 minutes. It locks and asks for the password again.
   - **Deactivation:** in the portal, as `admin.demo`, open **LHW accounts** and deactivate `LHW-DEMO-001`. On the phone, tap **ابھی سنک کریں** (sync now): the app locks and says the account is deactivated. Activate it again in the portal afterwards.
   - **Register a pregnant woman offline (M2):** sign in, turn on **airplane mode** and tap **حاملہ خاتون کا اندراج** (register a pregnant woman).
     1. Fill in a made-up name, age, pregnancy month and village; use synthetic values only, never a real person (LI-10).
     2. Outdoors, tap **گھر کا مقام محفوظ کریں** (record home location). The first fix without mobile data can take a minute; indoors it may fail, and the form can be saved without it.
     3. Tap **اندراج محفوظ کریں** (save registration). The app shows the patient ID, for example `LHW-DEMO-001-0001`.
     4. Open **رجسٹرڈ خواتین** (registered women): she is listed under her village, marked "not sent yet". Search for part of her name.
     5. Turn airplane mode off and sync. In the portal, as `supervisor.demo`, open **Registered women**: she is there with her history, and the dashboard count goes up.
   - **Record a visit offline (M3):** with **airplane mode** on, open her file from **رجسٹرڈ خواتین** and tap **نیا وزٹ** (new visit).
     1. **Voice guidance:** with the app in Urdu, tap the first field. The phone reads its name aloud and a speaker shows next to it. The registration form does the same. The speaker button at the top mutes it; the same switch is in the settings (gear icon), with **آواز آزمائیں** (test the voice). In English there is no voice. If nothing is heard, tap **آواز آزمائیں**: the app says whether the phone has an Urdu voice and how to install one.
     2. Leave every field empty and tap **وزٹ محفوظ کریں** (save visit): each required field says so. Type `98.6` as the temperature: it is refused, because the app takes °C.
     3. Type a systolic BP of `255` with the other values normal and save: a dialog asks you to check it. **درست کریں** goes back; **جی ہاں، محفوظ کریں** saves it.
     4. The file shows the visit, marked "not sent yet".
   - **Automatic sync and the conflict queue (M3):** turn airplane mode off, wait a few seconds and go back to the home screen: the status bar says everything is synced, without tapping sync. Then record a **second visit for the same woman** and wait again.
     1. Her file marks the second visit "waiting for the supervisor": the server held it because she already had a visit that day.
     2. In the portal, as `supervisor.demo`, open **Sync conflicts**: both visits are side by side. Choose one of the three decisions.
     3. Back on the phone, tap sync: the visit is no longer held (or, with "keep the stored visit", it disappears as a duplicate).
6. In the settings (gear icon), under **ٹیسٹنگ** (testing), **فیز 0 کی جانچ** (Phase 0 checks, debug builds and the test APK only):
   - **ویجٹ کٹ** (widget kit): scroll through the Urdu controls and check that nothing is cut off.
   - **ڈیٹا سنک کی جانچ** (sync test):
     1. Turn on **airplane mode** and tap **ٹیسٹ گھرانہ بنائیں** (create test household). It is saved on the phone.
     2. Turn airplane mode off and tap **ابھی سنک کریں** (sync now). The household gets a server number. If you signed in offline, the app asks you to sign in again with the internet first.
     3. In the portal, sign in as `supervisor.demo`: the household is in the count, on the map and in the table.
   - **اردو آواز کی جانچ** (Urdu voice check):
     1. With the app in Urdu and the phone in airplane mode, open it and tap the sample button. In English, the button is off, because voice guidance works only in Urdu.
     2. Write the results for this phone in the table in [`docs/decisions/0004-urdu-voice-source.md`](decisions/0004-urdu-voice-source.md).
     3. Repeat on every test phone.
7. **No phone at hand?** Use the configuration **MediQore app: Android emulator** with an emulator from Android Studio. The voice check still needs a real phone.

## Test APK: install the app on any phone

No USB cable, Flutter or Android Studio is needed. GitHub builds the app after every push to `dev` that changes `mobile/` (workflow **Test APK**). The test APK:

- starts with the staging server, `https://mediqore-staging.onrender.com` ([`staging.md`](staging.md));
- can use another server, for example your laptop's: press and hold the logo on the sign-in screen (nothing about the server shows on the screen);
- talks to a laptop server over plain HTTP;
- shows **فیز 0 کی جانچ** (Phase 0 checks) in the settings.

It is signed with a test key and is for testing only. Builds for LHWs will use one HTTPS server fixed at build time (M1 FE-2).

1. **Download it:** on GitHub, open **Actions** → **Test APK**, open the latest green run on `dev` and download the artifact `mediqore-test-apk-…` at the bottom of the page. You must be signed in to GitHub. It is a ZIP: unzip it to get `mediqore-test-xxxxxxx.apk`.
2. **Copy it to the phone,** for example by USB cable, Google Drive or email.
3. **Install it:** open the APK on the phone.
   - Android asks whether to allow installs from that app (Files, Drive or Chrome): allow it, go back and tap **Install**.
   - If Google Play Protect warns about an unknown app, tap **More details** → **Install anyway**.
   - If Android says **App not installed** or that the package conflicts, uninstall the old MediQore first. This happens when the old app came from VS Code or from a test APK built before 6 October 2026, or when no test APK was built for a week (the test key then changes). Uninstalling deletes records on the phone that were not synced.
4. **Wake the staging server:** open `https://mediqore-staging.onrender.com` in a browser and wait until the portal loads. The free server sleeps after 15 minutes without use and takes about a minute to wake.
5. **Sign in on the phone** as a synthetic LHW, for example `syn.lhw.001`, with the staging password. Approve the phone in the portal as `syn.admin` (**Phone approvals** → **Issue code**), then continue from step 7.5: offline sign-in, registration, visits and the conflict queue all work the same way. Staging has no `lhw.demo` account.

**With the server on your laptop instead:**

1. Run **MediQore: start API + portal** (step 5) and find the laptop's IPv4 address with `ipconfig` (step 7.3). The phone must be on the same Wi-Fi, and the firewall must allow Node.js on Private networks.
2. On the sign-in screen, **press and hold the MediQore logo** for a second. The **سرور کا پتہ** (server address) box opens.
   1. Type `http://` + the IPv4 address + `:3000`, for example `http://192.168.1.10:3000`. The app adds `/api/v1`.
   2. Tap **محفوظ کریں** (save). The app remembers the address. To go back to staging, type `https://mediqore-staging.onrender.com`.
3. Sign in as `lhw.demo` and approve the phone as `supervisor.demo` on `http://localhost:5173`.

To build a test APK that starts with another address, open **Actions** → **Test APK** → **Run workflow** and type the address.

## 8. ML notebook (optional)

- **Read the results without installing anything:** open `ml/notebooks/01_uci_exploration.ipynb` on GitHub (on the `dev` branch). GitHub shows the tables and charts.
- **Run it yourself:** see "Commands" in [`ml/CLAUDE.md`](../ml/CLAUDE.md). It needs Python 3.11 and `python scripts/download_uci.py`.

## After you pull new code

New code can bring new database changes (for example the LHW ID numbering and the previous area added in Module 1). After `git pull`, run the task **db: migrate (dev and test databases)**, then restart **MediQore: start API + portal**. For the app, run **mobile: get packages** again.

## Start again with fresh data

Run the task **MediQore: empty the database and reload the data**. It empties the local dev database, then loads the synthetic and demo data again. Anything synced from the phone is deleted.

## If something goes wrong

| Message or symptom | Fix |
|---|---|
| `password authentication failed for user "mediqore"` | The password in step 2 differs from the `.env` files. Make `db\.env` and `api\.env` match it. |
| `database "mediqore" does not exist` | Run step 2. |
| `npm` or `node` is not recognised | Close and reopen VS Code after installing Node.js. |
| `running scripts is disabled on this system` | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`, once. |
| `EADDRINUSE … :3000` or `:5173` | The API or portal is already running in another terminal. Close that terminal (bin icon) and start the task again. |
| `Synthetic data with prefix "syn" is already loaded` | Nothing is wrong: the data is already there. To get fresh data, use the reset task above. |
| The phone's sync fails with a network or timeout error | Check that the phone is on the same Wi-Fi, that the IPv4 address is right and that the firewall allows Node.js on Private networks. Some Wi-Fi networks (guest or university) block devices from reaching each other. If so, turn on the phone's hotspot, connect the laptop to it, run `ipconfig` again and use that address. |
| Red error lines all over the files in `mobile/` | Run the task **mobile: get packages**. If it fails, read its message (next row). |
| `flutter pub get` says *version solving failed* or *requires SDK version ^3.13.0* | Your Flutter is older than 3.47. Run `flutter upgrade`, then **mobile: get packages** again. |
| `flutter doctor` complains about Android licences | `flutter doctor --android-licenses` and accept them. |

## The staging server

To use the app and the portal from anywhere with internet, without the laptop, set up the staging server on Render and Neon: see [`staging.md`](staging.md).
