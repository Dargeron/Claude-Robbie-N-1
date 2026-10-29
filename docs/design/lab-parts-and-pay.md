# The Lab, its parts, the pay, and what the deep could hold

Status: **partly built in 0.10.0** (2026-10-29): Albert said yes to the pay and the debt and chose Lab draft C.
Built: the pay as in section 1 (survey fee by tries, first-try commendation, lost beacons paying on recovery; IN HAND
beside OWING; paying in against the debt), the six sockets, and these parts: spotlight, floodlight, red lamp, twin
screws, silent fins, flare launcher (replaces the laser), hydrophone, battery bank, reserve cell, plating, insulated
hull; the plates TURN LEFT/RIGHT, IF BEACON IN SIGHT, IF STUCK, IF HIT (and DROP FLARE, IF HEARD with their parts);
card-reader slots 3 to 6; the shellback (a yellow contact: harmless unless shot); lost beacons in all five sectors.
Prices and words: game/content/lab/parts.json; what parts do: game/sim/kit.gd. Not built yet: the other parts, the
lean-deck and full-chart bonuses, caches, the ONCE / FOR n SECONDS / AND modifiers, the regions. First written
2026-10-28 as a proposal: Albert asked for: rewards from the Company after
each mission that depend on how many tries it took; a Lab where the pay buys new instructions and better equipment
for Robbie (the obvious and the surprising); and a deeper brainstorm of level ideas and instructions. The Lab's
screen layout is in three drafts, in `docs/design/lab-drafts.md`.

Read the ★ items first: they are the ones I think could make the game special.

---

## 1. The pay

### What the Company pays

Each sector you certify pays a **survey fee** in scrip. Every Robbie you lose on the way costs a little of it, so the
fewer tries, the bigger the pay. The fee never drops below a floor, so a struggling player still moves on.

| Sector | Survey fee | Each Robbie lost after the first two | Floor |
| --- | --- | --- | --- |
| 1 · The Dark | 3,000 | −250 | 1,200 |
| 2 · The Jellyfish | 4,000 | −300 | 1,600 |
| 3 · The Listeners | 5,000 | −350 | 2,000 |
| 4 · The Gallery | 6,000 | −400 | 2,400 |
| 5 · The Lights | 7,000 | −450 | 2,800 |

Two lost Robbies are free: losing is how you learn, and the first naive deck is supposed to fail.

The tally memo prints it like a payslip, and the Company stamps it: **COMMENDED** (two or fewer lost),
**SATISFACTORY** (up to six), **NOTED** (more). The stamp is just pride, but it goes on the Wall.

### Bonuses, once per sector each (the optional goals)

| Bonus | How | Pays |
| --- | --- | --- |
| First try | The very first Robbie in the sector reached the beacon | +1,000 |
| Lean deck | Certified with fewer cards than the Company's record | +800 |
| Full chart | 90% of the sector seen, across all your Robbies | +600 |
| Salvage | A cache in the sector touched (off the safe path, on purpose) | +500 each |
| A wreck recovered | A later Robbie reaches where an earlier one died | +300 each |

The salvage caches are a new map item: one or two per sector, somewhere risky. They pull a player who already won
back in for one more dive.

### Where the pay goes: wage against debt

Today the counter shows what you **owe** (48,000 scrip for your passage). I'd keep that and add a second wheel:
**IN HAND**. The fee lands in hand. In the hangar you spend it on parts and type plates, or you push it through the
Company's slot against your debt.

That is Papers, Please's best trick turned towards Robbie. Every part you buy keeps you in your contract longer.
Paying the debt off is possible, and it is an ending (the Company "releases" you, and Robbie is reassigned to the
next operator). Most players won't, and they will feel why.

---

## 2. How Robbie is fitted

Bathy (the brass diving bell) has **six sockets**, each taking one part at a time:

