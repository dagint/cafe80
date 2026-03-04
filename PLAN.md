# Cafe80 – RustDesk Server Deployment Plan

Deploy a **RustDesk** server on an **Ubuntu Linux VPS** with security as the top priority, **GitHub Actions** for deployment, no PII in the repo, optional **free Web UI**, and a path for **backups (S3 / GDrive)** later.

---

## 1. Project overview

| Item | Choice |
|------|--------|
| **App** | RustDesk OSS (hbbs + hbbr) via Docker Compose |
| **OS** | Ubuntu Server 22.04/24.04 LTS (minimal) |
| **Secrets** | Local `.env` only; sync to GitHub via script (no secrets in repo/PRs) |
| **CI/CD** | GitHub Actions → SSH or deployment user on VPS |
| **Web UI** | Free options only (see §5) |
| **Backups** | Planned for later (S3 + GDrive) |

---

## 2. Security (primary concern)

### 2.1 OS hardening (Ubuntu VPS)

- **SSH**
  - Key-only auth (Ed25519), no password.
  - `PermitRootLogin no`, create a dedicated deploy/admin user (e.g. `deploy` or non-obvious name).
  - Optional: non-default SSH port (e.g. 9022) to reduce bot noise; document in runbooks.
- **Firewall (UFW)**
  - Default: deny incoming, allow outgoing.
  - Allow only: SSH (22 or your custom port), RustDesk ports (see below), and if you add a web UI later, 80/443.
- **RustDesk ports to allow**
  - 21115/tcp, 21116/tcp, 21116/udp, 21117/tcp, 21118/tcp, 21119/tcp (or restrict 21118/21119 if you don’t use web client).
- **Fail2ban**
  - Protect SSH (and optionally nginx if you add it) from brute force.
- **Updates**
  - `unattended-upgrades` for security updates; reboot if needed (e.g. kernel).
- **Minimal surface**
  - No unnecessary packages; prefer Docker from official install method; lock Docker Compose/image versions in repo.

All of this can be encoded in an **Ansible playbook** or **shell script** in the repo (no secrets, only logic and port lists). The script/playbook is applied once per server (or when you change hardening).

### 2.2 Application / RustDesk hardening

- Run containers as **non-root** if the image supports it; use **read-only** root filesystem where possible.
- Use **resource limits** (CPU/memory) in Compose to limit impact of abuse.
- **Key-based encryption**: use RustDesk’s public key (from server) for client connections; document in README how to distribute the key.
- **Reverse proxy**: put any web UI (or future web console) behind **HTTPS** (e.g. Caddy or Nginx + Let’s Encrypt); do not expose RustDesk admin endpoints directly to the internet if avoidable.
- **Network**: consider a single Docker network for hbbs/hbbr only; expose only required host ports.

### 2.3 Keeping things up to date

- **OS**: unattended-upgrades + periodic review.
- **RustDesk**: pin image tag in `docker-compose.yml` (e.g. `rustdesk/rustdesk-server:1.2.3`); use a scheduled GitHub Action or manual workflow to bump the tag and redeploy after checking release notes.
- **Dependencies**: Dependabot for the repo (e.g. GitHub Actions, Docker base images if you add custom Dockerfiles).

---

## 3. Repo and GitHub Actions (no PII)

### 3.1 Repo layout (public)

- **No PII and no secrets in the repo or in PRs.**
- All sensitive values live in:
  - **Local**: `.env` (gitignored).
  - **CI**: GitHub **Actions secrets** and **variables** (e.g. `VPS_HOST`, `SSH_PRIVATE_KEY`, `RUSTDESK_RELAY_HOST`).

Suggested layout:

