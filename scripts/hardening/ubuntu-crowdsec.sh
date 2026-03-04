#!/usr/bin/env bash
# Install CrowdSec + firewall bouncer for SSH (and optionally other services).
# Run as root or with sudo. No secrets.
# Use instead of or after fail2ban: CrowdSec uses shared threat intel and blocks at the firewall.
# See PLAN.md §2.1 and https://docs.crowdsec.net/

set -euo pipefail

# Install CrowdSec (official one-liner adds repo and installs engine)
if ! command -v crowdsec &>/dev/null; then
  curl -s https://install.crowdsec.net | sudo sh
fi

# Install firewall bouncer (iptables; use nftables bouncer if your system uses nftables)
BOUNCER="crowdsec-firewall-bouncer-iptables"
if command -v nft &>/dev/null && ! command -v iptables-legacy &>/dev/null 2>/dev/null; then
  BOUNCER="crowdsec-firewall-bouncer-nftables"
fi
apt-get update -qq
apt-get install -y "$BOUNCER" || true

# Ensure sshd scenario is enabled (parses logs and triggers decisions)
cscli scenarios install linux/sshd 2>/dev/null || true
cscli scenarios enable linux/sshd 2>/dev/null || true

# Optional: enable nginx if you add a reverse proxy later
# cscli scenarios install nginx/nginx-proxy && cscli scenarios enable nginx/nginx-proxy

systemctl enable --now crowdsec
systemctl enable --now crowdsec-firewall-bouncer 2>/dev/null || true

echo "CrowdSec installed. Check: sudo cscli decisions list"
echo "If you also use fail2ban, consider disabling fail2ban sshd jail to avoid duplicate blocking."
