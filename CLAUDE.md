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

## Commands

| Command | What it does |
| --- | --- |
| `tools/test.sh [filter]` | All tests, or those whose file or name contains the filter |
| `tools/dive.sh <room> <prog.rbt> [seed] [--calm] [--png out.png] [--trace] [--dump a:b]` | One dive, outcome as JSON; trace = why each rule ran; dump = per-tick state |
| `tools/certify.sh <room> <prog.rbt> [fleet] [first_seed]` | Survey fleet: pass rate over seeds |
| `tools/bless.sh` | Re-record golden replays after a deliberate sim change |
| `tools/godot.sh --headless --path game --script res://tools/hunt.gd -- <room> [seeds]` | Exploit hunt over all 1-rule and most 2-rule programs (slow) |
| `tools/movie.sh <room> <prog.rbt> [seed] [out.mp4] [speed] [serial]` | Record the replay as MP4 (GIF=1 for a GIF too) under a virtual display |
| `xvfb-run -a tools/godot.sh --path game --rendering-driver opengl3 --audio-driver Dummy res://tools/shots.tscn -- <out_dir>` | Scripted tour of the station UI, saving screenshots to look at |
| `tools/godot.sh --headless --path game --export-release <Linux/Windows/macOS/Web> <path>` | Builds (templates in ~/.local/share/godot/export_templates/4.7.2.stable) |
| `tools/web_artifact.sh` | Web build packed for a claude.ai page (engine gzipped inside a script); then publish build/artifact/robbie-play.html with its files |
| `tools/fleet.sh [glob] [n]` | Survey fleet summary for every reference program |
| `tools/save.sh` / `tools/restore.sh` | Back up the repo to /mnt/user-data/outputs, or rebuild it from there |
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

## Hourly work loop

Albert asked for continuous iteration: one work block per hour, woken by a scheduled message.
Each block: read `docs/BACKLOG.md`, pick the most valuable item, build it, test it, look at it,
update STATUS/BACKLOG/devlog, commit to main, run `tools/save.sh`, send Albert a short update
(with a clip, screenshot or new build when there is something to see), then schedule the next block.
The playable web page is https://claude.ai/artifact/EtAUzrsTr2DVgwN4zAeCuE ; republish it from
`build/artifact/robbie-play.html` after `tools/web_artifact.sh`.

## Talking with Albert

- Plain language, no code. Show GIFs or images and give him a build he can play.
- At most three questions at the end of a session; offer a recommended answer for each.
- He decides taste, tone, story and whether a gate passes. When unsure about taste, make two or
  three variants and let him pick.
- His language is Spanish/Catalan; he writes to us in English. The game is English first.
