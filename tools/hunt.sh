#!/usr/bin/env bash
# Resumable exploit hunt for one room, in the background at low priority.
# Progress and results: out/hunt/<room>.json ("finished": true when done).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/out/hunt"
PROG="$ROOT/out/hunt/$1.json"
# A finished hunt is still re-run: hunt.gd resumes at its saved index, so programs added to
# the sweep later get tried, and it quits at once when there is nothing new.
ROBBIE_TIMEOUT=36000 nohup nice -n 15 "$ROOT/tools/godot.sh" --headless --path "$ROOT/game" \
  --script res://tools/hunt.gd -- "$1" "${2:-3}" "$PROG" > "$ROOT/out/hunt/$1.log" 2>&1 &
echo "$1: hunting in the background"
