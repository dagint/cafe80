# Cafe80 Runbook

## First-time VPS setup

1. **Provision** Ubuntu 22.04/24.04 LTS (minimal).
2. **Create deploy user** (e.g. `deploy`), add your SSH public key to `~/.ssh/authorized_keys`.
3. **Harden OS** (run as root or with sudo):
   - SSH: disable root login, key-only auth, optional non-default port.
   - UFW: default deny incoming; allow SSH (22 or custom), RustDesk ports 21115–21119/tcp, 21116/udp.
   - Install and enable fail2ban (sshd).
   - Enable unattended-upgrades for security.
4. **Install Docker**: official method (`get.docker.com`) and add deploy user to `docker` group, or run compose with sudo.
5. **Create deploy directory** on server: `mkdir -p ~/cafe80` (or your `DEPLOY_PATH`).

## GitHub Actions secrets

Set these in the repo (Settings → Secrets and variables → Actions):

| Secret | Description |
|--------|-------------|
| `VPS_HOST` | VPS hostname or IP |
| `SSH_PRIVATE_KEY` | Full PEM body for the deploy user |
| `DEPLOY_USER` | SSH user (e.g. `deploy`) |
| `SSH_PORT` | Optional; default 22 |
| `DEPLOY_PATH` | Optional; default `~/cafe80` |
| `RUSTDESK_RELAY_HOST` | Hostname clients use (ID/Relay server); default = VPS_HOST |

Use `scripts/sync-secrets-to-github.sh` to push from your local `.env` (see README).

## Deploy

- **Via Actions**: push to `main` (changes under `deploy/` or this workflow) or run "Deploy" workflow manually.
- **Manual on server**: `cd ~/cafe80 && echo "RUSTDESK_RELAY_HOST=your-host" > .env && sudo docker compose -f docker-compose.yml up -d`.

## Client configuration

After first run, on the server:

- `~/cafe80/data/id_ed25519.pub` is the **public key**.
- In RustDesk client: Settings → Network → set **ID server** and **Relay server** to `RUSTDESK_RELAY_HOST`, and **Key** to the contents of `id_ed25519.pub`.

## Rotate secrets

1. Update local `.env`.
2. Run `./scripts/sync-secrets-to-github.sh` to update GitHub Secrets.
3. Re-run Deploy workflow if deploy credentials changed; restart containers if only app config changed.

## Recovery

- **Data**: Backed up later to S3/GDrive (see PLAN.md). Restore into `deploy/data/` and redeploy.
- **Rebuild**: Re-run deploy workflow; ensure `RUSTDESK_RELAY_HOST` and key are unchanged so existing clients still work.
