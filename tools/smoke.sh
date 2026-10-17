#!/usr/bin/env bash
# Smoke test for everything the headless tests can't see: run the scripted station tour
# under a virtual display and check every screenshot exists, is 1280x720 and isn't blank.
# Usage: tools/smoke.sh [out_dir]   (pause background hunts/solvers first: they share the CPU)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/out/smoke}"
rm -rf "$OUT"; mkdir -p "$OUT"
ROBBIE_TIMEOUT=150 xvfb-run -a -s "-screen 0 1280x720x24" "$ROOT/tools/godot.sh" --path "$ROOT/game" \
  --rendering-driver opengl3 --audio-driver Dummy res://tools/shots.tscn -- "$OUT" > "$OUT/log.txt" 2>&1 || true
if grep -qE "SCRIPT ERROR|Parse Error" "$OUT/log.txt"; then
  grep -E "SCRIPT ERROR|Parse Error" -A 2 "$OUT/log.txt" | head -20; echo "smoke: script errors"; exit 1
fi
expected=$(grep -o '\["shot", "[^"]*"\]' "$ROOT/game/tools/shots.gd" | wc -l)
python3 - "$OUT" "$expected" <<'PY'
import sys, os
from PIL import Image, ImageStat
out, expected = sys.argv[1], int(sys.argv[2])
shots = sorted(f for f in os.listdir(out) if f.endswith(".png"))
bad = []
for f in shots:
    im = Image.open(os.path.join(out, f)).convert("RGB")
    sd = sum(ImageStat.Stat(im).stddev) / 3
    if im.size != (1280, 720) or sd < 8:
        bad.append("%s (size %s, contrast %.1f)" % (f, im.size, sd))
print("smoke: %d of %d screenshots" % (len(shots), expected))
if len(shots) != expected or bad:
    print("smoke: FAILED", *bad, sep="\n  ")
    sys.exit(1)
print("smoke: ok")
PY
