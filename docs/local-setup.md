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
| `db` | 20 passed |
| `api` | lint clean, 75 passed |
| `web` | lint clean, 26 passed, build succeeds |

After step 7, the task **mobile: analyze and test** should show "No issues found" and 76 tests passed, with two skipped (the opt-in end-to-end tests).

## 7. The app on a real phone

This tries Module 1 sign-in (phone approval, offline sign-in, auto-lock), closes the Phase 0 exit gate ("one test record created on the phone offline, synced, stored in PostgreSQL and visible on the React portal") and runs the Urdu voice check (decision 0004).

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
   - **زبان / Language** at the top: tap **English** and the whole app switches to English, left to right. Tap **اردو** to switch back. The app remembers the choice after it is closed.
   - **First sign-in on this phone** (needs the internet): type `lhw.demo` and `demo-password` and tap **سائن ان کریں**.
     1. The app asks for the phone's **6-digit code** and shows the last six characters of the phone's ID.
     2. In the portal, sign in as `supervisor.demo` (or `admin.demo`), open **Phone approvals** and check that the row shows the same six characters. Click **Issue code**.
     3. Type the code in the app and tap **منظور کریں اور سائن ان کریں** (approve and sign in). The app downloads the area's records and opens the home screen.
   - **Offline sign-in:** tap **لاک کریں** (lock), turn on **airplane mode** and sign in again with the same password. It works without the internet. A wrong password is refused.
   - **Auto-lock:** leave the app untouched for 5 minutes. It locks and asks for the password again.
   - **Deactivation:** in the portal, as `admin.demo`, open **LHW accounts** and deactivate `LHW-DEMO-001`. On the phone, tap **ابھی سنک کریں** (sync now): the app locks and says the account is deactivated. Activate it again in the portal afterwards.
6. On the home screen, **فیز 0 کی جانچ** (Phase 0 checks, debug builds only):
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

## 8. ML notebook (optional)

- **Read the results without installing anything:** open `ml/notebooks/01_uci_exploration.ipynb` on GitHub (on the `dev` branch). GitHub shows the tables and charts.
- **Run it yourself:** see "Commands" in [`ml/CLAUDE.md`](../ml/CLAUDE.md). It needs Python 3.11 and `python scripts/download_uci.py`.

## After you pull new code

New code can bring new database changes (for example the LHW ID numbering added in Module 1). After `git pull`, run the task **db: migrate (dev and test databases)**, then restart **MediQore: start API + portal**. For the app, run **mobile: get packages** again.

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

## Later: a staging server

The roadmap plans one HTTPS staging server for supervisor reviews and demos ("Environments"). Vercel alone cannot host it:

- Vercel serves the React portal well.
- The API needs an always-on Node.js server and a PostgreSQL database.
- The app is an Android APK, which is installed on the phone.

Set the staging server up when the supervisor first needs to see the system, with a non-default password for the demo accounts, because the repository is public.
