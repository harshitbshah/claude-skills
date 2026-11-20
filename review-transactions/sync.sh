#!/usr/bin/env bash
# Keep review-transactions data on the OCI VM as the single source of truth.
#
#   bash sync.sh pull   # at startup: copy VM data here, remember its hashes
#   bash sync.sh push   # after writing data: copy back, refusing if the VM changed meanwhile
#
# On the VM itself (hostname clouddesktop) both commands are no-ops.
# Override the remote with REVIEW_TXN_REMOTE=user@host.

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "$0")" && pwd)"
REMOTE="${REVIEW_TXN_REMOTE:-clouddesktop}"  # ssh alias in ~/.ssh/config
REMOTE_DIR=".claude/skills/review-transactions"
FILES=(monarch-patterns.json state.json account-context.md categories-cache.json pending-roth.json)
BASE="$SKILL_DIR/.sync-base"

if [[ "$(hostname)" == "clouddesktop" ]]; then
  echo "On the VM: data is local, nothing to sync."
  exit 0
fi

remote_hashes() {
  # Prints "<sha> <file>" for each file that exists on the VM (sorted, stable).
  ssh -o BatchMode=yes -o ConnectTimeout=10 "$REMOTE" \
    "cd $REMOTE_DIR && sha256sum ${FILES[*]} 2>/dev/null || true" | sort -k2
}

case "${1:-}" in
  pull)
    for f in "${FILES[@]}"; do
      scp -q -o BatchMode=yes "$REMOTE:$REMOTE_DIR/$f" "$SKILL_DIR/$f" 2>/dev/null || true
    done
    remote_hashes > "$BASE"
    echo "Pulled review-transactions data from $REMOTE."
    ;;
  push)
    if [[ ! -f "$BASE" ]]; then
      echo "ERROR: no .sync-base — run 'sync.sh pull' first." >&2; exit 1
    fi
    if ! diff -q <(remote_hashes) "$BASE" >/dev/null; then
      echo "ERROR: VM data changed since pull (another run happened, e.g. via Muse)." >&2
      echo "Not overwriting. Run 'sync.sh pull' and redo the pattern updates." >&2
      exit 2
    fi
    for f in "${FILES[@]}"; do
      [[ -f "$SKILL_DIR/$f" ]] && scp -q -o BatchMode=yes "$SKILL_DIR/$f" "$REMOTE:$REMOTE_DIR/$f"
    done
    remote_hashes > "$BASE"
    echo "Pushed review-transactions data to $REMOTE."
    ;;
  *)
    echo "usage: $0 pull|push" >&2; exit 1
    ;;
esac
