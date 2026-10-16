#!/usr/bin/env bash
# Survey every reference program (or those matching a glob) and print a one-line summary each.
# Usage: tools/fleet.sh ["game/content/programs/valve/*.rbt"] [fleet_size=10]
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
for f in ${1:-game/content/programs/*/*.rbt}; do
  room=$(basename "$(dirname "$f")")
  out=$(tools/certify.sh "$room" "$f" "${2:-10}" 1 2>&1 | sed -n '/^{/,$p')
  r=$(echo "$out" | python3 -c "
import sys, json
from collections import Counter
d = json.load(sys.stdin)
c = Counter(x['cause'] for x in d['dives'])
print(f\"{d['passed']:>2}/{d['fleet']} cpu={d['cpu']:<2}\", dict(c))" 2>&1 | tail -1)
  printf "%-52s %s\n" "$f" "$r"
done
