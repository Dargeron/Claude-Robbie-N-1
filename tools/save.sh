#!/usr/bin/env bash
# Back up the whole repository (all branches) to the session's persistent outputs folder.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="${ROBBIE_BACKUP_DIR:-/mnt/user-data/outputs}"
mkdir -p "$DEST"
git -C "$ROOT" bundle create "$DEST/robbie-n1.bundle" --all >/dev/null 2>&1
git -C "$ROOT" archive --format=zip --prefix=robbie-n1/ -o "$DEST/robbie-n1.zip" main
echo "saved $(git -C "$ROOT" rev-parse --short HEAD) to $DEST/robbie-n1.bundle"
