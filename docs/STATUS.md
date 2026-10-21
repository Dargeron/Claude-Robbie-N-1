# Status

Updated 2026-10-21, after hourly block 19 (14:08 UTC): Albert's notes, part 1 (the lurker, CPU budgets, watching a launch).

## Where we are

**Hourly blocks resumed** on 21 October, working through Albert's 14 playtest notes first
(docs/design/feedback-2026-10-17.md). Done: #14 the lurker, #8 CPU budgets, #2 full-screen launch and skip-ahead.

**Albert played it (2026-10-17, evening): "I had FUN... the barest core is good."** The core loop passes his gate. He has many
changes, suggestions and problems to fix; those come first in the backlog as soon as he sends them.

**Phase M1, step P0b (first playable): every item on its list is done** (block 9). The station screen runs the whole loop:
write rules, launch, watch, understand, fix, survey. Builds exist for Linux, Windows, macOS and the web
(https://claude.ai/artifact/EtAUzrsTr2DVgwN4zAeCuE, and publicly at https://robbie-n1.bauldejuegos.workers.dev). Next: P0c, readable and charming. See docs/BACKLOG.md.

## What works

- Deterministic simulation in integer maths: Robbie, walls, the lamp and its line of sight,
  jellyfish, lurkers, eels, a valve, energy, crashes, an explored-tiles map. Same inputs give the
  same dive, checked by hash every second of dive time.
- Robbie's rule interpreter, with 7 orders and 6 conditions, CPU costs and a trace of every think.
  The trace explains in words why each rule ran or was skipped (the seed of the Why? panel).
- Five prototype rooms (The Dark, The Jellyfish, The Nursery, The Valve, The Listeners), one idea each. Each has an intended
  program that passes the survey fleet (20 of 20 dives), and naive programs that fail (see `docs/design/rooms.md`).
  Three creatures: jellyfish (light attracts them), lurkers (laser-proof; back away), eels (blind, hunt by sound;
  hold still). Jellyfish are partly scattered afresh on every dive, so no fixed route works.
- Sound v1: 15 synthesised sounds synced to the transmission, with a mute button.
- The station log: dated entries unlocked by certifying rooms; the slow story (content/story/log.json).
- Robbie's manual (H) and tooltips on every order and condition, from one source (Catalogue.HELP).
- Rooms open one after another as each is certified (Ctrl+Shift+U opens all, for testing).
- Launching goes full screen and skips fast to just before where the previous Robbie was lost (K toggles).
- A first-visit coach points at LAUNCH, the timeline and the editor until Robbie 002 is sent.
- AUTO playback: skims quiet water at 4x and slows to normal speed around every event.
- The Wall of Robbies: every Robbie sent, its route on a small map, how it ended and its last words; the per-room
  score. Click to rewatch.
- The Why? panel shows what Robbie sensed (wall ahead, nearest hostile, valve, energy); the previous Robbie in
  the room swims alongside the replay as a ghost.
- Survey fleet (certification: 16 of 20 dives on seeds of its own, sent a few per frame with progress), headless dive runner, PNG path images, golden
  replays, exploit hunt, and a mutation solver that finds the cheapest certifying program per room.
- 37 tests, all green: maths, generator, parser, rooms, determinism, lint (no floats in the
  sim), golden replays, reference programs.
- A dive takes 0.1–0.4 s to simulate natively, a little more in a browser (tools/webcheck.sh prints timings).

## Next three tasks

1. Albert's #11: everything hidden until the lamp finds it, the exit included.
2. Albert's #4 and #3: a big, obvious objectives control; a light guided first room.
3. Albert's #5: the beacon opens the next room; optional objectives per room. Needs his answer on the two currencies.

## Known issues and open questions

- GitHub is parked at Albert's request; backups go to the session outputs folder (tools/save.sh).
- `keep_distance` and `move_towards beacon` can alternate quickly at the edge of a range (zigzag).
  The 12 px margin helps but doesn't remove it. Watch whether players find it readable.
- The plan's open decisions (win condition = survey fleet, success transmission, etc.) are
  implemented with the recommended defaults, pending Albert's answers.
