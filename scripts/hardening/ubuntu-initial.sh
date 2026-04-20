#!/usr/bin/env bash
# Ubuntu VPS initial hardening (run as root or with sudo).
# No secrets – adjust ports/usernames for your environment.
# See PLAN.md §2.1 and docs/RUNBOOK.md.

set -euo pipefail

# --- SSH (adjust before run) ---
# Optionally set a custom SSH port, e.g. SSHD_PORT=9022
SSHD_PORT="${SSHD_PORT:-22}"
# Space-separated IPs/CIDRs allowed to SSH, e.g. "1.2.3.4 10.0.0.0/8"
# Leave empty to allow SSH from anywhere (not recommended)
SSH_ALLOW_IPS="${SSH_ALLOW_IPS:-}"
# Set to 1 to also allow SSH from the Tailscale interface (tailscale0)
SSH_ALLOW_TAILSCALE="${SSH_ALLOW_TAILSCALE:-1}"

# --- UFW: allow SSH and RustDesk only ---
ufw default deny incoming
ufw default allow outgoing

if [[ -n "$SSH_ALLOW_IPS" ]]; then
  for ip in $SSH_ALLOW_IPS; do
    ufw allow from "$ip" to any port "$SSHD_PORT" proto tcp
  done
else
  ufw allow "$SSHD_PORT/tcp"
fi

if [[ "${SSH_ALLOW_TAILSCALE}" == "1" ]]; then
  ufw allow in on tailscale0 to any port "$SSHD_PORT" proto tcp
fi

ufw allow 21114/tcp comment 'RustDesk Pro web console'
ufw allow 21115:21119/tcp
ufw allow 21116/udp
ufw --force enable

# --- Fail2ban for SSH ---
apt-get update -qq
apt-get install -y fail2ban
# Use SSHD_PORT so fail2ban watches the correct port when SSH is on a non-default port
FAIL2BAN_PORT="${SSHD_PORT:-22}"
cat > /etc/fail2ban/jail.d/sshd.local << EOF
[sshd]
enabled = true
port = ${FAIL2BAN_PORT}
maxretry = 3
bantime = 3600
findtime = 600
EOF
systemctl enable --now fail2ban

# --- Unattended security updates ---
apt-get install -y unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades || true

echo "Hardening applied. Ensure SSH key auth is working before disconnecting."
echo "If you changed SSHD_PORT, allow it in UFW and reload sshd."
