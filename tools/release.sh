#!/usr/bin/env bash
# Publish a test build for Albert on GitHub Releases (docs/RELEASES.md).
#
# Builds the signed Android APK and the Windows zip from the current commit, then pushes them to the throwaway
# branch `release-drop` as one extra commit on top of it. .github/workflows/release.yml attaches them to a release
# tagged v<version> and deletes the branch, so the binaries never enter the project's history.
# The version and the notes come from RELEASE.md (first line: "# <version> · <title>").
# The current commit must already be pushed: the release's tag points at it.
# Signing: Robbie's release key from the environment (see tools/android.sh), or from the key file cached at
# ~/.cache/robbie/keys/robbie-n1-signing-key.txt. Never with a throwaway key: that APK couldn't update his game.
# Usage: tools/release.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE="${ROBBIE_CACHE:-$HOME/.cache/robbie}"
cd "$ROOT"

VERSION=$(grep -m1 -oE '^# [0-9][^ ]*' RELEASE.md | cut -c3-)
[[ -n "$VERSION" ]] || { echo "release: RELEASE.md must start with '# <version> · <title>'" >&2; exit 1; }
SRC=$(git rev-parse HEAD)
[[ -z "$(git status --porcelain --untracked-files=no)" ]] || { echo "release: commit your changes first" >&2; exit 1; }
git fetch -q origin
git branch -r --contains "$SRC" | grep -q . || { echo "release: push $SRC first (the tag points at it)" >&2; exit 1; }
if git ls-remote --exit-code --heads origin release-drop > /dev/null; then
  echo "release: origin/release-drop still exists (a release in progress or a failed run); check the Actions tab" >&2
  exit 1
fi

if [[ -z "${ROBBIE_KEYSTORE_B64:-}${ROBBIE_KEYSTORE:-}" ]]; then
  KEYFILE="$CACHE/keys/robbie-n1-signing-key.txt"
  [[ -f "$KEYFILE" ]] || { echo "release: no release key (environment or $KEYFILE)" >&2; exit 1; }
  set -a; . "$KEYFILE"; set +a
fi

OUT="$ROOT/build/release"
rm -rf "$OUT"; mkdir -p "$OUT/windows"
"$ROOT/tools/android.sh" "$OUT/RobbieN1-$VERSION.apk"
"$ROOT/tools/godot.sh" --headless --path "$ROOT/game" --export-release Windows "$OUT/windows/RobbieN1.exe" > "$OUT/windows.log" 2>&1 || true
[[ -s "$OUT/windows/RobbieN1.exe" ]] || { grep -E "ERROR" "$OUT/windows.log" | head >&2; echo "release: Windows export failed" >&2; exit 1; }
(cd "$OUT/windows" && zip -q "$OUT/RobbieN1-$VERSION-windows.zip" ./*)

# One commit on top of the source, made in a temporary worktree so this checkout is untouched.
WT=$(mktemp -d)
git worktree add -q --detach "$WT" "$SRC"
trap 'git worktree remove --force "$WT" 2>/dev/null || true' EXIT
mkdir -p "$WT/release"
cp "$OUT/RobbieN1-$VERSION.apk" "$OUT/RobbieN1-$VERSION-windows.zip" "$WT/release/"
git -C "$WT" add -f release
git -C "$WT" commit -q -m "Release $VERSION (build files only; this branch is deleted once published)"
git -C "$WT" push -q origin HEAD:refs/heads/release-drop
echo "release: $VERSION pushed to release-drop; the Release workflow publishes it at"
echo "  https://github.com/Dargeron/Claude-Robbie-N-1/releases/tag/v$VERSION"
