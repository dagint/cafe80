#!/usr/bin/env bash
# Install CrowdSec + firewall bouncer for SSH (and optionally other services).
# Run as root or with sudo. No secrets.
# Use instead of or after fail2ban: CrowdSec uses shared threat intel and blocks at the firewall.
# See PLAN.md §2.1 and https://docs.crowdsec.net/

set -euo pipefail

# Add CrowdSec repo (install.crowdsec.net only adds the apt source, does not install)
if ! command -v crowdsec &>/dev/null; then
  curl -s https://install.crowdsec.net | sh
  apt-get install -y crowdsec
fi

# Install firewall bouncer (iptables; auto-detects nftables)
BOUNCER="crowdsec-firewall-bouncer-iptables"
if command -v nft &>/dev/null && ! command -v iptables-legacy &>/dev/null 2>/dev/null; then
  BOUNCER="crowdsec-firewall-bouncer-nftables"
fi
apt-get install -y "$BOUNCER" || true

# Register the bouncer with the local LAPI and inject the API key into its config
BOUNCER_NAME="firewall-bouncer-$(hostname -s)"
API_KEY=$(cscli bouncers add "$BOUNCER_NAME" --key "" -o raw 2>/dev/null || true)
if [[ -n "$API_KEY" ]]; then
  BOUNCER_CFG="/etc/crowdsec/bouncers/crowdsec-firewall-bouncer.yaml"
  sed -i "s/^api_key:.*/api_key: ${API_KEY}/" "$BOUNCER_CFG"
  echo "Bouncer registered: $BOUNCER_NAME"
else
  echo "Bouncer may already be registered or cscli failed — check manually:"
  echo "  cscli bouncers list"
  echo "  cscli bouncers add firewall-bouncer-manual"
fi

# Ensure sshd scenario is enabled
cscli scenarios install crowdsecurity/ssh-bf 2>/dev/null || true

systemctl enable --now crowdsec
systemctl restart crowdsec-firewall-bouncer 2>/dev/null || systemctl enable --now crowdsec-firewall-bouncer || true

echo "CrowdSec installed. Check: cscli decisions list"
echo "If you also use fail2ban, consider disabling the fail2ban sshd jail."
