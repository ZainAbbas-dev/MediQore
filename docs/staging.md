# Staging server (Render + Neon)

The roadmap's "one HTTPS staging server for supervisor reviews and demos" (Architecture and conventions: Environments). With it, the app and the portal work from anywhere with internet, without the laptop.

| Part | Where | Plan |
|---|---|---|
| REST API and the portal, on one HTTPS address | Render web service `mediqore-staging`, set up from [`render.yaml`](../render.yaml) | Free, Singapore |
| PostgreSQL | Neon project `mediqore-staging` | Free, Singapore |

How it runs:

- Render builds `db/`, `api/` and `web/` from the `dev` branch after every push.
- Each start applies new migrations (`db`: `npm run migrate:up`), then starts the API.
- The API serves the built portal (`PORTAL_DIR=../web/dist`), so the portal is at `https://<address>/` and the API at `https://<address>/api/v1`.
- Plain HTTP is refused (M1 FE-2). Render ends TLS in front of the service (`TRUST_PROXY=1`).

Rules:

- Synthetic data only (LI-10). Never real patient data.
- The Neon connection string and the account password live only in the Render dashboard, the Neon console and your own terminal. They never go into git, issues, chat or screenshots: the repository is public.
- Never load the demo accounts (`npm run seed:demo`). Their password is in the public repository.
- Don't share Render, Neon or GitHub logins. Invite your teammate to the Render workspace and the Neon project instead.

## Set it up (once, about 20 minutes)

### 1. Neon: the database

1. Sign in at **console.neon.tech** and create a project:
   - name `mediqore-staging`;
   - Postgres version 15 if it is offered (the project targets PostgreSQL 15), otherwise the lowest version offered;
   - region **AWS Asia Pacific (Singapore)**.
2. Click **Connect**:
   1. Keep the branch `main` and the database `neondb`.
   2. Turn **Connection pooling** off. The migrations take a session lock, which the pooled connection does not keep.
   3. Copy the connection string. It looks like `postgresql://…@ep-….neon.tech/neondb?sslmode=require…`.

### 2. Render: the API and the portal

1. Sign in at **dashboard.render.com** with GitHub. Choose **New** → **Blueprint**.
2. Choose the repository `ZainAbbas-dev/MediQore`. If it is not listed, give Render access to it. Render reads `render.yaml` from the `dev` branch.
3. Render shows the service `mediqore-staging` and asks for `DATABASE_URL`: paste the Neon connection string. Click **Apply** (or **Deploy Blueprint**).
4. The first build takes 5–10 minutes. When the service shows **Live**, its address is at the top of its page, for example `https://mediqore-staging.onrender.com`. Render adds a few letters if the name is taken.
5. Open `https://<address>/api/v1/health`. It should answer `{"status":"ok", …}`.

### 3. Synthetic data, from your laptop (once)

The Render start in step 2 has already created the tables. In VS Code, open a terminal (PowerShell) in the MediQore folder:

```powershell
cd db
$env:DATABASE_URL = "<the Neon connection string>"
$env:SYNTHETIC_PASSWORD = "<a new password; not demo-password>"
npm run seed:synthetic -- --allow-remote
```

- It prints the accounts: `syn.admin`, `syn.sup.01` … `syn.sup.04` and `syn.lhw.001` … `syn.lhw.016`. All of them use your new password.
- Close this terminal afterwards. Anything else run in it would also reach the staging database.
- Give the password to your teammate in person or by private message, never in the repository.

### 4. The test APK for staging

The staging address is `https://mediqore-staging.onrender.com`. Test APKs start with it (`.github/workflows/apk.yml`), so the server does not need changing on the phone. The **Change server** button still works for a laptop server.

If the address ever changes, set it for the APK builds on GitHub: **Settings** → **Secrets and variables** → **Actions** → **Variables** → **New repository variable**, name `MEDIQORE_API_BASE_URL`, value `https://<new address>/api/v1`. Then run **Actions** → **Test APK** → **Run workflow**.

## Use it

- **Portal:** open `https://<address>` and sign in as `syn.sup.01` (supervisor) or `syn.admin` (admin).
- **App:**
  1. Sign in as a synthetic LHW, for example `syn.lhw.001`. The app asks for the phone's 6-digit code.
  2. In the portal, as `syn.admin`, open **Phone approvals** and click **Issue code**.
  3. Type the code in the app.
  4. Then test as in step 7.5 of [`local-setup.md`](local-setup.md).
- **The free Render plan sleeps** after 15 minutes without requests. The next request then takes about a minute.
  - Open the portal or the health address first and wait until it loads, then sign in on the phone.
  - The app gives up after 30 seconds and says that it needs the internet.
- **Neon's free plan** pauses the database after 5 minutes without use. It wakes in about a second.
- **Updates:** every push to `dev` deploys by itself, and new migrations run at the next start. If a deploy fails, read **Events** and **Logs** on the service's page in Render.
- **Supervisor demos:** switch the service to `main` (Render → the service → **Settings** → **Branch**) once `main` has the modules to show.

## Start again with fresh data

`--reset` works only on a database on your own computer. On staging:

1. In the Neon console, open **Databases**, delete `neondb` and create it again with the same name and owner.
2. In Render, choose **Manual Deploy** → **Deploy latest commit**. The start recreates the tables.
3. Load the synthetic data again (step 3).