| Socket | Where on Bathy | Stock part |
| --- | --- | --- |
| LAMP | Under the porthole | Standard lamp |
| DRIVE | The two pods at his sides | Standard pods |
| HATCH | On top | Telemetry antenna |
| BELLY | The band round his middle | Standard cell |
| TOOL | Under his chin | Empty (the laser goes here) |
| HULL | His skin | Standard hull, 3 knocks |

One part per socket keeps the choice alive. You never just get "better". You choose which Robbie to send into
*this* sector: quiet or fast, bright or dark, tough or light. Many parts also bring a **new card** on the press, so
equipment and instructions grow together.

The card reader is upgraded separately: slots 3, 4, 5 and 6 are sealed today ("REQUISITION PENDING"), and each one
opens for a price.

---

## 3. The parts (44 ideas)

Prices are only a first guess, to show the scale against the fees above.

### LAMP

| Part | What it does | New card | Price |
| --- | --- | --- | --- |
| Standard lamp | 6 tiles, a 70° cone | LAMP ON/OFF | stock |
| Spotlight | 10 tiles, a narrow 30° cone. Sees far down corridors; jellyfish see it from far away too | | 3,000 |
| Floodlight | 3 tiles, almost all round. Sees round corners and lurkers at the side | | 3,000 |
| ★ **Red lamp** | Real deep-sea science: most creatures down there can't see red. Lamp on, and the jellyfish don't come. But red shows no colour, so glowing things look grey on the scope | | 6,000 |
| ★ **Strobe** | Flashes. A lurker caught in the flash is dazzled for two seconds; jellyfish come in bursts | STROBE | 5,000 |
| ★ **Ultraviolet lamp** | Shows what's hidden: resting lurkers, and marks on the rocks nobody admits to: arrows scratched by earlier Robbies, Op. 5's notes, things that aren't writing | | found / 8,000 |

### DRIVE

| Part | What it does | New card | Price |
| --- | --- | --- | --- |
| Standard pods | 1 tile a second | | stock |
| Twin screws | +50% speed, more drain. Loud: eels hear him twice as far | | 4,000 |
| Silent fins | 70% speed. Eels can't hear him at all | | 4,000 |
| ★ **Jet pump** | A burst of three times speed for one second, at a big energy cost. Outrun a jellyfish, slip under a closing valve | DASH | 6,000 |
| ★ **Crawler legs** | He walks on the rock instead of swimming. Silent, and currents can't touch him, but he can't cross open water | CLING / LET GO | 7,000 |
| Drag anchor | Holds him dead still, even in a current | ANCHOR | 2,500 |

### HATCH

| Part | What it does | New card | Price |
| --- | --- | --- | --- |
| Antenna | Telemetry home | | stock |
| Hydrophone | Hears creatures through rock, 8 tiles. Sound shows on the scope as rings | IF HEARD | 4,000 |
| Pinger | Active sonar: draws the chart 10 tiles around him for a moment. Every listener in the sector hears it | PING | 5,000 |
| ★ **Thermometer** | Feels whether the water is getting warmer. Op. 5's first letter: "Robbie 31 said it's warm by the wall." Warm water leads to vents, to hidden sectors, and to whatever is down there | SWIM TOWARDS WARMTH, IF WARMER | 6,000 |
| ★ **Wreck compass** | Points at the wrecks of earlier Robbies. They are where something stopped you, so they make good waymarks. And they are salvage | SWIM TOWARDS WRECK, IF WRECK NEAR | 5,000 |
| ★ **Long wire** | Trails a cable back to the station: telemetry even in dead-air zones where the scope goes blind. The cable can snag on rocks | | 7,000 |

### BELLY

| Part | What it does | New card | Price |
| --- | --- | --- | --- |
| Standard cell | The sector's charge | | stock |
| Battery bank | +40% charge, slightly slower | | 4,000 |
| Reserve cell | When the charge runs out, he gets 15% back, once | | 3,500 |
| ★ **Thermal cell** | Recharges near warm vents. Now the best route isn't the shortest one: it goes past the vents | | 6,000 |
| ★ **Clockwork timer** | He can count seconds | AFTER n SECONDS, FOR n SECONDS | 5,000 |
| ★ **Memory drum** | One thing remembered. Punch MARK and later cards can ask IF MARKED: "after the first jellyfish, run dark for good" | MARK, IF MARKED | 6,000 |