```text
cafe80/
├── .github/
│   └── workflows/
│       ├── deploy.yml          # Deploy to VPS (trigger: workflow_dispatch or push to main)
│       └── security-scan.yml  # Optional: trivy/codeql or similar
├── .env.example               # Template only (no real values)
├── .gitignore                 # .env, *.pem, etc.
├── scripts/
│   ├── sync-secrets-to-github.sh   # Pushes .env entries to GitHub Actions secrets
│   └── hardening/                  # Optional: OS hardening scripts
│       └── ubuntu-initial.sh
├── deploy/                    # Or 'ansible/' if you use Ansible
│   └── docker-compose.yml     # RustDesk hbbs + hbbr (env vars for hostname/key)
├── docs/
│   └── RUNBOOK.md             # How to deploy, recover, rotate secrets
├── PLAN.md                    # This file
└── README.md
```

### 3.2 GitHub Actions deploy workflow

- **Trigger**: `workflow_dispatch` and/or push to `main` (optional).
- **Steps** (high level):
  1. Checkout repo.
  2. (Optional) Validate compose file.
  3. Use **SSH** (key from `secrets.SSH_PRIVATE_KEY`) to connect to `secrets.VPS_HOST` (or variable).
  4. Copy `deploy/docker-compose.yml` and inject **only non-secret** config (e.g. relay hostname from a **variable**); **secrets** (e.g. any API keys, or RustDesk key paths) should already be on the server in a **.env** that you create once manually or via a one-time setup step that reads from a secret and writes a file (never commit that file).
  5. On the server: `docker compose pull && docker compose up -d` (and optionally `docker image prune`).
  6. Optionally: smoke test (e.g. curl a RustDesk port or health endpoint).

Important: **Secrets and PII stay in GitHub Secrets / server .env only**; the workflow uses them at runtime and never logs or commits them.

### 3.3 Keeping PII out of PRs

- **Branch protection**: require PR reviews; no force-push to main if you want audit trail.
- **.gitignore**: `.env`, `*.pem`, `*.key`, any file that might hold secrets.
- **.env.example**: list variable names and dummy values (e.g. `RELAY_HOST=your-server.example.com`); document in README that real values go in GitHub Secrets and (if applicable) server-side `.env`.
- **Pre-commit or CI**: optional check that no file in the repo contains obvious secrets (e.g. `env.example` is the only file with “example” env content; no `password=` or `api_key=` in tracked files).

---

## 4. .env and syncing secrets to GitHub Actions

- **Locally**: you maintain a single `.env` with all keys (VPS host, SSH key path or key content, relay hostname, etc.).
- **Sync script**: a script (e.g. `scripts/sync-secrets-to-github.sh`) that:
  - Reads your **local** `.env` (or a dedicated secrets file).
  - For each line `KEY=VALUE`, calls GitHub API or `gh secret set KEY --body VALUE` so that **repository secrets** are set for the cafe80 repo.
  - Uses **GitHub CLI (`gh`)** with appropriate auth (e.g. `gh auth login`) so the script runs under your identity and has permission to set repo secrets.
- **Security**: run the script only from your machine; never in CI. Add the script to the repo so others can use the same flow; document that the **source** of truth for secret values is local only.

Result: one place to edit (`.env`), one command to push to GitHub (sync script). No secrets in repo or PRs.

---

## 5. Web UI (free only)

- **RustDesk Web Client**: RustDesk supports a **web client** (browser-based). Hosting it yourself is free (open source); you’d serve the web client assets (and optional WebSocket endpoints) behind HTTPS. No extra license cost.
- **RustDesk “Web Console” (Pro)**: the 21114 “web console” is Pro-only; skip if you don’t want to pay.
- **Free admin UI options**: there is no official free “admin dashboard” for RustDesk OSS. Alternatives:
  - Use the **RustDesk desktop client** to connect and manage; no web UI needed.
  - A **minimal custom page** (e.g. static HTML or a tiny Flask/Node app) that shows “server status” (e.g. “RustDesk is running”) and links to client download/key instructions; no cost.
  - Later: open-source dashboards that list Docker containers (e.g. Portainer community) could be used only internally/VPN if you add them; not required for RustDesk itself.

