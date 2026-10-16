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
- [ ] **Wall of Robbies**: a screen of every serial with its epitaph; doubles as the score.
- [ ] **Station memory**: the room map assembled from every past dive's lamp, shown faintly.
- [x] **Survey fleet in the UI** (s02).
- [x] **Save/load** programs and the archive (s02).
- [ ] **Onboarding:** the first minute must teach the editor without a manual (see P0c).
- [ ] **Readability pass on the monitor:** at 1:1 the dive is small; offer a 2x "watch" mode.

## Next: P0c, readable and charming

- [ ] Live first viewing (fast-forward only until the transmission ends), then full scrubbing.
- [ ] Fast-forward that slows down by itself at markers.
- [ ] Ghost of the previous Robbie's path in the replay.
- [ ] Sound: underwater ambience, sonar-ish blips, the burst; procedural to start.
- [ ] Histograms per room: CPU and Robbies spent (seeded from solver runs).
- [ ] Onboarding: Room 1 opens with a pre-written broken program and one hint.

## Simulation and design

- [ ] Rerun exploit hunts for The Jellyfish and The Valve on the current sim (killed by a restart).
- [ ] The keep_distance / beacon zigzag at the edge of a range: decide whether it needs a fix.
- [ ] Jellyfish turn smoothly instead of snapping to a new heading.
- [ ] More rooms for the slice: a current, a vent, a second lurker type; one room that rewards the laser.
- [ ] Solver v1 (mutation search) to seed histograms and find cheaper solutions than ours.

## Quality and tooling

- [ ] Smoke test that renders one replay frame under Xvfb and checks it isn't blank.
- [ ] Tests for DiveText explanations.
- [ ] Profile the sim; keep a dive under 0.1 s as rooms grow.
- [ ] Custom size-optimised web export template (only if the web build is too big to share).

## Waiting on Albert

- Win condition (survey fleet), success transmission, first viewing, and the other open decisions in the plan doc.
- Vertex AI credentials, needed for art from M2.
