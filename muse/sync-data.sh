#!/usr/bin/env bash
# Keep a skill's data on the OCI VM as the single source of truth.
#
#   bash sync-data.sh <skill> pull   # at startup: copy VM data here, remember its hashes
#   bash sync-data.sh <skill> push   # after writing: copy back, refusing (exit 2) if the VM changed meanwhile
#
# On the VM itself (hostname clouddesktop) both are no-ops. Override the remote with SKILL_SYNC_REMOTE.

set -euo pipefail
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
. "$HERE/skills.sh"
SKILL="${1:-}"; ACTION="${2:-}"
skill_config "$SKILL"

[[ "$(hostname)" == "clouddesktop" ]] && { echo "On the VM: data is local, nothing to sync."; exit 0; }

SKILL_DIR="$HOME/.claude/skills/$SKILL"
REMOTE="${SKILL_SYNC_REMOTE:-${REVIEW_TXN_REMOTE:-clouddesktop}}"
REMOTE_DIR=".claude/skills/$SKILL"
BASE="$SKILL_DIR/.sync-base"

remote_hashes() {
  ssh -o BatchMode=yes -o ConnectTimeout=10 "$REMOTE" \
    "cd $REMOTE_DIR && sha256sum $DATA_FILES 2>/dev/null || true" | sort -k2
}

case "$ACTION" in
  pull)
    for f in $DATA_FILES; do
      scp -q -o BatchMode=yes "$REMOTE:$REMOTE_DIR/$f" "$SKILL_DIR/$f" 2>/dev/null || true
    done
    remote_hashes > "$BASE"
    echo "Pulled $SKILL data from $REMOTE." ;;
  push)
    [[ -f "$BASE" ]] || { echo "ERROR: no .sync-base, run pull first." >&2; exit 1; }
    if ! diff -q <(remote_hashes) "$BASE" >/dev/null; then
      echo "ERROR: VM data changed since pull (another run happened, e.g. via Muse)." >&2
      echo "Not overwriting. Pull, redo this run's updates on top, and push again." >&2
      exit 2
    fi
    for f in $DATA_FILES; do
      [[ -f "$SKILL_DIR/$f" ]] && scp -q -o BatchMode=yes "$SKILL_DIR/$f" "$REMOTE:$REMOTE_DIR/$f"
    done
    remote_hashes > "$BASE"
    echo "Pushed $SKILL data to $REMOTE." ;;
  *) echo "usage: $0 <skill> pull|push" >&2; exit 1 ;;
esac
