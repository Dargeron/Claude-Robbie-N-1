#!/usr/bin/env python3
"""Write game/content/solver/records.json from the solver's results in out/solve/.

For each room: the cheapest certified CPU the solver (or our reference programs) has
found, and how many distinct certified programs it knows. The programs themselves are
not shipped with the game. Run after tools/solve_all.sh; commit the result.
"""
import json, os, sys
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
out = {}
for room in ["dark", "jellyfish", "nursery", "valve"]:
    p = os.path.join(root, "out", "solve", room + ".json")
    if not os.path.exists(p):
        continue
    d = json.load(open(p))
    found = d.get("found", {})
    if not found:
        continue
    cpus = [int(v["cpu"]) for v in found.values()]
    out[room] = {"cpu": min(cpus), "certified_programs": len(found), "evaluations": int(d.get("evaluations", 0))}
dest = os.path.join(root, "game", "content", "solver", "records.json")
os.makedirs(os.path.dirname(dest), exist_ok=True)
json.dump(out, open(dest, "w"), indent=2, sort_keys=True)
print(json.dumps(out, indent=2, sort_keys=True))
