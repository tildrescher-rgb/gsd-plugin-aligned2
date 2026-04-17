#!/bin/bash
set -euo pipefail

# --- Configuration ---
REPO="gsd-build/get-shit-done"
VERSION_FILE="$HOME/.gsd-last-known-version"
GH="/opt/homebrew/bin/gh"
CURL="/usr/bin/curl"
SSH="/usr/bin/ssh"
RECIPIENT="jnuyens"
MAIL_HOST="m1.linuxbe.com"

# --- Network connectivity check ---
# Hit a lightweight GitHub endpoint; exit silently if unreachable
$CURL -sf --max-time 5 https://api.github.com/zen >/dev/null 2>&1 || exit 0

# --- Fetch latest release tag ---
LATEST=$($GH api "repos/$REPO/releases/latest" --jq '.tag_name' 2>/dev/null) || exit 0

# Strip leading "v" if present
LATEST="${LATEST#v}"

# Validate LATEST is non-empty
if [ -z "$LATEST" ]; then
  exit 0
fi

# --- First-run handling ---
# If version file does not exist, save current version and exit (no email)
if [ ! -f "$VERSION_FILE" ]; then
  echo "$LATEST" > "$VERSION_FILE"
  exit 0
fi

# --- Version comparison ---
PREVIOUS=$(cat "$VERSION_FILE")

if [ "$LATEST" = "$PREVIOUS" ]; then
  exit 0
fi

# --- Send notification email via SSH to mail host ---
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
BODY="New GSD upstream release detected.

New version:      v${LATEST}
Previous version: v${PREVIOUS}
Release URL:      https://github.com/${REPO}/releases/tag/v${LATEST}
Checked at:       ${TIMESTAMP}

--
Sent by check-gsd-release.sh on $(hostname)"

echo "$BODY" | $SSH "$MAIL_HOST" "mail -s 'GSD upstream release: v${LATEST} available (was v${PREVIOUS})' $RECIPIENT"

# --- Update version file (only after successful mail send) ---
echo "$LATEST" > "$VERSION_FILE"