### TOOL

| Part | What it does | New card | Price |
| --- | --- | --- | --- |
| Laser | The Company's patent (what we have today) | SHOOT | issued |
| Focused laser | Twice the range, slower to recharge | SHOOT | 5,000 |
| ★ **Stun prod** | Short reach. Stuns for three seconds and kills nothing. The Company pays a specimen bounty for live ones, and doesn't say what they're for | STUN | 5,000 |
| ★ **Flare launcher** | Leaves a burning flare behind. Jellyfish swarm the flare instead of his lamp. A decoy | DROP FLARE | 5,000 |
| ★ **Rattle buoy** | Leaves a noisemaker. Eels go to the noise. The Listeners' decoy | DROP RATTLE | 4,000 |
| ★ **Grapple** | Fires a line at the rock ahead and reels him in fast: across currents and gaps | GRAPPLE | 6,000 |
| ★ **Drill** | Bores through soft rock (it looks different on the scope): shortcuts the map didn't plan for | DRILL | 8,000 |
| ★★ **Marker buoys** | He drops a buoy, and **it stays in the sector for the next Robbies**, who can swim to it. Robbie leaves a trail for Robbie N+1. Three per sector, billed | DROP BUOY, SWIM TOWARDS BUOY | 6,000 |
| Sample jar | Picks up salvage and specimens on the way (the caches) | COLLECT | 3,000 |

### HULL

| Part | What it does | New card | Price |
| --- | --- | --- | --- |
| Standard hull | 3 knocks | | stock |
| Plating | +2 knocks, 10% slower | | 4,000 |
| Self-sealing hull | Mends one knock every 20 seconds | | 6,000 |
| Insulated hull | The shut valve doesn't sting (its crush still kills) | | 3,500 |
| ★ **Shock hull** | Whatever touches him gets a jolt (a stinging jellyfish dies). Each jolt costs charge | | 6,000 |
| ★ **Mimic skin** | While he's stopped, nothing can sense him: he passes for rock, like a lurker | HIDE | found |

### Parts nobody made (found, not bought)

Salvage sometimes comes back with something on it that was not fitted when he left. These don't fit the Company's
sockets until Op. 5's adapters arrive, and fitting them is how the deep starts to talk.

| Part | What it does |
| --- | --- |
| ★ **The eel's ear** | He understands the eels. Their calls come through on the teleprinter as words. New card: IF EEL ASLEEP |
| ★ **A cold light, carried** | Nothing hostile notices it. And where he carries it, more cold lights come out to meet him |
| ★ **The heart** | It grows. Robbie remembers: the last Robbie's route shows as a ghost on the scope, and a new card follows it: FOLLOW GHOST (follow the last Robbie as far as he got, then think for yourself) |
| ★ **Op. 5's key** | Opens the seal on the Company's Compliance Governor (from the hangar ideas): frees a card slot, and Robbie starts to talk differently |

---

## 4. New instructions (type plates)

Some come with a part (above); these are type plates for the press on their own. ★ are my favourites.

### Orders

