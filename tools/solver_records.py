#!/usr/bin/env python3
"""Write game/content/solver/records.json from the solver's results in out/solve/.

For each room: the cheapest certified CPU the solver (or our reference programs) has
found, and how many distinct certified programs it knows. The programs themselves are
not shipped with the game. Run after tools/solve_all.sh; commit the result.
"""
import json, os, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = {}
for room in ["dark", "jellyfish", "nursery", "valve", "listeners", "lock"]:
    p = os.path.join(root, "out", "solve", room + ".json")
    if not os.path.exists(p):
        continue
    d = json.load(open(p))
    # Only finds certified by the current survey (16 of 20; older runs kept 8-of-10 passes,
    # which the solver re-checks when it next runs that room).
    found = {k: v for k, v in d.get("found", {}).items() if int(v.get("passed", 0)) >= 16}
    if not found:
        continue
    cpus = [int(v["cpu"]) for v in found.values()]
    out[room] = {"cpu": min(cpus), "certified_programs": len(found), "evaluations": int(d.get("evaluations", 0))}
dest = os.path.join(root, "game", "content", "solver", "records.json")
os.makedirs(os.path.dirname(dest), exist_ok=True)
json.dump(out, open(dest, "w"), indent=2, sort_keys=True)
print(json.dumps(out, indent=2, sort_keys=True))
