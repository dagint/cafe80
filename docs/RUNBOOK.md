# Cafe80 Runbook

## Before first deploy: DNS

Clients use **RUSTDESK_RELAY_HOST** (e.g. `rustdesk.dagint.com`) as the ID/Relay server. That hostname must resolve to your VPS.

- In your DNS provider, add an **A record**: `rustdesk.yourdomain.com` → your VPS **public IP**.
- Or use a **CNAME** to whatever hostname already points at that IP.
- Wait for propagation, then check: `ping rustdesk.yourdomain.com` (or use `dig`/`nslookup`).

If you skip this, the server will run but clients will not be able to connect to your relay hostname.

---

## First-time VPS setup

1. **Provision** Ubuntu 22.04/24.04 LTS (minimal).
2. **Create deploy user** (e.g. `deploy`), add your SSH public key to `~/.ssh/authorized_keys`.
3. **Harden OS** (run as root or with sudo):
   - SSH: disable root login, key-only auth, optional non-default port.
   - UFW: default deny incoming; allow SSH (22 or custom), RustDesk ports 21114/tcp (Pro web console), 21115–21119/tcp, 21116/udp.
   - Install and enable fail2ban (sshd): `scripts/hardening/ubuntu-initial.sh`.
   - **Optional – CrowdSec**: run `scripts/hardening/ubuntu-crowdsec.sh` for shared threat intel and firewall blocking; consider disabling fail2ban sshd jail if using both.
   - Enable unattended-upgrades for security.
4. **Optional – Tailscale**: to reach this host from your tailnet without exposing SSH publicly, run once (auth key from `.env` or Admin): `TAILSCALE_AUTHKEY=tskey-... ./scripts/hardening/ubuntu-tailscale.sh`. Then set ACLs so this host only **accepts** inbound (no outbound to other tailnet devices). See **docs/TAILSCALE.md**.
5. **Install Docker**: official method (`get.docker.com`) and add deploy user to `docker` group, or run compose with sudo. If using sudo in the workflow, the deploy user must have **passwordless sudo** for `docker compose` (e.g. NOPASSWD in sudoers).
6. **Create deploy directory** on server: `mkdir -p ~/cafe80` (or your `DEPLOY_PATH`).

## GitHub Actions secrets

Set these in the repo (Settings → Secrets and variables → Actions):

| Secret | Description |
|--------|-------------|
| `VPS_HOST` | VPS hostname or IP |
| `SSH_PRIVATE_KEY_B64` | Base64-encoded PEM key (`cat ~/.ssh/id_ed25519 \| base64 -w 0`) |
| `DEPLOY_USER` | SSH user (e.g. `deploy`) |
| `SSH_PORT` | Optional; default 22 |
| `DEPLOY_PATH` | Optional; default `~/cafe80` |
| `RUSTDESK_RELAY_HOST` | Hostname clients use (ID/Relay server); default = VPS_HOST |
| `RUSTDESK_IMAGE_REPO` | Defaults to `rustdesk/rustdesk-server-pro`; set to `rustdesk/rustdesk-server` for OSS |
| `TAILSCALE_AUTHKEY` | Optional; one-time join for Tailscale (use tagged key, see docs/TAILSCALE.md) |

Use `scripts/sync-secrets-to-github.sh` to push from your local `.env` (see README).

## Deploy

- **Via Actions**: push to `main` (changes under `deploy/` or this workflow) or run "Deploy" workflow manually.
- **Manual on server**: `cd ~/cafe80 && echo "RUSTDESK_RELAY_HOST=your-host" > .env && sudo docker compose -f docker-compose.yml up -d`.

## Client configuration

For **unattended access** (servers/workstations you support without someone clicking Allow) and **keeping “Enable remote configuration modification” off**, see **[docs/CLIENT-DEPLOYMENT.md](CLIENT-DEPLOYMENT.md)**.

After first run, on the server:

- `~/cafe80/data/id_ed25519.pub` is the **public key** (give this to clients; e.g. add to your download page).
- `~/cafe80/data/id_ed25519` is the **private key**; do not share it.
- In RustDesk client: Settings → Network → set **ID server** and **Relay server** to `RUSTDESK_RELAY_HOST`, and **Key** to the contents of `id_ed25519.pub`.
- **License activation (Pro)**: open `http://<server>:21114`, enter your license key in the web console, and save. The server will not relay connections until the license is activated.

**Back up the key:** Copy `~/cafe80/data/` (or at least `id_ed25519` and `id_ed25519.pub`) to a safe place right after first deploy. If the VPS is lost without a backup, you will need to redistribute a new key to all clients.

## Rotate secrets

1. Update local `.env`.
2. Run `./scripts/sync-secrets-to-github.sh` to update GitHub Secrets.
3. Re-run Deploy workflow if deploy credentials changed; restart containers if only app config changed.

## First deploy (day 1) — in order

1. **DNS**: Create A (or CNAME) for your relay hostname (e.g. `rustdesk.yourdomain.com`) → VPS IP.
2. **VPS**: Provision Ubuntu, create deploy user + SSH key, harden (ubuntu-initial.sh), install Docker, `mkdir -p ~/cafe80`.
3. **Secrets**: Set GitHub Actions secrets (VPS_HOST, SSH_PRIVATE_KEY, DEPLOY_USER, RUSTDESK_RELAY_HOST).
4. **Deploy**: Run the Deploy workflow (Actions → Deploy → Run workflow).
5. **Key**: SSH to the VPS and copy `~/cafe80/data/id_ed25519.pub` (and back up the whole `data/` folder).
6. **Clients**: Add the public key to your download page or docs; test with one RustDesk client (ID server = relay hostname, Key = contents of `.pub`).

---

## Rollback

Use when a deploy breaks the server or you need to revert to a known-good version.

### Application (RustDesk image)

**Option A – Workflow (no repo change)**  
1. Actions → Deploy → **Run workflow**.  
2. Under **Run workflow**, set **Override image tag** to the previous tag (e.g. `1.1.14`).  
3. Run. The workflow deploys that image; relay host and key are unchanged.

**Option B – Repo + workflow**  
1. In `deploy/docker-compose.yml`, set both `image:` lines back to the previous tag (e.g. `rustdesk/rustdesk-server:1.1.14`).  
2. Commit, push (triggers deploy), or run the Deploy workflow manually.  
3. After confirming rollback, you can change the compose back to the desired tag for future deploys.

**Option C – Manual on server**  
1. SSH to the VPS, `cd ~/cafe80` (or your DEPLOY_PATH).  
2. Edit `docker-compose.yml`: set both services’ `image:` to the previous tag.  
3. Run: `sudo docker compose -f docker-compose.yml pull && sudo docker compose -f docker-compose.yml up -d`.

### Data (key / DB)

If you restored a backup of `~/cafe80/data/` (e.g. after data loss or a bad change):  
1. Stop: `sudo docker compose -f docker-compose.yml down`.  
2. Replace `./data` contents with the backup.  
3. Start: `sudo docker compose -f docker-compose.yml up -d`.  
If the key changed, update clients or your download page with the restored `id_ed25519.pub`.

---

## Recovery

- **Data**: Backed up later to S3/GDrive (see PLAN.md). Restore into `deploy/data/` and redeploy.
- **Rebuild**: Re-run deploy workflow; ensure `RUSTDESK_RELAY_HOST` and key are unchanged so existing clients still work.
