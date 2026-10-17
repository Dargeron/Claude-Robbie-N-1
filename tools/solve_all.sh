#!/usr/bin/env bash
# Run the solver on every room in turn, in the background (one process at a time).
# Usage: tools/solve_all.sh [evaluations_per_room=150]
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/out/solve"
(
  for room in dark jellyfish nursery valve; do
    ROBBIE_TIMEOUT=36000 nice -n 15 "$ROOT/tools/godot.sh" --headless --path "$ROOT/game" \
      --script res://tools/solve.gd -- "$room" "${1:-150}" "$ROOT/out/solve/$room.json" > "$ROOT/out/solve/$room.log" 2>&1
  done
) > /dev/null 2>&1 &
echo "solving every room in the background"
