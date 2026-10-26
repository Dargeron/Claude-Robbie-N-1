# Status

Updated 2026-10-26, session 43: **0.8.1, five sectors** (0.8.1 rebuilds the far half of The Lights after the hunt found decks that skip the lights). Station controls are done (0.7.0). Albert: the first two
levels are fine; get three more that are fun with two cards. Brainstorm of ten in docs/design/levels-3-5.md; picked
The Listeners (stop), The Gallery (back away; new room) and The Lights (follow the cold lights; new room and a new sim
element, `o` in a room, that goes out when Robbie reaches it). One new type plate per sector. The Nursery, Valve and
Lock stay for later. Waiting on Albert: his playtest of sectors 3-5; the Lab ideas (docs/design/hangar-ideas.md).

## Where we are

**Moved to GitHub and Claude Code on 22 October** after 32 hourly blocks in a Cowork session. Albert's 14 playtest notes come first
(docs/design/feedback-2026-10-17.md). Done: #14 the lurker, #8 CPU budgets, #2 full-screen launch and skip-ahead, #11 hidden until found, #4/#3 room goals and a guided first room, #10 last words.

**Albert played it (2026-10-17, evening): "I had FUN... the barest core is good."** The core loop passes his gate. He has many
changes, suggestions and problems to fix; those come first in the backlog as soon as he sends them.

**Phase M1, step P0b (first playable): every item on its list is done** (block 9). The station screen runs the whole loop:
write rules, launch, watch, understand, fix, survey. Builds exist for Linux, Windows, macOS and the web
(https://claude.ai/artifact/EtAUzrsTr2DVgwN4zAeCuE, and publicly at https://robbie-n1.bauldejuegos.workers.dev). Next: P0c, readable and charming. See docs/BACKLOG.md.

## What works

- **The operator's console** (session 36): the game on one desk in the Bathy + Dead Air look. Live sonar with Bathy's
  amber glyph and dead air on a loss; card rack with pilot lamps and stamped reasons; keypunch (drums, value wheel,
  NOT, PUNCH); reader load gauge; dispatch lever under a safety cover; sea trials on the analytical engine; wire
  recorder and teleprinter linked to the dive; Company tube with memos and tallies; sector dial; shift nixies; Bathy's
  mood porthole; the binder; the Wall as a corkboard of torn tapes. Three shifts with type plates issued shift by
  shift, Op. 5's notes as the tutorial and his letters as the plot. Everything works by touch (tested by a
  play-through that only taps and drags). See docs/devlog/2026-10-25-s36.md.
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

1. **Albert's playtest of 0.2.0** (the press, slots, lid, chute): fix what he finds first.
2. **The art direction he picks** (A: 3D from the chair, recommended; B: lived-in 2D; C: inked). If A: a small
   Godot 3D test of one machine on his tablet first, with light baked in Blender, then the whole desk.
3. **The Lab (hangar)**, once he has answered the three questions in `docs/design/hangar-ideas.md`. More reader
   slots are a natural first part to requisition.

## Known bugs and open questions

- **The console's prototype doesn't have yet:** the hangar (sealed), sectors 4–6, and a way to copy a deck between
  sectors. The old CPU costs still exist in the sim and the old station; the console ignores them.
- **Not verified on a device:** the console's touch handling is tested with simulated taps and drags
  (`tools/console_check.sh`), not yet on Albert's tablet.

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
