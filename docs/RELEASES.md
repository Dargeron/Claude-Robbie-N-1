# Test builds on GitHub Releases

Albert downloads every test build from https://github.com/Dargeron/Claude-Robbie-N-1/releases: the Android APK
for his tablet and a Windows zip. Each release says what's new and what to try.

## How a release is made

1. Change `RELEASE.md`: the first line is `# <version> · <title>` (a new version each time, e.g. `0.1.1-console`),
   then plain-language notes for Albert. Bump `version/code` in `game/export_presets.cfg` as well.
2. Push. `.github/workflows/release.yml` runs on GitHub: it installs Godot, the export templates and the Android
   build tools, builds and signs the APK, builds the Windows EXE, and publishes both as a release tagged
   `v<version>` (marked pre-release). About 10 minutes the first time, less once its caches are warm.
3. Check the run (Actions tab, or the GitHub tools) and send Albert the release link.

It can also be run by hand from the Actions tab ("Release", "Run workflow").

## The signing key (once)

The APK must be signed with Robbie's release key, or it can't update the game already on the tablet. The key is in
Albert's Google Drive, "Robbie N+1 - Android signing key (private).txt", as three lines `NAME=value`. Each line
becomes a repository secret: on GitHub, **Settings > Secrets and variables > Actions > New repository secret**, the
name is the part before `=` and the secret is everything after it:

- `ROBBIE_KEYSTORE_B64`
- `ROBBIE_KEYSTORE_PASS`
- `ROBBIE_KEY_ALIAS`

Secrets are encrypted; nobody can read them back, and they never appear in the repository or the logs. Without
them the workflow still builds, as a test, but publishes nothing and ends in an error: an APK signed with another key
could not update the game on the tablet.
