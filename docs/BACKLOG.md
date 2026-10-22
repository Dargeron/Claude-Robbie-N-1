# Backlog

The hourly work loop picks from the top. Each block: pick the most valuable item, build it,
test it, look at it, log it, back it up. Re-rank when something new is learned.

Status marks: `[ ]` to do · `[~]` in progress · `[x]` done (with the session it landed in).

## Albert's feedback (top priority)

Full notes and triage: docs/design/feedback-2026-10-17.md. Order to confirm with Albert.

- [x] #14 The Valve's lurker can't be read: a sleeping lurker shows in the lamp's glow, clearer wake, hint and manual say it's camouflaged (s21).
- [x] #8 Raise CPU budgets now, by about half (s21). Later: CPU as an upgrade.
- [ ] #5 Beacon opens the next room; optional objectives per room pay currency (survey becomes one of them?).
- [x] #2 Full-screen Game on launch; Left/Right speed incl. x0.5; K skips fast to just before where the last Robbie was lost, on by default (s21).
- [x] #3/#4 Room goals under LAUNCH with a big survey button that glows when it's time; a guided first room; "New station" in the manual (s23). Later: a fuller tutorial for later rooms if playtests ask.
- [x] #11 Everything hidden until discovered, exit included; a green tick shows the beacon's bearing (s22).
- [x] #10 340 last words, chosen by cause and circumstance, never repeated while others fit (s24). Keep adding; Albert can edit lines.json.
- [ ] #1/#6 Design with Albert: two currencies, the Lab (Robbie sprite, slots), shop for equipment and instructions.
- [~] #6 Three screens: Game (full-screen launch, s21), Mission Control, and a first sketch of the Lab (s30): Robbie on the
      bench with a card per part and two empty slots. Waiting on Albert's reaction and the currencies.
- [~] #7/#9/#13 Art pass: cute, drawn, steampunk-ish, organic and moving walls (needs Vertex AI credentials). Without it so far:
      full screen at full resolution, a round Robbie with a big eye, pulsing jellyfish with smooth paths (s27). Rounded rock, anemones, a beacon buoy (s28). Eel and lurker redrawn, marine snow in the lamp (s29).

## Now: P0b, the first playable

- [x] **Station screen**: monitor + rule editor + CPU meter + launch + archive in one screen (s02).
- [x] **Builds Albert can run**: Linux/Windows/macOS zips; web build on a claude.ai page (s02).
- [~] **Verify the web page inside the claude.ai frame** (WebAssembly may be blocked there). Runs in headless
      Chromium end to end (tools/webcheck.sh, block 15); the claude.ai frame still needs Albert's eyes.
- [x] **Replay controls on screen**: transport, timeline with markers, click-to-seek (s02).
- [x] **Why? panel**: the rule-by-rule explanation for the moment under the playhead (s02).
- [x] **Robbie's voice v1**: subtitles and last words, 40 lines (s02).
- [x] **Wall of Robbies**: a screen of every serial with its epitaph; doubles as the score (block 4).
      Route thumbnails on each plaque (block 12). Later: survey Robbies with serials of their own (decision for Albert).
- [x] **Station memory**: the faint chart of what earlier Robbies saw (block 1).
- [x] **Survey fleet in the UI** (s02).
- [x] **Save/load** programs and the archive (s02).
- [x] **Onboarding:** mission-control lines and hints (block 1); a broken one-rule starter program; a first-visit
      coach pointing at LAUNCH, the timeline and the editor (block 9).
- [x] **Watch large** mode at 2x (block 1).

## Next: P0c, readable and charming

- [x] Robbie's manual and tooltips for every order and condition (block 16).

- [x] **Robbie's senses in the Why? panel**: what each condition read at that moment (block 5).
- [ ] Live first viewing (fast-forward only until the transmission ends), then full scrubbing.
- [x] Fast-forward that slows down by itself at markers: AUTO speed (block 8).
- [x] Ghost of the previous Robbie's path in the replay (block 5).
- [x] Sound v1: 15 synthesised sounds, event-synced, mute (block 2).
- [~] Histograms per room: "the cheapest known" CPU after certification (block 10); a real histogram needs players.

## Story

- [x] Station log: six entries, one per certified room, understated (block 14). Albert to rewrite as he likes.
- [ ] Make one of the log's oddities mechanical in a later room (the swarm drifting to where Robbies fell; the ping).

## Simulation and design

- [~] Exploit hunts (resumable, tools/hunt.sh): jellyfish wall-hug fixed (block 1); valve far-wall
      shortcut fixed with a second lurker (block 2); jellyfish fixed routes fixed with a fresh swarm every
      dive and a lamp glow (block 3); valve "shoot + open water" closed by laser-proof lurkers (block 6).
      The Valve hunt finished (8,420 programs). The Listeners hunt finished (8,560): its 20 passing programs are all
      variants of the intended "stop when an eel is near" (block 19). The Nursery hunt is running.
- [x] **Survey luck**: fixed with a fleet of 20, 16 needed (block 13), after the solver certified a 45% Valve program.
- [ ] Hunt three-rule programs (sampled), now that two-rule sweeps are done.
- [ ] The keep_distance / beacon zigzag at the edge of a range: decide whether it needs a fix.
- [x] `keep_distance` reverses blind and can back Robbie into rock: a `wall_behind` condition (block 24). Later: a room
      that teaches it.
- [~] Jellyfish turn smoothly instead of snapping to a new heading: smoothed in the picture (s27); the sim still snaps.
- [x] One room that rewards the laser: The Nursery (block 7).
- [x] A new creature that needs a new answer: the eel, and The Listeners (block 11).
- [~] More rooms for the slice: The Lock combines the valve and the eels (block 23). Next: a current, a vent; jellyfish with eels.
- [~] Solver v1 (mutation search, block 10): running room by room; records for The Dark so far. Refresh
      `content/solver/records.json` with `tools/solver_records.py` as results come in.

## Quality and tooling

- [x] Smoke test: tools/smoke.sh renders the station tour and checks every shot (block 12).
- [ ] Tests for DiveText explanations.
- [x] Profile the sim (block 15): sensing checks distance before line of sight, nearest hostile cached per think.
- [ ] Custom size-optimised web export template (only if the web build is too big to share).

## Waiting on Albert

- Win condition (survey fleet), success transmission, first viewing, and the other open decisions in the plan doc.
- Vertex AI credentials, needed for art from M2.
