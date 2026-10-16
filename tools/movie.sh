#!/usr/bin/env bash
# Record a dive's replay as an MP4 (and optionally a GIF) using a virtual display.
# Usage: tools/movie.sh <room> <program.rbt> [seed] [out.mp4] [speed=1] [serial=1]
# Example: tools/movie.sh valve game/content/programs/valve/intended.rbt 4 out/valve.mp4
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOM="$1"; PROG="$(realpath -m "$2")"; SEED="${3:-1}"; OUT="$(realpath -m "${4:-$ROOT/out/$ROOM.mp4}")"
SPEED="${5:-1}"; SERIAL="${6:-1}"
FRAMES="$(mktemp -d)"
xvfb-run -a -s "-screen 0 1280x720x24" "$ROOT/tools/godot.sh" --path "$ROOT/game" --rendering-driver opengl3 \
  --write-movie "$FRAMES/f.png" --fixed-fps 30 --quit-after 9000 res://view/replay_scene.tscn -- \
  "$ROOM" "$PROG" "$SEED" "speed=$SPEED" "serial=$SERIAL" hold=30 movie > /dev/null 2>&1
mkdir -p "$(dirname "$OUT")"
if [[ -f "$FRAMES/f.wav" ]]; then
  ffmpeg -y -loglevel error -framerate 30 -i "$FRAMES/f%08d.png" -i "$FRAMES/f.wav" -vf "scale=1280:720:flags=neighbor" \
    -c:v libx264 -pix_fmt yuv420p -crf 18 -c:a aac -b:a 128k -shortest "$OUT"
else
  ffmpeg -y -loglevel error -framerate 30 -i "$FRAMES/f%08d.png" -vf "scale=1280:720:flags=neighbor" \
    -c:v libx264 -pix_fmt yuv420p -crf 18 "$OUT"
fi
if [[ "${GIF:-0}" == "1" ]]; then
  ffmpeg -y -loglevel error -framerate 30 -i "$FRAMES/f%08d.png" \
    -vf "fps=15,split[a][b];[a]palettegen=max_colors=64[p];[b][p]paletteuse=dither=none" "${OUT%.mp4}.gif"
fi
[[ -n "${KEEP_WAV:-}" && -f "$FRAMES/f.wav" ]] && cp "$FRAMES/f.wav" "${OUT%.mp4}.wav"
rm -rf "$FRAMES"
echo "$OUT"
