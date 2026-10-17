# The Jellyfish Rooms: prototype room designs

Three one-screen rooms (40 x 22 tiles, 1 tile = 1 m = 16 px) that share one set of orders.
Each has an intended solution, naive programs that must fail, and the idea it teaches.
Programs live in `game/content/programs/<room>/`; `tests/test_reference_programs.gd` checks every claim below.

Map key: `#` rock, `.` water, `S` start, `E` exit and beacon, `J` jellyfish, `L` lurker niche, `G` valve, `p` glowing plant.

## 1. The Dark

CPU budget 6 · energy 4200

```text
########################################
#..................................#####
#.S................................#####
#..................................#####
##############..########..######...#####
################################...#####
################################...#####
#####..............................#####
#####..............................#####
#####..............................#####
#####...################################
#####...################################
#####...################################
#####...............................EEE#
#####...............................EEE#
#####...............................EEE#
##########...###########################
##.............................#########
##.........................p...#########
##..................p..........#########
##.............................#########
########################################
```

**Teaches:** the beacon is not a path; following a wall is. Left and right are not the same.

| Program | CPU | Survey fleet (20 seeds) | What happens |
| --- | --- | --- | --- |
| `follow_wall left` (intended) | 3 | 20/20 | Out in 55 s with energy to spare |
| `follow_wall right` | 3 | 0/20 | Takes the big side cave, runs out of energy at 70 s |
| `move_towards beacon` | 2 | 0/20 | Crashes into the first wall three times |
| `move 90` | 1 | 0/20 | Same, slightly later |

![The Dark intended](../devlog/img/s01/dark-intended.png)

## 2. The Jellyfish

CPU budget 8 · energy 6000 · swarm: 8 jellyfish resting by the rock plus 16 scattered fresh on every dive

```text
########################################
#................J.....................#
#.....J.....###............J...........#
#...........###...##...........###.....#
#....p......###...##...........###.J...#
#..............................###.....#
#......................................#
#......................................#
#......................................#
#....................................EE#
#.S..................................EE#
#....................................EE#
#....................................EE#
#......................................#
#......................................#
#......###..........................J..#
#......###.............................#
#...J..###..............####...........#
#.......................####.......p...#
#..............J........####...........#
#...........................J..........#
########################################
```

The `J` marks are the jellyfish that rest along the rock. Sixteen more are scattered over open water on
every dive (`jelly_scatter`: at least 6 tiles from the start, 3 from the exit, 2 from each other), so no
fixed route works twice. A lit lamp draws jellyfish from its beam and from a 3-tile glow all around Robbie
(`LAMP_HALO`), so sneaking past with the lamp on and the swarm behind you doesn't work either.

**Teaches:** light attracts. Darkness hides Robbie, and the jellyfish's own glow still warns it. Or: the loud way, with the laser.
One new idea after The Dark: a setting (the lamp). The hunt (block 6) showed that `lamp off` alone is enough; keeping
distance as well is the careful version, and costs more CPU. We tried making dark jellyfish notice Robbie up close
(block 6): it punished the careful program more than the simple one, because lingering near a jellyfish is worse than
swimming past it, so it was dropped.

| Program | CPU | Survey fleet (20 seeds) | What happens |
| --- | --- | --- | --- |
| `lamp off` / `move_towards beacon` (intended, simplest) | 3 | 20/20 | Swims straight through the dark; the scattered swarm rarely drifts into its path |
| `lamp off` / `move 90` | 2 | 20/20 | The same, knowing the exit is due east: the cheapest known solution |
| `lamp off` / `keep_distance 2` / `move_towards beacon` (intended, careful) | 6 | 18/20 | Slips through the swarm in the dark. Backing away is blind: twice in 20 a drifting jellyfish herds Robbie into rock |
| `shoot if hostile_near 4` / `move_towards beacon` (intended, loud) | 8 | 20/20 | Faster (about 20 s) but spends energy on every shot |
| `move_towards beacon` | 2 | 0/20 | Lit jellyfish dart at the lamp faster than Robbie swims |
| `keep_distance 2` / `move_towards beacon` | 5 | 0/20 | Backing away with the lamp on: the swarm follows |
| `follow_wall left` | 3 | 0/20 | Found by the exploit hunt (block 1): skirting the swarm along the rock. Jellyfish rest along the walls |
| `move 45 if energy_below 75` / `move 135` | 4 | 0/20 | Found by the exploit hunt (block 3): a fixed route that never looks. It passed 20/20 while the swarm sat still; now the swarm moves every dive |

![Three dives of the intended program, and the fixed route](../devlog/img/s05/jellyfish-swarms.png)

## 3. The Valve

CPU budget 10 · energy 6000 · valve cycle 60/45/150 ticks (open/closing/shut)

```text
########################################
########################################
########################################
########################################
########################################
########################################
#......##########################......#
#......##########################......#
#......###################L######......#
#.................G.................EEE#
#..S..............G.................EEE#
#.................G.................EEE#
#......##########################......#
#...p..##########################......#
#......##########################......#
########################################
########################################
########################################
########################################
########################################
########################################
########################################
```

**Teaches:** wait for the world; flinch from what wakes up. Sensing matters: Robbie only knows the valve is shut when it can see it ahead.

| Program | CPU | Survey fleet (20 seeds) | What happens |
| --- | --- | --- | --- |
| `keep_distance 4` / `stop if valve_shut` / `move_towards beacon` (intended) | 9 | 20/20 | Waits for the valve, backs off the lurker's glowing eyes, slips past while it rests |
| `keep_distance 4` / `move_towards beacon` | 5 | 5/20 | Ignores the valve: stung to death by it three times in four |
| `move_towards beacon if valve_open` / `stop if wall_ahead` / `move_towards beacon` | 10 | 0/20 | Waits perfectly, then swims straight into the lurker |
| `move_towards beacon` | 2 | 0/20 | Valve or lurker, whichever comes first |
| `shoot` / `move_towards open_water` | 6 | 0/20 | Found by the exploit hunt (block 6): shoot whatever wakes, otherwise explore (the shut valve looks like rock to the open-water sense, so it waits by accident). It passed the survey fleet at 6 CPU, cheaper than the intended 9, so **lurkers are now laser-proof**: the beam glances off, Robbie pays for the shot and stands still while the lurker strikes. The 10-CPU variant accepted in block 4 fails too |
| `keep_distance 4` / `move_towards open_water` | 6 | 9/20 (7/10 on the survey seeds) | Flinch and explore: close to certifying, wanders and runs out of energy too often |

![The Valve intended](../devlog/img/s01/valve-intended.png)