Recommendation: start **without** a paid web console; use the **desktop client** for admin and optionally host the **free web client** for browser access. Add a minimal status page only if you want a simple “public” landing.

---

## 6. Backups (later: S3 & GDrive)

- **What to back up**: server-side RustDesk **data** (e.g. `./data` bind-mounted for hbbs/hbbr: keys, DB, logs). Optionally: Compose file and server config (already in repo).
- **Where**: S3 (e.g. AWS S3, MinIO, or S3-compatible) and/or Google Drive (e.g. rclone).
- **How**: cron or a systemd timer on the VPS that:
  - Creates a tarball (or restic/duplicity) of the data dir.
  - Encrypts (e.g. GPG or restic’s encryption).
  - Pushes to S3 and/or GDrive via rclone/s3 CLI.
- **Secrets**: backup credentials (S3 keys, GDrive OAuth) in server `.env` or a separate secrets store; never in the repo. You can later add a **backup job** in GitHub Actions that triggers a script on the server (via SSH) to run the backup, or run backup entirely on the server.

This can be a separate **docs/BACKUP.md** and a `scripts/backup/` (or `deploy/backup/`) when you’re ready.

---

## 7. How to proceed (recommended order)

1. **Create the repo (e.g. `cafe80`)**  
   - Public GitHub repo; add `.gitignore`, `README.md`, `PLAN.md`.

2. **Scaffold deployment and secrets**
   - Add `deploy/docker-compose.yml` (RustDesk hbbs/hbbr; relay host from env).
   - Add `.env.example` with every variable name and placeholder values.
   - Add `scripts/sync-secrets-to-github.sh` that reads `.env` and runs `gh secret set` for each line (with safety checks: no accidental run in CI, no commit of `.env`).

3. **One-time VPS setup**
   - Provision Ubuntu 22.04/24.04; create deploy user; add your SSH key.
   - Run OS hardening (SSH, UFW, fail2ban, unattended-upgrades) via script or Ansible from the repo (no secrets in scripts).
   - Install Docker (and Docker Compose) on the server.
   - On the server, create a `.env` (or copy from a one-time paste) with relay hostname and any other runtime secrets; ensure `docker compose` uses this file.

4. **GitHub Actions**
   - Store in repo secrets: `VPS_HOST`, `SSH_PRIVATE_KEY`, `DEPLOY_USER` (e.g. `deploy`), and any other needed vars.
   - Add `.github/workflows/deploy.yml`: SSH to VPS, copy compose and optional env-building step, run `docker compose pull && docker compose up -d`.
   - Test with `workflow_dispatch`; then optionally enable on push to `main`.

5. **Documentation**
   - README: what the repo does, how to clone, how to set up `.env` and run the sync script, how to deploy.
   - RUNBOOK: how to rotate secrets, how to recover, how to add the server public key to clients.

6. **Web UI (optional)**
   - If you want the free web client: add a reverse proxy (Caddy/Nginx) and serve the web client + HTTPS; document in RUNBOOK.

7. **Backups**
   - When ready: design backup script (tarball + encrypt + S3/GDrive), store backup credentials on server only, add BACKUP.md and optional cron/timer.

---

## 8. Summary

- **Security**: OS hardening (SSH, UFW, fail2ban, unattended-upgrades), RustDesk in Docker with limits and key-based encryption, no secrets in repo.
- **Deployment**: Public repo + GitHub Actions; secrets in GitHub Secrets and server `.env`; sync script to push local `.env` to GitHub.
- **Web UI**: Free web client or desktop client only; no paid Pro console.
- **Backups**: Later, with S3 and GDrive, credentials only on server or in GitHub Secrets (used by a backup job), never in repo.

If you tell me your preferred directory name (e.g. `cafe80` under `code`), I can generate the actual `docker-compose.yml`, `.env.example`, `sync-secrets-to-github.sh`, and a minimal `deploy.yml` next.
