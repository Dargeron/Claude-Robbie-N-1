#!/usr/bin/env bash
# Export the Linux, Windows and macOS builds and zip them into /mnt/user-data/outputs.
# Usage: tools/desktop.sh [out_dir=/mnt/user-data/outputs]
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-/mnt/user-data/outputs}"
cd "$ROOT"
mkdir -p build/linux build/windows build/macos "$OUT"
for p in Linux Windows macOS; do
  case $p in
    Linux) f=build/linux/RobbieN1.x86_64 ;;
    Windows) f=build/windows/RobbieN1.exe ;;
    macOS) f=build/macos/RobbieN1.zip ;;
  esac
  tools/godot.sh --headless --path game --export-release "$p" "$ROOT/$f" > /dev/null 2>&1
  [[ -s "$f" ]] || { echo "export failed: $p" >&2; exit 1; }
done
rm -f "$OUT"/RobbieN1-{linux,windows,macos}.zip
(cd build/linux && zip -q -9 "$OUT/RobbieN1-linux.zip" RobbieN1.x86_64)
(cd build/windows && zip -q -9 "$OUT/RobbieN1-windows.zip" RobbieN1.exe)
cp build/macos/RobbieN1.zip "$OUT/RobbieN1-macos.zip"
ls -la "$OUT"/RobbieN1-*.zip
