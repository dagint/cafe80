#!/usr/bin/env bash
# Ubuntu VPS initial hardening (run as root or with sudo).
# No secrets – adjust ports/usernames for your environment.
# See PLAN.md §2.1 and docs/RUNBOOK.md.

set -euo pipefail

# --- SSH (adjust before run) ---
# Optionally set a custom SSH port, e.g. SSHD_PORT=9022
SSHD_PORT="${SSHD_PORT:-22}"

# --- UFW: allow SSH and RustDesk only ---
ufw default deny incoming
ufw default allow outgoing
ufw allow "$SSHD_PORT/tcp"
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
