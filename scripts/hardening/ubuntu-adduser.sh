#!/usr/bin/env bash
# Add a user with sudo (password required) and docker group access.
# Run as root or with sudo.
#
# Usage:
#   NEW_USER=alice NEW_PASSWORD=secret USER_SSH_KEY="ssh-ed25519 ..." sudo -E bash ubuntu-adduser.sh
#
# NEW_USER      required  Username to create
# NEW_PASSWORD  optional  If unset, a random password is generated and printed once
# USER_SSH_KEY  optional  Public key added to ~/.ssh/authorized_keys

set -euo pipefail

if [[ -z "${NEW_USER:-}" ]]; then
  echo "Set NEW_USER before running."
  exit 1
fi

# Create user if not already present
if id "$NEW_USER" &>/dev/null; then
  echo "User $NEW_USER already exists, skipping creation."
else
  adduser --disabled-password --gecos "" "$NEW_USER"
fi

# Set password
if [[ -n "${NEW_PASSWORD:-}" ]]; then
  echo "$NEW_USER:$NEW_PASSWORD" | chpasswd
  echo "Password set."
else
  GENERATED="$(openssl rand -base64 16)"
  echo "$NEW_USER:$GENERATED" | chpasswd
  echo "Generated password for $NEW_USER: $GENERATED"
  echo "Save this — it will not be shown again."
fi

# Sudo with password (via sudo group)
usermod -aG sudo "$NEW_USER"

# Docker group
if getent group docker &>/dev/null; then
  usermod -aG docker "$NEW_USER"
  echo "Added $NEW_USER to docker group."
else
  echo "Docker group not found — install Docker first, then run: usermod -aG docker $NEW_USER"
fi

# Optional SSH key
if [[ -n "${USER_SSH_KEY:-}" ]]; then
  SSH_DIR="/home/$NEW_USER/.ssh"
  mkdir -p "$SSH_DIR"
  echo "$USER_SSH_KEY" >> "$SSH_DIR/authorized_keys"
  chmod 700 "$SSH_DIR"
  chmod 600 "$SSH_DIR/authorized_keys"
  chown -R "$NEW_USER:$NEW_USER" "$SSH_DIR"
  echo "SSH key added."
fi

echo "Done. $NEW_USER can sudo with password and is in the docker group."
