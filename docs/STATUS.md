# Status

Updated 2026-10-24, session 35: on GitHub and Claude Code; builds are now a native Android APK and a Windows EXE
(tools/android.sh, tools/desktop.sh). Next: the art pass, starting with 5 style concepts and 5 Robbie designs for
Albert to choose from. Still waiting on Albert's yes to the progression proposal.

## Where we are

**Moved to GitHub and Claude Code on 22 October** after 32 hourly blocks in a Cowork session. Albert's 14 playtest notes come first
(docs/design/feedback-2026-10-17.md). Done: #14 the lurker, #8 CPU budgets, #2 full-screen launch and skip-ahead, #11 hidden until found, #4/#3 room goals and a guided first room, #10 last words.

**Albert played it (2026-10-17, evening): "I had FUN... the barest core is good."** The core loop passes his gate. He has many
changes, suggestions and problems to fix; those come first in the backlog as soon as he sends them.

**Phase M1, step P0b (first playable): every item on its list is done** (block 9). The station screen runs the whole loop:
write rules, launch, watch, understand, fix, survey. Builds exist for Linux, Windows, macOS and the web
(https://claude.ai/artifact/EtAUzrsTr2DVgwN4zAeCuE, and publicly at https://robbie-n1.bauldejuegos.workers.dev). Next: P0c, readable and charming. See docs/BACKLOG.md.

## What works

- Deterministic simulation in integer maths: Robbie, walls, the lamp and its line of sight,
  jellyfish, lurkers, eels, a valve, energy, crashes, an explored-tiles map. Same inputs give the
  same dive, checked by hash every second of dive time.
- Robbie's rule interpreter, with 7 orders and 7 conditions, CPU costs and a trace of every think.
  The trace explains in words why each rule ran or was skipped (the seed of the Why? panel).
- Six prototype rooms (The Dark, The Jellyfish, The Nursery, The Valve, The Listeners, The Lock): one idea each, and The Lock
  needs two at once. Each has an intended
  program that passes the survey fleet (20 of 20 dives), and naive programs that fail (see `docs/design/rooms.md`).
  Three creatures: jellyfish (light attracts them), lurkers (laser-proof; back away), eels (blind, hunt by sound;
  hold still). Jellyfish are partly scattered afresh on every dive, so no fixed route works.
- Robbie's voice: 340 last words chosen by cause and circumstance, rarely repeated; subtitles during the dive.
- Sound v1: 15 synthesised sounds synced to the transmission, with a mute button.
- The station log: dated entries unlocked by certifying rooms; the slow story (content/story/log.json).
- Robbie's manual (H) and tooltips on every order and condition, from one source (Catalogue.HELP).
- Rooms open one after another as each is certified (Ctrl+Shift+U opens all, for testing).
- The transmission shows only what Robbie sensed; a green tick beside Robbie points at the beacon.
- The Lab (B): a first sketch, Robbie on the bench with a card per part; nothing to buy yet.
- Launching goes full screen and skips fast to just before where the previous Robbie was lost (K toggles).
- Room goals under LAUNCH: reach the exit, prove it (survey fleet, its button glows when it's time), lean (CPU record).
- A guided first room: in The Dark the guide points at the next thing to do until the room is certified. "New station" in the manual starts over.
- AUTO playback: skims quiet water at 4x and slows to normal speed around every event.
- The Wall of Robbies: every Robbie sent, its route on a small map, how it ended and its last words; the per-room
  score. Click to rewatch.
- The Why? panel shows what Robbie sensed (wall ahead, nearest hostile, valve, energy); the previous Robbie in
  the room swims alongside the replay as a ghost.
- Survey fleet (certification: 16 of 20 dives on seeds of its own, sent a few per frame with progress), headless dive runner, PNG path images, golden
  replays, exploit hunt, and a mutation solver that finds the cheapest certifying program per room.
- 51 tests, all green: maths, generator, parser, rooms, determinism, lint (no floats in the
  sim), golden replays, reference programs.
- A dive takes 0.1–0.4 s to simulate natively, a little more in a browser (tools/webcheck.sh prints timings).

## Next three tasks

1. **Art pass** (#7/#9/#13), Albert's priority since 2026-10-24: cool backgrounds, a Robbie sprite, the whole game
   and UI looking like a proper game, and a big Robbie in the Lab that changes as it is customised. Made in Blender.
   The setting is now a steampunk space colonisation (Radiance, Outer Wilds), darker. Round 1: 5 styles, 5 cute
   Robbies (he liked Jovian Comic and Bathy). Round 2: 5 truly different worlds and 5 machine Robbies
   (docs/art/README.md). Waiting for his final pick.
2. **Progression, step 1** (Albert's #5 and #1), once he approves `docs/design/progression.md`: reaching the exit
   opens the next room; room goals pay Data, shown in the header; old saves are paid for rooms already certified.
   If he hasn't answered, ask him first: it changes how rooms open.
3. **The Lab** (#6): act on Albert's reaction to the sketch (`game/station/lab.gd`, key B). Then slots and the
   first purchase (CPU modules) from step 2 of the proposal. Its Robbie sprite comes from the art pass.

## Known bugs and open questions

- **The Lock's intended program passes 18/20, not 20/20:** twice an eel lingers within range and Robbie waits until
  its battery runs out. It certifies (16 needed), but a tighter room or a better reference program would help.
- **Zigzag:** `keep_distance` and `move_towards beacon` can alternate quickly at the edge of a range. The 12 px
  margin helps but doesn't remove it.
- **The sim's jellyfish still snap to new headings;** only the picture smooths them (`_smooth_pos` in dive_view.gd).
- **`tools/bootstrap.sh` doesn't report GDScript parse errors;** run the tests or `tools/smoke.sh` after edits.
- **Background jobs** (`tools/hunt.sh`, `tools/solve_all.sh`) write to `out/`, which isn't in git. The Lock's hunt
  stopped at 7,750 programs (none passing the survey); The Nursery's at about 7,150. Restart them to continue.
- **Not verified:** the web build inside the claude.ai frame; it runs in headless Chromium and on Cloudflare.
- The plan's open decisions (win condition = survey fleet, success transmission, etc.) are implemented with the
  recommended defaults, pending Albert's answers.
