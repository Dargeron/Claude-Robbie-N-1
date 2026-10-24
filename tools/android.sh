#!/usr/bin/env bash
# Export the signed Android APK (arm64) to build/android/RobbieN1.apk, installing the tools first if needed.
#
# Signing: Android installs an update only if it is signed with the same key as the installed app, so every
# build Albert installs must use Robbie's release key. It comes from the environment, never from the repo:
#   ROBBIE_KEYSTORE (a file path) or ROBBIE_KEYSTORE_B64 (the file, base64), ROBBIE_KEYSTORE_PASS, ROBBIE_KEY_ALIAS.
# Without them the build is signed with a throwaway test key, and installing it over a release build fails
# (uninstalling first loses the save).
# Usage: tools/android.sh [out.apk]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE="${ROBBIE_CACHE:-$HOME/.cache/robbie}"
OUT="${1:-$ROOT/build/android/RobbieN1.apk}"
APKSIGNER="$CACHE/android-sdk/build-tools/36.1.0/apksigner"

"$ROOT/tools/export_setup.sh"

KEYS="$CACHE/keys"
mkdir -p "$KEYS"
if [[ -n "${ROBBIE_KEYSTORE_B64:-}" ]]; then
  printf '%s' "$ROBBIE_KEYSTORE_B64" | base64 -d > "$KEYS/release.keystore"
  ROBBIE_KEYSTORE="$KEYS/release.keystore"
fi
if [[ -n "${ROBBIE_KEYSTORE:-}" ]]; then
  export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$ROBBIE_KEYSTORE"
  export GODOT_ANDROID_KEYSTORE_RELEASE_USER="${ROBBIE_KEY_ALIAS:-robbie}"
  export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="${ROBBIE_KEYSTORE_PASS:?ROBBIE_KEYSTORE_PASS is not set}"
else
  echo "android: no release key in the environment; signing with a throwaway test key" >&2
  if [[ ! -f "$KEYS/test.keystore" ]]; then
    keytool -genkeypair -keystore "$KEYS/test.keystore" -storepass robbietest -keypass robbietest -alias robbie \
      -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Robbie N1 test build" > /dev/null 2>&1
  fi
  export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYS/test.keystore"
  export GODOT_ANDROID_KEYSTORE_RELEASE_USER=robbie
  export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=robbietest
fi

mkdir -p "$(dirname "$OUT")"
rm -f "$OUT" "$OUT.idsig"
LOG="$(dirname "$OUT")/export.log"
"$ROOT/tools/godot.sh" --headless --path "$ROOT/game" --export-release Android "$OUT" > "$LOG" 2>&1 || true
if [[ ! -s "$OUT" ]] || ! "$APKSIGNER" verify "$OUT" > /dev/null 2>&1; then
  grep -E "ERROR|error" "$LOG" | head -20 >&2
  echo "export failed: Android (log in $LOG)" >&2
  exit 1
fi
rm -f "$OUT.idsig"
"$APKSIGNER" verify --print-certs "$OUT" 2>/dev/null | grep -m1 "certificate DN" >&2
ls -la "$OUT"
