# Robbie N+1

You never steer Robbie. You write its orders, launch it into Jupiter's dark
ocean, watch the video it beams up when it dies, and send the next one.

A programming puzzle game in Godot 4.7, built by Albert (creative director) and
Claude (everything else) over many sessions.

- **Production plan:** [Robbie N+1 — Production Plan](https://claude.ai/code/artifact/5d012179-55e8-44ae-86b9-337c8dd39570)
- **Where we are:** [docs/STATUS.md](docs/STATUS.md)
- **Session logs:** [docs/devlog/](docs/devlog/)
- **How to work in this repo:** [CLAUDE.md](CLAUDE.md)

## Quick start

```bash
tools/bootstrap.sh          # downloads the pinned Godot 4.7.2 once, imports the project
tools/test.sh               # every test: maths, determinism, golden replays, reference programs
tools/dive.sh dark game/content/programs/dark/intended.rbt 1 --png out/dark.png --trace
tools/certify.sh valve game/content/programs/valve/intended.rbt 10
```

## Layout

```text
game/            the Godot project
  sim/           deterministic core (integers only): world, bodies, rooms, recorder, dive, survey
  vm/            Robbie's programs: catalogue of orders, parser, interpreter, explanations
  content/       rooms/*.room, programs/<room>/*.rbt, golden/*.json
  view/          presentation (P0b onwards); path_image.gd draws a dive as a PNG
  station/       the station UI (P0b onwards)
  tests/         test_*.gd, run by tools/run_tests.gd
  tools/         headless entry points: run_dive, certify, hunt, bless, run_tests
tools/           shell wrappers and generators
docs/            status, devlog, design notes, decisions
```
