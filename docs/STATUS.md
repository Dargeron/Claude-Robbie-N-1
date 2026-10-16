# Status

Updated 2026-10-16, end of session 2.

## Where we are

**Phase M1, step P0b (first playable): done in a first version.** The station screen runs the whole loop:
write rules, launch, watch, understand, fix, survey. Builds exist for Linux, Windows, macOS and the web
(https://claude.ai/artifact/EtAUzrsTr2DVgwN4zAeCuE). Next: P0c, readable and charming. See docs/BACKLOG.md.

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

## Next three tasks

1. Verify the web page inside the claude.ai frame; fix or fall back.
2. Onboarding for the first minute, and a 2x watch mode for the monitor.
3. Station memory (map from every past dive) and the Wall of Robbies.

## Known issues and open questions

- GitHub is parked at Albert's request; backups go to the session outputs folder (tools/save.sh).
- `keep_distance` and `move_towards beacon` can alternate quickly at the edge of a range (zigzag).
  The 12 px margin helps but doesn't remove it. Watch whether players find it readable.
- The plan's open decisions (win condition = survey fleet, success transmission, etc.) are
  implemented with the recommended defaults, pending Albert's answers.
