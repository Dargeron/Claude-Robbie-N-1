#!/usr/bin/env bash
# Send a survey fleet: run a program on N seeds and report the pass rate.
# Usage: tools/certify.sh <room> <program.rbt> [fleet_size=10] [first_seed=1]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROG="$(realpath -m "$2")"
"$ROOT/tools/godot.sh" --headless --path "$ROOT/game" --script res://tools/certify.gd -- "$1" "$PROG" "${3:-10}" "${4:-1}"
