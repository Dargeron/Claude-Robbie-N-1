# The operator's console: the game as one dark station desk (proposal for Albert)

Status: **proposal**, 2026-10-25. Albert chose the art (Bathy + Dead Air) and asked for a UI where everything lives
inside the game world: the player is the operator in a station, clicking through its systems, with Robbie's sonar
taking about a third of the screen and the rest being systems; launching never hides them; a button magnifies the
sonar to full screen. Dark steampunk, the mood of Peter Watts' *Starfish*; everything dark except Bathy, who stays
cute. Papers, Please is "our God". The main question: how to make **giving instructions** part of the system, and fun.

Mock-up of the console: [`docs/art/station/console-mock-1.png`](../art/station/console-mock-1.png)
(`tools/art/station_mock.py`).

## What we take from Papers, Please

| Papers, Please | Robbie N+1 |
|---|---|
| The booth and desk are the interface; nothing floats | The console is the interface: every control is a machine, every message is paper |
| Every verb has a thing and a sound: the stamp's thunk | Punch lever (ka-chunk), dispatch lever (hiss, clank), tearing the tape, the tube's thump |
| The desk is cramped; documents pile up | The rack holds only so many cards: the card reader's capacity is the CPU budget |
| New rules arrive day by day, on paper; the rulebook grows | New orders arrive by pneumatic tube as type plates for the keypunch drum; the binder grows |
| Mistakes print a citation | The teleprinter prints every loss; the Company sends Notices (dry, funny, not punishing) |
| A day's rhythm: bulletin, work, the evening tally | Shifts: the morning memo, the work, the end-of-shift tally from the Company |
| The story comes through the paperwork | Memos, the previous operator's notes, Robbie's last words, the Wall |
| Inspecting finds the discrepancy | After a loss you inspect: tap a line on the tape, the recorder jumps there, the guilty card lights |
| Efficiency against humanity | The Company counts Robbies as stock; their last words say otherwise |

From *Starfish*: darkness and pressure, the station's constant creaks and drips, a deep known only through
instruments, a company that doesn't care, and a mind in a box doing what it was taught.

## The screens

### 1. The console (the game, always)

One fixed view, like the booth. Left: the **sonar receiver** (about a third of the screen) with the **wire recorder**
and the **teleprinter** under it. Right: Robbie's **program** (the card rack), the **keypunch**, the **card reader
load** gauge (CPU), the **dispatch lever**. Along the top: the **Company tube**, the **sector selector**, the **shift**
counter, **Robbie's mood** porthole and the **hangar window** (spare hulls; the way to the Lab).

- **Sonar receiver.** The dive plays here as it happens: contours where the sonar returns, contacts as blips, Robbie
  as an amber transponder glyph, his lamp as an amber wedge. **Magnify** pulls a hood over the scope for full screen.
- **Wire recorder.** Every dive is recorded on wire. Scrub by dragging the reel; event marks on the wire (contacts,
  card changes, hits); keys for back, play, forward, and "to last loss"; a speed dial ½ to 8.
- **Teleprinter.** Prints the dive as it happens ("0:01.4 CONTACT C-1 BRG 040") and the last words at the end. Tear
  the strip off and pin it to the Wall.
- **Card rack.** The program, read top to bottom. Each card has a **pilot lamp**: amber while it runs, dim red when
  its condition fails (with the reason stamped: NO CONTACT, NO WALL), dark when never reached. This is the Why? panel
  made physical, and it makes the program visibly *run*.
- **Keypunch.** Compose a card: turn the order drum, the condition drum, the parameter wheel, flip NOT, pull PUNCH.
  The card drops into the rack. Drag cards to reorder; drop one in the bin to discard. Holes are the CPU cost.
- **Card reader load.** A needle gauge: what the deck weighs against Robbie's reader (the CPU budget). In the red, the
  reader refuses the deck. A bigger reader comes from the Hangar.
- **Dispatch.** Flip the safety, pull the lever: hatch, hiss, Robbie N+1 drops and the scope wakes. Its plate names
  the next Robbie.
- **Sector selector.** Turn the dial to choose the room; the scope shows its chart (only what Robbies have seen, with
  a cross where each one was lost).
