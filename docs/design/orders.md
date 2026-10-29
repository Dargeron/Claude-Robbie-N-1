# Orders, conditions and sensing (prototype set)

Source of truth: `game/vm/catalogue.gd` and `game/sim/world.gd`. This page explains them.

## How a program runs

A program is an ordered list of rules: `ORDER [parameter] [if [not] CONDITION [parameter]]`.

- Robbie **thinks** every 3 ticks (10 times a second). It reads the list from the top and runs the
  first rule whose condition holds and whose order can be carried out.
- A rule with no condition always holds.
- An order that cannot be carried out right now (nothing to keep away from, nothing to shoot, no
  light in sight) is skipped, and Robbie keeps reading.
- **Settings** (`lamp on/off`) are applied and Robbie keeps reading.
- `shoot` commits Robbie for 6 ticks; no thinking happens until it finishes.
- If no rule applies, Robbie drifts in place.

## Orders

| Id | Station label | CPU | Notes |
| --- | --- | --- | --- |
| `move <degrees>` | Move 90° | 1 | Compass: 0° up, 90° right. Turns at about 180° per second |
| `move_towards beacon` | Move towards beacon | 2 | Straight line to the exit's beacon. The beacon is not a path |
| `move_towards light` | Move towards light | 2 | Nearest glowing thing Robbie senses. Usually a terrible idea |
| `move_towards open_water` | Move towards open water | 3 | The freest of 16 directions, preferring straight ahead |
| `keep_distance <2/4/6>` | Keep distance from hostile 2 tiles | 3 | Backs away at 0.75 px/tick while facing the threat |
| `follow_wall <left/right>` | Follow wall left | 3 | Keeps a wall about 12 px away on that side |
| `stop` | Stop | 1 | Saves movement energy |
| `shoot` | Shoot laser | 3 | Nearest sensed hostile within 6 tiles and in line of sight; 200 energy; 1 s cooldown |
| `lamp <on/off>` | Lamp off | 1 | Setting. Off: jellyfish don't come, but Robbie sees much less |
| `turn <left/right>` | Turn left | 1 | A quarter turn from where he faces; he doesn't think again for about half a second (plate bought in the Lab) |
| `drop_flare` | Drop flare | 2 | Needs the flare launcher (3 flares, no laser). Burns 10 s; jellyfish within 4 tiles that can see it gather on it instead of the lamp |

`if` costs 1 more CPU, `not` 1 more, plus the condition's own cost.

## Conditions

| Id | Label | CPU | True when |
| --- | --- | --- | --- |
| `hostile_near <2/4/6>` | hostile is near | 2 | A sensed hostile is within that many tiles (switches off 12 px further out) |
| `wall_ahead` | wall ahead | 1 | Rock, or a valve that isn't fully open, within 16 px of the hull |
| `valve_open` | valve is open | 2 | Robbie senses the valve ahead and it is fully open |
| `valve_shut` | valve is shut | 2 | Robbie senses the valve ahead and it is closing or closed |
| `energy_below <25/50/75>` | energy below | 1 | Energy under that percentage |
| `executing <n>` | executing rule | 2 | Rule n was the one running at the last think |
| `beacon_seen` | beacon in sight | 2 | Line of sight from Robbie to the beacon (plate bought in the Lab) |
| `stuck` | stuck | 1 | Robbie moved less than 6 px in the last 2 s (plate bought in the Lab) |
| `hit` | hit | 1 | Robbie was hurt in the last 2 s (plate bought in the Lab) |
| `heard` | heard | 2 | Needs the hydrophone: an eel or a shellback within 8 tiles, through rock |

## Sensing: Robbie only knows what it senses

- **Lamp:** a 70° cone, 6 tiles (96 px) long, blocked by walls.
- **Pressure sense:** anything within 20 px, light or not.
- **Glow:** jellyfish glow (3 tiles); a lurker's eyes glow while it winds up to strike.
- **Camouflage:** a resting lurker cannot be seen, even in the lamp.
- **The valve** is sensed only ahead of Robbie, and not while Robbie is inside it.
- **Tiles** become part of the station map when the lamp or the pressure sense touches them.

## Robbie, prototype loadout

| Stat | Value |
| --- | --- |
| Speed | 1 px per tick (30 px/s); 0.75 when backing away |
| Hull | 3 hits |
| Energy | Per room (4,200–6,000). 1 per tick alive, +1 per tick moving, 200 per laser shot |
| Crash | Hitting rock nearly head-on (within ~30°) costs 1 hit; then 1 s of grace |

## Creatures

| Creature | Behaviour | Damage |
| --- | --- | --- |
| Jellyfish | Drifts at 0.25 px/tick. When Robbie's lamp lights it, darts at the light at 1.1 px/tick, faster than Robbie | 1 per sting, 1 s apart |
| Lurker | Hidden in a wall niche. When Robbie comes within 34 px, its eyes glow for 0.5–0.67 s, then it strikes everything within 38 px. Rests 4 s | 3 (lethal) |
| Valve | Opens 2 s, trembles 1.5 s, stays shut 5 s; the phase varies per dive. Shut, it stings what touches it; closing on Robbie crushes it | 1 per sting; crush is lethal |
| Shellback | A slow armoured grazer on a three-tile leash; solid (Robbie bumps off it). Shot, the laser glances off and it charges at 1.2 px/tick for 8 s. Shown yellow on the scope (red while angry); every other creature is red | 2 per hit while angry |

## Parts (the Lab, 0.10.0)

A hull's parts are a `Kit` (game/sim/kit.gd) passed to the dive; no parts is the stock hull above. Each dive's parts
are saved with it, so replays match. One part per socket: lamp (spotlight 10 tiles and about 17 degrees; floodlight
3.5 tiles and about 120 degrees; red lamp, which jellyfish ignore), drive (twin screws 1.5 px/tick, double drain,
eels hear at 6 tiles; silent fins 0.7 px/tick, eels never hear), belly (battery bank +40%; reserve cell, 15% back
once), hull (plating 5 knocks and 10% slower; insulated, valve stings do nothing), tool (the laser; or the flare
launcher, which replaces it), hatch (the hydrophone, for IF HEARD).
