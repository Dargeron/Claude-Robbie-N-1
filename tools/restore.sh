#!/usr/bin/env bash
# Recreate the working repository from the backup bundle (for a fresh workspace).
# Usage: tools/restore.sh [target_dir=/home/claude/robbie]
set -euo pipefail
SRC="${ROBBIE_BACKUP_DIR:-/mnt/user-data/outputs}/robbie-n1.bundle"
TARGET="${1:-/home/claude/robbie}"
[[ -d "$TARGET/.git" ]] && { echo "$TARGET already exists"; exit 0; }
git clone -q "$SRC" "$TARGET"
cd "$TARGET" && git checkout -q main
echo "restored into $TARGET"