- **Company tube.** Memos arrive in brass capsules: objectives, new type plates, regulations, news.
- **Robbie's mood.** A porthole showing Bathy's face screen live: calm, curious, worried, scared, happy at the beacon;
  static at the end. The only full-colour, cute thing on the console.
- **Hangar window.** The spare hulls hanging in the hangar; click to go there.
- Also on the desk, as paper: the **binder** (orders, conditions, a bestiary drawn from sonar, Company regulations)
  and the **previous operator's notes**, taped where they help: the tutorial, in his handwriting.

### 2. The hangar (the Lab)

The one warm room. Bathy hangs from a chain hoist under a work lamp, in full colour. A pegboard of parts (lamps, props,
sensors, batteries, card readers); drag a part onto a socket on his hull and he changes. The requisition desk: the
Company catalogue, and requisition forms you fill in and stamp (Salvage for parts, Data for type plates and bigger
readers). Spare hulls on the rack: building a hull costs Salvage.

### 3. The Wall

Behind the operator's chair: a corkboard of every Robbie's torn tape and number. Tap one to play its dive again on the
scope.

## Making instructions fun

1. **The keypunch is a toy.** Drums that click, a wheel, a switch, a lever with weight. Composing a rule is a
   physical act with a sound, not a form.
2. **The deck is an object.** Order is position; reordering is moving paper.
3. **The program visibly runs.** Pilot lamps flick from card to card during the dive; you see Robbie think.
4. **Losses are an inspection.** Tape line, recorder, card lamp, all linked: find the card that killed him.
5. **New orders are new tools.** A new type plate arrives in the tube and goes into the drum, like Papers, Please's
   new booth tools.
6. **Sea trials.** The survey fleet becomes the station's analytical engine: feed it the deck, it clatters through 20
   dives and prints a strip of results; at 16, the Company stamps CERTIFIED on the sector's chart.
7. **The previous operator's notes** teach the game in a voice, with a story behind them.
8. **A card file** keeps decks per sector, to copy and try variations.

## Art rules

- Everything is lit only by its instruments: green phosphor, amber nixies and pilot lamps, the orange of valves.
  Steel, bakelite and brass; condensation; deep shadow. A red lamp when a Robbie is lost.
- **Bathy is the only warm, cute thing.** On the scope he is an amber glyph (round hull, porthole, two eye dots, pods;
  16 headings; expressions in the eyes); his lamp an amber wedge; when hurt the glyph flickers; when lost it breaks
  into static and the carrier drops: dead air. In the mood porthole and the hangar, the full-colour Bathy.
- Creatures are green contours, drawn only where sensed; unknown contacts are fuzzy echoes until the binder has them.

## The shift (Papers, Please's rhythm, without a timer)

- **Start:** a capsule from the Company: the shift's objectives, new plates, a regulation, a piece of news.
- **Work:** program, dispatch, watch, inspect, fix. No clock pressing on the player: this is a thinking game.
- **End:** the Company's tally: hulls lost, Data and Salvage earned, commendations, notices.

## Story seeds (for Albert)

The operator before you (Op. 5) left notes; they get stranger. The Company says Robbies feel nothing; their last words
disagree. Wrecks are not where they fell. Later sectors reach places the colony built: the other four worlds of round 2
can appear as sonar ruins (the drowned streets, the deco gardens, the mine).

## Decisions for Albert

1. **The instruction machine:** punch cards and a keypunch? (Alternatives: a patch panel of cables; a telegraph key.)
   *Recommended: punch cards.*
2. **Shifts with Company memos and an end-of-shift tally**, no timer? *Recommended: yes.*
3. **The Company as a quiet antagonist**, with the question of whether Robbies feel anything left open? *Recommended:
   yes, lightly.*

## Build order once agreed

1. The console layout in Godot: the scope in the Dead Air look with Bathy's amber glyph, the rest as static machines.
2. Cards and the keypunch replace today's rule editor; pilot lamps during dives.
3. Wire recorder and teleprinter replace the replay bar; inspection links.
4. Bathy's mood porthole and his scope glyph in 16 headings.
5. The hangar (Lab), then shifts and Company memos.
