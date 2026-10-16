# Status

Updated 2026-10-16, end of session 1.

## Where we are

**Phase M1, step P0a (sim in a terminal): done.** M0 foundations are in place, apart from CI,
which runs for the first time on the first push.

## What works

- Deterministic simulation in integer maths: Robbie, walls, the lamp and its line of sight,
  jellyfish, a lurker, a valve, energy, crashes, an explored-tiles map. Same inputs give the
  same dive, checked by hash every second of dive time.
- Robbie's rule interpreter, with 9 orders and 7 conditions, CPU costs and a trace of every think.
  The trace explains in words why each rule ran or was skipped (the seed of the Why? panel).
- Three prototype rooms (The Dark, The Jellyfish, The Valve). Each has an intended program that
  passes 20/20 survey dives, and naive programs that fail (see `docs/design/rooms.md`).
- Survey fleet (certification over 10 seeds), headless dive runner, PNG path images, golden
  replays, exploit hunt tool.
- 25 tests, all green: maths, generator, parser, rooms, determinism, lint (no floats in the
  sim), golden replays, reference programs.
- A dive takes about 0.1 s to simulate. The solver bot is cheaper than we feared.

## Next three tasks (P0b, first playable)

1. **Replay controls on screen:** the dive view already draws recordings (`view/replay_scene.tscn`,
   keyboard VCR controls, VHS lines); it needs clickable controls, a timeline with event markers
   and the Why? panel.
2. **Rule editor:** click-built rules (New → order → parameter → + if → condition) with a CPU meter.
3. **The loop:** launch → watch with the active rule lit up → edit → relaunch. A web build for Albert.

## Known issues and open questions

- Push to GitHub depends on the repo being attached to the session.
- CI has never run (first push will tell).
- `follow_wall` wobbles visibly; harmless, but smoothing would read better on screen.
- `keep_distance` and `move_towards beacon` can alternate quickly at the edge of a range (zigzag).
  The 12 px margin helps but doesn't remove it. Watch whether players find it readable.
- The plan's open decisions (win condition = survey fleet, success transmission, etc.) are
  implemented with the recommended defaults, pending Albert's answers.
