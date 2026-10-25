#!/usr/bin/env bash
# Smoke test for the operator's console: the scripted tour (every screenshot there, 1280x720, not blank) and the
# touch play-through (only taps and drags at screen positions; every machine must answer).
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
if grep -qE "SCRIPT ERROR|Parse Error" "$OUT/tour.txt" "$OUT/play.txt"; then
  grep -hE "SCRIPT ERROR|Parse Error" -A 2 "$OUT/tour.txt" "$OUT/play.txt" | head -20; echo "console: script errors"; exit 1
fi
grep -E "^(PASS|FAIL)" "$OUT/play.txt" | grep FAIL || true
grep "console_play:" "$OUT/play.txt"
expected=$(grep -o '\["shot", "[^"]*"\]' "$ROOT/game/tools/console_shots.gd" | wc -l)
python3 - "$OUT" "$expected" <<'PY'
import sys, os
from PIL import Image, ImageStat
out, expected = sys.argv[1], int(sys.argv[2])
shots = sorted(f for f in os.listdir(out) if f.endswith(".png"))
bad = [f for f in shots if Image.open(os.path.join(out, f)).size != (1280, 720)
       or sum(ImageStat.Stat(Image.open(os.path.join(out, f)).convert("RGB")).stddev) / 3 < 8]
print("console: %d of %d screenshots" % (len(shots), expected))
sys.exit(1 if len(shots) != expected or bad else 0)
PY
[[ "$play" == 0 ]] || { echo "console: play-through failed"; exit 1; }
echo "console: ok"