| Card | What it does |
| --- | --- |
| TURN LEFT / TURN RIGHT | A quarter turn from where he faces (today's SWIM is by compass) |
| BACK UP | Reverse a little, facing the same way |
| WAIT n SECONDS | Stop for that long, then read the deck again |
| CIRCLE | Swim in a tight circle (search a small space, or wait without stopping) |
| ★ SING | He sends a tone. In the deep, something sometimes answers |

### Conditions

| Card | True when |
| --- | --- |
| ★ **IF BEACON IN SIGHT** | Nothing but water between him and the beacon. "Follow the wall until you can see it, then go": the most useful card in the game |
| ★ **IF STUCK** | He hasn't got anywhere in two seconds (pushing a wall, going round in a tiny circle) |
| IF HIT | He was just hurt |
| IF ALONE | He senses nothing at all |
| IF WALL LEFT / IF WALL RIGHT | Rock beside him |
| IF OPEN AHEAD | Open water for 4 tiles ahead |
| ★ **IF NEW WATER** | The water ahead is not on the chart yet (explore, instead of retracing) |
| IF LIT | He is in light (his own, a flare, a cold light) |
| ★ **IF COIN** | Heads or tails, a new toss each second. The only card that isn't certain, and the cure for a deck that loops forever |

### Modifiers (a third wheel on the press, beside NOT)

| Card | What it does |
| --- | --- |
| NOT | Flips the condition (we have it) |
| ★ **ONCE** | The card runs once, then its holes burn through and the reader skips it. The press shows a scorched card |
| ★ **FOR n SECONDS** | Once the card starts, he keeps doing it for that long, whatever else fits. The fix for decks that dither between two cards |
| AND | Two conditions on one card. It's a double-width card that takes two slots |

---

## 5. A deeper brainstorm of levels

### What a sector can be about

The five sectors so far are all "reach the beacon, with one idea in the way". Here is the wider menu:

- **Goals:** reach the beacon; go there and **come back** (salvage a wreck); **touch** every cache; **escort**
  something; **stay hidden** the whole way; **leave** a buoy at a mark for the next shift; **bring back** a specimen.
- **Water:** currents (one-way), undertows (loops), warm vents (recharge, eruptions on a timer), dead air (the scope
  goes blind), soft rock (drillable), tides (walls that move with time), murk (the lamp reaches half as far).
- **Life:** hunters that patrol, swarms that sweep, things that follow the light, things that follow sound, things
  that sleep and wake, something friendly, something huge.
- **Across dives:** buoys that stay, wrecks that stay (and move), ghosts of the last route. Puzzles no single Robbie
  can solve, only a line of them: the game's title made into a rule.

### 24 sector ideas, in four regions

**Region 2 · The Vents** (heat and currents: the thermometer, the anchor, the timer)

| Sector | The idea | The answer | The trap |
| --- | --- | --- | --- |
| The Chimney | A current sweeps up a shaft past the exit's side tunnel | ANCHOR IF WALL LEFT · FOLLOW WALL LEFT | Swim to the beacon: swept past it, every time |
| Warm Water | A maze of vents; the warmest path is the way | SWIM TOWARDS WARMTH · SWIM TOWARDS BEACON | The beacon and the wall both lead to dead ends |
| The Boil | Vents erupt in turn: crossing one at the wrong moment boils him | WAIT 3 SECONDS IF HEARD · SWIM TOWARDS BEACON | Straight across; or waiting too long and running dry |
| The Long Way | Too far for the battery, unless he passes the vents | Thermal cell + SWIM TOWARDS WARMTH IF ENERGY BELOW 50 | The short route runs out of charge |
| Undertow | A current runs in a loop round an island | FOLLOW WALL RIGHT FOR 5 SECONDS IF STUCK · SWIM TOWARDS BEACON | Any deck without a way out of the loop goes round forever |
| Coin Toss | A symmetric cave where every certain deck goes round and round | MOVE TOWARDS OPEN WATER IF COIN · FOLLOW WALL LEFT | Every deck without the coin, forever |

**Region 3 · The Wreck Field** (memory and generations: buoys, the wreck compass, the ghost)

| Sector | The idea | The answer | The trap |
| --- | --- | --- | --- |
| ★ Breadcrumbs | A labyrinth longer than any battery. Each Robbie drops buoys where he got to; the next swims buoy to buoy and goes further | DROP BUOY IF ENERGY BELOW 25 · SWIM TOWARDS BUOY · FOLLOW WALL LEFT | One Robbie can't make it; you have to think in Robbies |
| ★ The Ghost Road | The same, with the heart: FOLLOW GHOST takes each Robbie as far as the last, then he explores | FOLLOW GHOST · FOLLOW WALL LEFT IF NEW WATER | Starting fresh every time |
| Salvage | The wreck of Robbie 001 lies deep. Bring a part back to the drop point | SWIM TOWARDS WRECK · then home: the drop point is the exit | Getting there is easy; there's no charge to get back the way you came |
| The Moving Wrecks | The wrecks are not where they fell. The compass leads somewhere new each dive | (story sector: the compass leads to the deep's first door) | Trusting the map |
| Hulls | Old Robbie hulls, propped up like sentries. One of them still answers | SING · SWIM TOWARDS LIGHT | (story) |
| Recovery | A sector you failed in many times: every wreck there pays salvage | (a sector that rewards past failure) | |

**Region 4 · The Hunting Grounds** (predators: flares, rattles, the strobe, the stun prod, the jet)

| Sector | The idea | The answer | The trap |
| --- | --- | --- | --- |
| The Shepherd | Jellyfish crowd the exit; lead them off with a flare | DROP FLARE IF HOSTILE NEAR 6 · LAMP OFF · FOLLOW WALL | Lamp off: they never leave the door |
| Hide and Seek | A hunter patrols a maze by sound | HIDE IF HEARD · SWIM TOWARDS BEACON | Run, and it's faster |
| The Choir Loft | Eels in every shaft, too many to wait out one by one | DROP RATTLE · then slip through while they go to it | STOP works for one; here there are nine |
| Mirror Hall | Glassy rock reflects the laser; shoot the wrong way and it comes back | SHOOT only IF BEACON IN SIGHT... (the room teaches where not to shoot) | Shooting everything |
| The Swarm | A wall of jellyfish sweeps the cavern, with one gap | DASH IF HOSTILE NEAR 4 · SWIM TOWARDS OPEN WATER | Running from it: it's wider than the cave |
| Specimen | The Company wants one eel alive | STUN IF HOSTILE NEAR 2 · COLLECT | The laser pays nothing: dead specimens are "unusable" |

**Region 5 · The Deep** (the story's end: the ultraviolet lamp, the eel's ear, the cold light, SING)

| Sector | The idea | The answer | The trap |
| --- | --- | --- | --- |
| Dead Air | A zone where the telemetry fails: you see him go in and come out, or not | Long wire; or a deck you trust without watching | Not knowing what killed him |
| The Writing | The ultraviolet lamp shows arrows scratched on the rocks by earlier Robbies. They lead the right way. Who taught them? | (UV + FOLLOW WALL on the marked side) | |
| The Garden | Cold lights in a pattern; taking them in the wrong order relights them all | MARK + ONCE: each light once, in order | Nearest-first, which is wrong here |
| The Choir | The eels sing; when Robbie answers in tune, the walls open | SING IF HEARD · SWIM TOWARDS OPEN WATER | Silence |
| The Mouth | The whole sector is one sleeping thing. Wake it and the walls move | HIDE · WAIT · stealth all the way | Light, noise, haste |
| Two Doors | Two exits: the Company's beacon, and a cold-light door the Company says isn't there | Either. One is certified and paid. The other is the ending | (the game's last choice) |

---

## 6. Decisions for Albert

1. **The pay:** a wage IN HAND for parts, beside the debt you OWE, so every part keeps you in your contract longer?
   *Recommended: yes. One currency (scrip) and one choice: Robbie or your freedom.*
2. **Instructions:** the plate a sector teaches comes free with its orders, and everything else is bought in the
   Lab? *Recommended: yes, so every sector stays solvable without buying.*
3. **Which ★ parts and cards** should the next sectors be built around? *Recommended to start: the red lamp, flares,
   the thermometer, IF BEACON IN SIGHT, FOR n SECONDS, and the marker buoys (Breadcrumbs).*
