#!/usr/bin/env bash
# Backup review-transactions private files to Google Drive (Vault)
# Run manually whenever you want a snapshot: bash backup.sh

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="${HOME}/gdrive/Vault/claude-skills"

if [ ! -d "${HOME}/gdrive" ] || ! mountpoint -q "${HOME}/gdrive"; then
  echo "gdrive is not mounted. Run: systemctl --user start rclone-gdrive.service"
  exit 1
fi

mkdir -p "$DEST"

cp "$SKILL_DIR/monarch-patterns.json" "$DEST/"
cp "$SKILL_DIR/account-context.md"    "$DEST/"
cp "$SKILL_DIR/state.json"            "$DEST/"

echo "Backed up to $DEST"
echo "  monarch-patterns.json"
echo "  account-context.md"
echo "  state.json"
