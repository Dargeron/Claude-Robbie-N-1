#!/usr/bin/env bash
# Download the pinned Godot editor (once per machine), verify it, and import the
# project so class names resolve in headless runs. Safe to run repeatedly.
set -euo pipefail

GODOT_VERSION="4.7.2-stable"
GODOT_ZIP="Godot_v${GODOT_VERSION}_linux.x86_64.zip"
GODOT_SHA256="cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4"
GODOT_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/${GODOT_ZIP}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE="${ROBBIE_CACHE:-$HOME/.cache/robbie}/godot-${GODOT_VERSION}"
BIN="$CACHE/godot"

if [[ ! -x "$BIN" ]]; then
  mkdir -p "$CACHE"
  echo "Downloading Godot ${GODOT_VERSION}..." >&2
  curl -sSL --retry 3 -o "$CACHE/$GODOT_ZIP" "$GODOT_URL"
  echo "${GODOT_SHA256}  $CACHE/$GODOT_ZIP" | sha256sum -c - >&2
  unzip -o -q "$CACHE/$GODOT_ZIP" -d "$CACHE"
  mv "$CACHE/Godot_v${GODOT_VERSION}_linux.x86_64" "$BIN"
  chmod +x "$BIN"
  rm -f "$CACHE/$GODOT_ZIP"
fi

# Import so the global class cache exists for --script runs.
"$BIN" --headless --path "$ROOT/game" --import >/dev/null 2>&1 || true
echo "$BIN"
