#!/usr/bin/env bash
# Run the solver on every room in turn, in the background (one process at a time).
# Usage: tools/solve_all.sh [total_evaluations_per_room=300]: each room is searched until its
# cumulative count reaches the target, least-searched rooms first, so restarts never redo work.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/out/solve"
(
  rooms=$(cd "$ROOT" && python3 -c "
import json, os
rs = ['dark', 'jellyfish', 'nursery', 'valve', 'listeners']
def n(r):
    p = 'out/solve/%s.json' % r
    return json.load(open(p)).get('evaluations', 0) if os.path.exists(p) else 0
print(' '.join(sorted(rs, key=n)))")
  for room in $rooms; do
    ROBBIE_TIMEOUT=36000 nice -n 15 "$ROOT/tools/godot.sh" --headless --path "$ROOT/game" \
      --script res://tools/solve.gd -- "$room" "${1:-300}" "$ROOT/out/solve/$room.json" > "$ROOT/out/solve/$room.log" 2>&1
  done
) > /dev/null 2>&1 &
echo "solving every room in the background"
