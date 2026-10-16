#!/usr/bin/env bash
# Run the pinned Godot binary, bootstrapping it first if needed.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${ROBBIE_CACHE:-$HOME/.cache/robbie}/godot-4.7.2-stable/godot"
[[ -x "$BIN" ]] || BIN="$("$ROOT/tools/bootstrap.sh")"
exec timeout "${ROBBIE_TIMEOUT:-900}" "$BIN" "$@"
