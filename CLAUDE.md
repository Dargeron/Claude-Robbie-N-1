# CLAUDE.md — how to work on Robbie N+1

Read this first, every session. Then read `docs/STATUS.md` and the newest file in `docs/devlog/`.

## The project in one paragraph

Robbie N+1 is a programming puzzle game in Godot 4.7.2 (GDScript, Compatibility renderer).
The player never steers Robbie: they write a list of rules, launch Robbie into a dark Jovian
ocean, watch the transmission it sends when it dies, fix the rules and send Robbie N+1.
Albert is the creative director and first playtester; he does not read code. Claude is the team.
The full plan, roadmap and open decisions live in the plan doc:
https://claude.ai/code/artifact/5d012179-55e8-44ae-86b9-337c8dd39570

## Start of every session

```bash
tools/bootstrap.sh     # pinned Godot into ~/.cache/robbie (30 s the first time), imports the project
tools/test.sh          # must be green before you change anything
```

Then post a short plan to Albert: the goal, three to six tasks, what he will see at the end.

## Running the game

```bash
tools/godot.sh --path game                    # opens the console (the game) in a window
tools/godot.sh -e --path game                 # the Godot editor
tools/web_artifact.sh && tools/site.sh        # web build in out/site; serve it: (cd out/site && python3 -m http.server 8765)
```

Main scene since 2026-10-25: **the operator's console** (`game/console/console.tscn`, design in
`docs/design/station-ui.md`): the whole game on one desk, the first three sectors only. Its own save
(`user://console_save.json`), so it starts fresh. Keys: Space play/pause, F magnify, M sound, W the Wall, H the binder,
Ctrl+Shift+U opens every sector. The layout (screen rects for every machine) is `game/content/console_layout.json`,
shared by the Godot code and the Blender art (`tools/art/console_scene.py`); change it there, then re-render.
The old station (`game/station/station.tscn`) still runs: Mission Control, the Lab (B), the log (L), the manual (H).

## Commands

| Command | What it does |
| --- | --- |
| `tools/test.sh [filter]` | All tests, or those whose file or name contains the filter |
| `tools/dive.sh <room> <prog.rbt> [seed] [--calm] [--png out.png] [--trace] [--dump a:b]` | One dive, outcome as JSON; trace = why each rule ran; dump = per-tick state |
| `tools/certify.sh <room> <prog.rbt> [fleet] [first_seed]` | Survey fleet: pass rate over seeds |
| `tools/bless.sh` | Re-record golden replays after a deliberate sim change |
| `tools/godot.sh --headless --path game --script res://tools/hunt.gd -- <room> [seeds]` | Exploit hunt over all 1-rule and most 2-rule programs (slow) |
| `tools/movie.sh <room> <prog.rbt> [seed] [out.mp4] [speed] [serial]` | Record the replay as MP4 (GIF=1 for a GIF too) under a virtual display |
| `xvfb-run -a tools/godot.sh --path game --rendering-driver opengl3 --audio-driver Dummy res://tools/shots.tscn -- <out_dir>` | Scripted tour of the old station UI, saving screenshots to look at |
| `tools/console_check.sh [out_dir]` | The console's smoke test: the scripted tour (screenshots, none blank) and the touch play-through (taps and drags only; every machine must answer) |
| `~/.cache/blender/blender-5.2.3-linux-x64/blender -b --factory-startup -P tools/art/console_scene.py -- game/art/console [plate\|sprites\|all] [preview]` | Render the console's desk plate (about 12 min) and its moving parts |
| `python3 tools/art/console_paper.py` | The tiling paper grain for cards, tape, memos and notes |
| `tools/godot.sh --headless --path game --export-release <Linux/Windows/macOS/Web> <path>` | Builds (templates in ~/.local/share/godot/export_templates/4.7.2.stable) |
| `tools/export_setup.sh [--desktop-only]` | Installs the export templates and the Android build tools (about 2 min the first time) |
| `tools/release.sh` | Publish a test build for Albert on GitHub Releases (signed APK + Windows zip; see docs/RELEASES.md) |
| `tools/android.sh [out.apk]` | The signed Android APK (arm64) in build/android/; needs the release key in the environment (see "Where the project lives") |
| `tools/web_artifact.sh` | Web build packed for a claude.ai page (engine gzipped inside a script); then publish build/artifact/robbie-play.html with its files |
| `tools/desktop.sh [out_dir]` | Export Linux/Windows/macOS and zip them into /mnt/user-data/outputs (about 90 s) |
| `tools/fleet.sh [glob] [n]` | Survey fleet summary for every reference program |
| `tools/save.sh` / `tools/restore.sh` | Back up the repo to /mnt/user-data/outputs, or rebuild it from there |
| `python3 tools/gen_audio.py` | Regenerate the synthesised sounds in game/audio/ |
| `tools/solve_all.sh [n]` / `tools/solve.sh <room> [n]` | Solver v1 in the background (n evaluations per room); results in out/solve/ |
| `tools/webcheck.sh` | After `tools/web_artifact.sh`: the packed page in headless Chromium with the station's `perf` benchmark; fails on script errors |
| `tools/site.sh` | After `tools/web_artifact.sh`: a static website (out/site, robbie-n1-site.zip) for any host, every file under 25 MiB |
| `python3 tools/web/playtest.py <url> <dir>` | A scripted first-time player in headless Chromium (serve out/site first): launch, scrub, edit, launch, survey |
| `tools/deploy_cf.sh` | After `tools/site.sh`: deploy to Albert's Cloudflare (static-assets Worker, https://robbie-n1.bauldejuegos.workers.dev). Needs CLOUDFLARE_API_TOKEN in the environment; never write it to a file or the repo |
| `tools/smoke.sh` | Render smoke test: the station tour under Xvfb; fails on script errors, missing or blank shots |
| `python3 tools/solver_records.py` | Write content/solver/records.json (cheapest known CPU per room) from the solver's results |
| `tools/hunt.sh <room>` | Resumable exploit hunt in the background; results in out/hunt/<room>.json |
| `tools/godot.sh --headless --path game --script res://tools/voice_sample.gd` | Last words a run of Robbies would send for a few typical dives, with their circumstance tags (to read new lines in context) |
| `python3 tools/gen_fx_tables.py` | Regenerate the integer trig tables (never needed unless Fx changes) |

