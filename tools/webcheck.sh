#!/usr/bin/env bash
# End-to-end check of the packed web build (run tools/web_artifact.sh first): serve it locally,
# open it in headless Chromium with the station's "perf" benchmark switched on, and fail on any
# script error. Exported builds leave out tools/ and tests/, so this catches what the project
# run can't. Prints the browser timings. About a minute.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIR="$ROOT/out/webcheck"
rm -rf "$DIR"; mkdir -p "$DIR"
cp "$ROOT"/build/artifact/*.js "$DIR/"
{ echo '<!doctype html><html><head><meta charset="utf-8"></head><body style="margin:0">'
  sed 's/args: \[\],/args: ["--", "perf"],/' "$ROOT/build/artifact/robbie-play.html"
  echo '</body></html>'; } > "$DIR/index.html"
grep -q '"perf"' "$DIR/index.html" || { echo "webcheck: could not switch the benchmark on"; exit 1; }
PORT=8766
(cd "$DIR" && exec python3 -m http.server $PORT > /dev/null 2>&1) &
SERVER=$!
trap 'kill $SERVER 2>/dev/null' EXIT
sleep 1
timeout 140 python3 "$ROOT/tools/web/check_page.py" "http://127.0.0.1:$PORT/index.html" "$DIR/shot.png"
