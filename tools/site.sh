#!/usr/bin/env bash
# Build a self-contained static website of the game from the packed web build (run
# tools/web_artifact.sh first), ready for any static host (Cloudflare Pages, Netlify, ...).
# Every file stays under 25 MiB (Cloudflare Pages' per-file limit): the 39 MB engine ships
# gzipped inside engine_data.js. Output: out/site/ and /mnt/user-data/outputs/robbie-n1-site.zip
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SITE="$ROOT/out/site"
rm -rf "$SITE"; mkdir -p "$SITE"
cp "$ROOT"/build/artifact/*.js "$SITE/"
{ echo '<!doctype html>'
  echo '<html lang="en"><head><meta charset="utf-8">'
  echo '<meta name="viewport" content="width=device-width, initial-scale=1">'
  echo '<meta name="description" content="Robbie N+1: program a robot, send it into a dark Jovian ocean, watch its last transmission, send the next one.">'
  echo '</head><body style="margin:0">'
  cat "$ROOT/build/artifact/robbie-play.html"
  echo '</body></html>'; } > "$SITE/index.html"
cat > "$SITE/_headers" <<'H'
/*.js
  Cache-Control: public, max-age=300
/index.html
  Cache-Control: no-cache
H
(cd "$SITE" && rm -f /mnt/user-data/outputs/robbie-n1-site.zip && zip -q -9 -r /mnt/user-data/outputs/robbie-n1-site.zip .)
find "$SITE" -type f -size +25M -print | grep -q . && { echo "a file is over 25 MiB"; exit 1; }
ls -la "$SITE"; ls -la /mnt/user-data/outputs/robbie-n1-site.zip