Rendering works here too: `xvfb-run -a tools/godot.sh --path game --rendering-driver opengl3 --write-movie out/x.png --fixed-fps 30 --quit-after N` writes frames you can look at with the Read tool.

## Hard rules

1. **`game/sim/` and `game/vm/` are integer-only.** No `float`, no `Vector2` (use `Vector2i`), no engine
   `sin/cos/sqrt/atan2`, no `randf/randi/RandomNumberGenerator`, no `Time`. Use `Fx` and `Rng`.
   `tests/test_lint.gd` enforces it. JSON numbers arrive as floats: convert with `int()` at load time.
2. **Determinism is sacred.** Same room + program + seed = same dive on every machine. The tick order
   is documented at the top of `sim/world.gd`; changing it, or any constant, changes golden replays.
   If a change alters dives on purpose, run `tools/bless.sh` and say why in the commit message.
3. **The sim never touches nodes or rendering.** Views read `Recorder` snapshots. Godot physics is not used.
4. **Content is text.** Rooms are `.room` files, programs are `.rbt` files. Every room has an intended
   program (`# expect: exit`, `# certify: yes`) and at least two naive ones that must fail
   (`# expect: fail`, `# certify: no`). `tests/test_reference_programs.gd` checks them all.
5. **Never commit secrets** (Vertex AI keys, build upload keys). They live in the session environment.

## GDScript gotchas we already hit

- Global built-ins shadow static methods with the same name: `wrap`, `len`, `range`, `min`, `max`
  as method or variable names cause parse errors or warnings. `Fx.norm` exists because of this.
- A script error in `--script` mode does not exit Godot; it can hang. `tools/godot.sh` wraps every
  run in `timeout` (`ROBBIE_TIMEOUT`, default 900 s).
- Class names resolve only after an import: `tools/bootstrap.sh` runs `--import`. If a new
  `class_name` is "not declared", run bootstrap again.
- `tools/test.sh | tail` hides a failure behind tail's exit code: run commands with `set -o pipefail`.
- Background hunts compete for the two cores: `pkill -STOP -f "[h]unt.gd"` before tests or renders,
  `pkill -CONT -f "[h]unt.gd"` after.
- GDScript lambdas capture packed arrays by value: changes inside the lambda are lost. Use a loop.
- Tool scripts run with `--path game`: pass absolute file paths (`$PWD/out/...`). A relative path fails
  silently and nothing is saved.
- Exported builds leave out `tools/` and `tests/` (export filter). Game code must never use their classes
  (`test_lint` checks), and exports infer types more strictly: annotate loop variables over untyped arrays.
  `tools/webcheck.sh` is the only check that runs the exported game: run it before publishing.
