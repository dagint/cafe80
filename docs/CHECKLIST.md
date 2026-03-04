# Cafe80 – What’s done and what’s missing

Quick reference against [PLAN.md](../PLAN.md). Use this to close gaps before or after first deploy.

---

## Done

- [x] **Repo layout**: deploy/, scripts/, docs/, .github/workflows, .env.example, .gitignore
- [x] **Deploy workflow**: SCP deploy/ to VPS, write .env with relay host, `docker compose up -d`
- [x] **Secrets sync**: `scripts/sync-secrets-to-github.sh` (local .env → GitHub Actions secrets)
- [x] **RustDesk Compose**: hbbs + hbbr, resource limits, no-new-privileges, **pinned image** (1.1.15)
- [x] **Hardening scripts**: ubuntu-initial.sh (UFW, fail2ban, unattended-upgrades), **fail2ban port** follows SSHD_PORT
- [x] **Optional hardening**: ubuntu-crowdsec.sh, ubuntu-tailscale.sh + docs/TAILSCALE.md
- [x] **Docs**: RUNBOOK (first-time setup, deploy, client config, recovery), PLAN, README

---

## Missing or manual (you should do)

| Item | Where / how |
|------|--------------|
| **DNS for relay hostname** | Create an **A record** (or CNAME): e.g. `rustdesk.yourdomain.com` → VPS public IP. See RUNBOOK "Before first deploy: DNS". |
| **SSH hardening** | PLAN says key-only auth, disable root, optional non-default port. Scripts don’t change `sshd_config` (to avoid lockout). Do once on the VPS: `PermitRootLogin no`, `PasswordAuthentication no`, create deploy user, add your key. |
| **Docker on VPS** | Not in repo. One-time: install Docker (e.g. get.docker.com) and add deploy user to `docker` group (or use sudo in workflow). |
| **Create deploy dir** | Workflow creates it; optional: `mkdir -p ~/cafe80` (or your DEPLOY_PATH). Workflow doesn’t create it. |
| **GitHub Secrets** | Set VPS_HOST, SSH_PRIVATE_KEY, DEPLOY_USER; optional SSH_PORT, DEPLOY_PATH, RUSTDESK_RELAY_HOST. Use sync script or add in repo Settings. |
| **First deploy** | Follow RUNBOOK "First deploy (day 1)". After deploy, back up `~/cafe80/data/` and add the public key to your download page. |

---

## Optional / later

| Item | Notes |
|------|--------|
| **security-scan.yml** | PLAN mentions optional Trivy/CodeQL workflow. Add under `.github/workflows/` if you want CI scans. |
| **Compose validate + smoke test** | Workflow could add a step to validate compose and curl a RustDesk port after deploy. |
| **Backups** | Planned for later. Add docs/BACKUP.md and a script (tarball + encrypt + S3/GDrive); credentials on server or in secrets only. |
| **Web client** | Free RustDesk web client: reverse proxy (Caddy/Nginx) + HTTPS; document in RUNBOOK if you add it. |
| **Dependabot** | Enable in repo for GitHub Actions and (if any) Docker base images. |
| **Branch protection** | Optional: require PR reviews, no force-push to main. |

---

## Image pinning

Compose uses `rustdesk/rustdesk-server:1.1.15`. To upgrade:

1. Check [RustDesk server releases](https://github.com/rustdesk/rustdesk-server/releases).
2. Update the tag in `deploy/docker-compose.yml` for both hbbs and hbbr.
3. Commit and push (or run Deploy workflow) so the VPS pulls the new image.
