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

CPU budget 8 · energy 6000

```text
########################################
#......................................#
#...........###........................#
#...........###...##...........###.....#
#....p......###...##...........###.....#
#..............................###.....#
#....................J.................#
#...........................J..........#
#...............J......................#
#.........................J..........EE#
#.S.......J..........J...........J...EE#
#............................J.......EE#
#............J.........J.............EE#
#................J.....................#
#..............................J.......#
#......###.............................#
#......###.............................#
#......###..............####...........#
#.......................####.......p...#
#.......................####...........#
#......................................#
########################################
```

**Teaches:** light attracts. Darkness hides Robbie, and the jellyfish's own glow still warns it. Or: the loud way, with the laser.

| Program | CPU | Survey fleet (20 seeds) | What happens |
| --- | --- | --- | --- |
| `lamp off` / `keep_distance 2` / `move_towards beacon` (intended) | 6 | 20/20 | Slips through the swarm in the dark, about 35–40 s |
| `shoot if hostile_near 4` / `move_towards beacon` (intended, loud) | 8 | 20/20 | Faster (about 20 s) but spends energy on every shot |
| `move_towards beacon` | 2 | 1/20 | Lit jellyfish dart at the lamp faster than Robbie swims |
| `keep_distance 2` / `move_towards beacon` | 5 | 0/20 | Backing away with the lamp on: the swarm follows |
| `follow_wall left` | 3 | 9/20 | Found by the exploit hunt: skirting the swarm along the rock. Jellyfish now rest along the walls too, so it fails the survey fleet |

![The Jellyfish intended](../devlog/img/s01/jellyfish-intended_dark.png)

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

![The Valve intended](../devlog/img/s01/valve-intended.png)