- `tools/bootstrap.sh` doesn't report GDScript parse errors; the tests and `tools/smoke.sh` do.
- `tools/smoke.sh` runs the station tour and checks every screenshot is there and not blank: run it before
  publishing anything visual.
- Integer division warnings are disabled in `project.godot`; integer division is intended everywhere.

## Definition of done

- `tools/test.sh` passes; no new engine warnings in its output.
- Golden replays unchanged, or re-blessed with a one-line reason.
- Anything visual: you rendered it and looked at it.
- `docs/STATUS.md` updated; a devlog entry for the session (`docs/devlog/YYYY-MM-DD-sNN.md`).
- `main` stays playable. Merge to `main` yourself when tests pass; Albert reviews builds, not diffs.

## Git

- One branch per session, `sNN-short-topic`, merged to `main` when green.
- Commit messages: what changed and why, in plain words. End with the attribution lines the session
  gives you (Co-Authored-By and Claude-Session).
- Tag finished phases: `m0-foundations`, `m1-prototype`, ...

## Where the project lives

Since 2026-10-22 the project lives on GitHub (https://github.com/Dargeron/Claude-Robbie-N-1) and is worked on with
Claude Code. Blocks 1–32 were done in a Cowork cloud session with hourly scheduled blocks; that loop has ended.
Each work session still follows the same rhythm: read `docs/BACKLOG.md`, pick the most valuable item, build it, test
it, look at it, update STATUS/BACKLOG/devlog, commit, and show Albert something he can play.

- **Builds for Albert (since 2026-10-24):** native apps, not the browser. An Android APK for his tablet
  (`tools/android.sh`) and a Windows EXE (`tools/desktop.sh`, or the Windows preset alone).
  **Since 2026-10-25 he downloads them from the GitHub Releases page**
  (https://github.com/Dargeron/Claude-Robbie-N-1/releases). To publish a test build: rewrite `RELEASE.md` (first line
  `# <new version> · <title>`, then what's new and what to try, in plain words), bump `version/code` in
  `game/export_presets.cfg`, commit and push, then run `tools/release.sh`. It builds and signs both here and pushes
  them to the throwaway branch `release-drop` (Albert allowed pushing to it on 2026-10-25);
  `.github/workflows/release.yml` publishes them and deletes the branch, so binaries never enter the history. Check
  the run with the GitHub tools and give him the link. See `docs/RELEASES.md`.
  Android installs an update only if it carries the same signature, so always sign with Robbie's release key: it is
  in Albert's Google Drive as "Robbie N+1 - Android signing key (private).txt"; export its three lines as environment
  variables before `tools/android.sh`, or save the file as `~/.cache/robbie/keys/robbie-n1-signing-key.txt`, where
  `tools/release.sh` reads it. Never commit it. A build signed with another key can't replace his installed
  game without an uninstall, which deletes his save.
- **The web build** (`tools/web_artifact.sh` → `tools/webcheck.sh` → `tools/site.sh` → `tools/deploy_cf.sh`,
  https://robbie-n1.bauldejuegos.workers.dev, needs `CLOUDFLARE_API_TOKEN`) is no longer the main target. The old
  claude.ai page (https://claude.ai/artifact/EtAUzrsTr2DVgwN4zAeCuE) is no longer updated.
- **Needs on a new machine:** bash, Python 3 with Pillow, `xvfb-run` and Mesa (for `tools/smoke.sh`), a JDK (for
  Android signing), Playwright with Chromium (for `tools/webcheck.sh` and `tools/web/playtest.py`), Node/npx (for
  wrangler). `tools/bootstrap.sh` fetches Godot; `tools/export_setup.sh` fetches the export templates and the Android
  build tools.
- **Art:** Blender (5.2.3 LTS, headless, Cycles on the CPU; no GPU in the cloud machine) for models and rendered
  sprites. Unity was considered and set aside on 2026-10-24: this game stays on Godot.
- **Waiting on Albert** (see docs/STATUS.md): his yes on `docs/design/progression.md` (currencies, goals, the Lab's
  shop), his reaction to the Lab sketch, and art references plus Vertex AI access for the art pass.
- **Background searches:** `tools/hunt.sh <room>` and `tools/solve_all.sh <n>` write to `out/` (not in git). The
  Lock's hunt had checked 7,750 programs with nothing passing the survey; restart it to continue.

## Talking with Albert

- Plain language, no code. Show GIFs or images and give him a build he can play.
- At most three questions at the end of a session; offer a recommended answer for each.
- He decides taste, tone, story and whether a gate passes. When unsure about taste, make two or
  three variants and let him pick.
- His language is Spanish/Catalan; he writes to us in English. The game is English first.
