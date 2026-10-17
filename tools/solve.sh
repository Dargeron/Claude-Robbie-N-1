#!/usr/bin/env bash
# Solver v1 in the background: mutation search for the cheapest certifying program.
# Usage: tools/solve.sh <room> [evaluations=400]. Cumulative results in out/solve/<room>.json.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/out/solve"
ROBBIE_TIMEOUT=36000 nohup nice -n 15 "$ROOT/tools/godot.sh" --headless --path "$ROOT/game" \
  --script res://tools/solve.gd -- "$1" "${2:-400}" "$ROOT/out/solve/$1.json" > "$ROOT/out/solve/$1.log" 2>&1 &
echo "$1: solving in the background"
