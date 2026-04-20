# CLAUDE.md — Cafe80

## Project

Self-hosted **RustDesk** ID/relay server on Ubuntu VPS, deployed via GitHub Actions.
Stack: Docker Compose (hbbs + hbbr), hardening scripts, secrets managed via `.env` + `gh secret set`.

## Repo layout

```
deploy/docker-compose.yml         # RustDesk hbbs + hbbr + Caddy services
deploy/Caddyfile                  # Caddy reverse proxy config (HTTPS → :21114)
scripts/sync-secrets-to-github.sh # Push local .env → GitHub Actions secrets
scripts/hardening/ubuntu-initial.sh
scripts/hardening/ubuntu-crowdsec.sh
scripts/hardening/ubuntu-tailscale.sh
.github/workflows/deploy.yml      # SCP deploy/ to VPS, docker compose up -d
.env                              # Real secrets — gitignored, never commit
.env.example                      # Template with placeholder values
docs/RUNBOOK.md                   # First-time setup, deploy, rollback
docs/CHECKLIST.md                 # What's done vs missing
```

## Environment

- Dev machine: Windows with WSL2 (paths under `/mnt/c/Users/...`)
- Scripts require LF line endings — enforced by `.gitattributes` (`*.sh text eol=lf`)
- Shell scripts use `#!/usr/bin/env bash` + `set -euo pipefail`

## Secrets model

- Local `.env` is the source of truth for all credentials (gitignored)
- `scripts/sync-secrets-to-github.sh` reads `.env` and calls `gh secret set` for each key
- GitHub Actions secrets are consumed by `appleboy/ssh-action` and `appleboy/scp-action`
- `.env` values must be single-line (no embedded newlines)
- `SSH_PRIVATE_KEY_B64`: base64-encode the key first (`cat ~/.ssh/id_ed25519 | base64 -w 0`); workflow decodes it to `$RUNNER_TEMP/deploy_key` and passes `key_path` to appleboy actions

## Known issues in sync-secrets-to-github.sh

1. **SSH key format**: `SSH_PRIVATE_KEY` stored as a single line in `.env` (no newlines between PEM header/body/footer). `appleboy/ssh-action` may fail to parse it. Fix: the key must have real newlines or be converted on the way to `gh secret set`.

2. **Comment stripping bug** (line 45): `line="${line%%#*}"` silently truncates values containing `#` (e.g. URLs with fragments). Safe for current `.env` values but a latent bug.

3. **No `--repo` flag**: `gh secret set "$key"` infers the repo from the git remote in the current directory. Script does `cd "$REPO_ROOT"` so it works, but it would be more robust to pass `--repo "$REPO"` explicitly.

## GitHub Actions secrets required

| Secret | Required | Notes |
|---|---|---|
| `VPS_HOST` | Yes | VPS hostname or IP |
| `SSH_PRIVATE_KEY_B64` | Yes | Base64-encoded PEM key (see below) |
| `DEPLOY_USER` | Yes | SSH username (e.g. `deploy`) |
| `SSH_PORT` | No | Defaults to 22 |
| `DEPLOY_PATH` | No | Defaults to `~/cafe80` |
| `RUSTDESK_RELAY_HOST` | No | Defaults to `VPS_HOST` |

## RustDesk image

Defaults to `rustdesk/rustdesk-server-pro:1.1.15` (licensed Pro) in `deploy/docker-compose.yml`.
Override `RUSTDESK_IMAGE_REPO` in `.env` to switch images (e.g. `rustdesk/rustdesk-server` for OSS).
Pro web console on :21114 is reverse-proxied by Caddy (HTTPS on :443). Activate your license at `https://RUSTDESK_RELAY_HOST`.
Check [github.com/rustdesk/rustdesk-server-pro/releases](https://github.com/rustdesk/rustdesk-server-pro/releases) before upgrading.
To upgrade: update both `hbbs` and `hbbr` image tags, commit and push (or run workflow).

## Key files on the VPS (after first deploy)

```
~/cafe80/data/id_ed25519.pub   # Give to RustDesk clients as "Key"
~/cafe80/data/id_ed25519       # Private key — back this up immediately
~/cafe80/.env                  # Written by deploy workflow (RUSTDESK_RELAY_HOST)
```

## Rollback

Run "Deploy" workflow → set "Override image tag" to previous tag (e.g. `1.1.14`).
See `docs/RUNBOOK.md` § Rollback for manual options.

## VPS setup checklist (one-time)

- [ ] DNS A record for relay hostname → VPS IP
- [ ] Ubuntu 22.04/24.04, deploy user, SSH key in `authorized_keys`
- [ ] SSH: `PermitRootLogin no`, `PasswordAuthentication no`
- [ ] UFW: allow 22 (or custom SSH port), 80/tcp, 443/tcp (Caddy), 21115–21119/tcp, 21116/udp
- [ ] `scripts/hardening/ubuntu-initial.sh` (fail2ban, unattended-upgrades)
- [ ] Docker installed, deploy user in `docker` group (or passwordless sudo for `docker compose`)
- [ ] `mkdir -p ~/cafe80`
- [ ] Back up `~/cafe80/data/` after first deploy

## What NOT to do

- Do not commit `.env` — it contains live credentials
- Do not store SSH private keys without proper PEM formatting (newlines matter)
- Do not push to main unless deploy secrets are configured — the workflow fires on push to main when `deploy/` changes
