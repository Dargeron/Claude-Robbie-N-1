#!/usr/bin/env bash
# Run every test headless. Exit code is non-zero on any failure.
# Usage: tools/test.sh [name-filter]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT/tools/godot.sh" --headless --path "$ROOT/game" --script res://tools/run_tests.gd -- "$@"
