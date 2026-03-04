#!/usr/bin/env bash
# Sync local .env to GitHub Actions repository secrets.
# Run only from your machine; requires gh CLI and gh auth login.
# Usage: ./scripts/sync-secrets-to-github.sh [path-to-.env]
# Note: .env values must be single-line (no embedded newlines in values).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="${1:-$REPO_ROOT/.env}"

# Safety: do not run in CI
if [[ -n "${CI:-}" && "${CI}" == "true" ]]; then
  echo "Refusing to sync secrets in CI."
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Env file not found: $ENV_FILE"
  echo "Copy .env.example to .env and fill in values, then run again."
  exit 1
fi

if ! command -v gh &>/dev/null; then
  echo "GitHub CLI (gh) is required. Install: https://cli.github.com/"
  exit 1
fi

if ! gh auth status &>/dev/null; then
  echo "Run: gh auth login"
  exit 1
fi

# Use repo from current directory
cd "$REPO_ROOT"
REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)
if [[ -z "$REPO" ]]; then
  echo "Not a GitHub repo or gh could not determine repo. Run from cafe80 repo root."
  exit 1
fi
echo "Syncing secrets to repository: $REPO"

while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%%#*}"
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -z "$line" ]] && continue
  if [[ "$line" != *=* ]]; then
    echo "Skipping invalid line: $line"
    continue
  fi
  key="${line%%=*}"
  key="${key%"${key##*[![:space:]]}"}"
  value="${line#*=}"
  value="${value#\"}"
  value="${value%\"}"
  [[ -z "$key" ]] && continue
  if [[ -z "$value" ]]; then
    echo "Skipping empty value for $key"
    continue
  fi
  echo "Setting secret: $key"
  printf '%s' "$value" | gh secret set "$key"
done < "$ENV_FILE"

echo "Done. Verify with: gh secret list"
