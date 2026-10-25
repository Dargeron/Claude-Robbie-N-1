# Test builds on GitHub Releases

Albert downloads every test build from https://github.com/Dargeron/Claude-Robbie-N-1/releases: the Android APK
for his tablet and a Windows zip, with notes on what's new and what to try. Old releases stay up; they live outside
the project's history and cost nothing, and give him a way back to any earlier build.

## How a release is made

1. Rewrite `RELEASE.md`: the first line is `# <version> · <title>` (a new version each time, e.g. `0.1.1-console`),
   then plain-language notes for Albert. Bump `version/code` in `game/export_presets.cfg`, so Android sees an update.
2. Commit and push the session branch (the release's tag points at that commit).
3. Run `tools/release.sh`. It builds and signs the APK with Robbie's release key, exports Windows, and pushes the
   two files as one commit to the throwaway branch `release-drop`.
4. `.github/workflows/release.yml` runs on that push: it publishes the release `v<version>` (marked pre-release)
   and deletes `release-drop`. Because no branch keeps that commit, the binaries never enter the history that
   anyone downloads with the code. Check the run (Actions tab, or the GitHub tools) and send Albert the link.

## The signing key

The APK must be signed with Robbie's release key, or it can't update the game already on the tablet (and
uninstalling first deletes his save). The key is in Albert's Google Drive, "Robbie N+1 - Android signing key
(private).txt", three lines `NAME=value`. `tools/release.sh` reads them from the environment, or from
`~/.cache/robbie/keys/robbie-n1-signing-key.txt`. It never builds a release with any other key. Never commit it.
