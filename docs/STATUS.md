# Status

Updated 2026-10-17, after hourly block 4 (02:18 UTC): the Wall of Robbies.

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
  passes the survey fleet (18–20 of 20 dives), and naive programs that fail (see `docs/design/rooms.md`).
  The Jellyfish scatters 16 of its 24 jellyfish afresh on every dive, so no fixed route works.
- Sound v1: 15 synthesised sounds synced to the transmission, with a mute button.
- The Wall of Robbies: every Robbie sent, how it ended and its last words; the per-room score. Click to rewatch.
- Survey fleet (certification over 10 seeds), headless dive runner, PNG path images, golden
  replays, exploit hunt tool.
- 31 tests, all green: maths, generator, parser, rooms, determinism, lint (no floats in the
  sim), golden replays, reference programs.
- A dive takes about 0.1 s to simulate. The solver bot is cheaper than we feared.

## Next three tasks

1. Verify the web page inside the claude.ai frame (needs Albert's eyes); fix or fall back.
2. Robbie's senses in the Why? panel, so players discover conditions in context.
3. Live first viewing; onboarding pointer at the editor on the first visit.

## Known issues and open questions

- GitHub is parked at Albert's request; backups go to the session outputs folder (tools/save.sh).
- `keep_distance` and `move_towards beacon` can alternate quickly at the edge of a range (zigzag).
  The 12 px margin helps but doesn't remove it. Watch whether players find it readable.
- The plan's open decisions (win condition = survey fleet, success transmission, etc.) are
  implemented with the recommended defaults, pending Albert's answers.
