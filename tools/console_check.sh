#!/usr/bin/env bash
# Smoke test for the operator's console: the scripted tour (every screenshot there, 1280x720, not blank) and the
# touch play-through (only taps and drags at screen positions; every machine must answer), in the flat view and again
# through the 3D chair view (ROBBIE_VIEW=chair: the same taps traced onto the console's faces; its tour goes in chair/).
# Usage: tools/console_check.sh [out_dir]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/out/console_check}"
rm -rf "$OUT"; mkdir -p "$OUT"
run() {
  ROBBIE_TIMEOUT=300 xvfb-run -a -s "-screen 0 1280x720x24" "$ROOT/tools/godot.sh" --path "$ROOT/game" \
    --rendering-driver opengl3 --audio-driver Dummy "$@"
}
run res://tools/console_shots.tscn -- "$OUT" > "$OUT/tour.txt" 2>&1 || true
run res://tools/console_play.tscn > "$OUT/play.txt" 2>&1 && play=0 || play=$?
mkdir -p "$OUT/chair"
ROBBIE_VIEW=chair run res://tools/console_shots.tscn -- "$OUT/chair" > "$OUT/chair/tour.txt" 2>&1 || true
ROBBIE_VIEW=chair run res://tools/console_play.tscn > "$OUT/chair/play.txt" 2>&1 && play_c=0 || play_c=$?
if grep -qE "SCRIPT ERROR|Parse Error" "$OUT/tour.txt" "$OUT/play.txt" "$OUT/chair/tour.txt" "$OUT/chair/play.txt"; then
  grep -hE "SCRIPT ERROR|Parse Error" -A 2 "$OUT/tour.txt" "$OUT/play.txt" "$OUT/chair/tour.txt" "$OUT/chair/play.txt" | head -20
  echo "console: script errors"; exit 1
fi
grep -hE "^(PASS|FAIL)" "$OUT/play.txt" "$OUT/chair/play.txt" | grep FAIL || true
echo "flat:  $(grep "console_play:" "$OUT/play.txt")"
echo "chair: $(grep "console_play:" "$OUT/chair/play.txt")"
expected=$(grep -o '\["shot", "[^"]*"\]' "$ROOT/game/tools/console_shots.gd" | wc -l)
python3 - "$OUT" "$expected" <<'PY'
import sys, os
from PIL import Image, ImageStat
out, expected = sys.argv[1], int(sys.argv[2])
ok = True
for d in (out, os.path.join(out, "chair")):
    shots = sorted(f for f in os.listdir(d) if f.endswith(".png"))
    bad = [f for f in shots if Image.open(os.path.join(d, f)).size != (1280, 720)
           or sum(ImageStat.Stat(Image.open(os.path.join(d, f)).convert("RGB")).stddev) / 3 < 8]
    print("console: %d of %d screenshots in %s%s" % (len(shots), expected, os.path.basename(d), (", blank: " + ", ".join(bad)) if bad else ""))
    ok = ok and len(shots) == expected and not bad
sys.exit(0 if ok else 1)
PY
[[ "$play" == 0 && "$play_c" == 0 ]] || { echo "console: play-through failed"; exit 1; }
echo "console: ok"
