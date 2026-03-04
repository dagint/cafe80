#!/usr/bin/env bash
# Join this host to your Tailscale tailnet with a tagged auth key.
# Run once on the VPS. Auth key must be passed in (not stored in repo).
#
# Goal: host is ON the tailnet so other tailnet devices can reach it (SSH, RustDesk).
#       This host must NOT be able to reach other tailnet resources (use ACLs; see docs/TAILSCALE.md).
#
# Usage (auth key from env or stdin):
#   TAILSCALE_AUTHKEY=tskey-auth-xxx ./ubuntu-tailscale.sh
#   Or: echo "tskey-auth-xxx" | ./ubuntu-tailscale.sh
#
# Create a tagged key in Admin -> Keys: tag:rustdesk-server (or your tag). Use that key here.

set -euo pipefail

TAG="${TAILSCALE_TAG:-tag:rustdesk-server}"

if [[ -n "${TAILSCALE_AUTHKEY:-}" ]]; then
  AUTHKEY="$TAILSCALE_AUTHKEY"
elif [[ ! -t 0 ]]; then
  AUTHKEY=$(cat)
else
  echo "Set TAILSCALE_AUTHKEY or pipe the key on stdin."
  exit 1
fi

# Install Tailscale (official method)
if ! command -v tailscale &>/dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi

# Join with tagged key so ACLs can restrict this node (no outbound to rest of tailnet)
tailscale up --authkey="$AUTHKEY" --advertise-tags="$TAG"

echo "Tailscale joined. Configure ACLs so this host only accepts inbound (see docs/TAILSCALE.md)."
