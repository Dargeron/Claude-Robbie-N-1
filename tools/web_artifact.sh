#!/usr/bin/env bash
# Export the web build and pack it for hosting as a claude.ai artifact page.
# The engine (39 MB) is gzipped and base64-wrapped in a script file to fit the
# 15 MB-per-file limit and the served file types; the page unpacks it.
# Output: build/artifact/ (robbie-play.html + data scripts). Publish with the Artifact tool.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
mkdir -p build/web build/artifact
tools/godot.sh --headless --path game --export-release Web "$ROOT/build/web/index.html" > /dev/null 2>&1
cp build/web/index.js build/web/index.audio.worklet.js build/web/index.audio.position.worklet.js build/artifact/
python3 - <<'PY'
import base64, gzip
root = "build"
wasm = open(f"{root}/web/index.wasm", "rb").read()
pck = open(f"{root}/web/index.pck", "rb").read()
gz = gzip.compress(wasm, 9)
open(f"{root}/artifact/engine_data.js", "w").write(
    '// Godot web engine, gzip-compressed and base64-encoded. Unpacked by the page.\n'
    'window.ROBBIE_ENGINE_GZ = "' + base64.b64encode(gz).decode() + '";\n')
open(f"{root}/artifact/game_data.js", "w").write(
    '// Robbie N+1 game data (Godot .pck), base64-encoded. Unpacked by the page.\n'
    'window.ROBBIE_PCK = "' + base64.b64encode(pck).decode() + '";\n')
page = open("tools/web/robbie-play.html").read()
page = page.replace("__PCK_SIZE__", str(len(pck))).replace("__WASM_SIZE__", str(len(wasm)))
open(f"{root}/artifact/robbie-play.html", "w").write(page)
print(f"engine {len(wasm)} B -> {len(gz)} B gzip; pck {len(pck)} B")
PY
ls -la build/artifact
