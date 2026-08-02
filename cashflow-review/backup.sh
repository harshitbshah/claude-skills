#!/usr/bin/env bash
# Backup cashflow-review private files to Google Drive (Vault)
# Run manually whenever you want a snapshot: bash backup.sh

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="${HOME}/Documents/Vault/claude-skills"

mkdir -p "$DEST"

cp "$SKILL_DIR/history.json"  "$DEST/"
cp "$SKILL_DIR/insights.json" "$DEST/"

echo "Backed up to $DEST"
echo "  history.json"
echo "  insights.json"
