#!/usr/bin/env bash
# Resumable exploit hunt for one room, in the background at low priority.
# Progress and results: out/hunt/<room>.json ("finished": true when done).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/out/hunt"
PROG="$ROOT/out/hunt/$1.json"
if [[ -f "$PROG" ]] && grep -q '"finished": true' "$PROG"; then echo "$1: already finished"; exit 0; fi
ROBBIE_TIMEOUT=36000 nohup nice -n 15 "$ROOT/tools/godot.sh" --headless --path "$ROOT/game" \
  --script res://tools/hunt.gd -- "$1" "${2:-3}" "$PROG" > "$ROOT/out/hunt/$1.log" 2>&1 &
echo "$1: hunting in the background"
