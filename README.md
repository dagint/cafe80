# Cafe80 – RustDesk server deployment

Deploy a **RustDesk** ID/relay server on Ubuntu with security-focused defaults and GitHub Actions.

- **Security**: OS hardening (SSH, UFW, fail2ban, unattended-upgrades), Docker with limits and no-new-privileges.
- **Secrets**: Local `.env` only; sync to GitHub with `scripts/sync-secrets-to-github.sh` (no PII in repo).
- **CI/CD**: GitHub Actions copies `deploy/` to the VPS and runs Docker Compose.

## Quick start

1. **Clone** this repo and create your env:
   ```bash
   cp .env.example .env
   # Edit .env with VPS_HOST, DEPLOY_USER, SSH_PRIVATE_KEY, RUSTDESK_RELAY_HOST
   ```

2. **Sync secrets to GitHub** (from repo root, with [gh](https://cli.github.com/) installed and logged in):
   ```bash
   ./scripts/sync-secrets-to-github.sh
   ```

3. **One-time VPS setup**: Ubuntu 22.04/24.04, deploy user, SSH key, firewall (ports 21115–21119/tcp, 21116/udp), fail2ban, unattended-upgrades, Docker. See [docs/RUNBOOK.md](docs/RUNBOOK.md).

4. **Deploy**: Run the "Deploy" workflow from the Actions tab or push to `main` (when `deploy/` or the workflow file changes).

5. **Clients**: Use `RUSTDESK_RELAY_HOST` as ID/Relay server; set **Key** to the server’s `deploy/data/id_ed25519.pub` content.

## Repo layout

- `deploy/` – Docker Compose for RustDesk (hbbs + hbbr).
- `scripts/` – `sync-secrets-to-github.sh` and (optional) hardening scripts.
- `docs/` – RUNBOOK, backup design (later).
- `.env.example` – Variable names and placeholders only; real values in `.env` (gitignored) and GitHub Secrets.

## Plan and runbook

- [PLAN.md](PLAN.md) – Security, backups, Web UI, and how to proceed.
- [docs/RUNBOOK.md](docs/RUNBOOK.md) – First-time setup, deploy, client config, recovery.

## License

MIT (or your choice). RustDesk server is under its own license.
