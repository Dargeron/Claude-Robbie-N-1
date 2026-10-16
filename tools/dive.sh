#!/usr/bin/env bash
# Run one dive headless and print its outcome as JSON.
# Usage: tools/dive.sh <room> <program.rbt> [seed] [--calm] [--png out.png] [--trace]
# Example: tools/dive.sh dark game/content/programs/dark/intended.rbt 1 --png out/dark.png
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARGS=()
for a in "$@"; do
  # Paths given relative to the repo become absolute, since Godot runs from game/.
  if [[ -e "$a" || "$a" == *.png ]]; then ARGS+=("$(realpath -m "$a")"); else ARGS+=("$a"); fi
done
"$ROOT/tools/godot.sh" --headless --path "$ROOT/game" --script res://tools/run_dive.gd -- "${ARGS[@]}"
