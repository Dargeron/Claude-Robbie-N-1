# Backlog

The hourly work loop picks from the top. Each block: pick the most valuable item, build it,
test it, look at it, log it, back it up. Re-rank when something new is learned.

Status marks: `[ ]` to do · `[~]` in progress · `[x]` done (with the session it landed in).

## Now: P0b, the first playable

- [x] **Station screen**: monitor + rule editor + CPU meter + launch + archive in one screen (s02).
- [x] **Builds Albert can run**: Linux/Windows/macOS zips; web build on a claude.ai page (s02).
- [ ] **Verify the web page inside the claude.ai frame** (WebAssembly may be blocked there).
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

- [x] **Robbie's senses in the Why? panel**: what each condition read at that moment (block 5).
- [ ] Live first viewing (fast-forward only until the transmission ends), then full scrubbing.
- [x] Fast-forward that slows down by itself at markers: AUTO speed (block 8).
- [x] Ghost of the previous Robbie's path in the replay (block 5).
- [x] Sound v1: 15 synthesised sounds, event-synced, mute (block 2).
- [~] Histograms per room: "the cheapest known" CPU after certification (block 10); a real histogram needs players.

## Simulation and design

- [~] Exploit hunts (resumable, tools/hunt.sh): jellyfish wall-hug fixed (block 1); valve far-wall
      shortcut fixed with a second lurker (block 2); jellyfish fixed routes fixed with a fresh swarm every
      dive and a lamp glow (block 3); valve "shoot + open water" closed by laser-proof lurkers (block 6).
      The Valve hunt finished (8,420 programs); The Jellyfish hunt is running.
- [x] **Survey luck**: fixed with a fleet of 20, 16 needed (block 13), after the solver certified a 45% Valve program.
- [ ] Hunt three-rule programs (sampled), now that two-rule sweeps are done.
- [ ] The keep_distance / beacon zigzag at the edge of a range: decide whether it needs a fix.
- [ ] `keep_distance` reverses blind and can back Robbie into rock (2 of 20 jellyfish dives). Candidate
      lesson: a `wall_behind` condition, or a room that teaches it.
- [ ] Jellyfish turn smoothly instead of snapping to a new heading.
- [x] One room that rewards the laser: The Nursery (block 7).
- [x] A new creature that needs a new answer: the eel, and The Listeners (block 11).
- [ ] More rooms for the slice: a current, a vent; rooms that combine two creatures.
- [~] Solver v1 (mutation search, block 10): running room by room; records for The Dark so far. Refresh
      `content/solver/records.json` with `tools/solver_records.py` as results come in.

## Quality and tooling

- [x] Smoke test: tools/smoke.sh renders the station tour and checks every shot (block 12).
- [ ] Tests for DiveText explanations.
- [ ] Profile the sim; keep a dive under 0.1 s as rooms grow.
- [ ] Custom size-optimised web export template (only if the web build is too big to share).

## Waiting on Albert

- Win condition (survey fleet), success transmission, first viewing, and the other open decisions in the plan doc.
- Vertex AI credentials, needed for art from M2.
