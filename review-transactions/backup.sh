#!/usr/bin/env bash
# Backup review-transactions private files to the Obsidian vault (synced via Obsidian Sync)
# Run manually whenever you want a snapshot: bash backup.sh

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
DEST="${HOME}/Documents/Vault/claude-skills/$(basename "$SKILL_DIR")"

mkdir -p "$DEST"

cp "$SKILL_DIR/monarch-patterns.json" "$DEST/"
cp "$SKILL_DIR/account-context.md"    "$DEST/"
cp "$SKILL_DIR/state.json"            "$DEST/"

echo "Backed up to $DEST"
echo "  monarch-patterns.json"
echo "  account-context.md"
echo "  state.json"
