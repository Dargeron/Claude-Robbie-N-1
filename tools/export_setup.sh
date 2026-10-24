#!/usr/bin/env bash
# Install what exports need, once per machine: the pinned export templates and, unless --desktop-only,
# the Android SDK build tools, with Godot's editor settings pointing at them. Safe to run repeatedly.
# Usage: tools/export_setup.sh [--desktop-only]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE="${ROBBIE_CACHE:-$HOME/.cache/robbie}"

TPL_VERSION="4.7.2-stable"
TPL_SHA512="ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079"
TPL_URL="https://github.com/godotengine/godot/releases/download/${TPL_VERSION}/Godot_v${TPL_VERSION}_export_templates.tpz"
TPL_DIR="$HOME/.local/share/godot/export_templates/4.7.2.stable"

if [[ ! -f "$TPL_DIR/version.txt" ]]; then
  mkdir -p "$CACHE" "$TPL_DIR"
  echo "Downloading export templates ${TPL_VERSION} (1.2 GB)..." >&2
  curl -sSL --retry 3 -o "$CACHE/templates.tpz" "$TPL_URL"
  echo "${TPL_SHA512}  $CACHE/templates.tpz" | sha512sum -c - >&2
  rm -rf "$CACHE/tpl"
  unzip -q -o "$CACHE/templates.tpz" -d "$CACHE/tpl"
  mv "$CACHE"/tpl/templates/* "$TPL_DIR/"
  rm -rf "$CACHE/tpl" "$CACHE/templates.tpz"
fi
[[ "${1:-}" == "--desktop-only" ]] && exit 0

# Android: only the build tools (apksigner, zipalign) and platform-tools; the APK is built from Godot's
# prebuilt template, so no Gradle or NDK.
SDK="$CACHE/android-sdk"
BUILD_TOOLS="36.1.0"
CLT_ZIP="commandlinetools-linux-16111833_latest.zip"
CLT_SHA1="e025545c62a8e64c7559119566a569fb1dec5f60"

if [[ ! -x "$SDK/build-tools/$BUILD_TOOLS/apksigner" ]]; then
  mkdir -p "$SDK/cmdline-tools"
  echo "Downloading the Android SDK command-line tools..." >&2
  curl -sSL --retry 3 -o "$SDK/clt.zip" "https://dl.google.com/android/repository/$CLT_ZIP"
  echo "${CLT_SHA1}  $SDK/clt.zip" | sha1sum -c - >&2
  rm -rf "$SDK/cmdline-tools/latest" "$SDK/cmdline-tools/cmdline-tools"
  unzip -q -o "$SDK/clt.zip" -d "$SDK/cmdline-tools"
  mv "$SDK/cmdline-tools/cmdline-tools" "$SDK/cmdline-tools/latest"
  rm -f "$SDK/clt.zip"
  yes | "$SDK/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK" --licenses > /dev/null 2>&1 || true
  "$SDK/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$SDK" --install "build-tools;$BUILD_TOOLS" "platform-tools" > /dev/null 2>&1
  [[ -x "$SDK/build-tools/$BUILD_TOOLS/apksigner" ]] || { echo "export_setup: Android build-tools missing" >&2; exit 1; }
fi

# Godot reads the SDK and Java paths from its editor settings; any editor run creates the file.
SETTINGS="$HOME/.config/godot/editor_settings-4.7.tres"
[[ -f "$SETTINGS" ]] || "$ROOT/tools/godot.sh" --headless --path "$ROOT/game" --import > /dev/null 2>&1 || true
JAVA_DIR="${JAVA_HOME:-$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")}"
set_editor() {  # set_editor <key> <value>: replace the line, or append it to the [resource] section at the end
  if grep -q "^$1 = " "$SETTINGS"; then
    sed -i "s|^$1 = .*|$1 = \"$2\"|" "$SETTINGS"
  else
    echo "$1 = \"$2\"" >> "$SETTINGS"
  fi
}
set_editor export/android/android_sdk_path "$SDK"
set_editor export/android/java_sdk_path "$JAVA_DIR"
