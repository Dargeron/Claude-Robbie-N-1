#!/usr/bin/env bash
# Re-record golden replays after a deliberate change to the simulation.
# Always say in the commit message why the dives changed.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/tools/godot.sh" --headless --path "$ROOT/game" --script res://tools/bless.gd
