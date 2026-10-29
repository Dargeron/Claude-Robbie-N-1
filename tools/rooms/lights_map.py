#!/usr/bin/env python3
"""Generate game/content/rooms/lights.room: The Lights (sector 5).

A dark cave with pillars, a long wall with a gap at the bottom, and past it a floating island of rock. The exit is
inside the island, at the end of an S-shaped passage: up one corridor, down the next, into a hall. Cold lights mark
the way. Why the shape:

- The island floats, so a wall-follower tracing the outer wall never goes in, and no straight line from outside
  reaches the exit: "beacon when the battery gets low" after a wall tour or open water hits rock.
- The S needs the wall on the right going up and on the left going down, so "beacon unless a wall is ahead, else
  follow the wall" (either hand) can't thread it.
- The exit floats in the hall, off every compass line from the last light, so "lights, then a fixed heading" misses.

Checks every light can see the next and none is closer to an earlier one than the next (so Robbie never turns
back). Usage: tools/rooms/lights_map.py [--write]
"""
import math
import sys
from pathlib import Path

W, H = 40, 22
grid = [["." for _ in range(W)] for _ in range(H)]


def wall(x0, y0, x1, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            grid[y][x] = "#"


def clear(x0, y0, x1, y1):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            grid[y][x] = "."


wall(0, 0, W - 1, 0)
wall(0, H - 1, W - 1, H - 1)
wall(0, 0, 0, H - 1)
wall(W - 1, 0, W - 1, H - 1)
# The cave's pillars.
for (x, y) in [(4, 4), (9, 3), (10, 9), (5, 10), (2, 15), (9, 14)]:
    wall(x, y, x + 1, y + 1)
# The long wall, open at the bottom.
wall(14, 1, 14, 16)
# The island: outer box, its door at the bottom left, then the S inside.
wall(19, 4, 35, 17)
clear(20, 5, 34, 16)
clear(20, 17, 22, 17)          # the door, into corridor A
wall(23, 8, 23, 16)            # W1: A goes up and over it (gap rows 5-7)
wall(27, 5, 27, 13)            # W2: B comes down and under it (gap rows 14-16)
EXIT = [(32, 8), (33, 8), (32, 9), (33, 9)]
# Lost beacons (secondary goals, docs/design/lab-parts-and-pay.md): the far wall of the cave by
# the long wall, and its bottom corner. Neither is on the way the lights lead.
BONUS = [(12, 1), (1, 20)]
for (x, y) in EXIT:
    grid[y][x] = "E"
START = (2, 2)
grid[START[1]][START[0]] = "S"

# The way, as waypoints; lights every ~2 tiles along it.
WAY = [(2, 2), (7, 2), (7, 6), (3, 7), (3, 12), (7, 12), (7, 17), (12, 19), (17, 19), (21, 19), (21, 15),
       (21, 6), (25, 6), (25, 15), (30, 15)]
SPACING = 2.2
lights = []
for (ax, ay), (bx, by) in zip(WAY, WAY[1:]):
    n = max(1, round(math.hypot(bx - ax, by - ay) / SPACING))
    for k in range(1, n + 1):
        p = (round(ax + (bx - ax) * k / n), round(ay + (by - ay) * k / n))
        if not lights or p != lights[-1]:
            lights.append(p)
lights = [p for p in lights if p != START]


def los(a, b):
    ax, ay = a[0] + 0.5, a[1] + 0.5
    bx, by = b[0] + 0.5, b[1] + 0.5
    steps = int(math.hypot(bx - ax, by - ay) * 8) + 1
    for i in range(steps + 1):
        x = ax + (bx - ax) * i / steps
        y = ay + (by - ay) * i / steps
        if grid[int(y)][int(x)] == "#":
            return False
    return True


ok = True
for i, p in enumerate(lights):
    if grid[p[1]][p[0]] != ".":
        print("light on rock or exit:", p)
        ok = False
    prev = START if i == 0 else lights[i - 1]
    if not los(prev, p) or math.dist(prev, p) > 3.3:
        print("can't see the next light from", prev, "to", p)
        ok = False
    # From where Robbie puts out light i-1, the nearest light he can sense must be light i.
    for j in range(i + 1, len(lights)):
        q = lights[j]
        if math.dist(prev, q) <= math.dist(prev, p) and math.dist(prev, q) <= 3.5 and los(prev, q):
            print("skips ahead from", prev, "to", q)
            ok = False
for (x, y) in lights:
    grid[y][x] = "o"
for (x, y) in BONUS:
    assert grid[y][x] == ".", (x, y)
    grid[y][x] = "*"

# The last light must not have the exit on a compass line.
lx, ly = lights[-1][0] + 0.5, lights[-1][1] + 0.5
ex, ey = sum(x for x, _ in EXIT) / 4 + 0.5, sum(y for _, y in EXIT) / 4 + 0.5
ang = math.degrees(math.atan2(ey - ly, ex - lx)) % 45
off = min(ang, 45 - ang)
miss = math.dist((lx, ly), (ex, ey)) * math.sin(math.radians(off))
print(f"{len(lights)} lights; exit {off:.1f} deg off the nearest compass line from the last light, {miss:.1f} tiles")
if miss < 1.8:
    ok = False

text = "\n".join("".join(r) for r in grid)
print(text)
if not ok:
    sys.exit("lights_map: checks failed")
if "--write" in sys.argv:
    room = Path(__file__).resolve().parents[2] / "game/content/rooms/lights.room"
    head = room.read_text().split("---\n")[0]
    room.write_text(head + "---\n" + text + "\n")
    print("wrote", room)
