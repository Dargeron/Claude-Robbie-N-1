"""Round 2 mood concepts: five different worlds for the whole game, in a steampunk space colonisation (Valente's
Radiance, Outer Wilds), darker. Each world has its own place, shapes, rendering and palette; Robbie is Bathy in all.

  1 The Drowned Colony    flooded iron streets of a dead steam colony; noir comic
  2 The Pleasure Gardens  a sunken Art Deco promenade; tinted silent film
  3 Dead Air              the world only as sonar returns on a valve-radio screen
  4 The Verdigris Reef    a living reef at the edge of an abyss, with the colonists' folk-tech; painterly
  5 The Red Spot Mine     a jagged ice canyon gouged by the Company's drill; three-ink woodcut

Run: blender -b --factory-startup -P tools/art/mood_scene.py -- <world 1-5> <out.png> [samples]
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402
import robbie_designs  # noqa: E402
from kit import rgb, scale_rgb  # noqa: E402

WORLDS = {1: "The Drowned Colony", 2: "The Pleasure Gardens", 3: "Dead Air", 4: "The Verdigris Reef",
          5: "The Red Spot Mine"}
FONT = os.path.expanduser("~/.cache/robbie/fonts/BigShoulders.ttf")
TAU = 2 * math.pi


def lin(h, k=1.0):
    return scale_rgb(rgb(h), k)


class World:
    """Shared scaffolding: the light model around Robbie's lamp, materials, Robbie (Bathy) and his tether."""

    def __init__(self, robbie, angle, **cfg):
        self.rx, self.ry = robbie
        self.angle = angle
        base = dict(robbie=robbie, lamp_angle=angle, cone_half=24, cone_soft=5, cone_range=10.5, radial=(0.8, 2.8),
                    radial_gain=0.85, ambient=(0.02, 0.02, 0.02), lamp_color=lin("#ffbe6a", 1.3), glows=[],
                    sun=(-0.45, -0.55, 0.7), bands=(0.5, 0.86), band_soft=0.006, sky=None, rim=None)
        base.update(cfg)
        self.cfg = base
        self.light = kit.lighting_group(base)
        self.shadow = kit.shadow("shadow", "#000000", 0.55)

    def toon(self, name, base, shade=None, high=None, **kw):
        kw.setdefault("ao", 0.6)
        return kit.toon(name, self.light, base, shade, high, **kw)

    def bathy(self, scale=0.82, z=0.15, toon=None):
        before = set(bpy.data.objects)
        robbie_designs.bathy(toon or self.toon)
        new = [o for o in bpy.data.objects if o not in before and o.parent is None]
        root = kit.group_under("bathy", new, loc=(self.rx, self.ry, z))
        root.scale = (scale, scale, scale)
        root.rotation_euler = (0, 0, math.radians(self.angle))
        kit.no_lines(kit.sphere((self.rx + 0.25, self.ry - 0.6, 0.04), 0.85, self.shadow, scale=(1.2, 0.95, 0.04),
                                segs=24))
        return root

    def back(self, d=0.75, z=0.95):
        a = math.radians(self.angle)
        return (self.rx - math.cos(a) * d, self.ry - math.sin(a) * d, z)

    def tether(self, mat, wiggle=0.35, to_x=-14.0):
        """The cable from Robbie's back to the station, off the left of the frame."""
        b = self.back()
        pts = [b, (b[0] - 0.7, b[1] - 0.05, 0.55), (b[0] - 1.6, b[1] + 0.25, 0.12)]
        x = b[0] - 1.6
        while x > to_x:
            x -= 1.1
            pts.append((x, b[1] + 0.25 + wiggle * math.sin(x * 0.9), 0.06))
        return kit.tube(pts, 0.045, mat)

    def beam(self, color, strength, z=1.0):
        a0 = math.radians(self.angle)
        half, rng = math.radians(self.cfg["cone_half"]), self.cfg["cone_range"]
        apex = (self.rx + math.cos(a0) * 0.95, self.ry + math.sin(a0) * 0.95)
        bm = bmesh.new()
        verts = [bm.verts.new((apex[0], apex[1], z))]
        for k in range(25):
            a = a0 - half + 2 * half * k / 24
            verts.append(bm.verts.new((apex[0] + math.cos(a) * rng, apex[1] + math.sin(a) * rng, z - 0.1)))
        for k in range(24):
            bm.faces.new((verts[0], verts[k + 1], verts[k + 2]))
        me = bpy.data.meshes.new("beam")
        bm.to_mesh(me)
        ob = bpy.data.objects.new("beam", me)
        bpy.context.scene.collection.objects.link(ob)
        me.materials.append(kit.additive("beam", color, strength, apex=apex, length=rng,
                                         cone=(self.angle, self.cfg["cone_half"], self.cfg["cone_half"] * 0.8)))
        return kit.no_lines(ob)


def jelly(w, x, y, color, glow_k=1.0, z=1.4, size=1.0, frill=True, tentacles=6, mats=None):
    """A drifting jellyfish: bell with rings, bright core, scalloped rim, trailing tentacles."""
    c = color
    bell = mats[0] if mats else w.toon("jelly", c, high="#ffffff", glow=scale_rgb(lin(c), 0.35 * glow_k), ao=0.1,
                                        rings=(7.0, kit.mix_hex(c, "#ffffff", 0.6)))
    fr = mats[1] if mats else w.toon("frill", kit.mix_hex(c, "#ffffff", 0.35), glow=scale_rgb(lin(c), 0.5 * glow_k),
                                      ao=0.0)
    core = kit.glow("core", kit.mix_hex(c, "#ffffff", 0.5), 1.3 * glow_k)
    kit.no_lines(kit.sphere((x + 0.15, y - 0.5, 0.03), 0.6 * size, w.shadow, scale=(1.1, 0.9, 0.05), segs=24))
    kit.sphere((x, y, z), 0.6 * size, bell, scale=(1, 1, 0.45))
    kit.sphere((x - 0.04, y + 0.02, z + 0.22 * size), 0.16 * size, core, scale=(1, 1, 0.5), segs=24)
    if frill:
        for k in range(10):
            a = k * TAU / 10
            kit.sphere((x + math.cos(a) * 0.6 * size, y + math.sin(a) * 0.6 * size, z - 0.1), 0.13 * size, fr,
                       scale=(1, 1, 0.5), segs=12)
    drift = random.uniform(-0.6, 0.6) + math.pi
    for k in range(tentacles):
        a = drift + (k - (tentacles - 1) / 2) * 0.18
        pts = [(x + math.cos(a) * (0.35 + d * 0.5) * size + 0.08 * math.sin(d * 2.2 + k),
                y + math.sin(a) * (0.35 + d * 0.5) * size + 0.08 * math.cos(d * 2.0 + k), z - 0.25 - d * 0.12)
               for d in range(6)]
        kit.tube(pts, 0.035 * size, bell, taper=0.3)


def text3d(body, loc, size, mat, rot=(0, 0, 0), extrude=0.01):
    cu = bpy.data.curves.new("text", "FONT")
    cu.body = body
    cu.size = size
    cu.extrude = extrude
    cu.align_x, cu.align_y = "CENTER", "CENTER"
    if os.path.exists(FONT):
        cu.font = bpy.data.fonts.load(FONT)
    o = bpy.data.objects.new("text", cu)
    bpy.context.scene.collection.objects.link(o)
    o.location, o.rotation_euler = loc, rot
    cu.materials.append(mat)
    return o


def beam_between(a, b, size, mat):
    """A box from point a to point b (girders, rails, planks), size = (thickness, height)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    o = kit.box((a + b) / 2, (d.length, size[0], size[1]), mat)
    o.rotation_euler = d.to_track_quat("X", "Z").to_euler()
    return o


def flat(o):
    for p in o.data.polygons:
        p.use_smooth = False
    return o


def snow(color, strength, n=120, z=(2.4, 3.4), area=(13, 9)):
    m = kit.glow("snow", color, strength)
    for _ in range(n):
        kit.no_lines(kit.sphere((random.uniform(-area[0], area[0]), random.uniform(-area[1], area[1]),
                                 random.uniform(*z)), random.uniform(0.02, 0.045), m, segs=8))


# --- 1. The Drowned Colony ---------------------------------------------------------------------------------------

def drowned_colony():
    """Flooded iron streets of a dead steam colony: deck plates, riveted bulkheads, burst pipes, a fallen girder, a
    doorway where something waits, and a floor hatch out. Noir: everything outside the lamp is black."""
    jellies = [(-2.2, 1.5, "#c9507e"), (2.4, -1.1, "#d6a33c"), (7.2, 2.1, "#4fb3c6")]
    hatch = (10.0, -0.5)
    lamp_post = (-0.4, 2.7)
    glows = [(x, y, 2.2, lin(c), 0.45) for x, y, c in jellies]
    glows += [(hatch[0], hatch[1], 2.4, lin("#6dffb0"), 0.5), (lamp_post[0], lamp_post[1] - 0.6, 1.8, lin("#ffb060"),
                                                                 0.4)]
    w = World((-7.6, 0.3), 6, ambient=lin("#0a222a", 0.8), lamp_color=lin("#ffbe6a", 1.4), glows=glows,
              rim=(lin("#ff7a1a"), 0.6, 0.0, True, (0.5, 0.42)),
              sky=((0.0, -0.2, 1.0), lin("#30525c", 0.32), 0.85, 0.95, 1.75, 1.85))
    iron = w.toon("iron", "#1d2b31", "#060b0d", "#3e535b", patches=(0.55, "#4a2a18", 0.6))
    deck = w.toon("deck", "#18272c", "#060b0d", "#2f474e", patches=(0.4, "#3c2618", 0.58), ao=0.7)
    brass = w.toon("brass", "#b07a2a", "#5a3a12", "#f0c070", ao=0.3)
    pipe = w.toon("pipe", "#26343c", "#080e11", "#4c626a", patches=(1.1, "#5a2e16", 0.62))
    dark = w.toon("dark", "#04080a", "#020405", "#0a1216")
    paint = w.toon("paint", "#8a8270", "#3a362c", "#b8b098", ao=0.2, lit=0.4)
    rivet = w.toon("rivet", "#3e535b", "#101a1e", "#7a9098", ao=0.2)
    north, south = 3.6, -3.2

    # Deck plates with rivets; some missing (black holes), some lifted.
    for ix in range(-13, 13):
        for iy in range(-3, 4):
            x, y = ix + 0.5, iy + 0.5
            if random.random() < 0.06:
                continue
            tilt = (random.uniform(-0.14, 0.14), random.uniform(-0.14, 0.14), 0) if random.random() < 0.1 else (0, 0, 0)
            kit.box((x, y, -0.04), (0.95, 0.95, 0.08), deck, rot=tilt)
            if random.random() < 0.6:
                for dx, dy in ((-0.38, -0.38), (0.38, -0.38), (-0.38, 0.38), (0.38, 0.38)):
                    kit.sphere((x + dx, y + dy, 0.0), 0.035, rivet, segs=6)
    kit.box((0, 0, -0.8), (40, 30, 0.2), dark)

    # Bulkheads: the north wall has a doorway, the south wall has caved in.
    for x0, x1 in ((-14.0, 3.0), (5.0, 14.0)):
        kit.box(((x0 + x1) / 2, north + 0.5, 0.95), (x1 - x0, 1.0, 1.9), iron)
    for x0, x1 in ((-14.0, -1.2), (2.4, 14.0)):
        kit.box(((x0 + x1) / 2, south - 0.5, 0.95), (x1 - x0, 1.0, 1.9), iron)
    for x in (2.8, 5.2):
        kit.box((x, north + 2.0, 0.95), (0.4, 3.0, 1.9), iron)
    for i in range(14):  # rubble of the south wall spilling into the street
        kit.box((random.uniform(-1.4, 2.6), random.uniform(south - 1.4, south + 0.8), random.uniform(0.1, 0.6)),
                (random.uniform(0.4, 1.2), random.uniform(0.3, 0.9), random.uniform(0.15, 0.5)), iron,
                rot=(random.uniform(-0.6, 0.6), random.uniform(-0.6, 0.6), random.uniform(0, math.pi)))
    for x in [x * 2.6 - 12.4 for x in range(11)]:  # I-beam pilasters with rivets along the top of both walls
        for y, gap in ((north - 0.1, (2.6, 5.4)), (south + 0.1, (-1.6, 2.8))):
            if gap[0] < x < gap[1]:
                continue
            kit.box((x, y, 0.95), (0.42, 0.22, 1.9), iron)
            kit.box((x, y, 1.92), (0.62, 0.42, 0.08), iron)
    for x in [i * 0.4 - 13.8 for i in range(70)]:
        for y, gap in ((north + 0.05, (2.9, 5.1)), (south - 0.05, (-1.3, 2.5))):
            if not gap[0] < x < gap[1]:
                kit.sphere((x, y, 1.9), 0.045, rivet, segs=6)
    for x in (-10.2, -4.9, 7.5, 11.0):  # portholes in the north wall, one smashed
        kit.torus((x, north + 0.01, 1.15), 0.33, 0.06, brass, rot=(math.pi / 2, 0, 0))
        kit.cyl((x, north + 0.02, 1.15), 0.3, 0.03, dark if x != -4.9 else iron, rot=(math.pi / 2, 0, 0))

    # Pipes along the north wall, one burst.
    for y, z, r in ((north - 0.35, 0.3, 0.2), (north - 0.35, 0.72, 0.16), (north - 0.75, 0.22, 0.14)):
        for x0, x1 in ((-14.0, 5.8), (7.0, 14.0)) if z == 0.72 else ((-14.0, 14.0),):
            kit.cyl(((x0 + x1) / 2, y, z), r, x1 - x0, pipe, rot=(0, math.pi / 2, 0))
        for x in [i * 2.0 - 13 for i in range(14)]:
            kit.cyl((x, y, z), r + 0.06, 0.12, pipe, rot=(0, math.pi / 2, 0))
    kit.cyl((6.3, north - 0.55, 0.5), 0.16, 1.0, pipe, rot=(0.9, 0.5, 0))
    vx, vy = -3.6, north - 0.75
    kit.cyl((vx, vy, 0.55), 0.09, 0.5, pipe)
    kit.torus((vx, vy, 0.85), 0.45, 0.06, brass)
    for k in range(3):
        kit.cyl((vx, vy, 0.85), 0.035, 0.9, brass, rot=(math.pi / 2, 0, k * math.pi / 3))

    # A colony street lamp, bent over, still flickering.
    lx, ly = lamp_post
    kit.cyl((lx, ly, 0.75), 0.07, 1.5, iron)
    beam_between((lx, ly, 1.5), (lx + 0.3, ly - 0.7, 1.85), (0.12, 0.12), iron)
    kit.cone((lx + 0.32, ly - 0.75, 1.72), 0.3, 0.08, 0.3, iron)
    kit.sphere((lx + 0.32, ly - 0.75, 1.6), 0.12, kit.glow("bulb", "#ffb060", 1.6), segs=16)

    # A fallen girder across the street, and a great gear half-sunk in the rubble.
    a, b = Vector((4.0, -2.8, 0.25)), Vector((7.8, 1.7, 0.95))
    beam_between(a, b, (0.18, 0.5), iron)
    for t in (0.5, -0.5):
        off = Vector((0, 0, t * 0.25))
        beam_between(a + off, b + off, (0.5, 0.06), iron)
    gear = kit.cyl((0.6, south - 0.3, 0.3), 1.1, 0.25, brass, rot=(0.5, 0.25, 0))
    for k in range(16):
        t = kit.box((0, 0, 0), (0.28, 0.25, 0.22), brass)
        t.parent = gear
        t.location = (math.cos(k * TAU / 16) * 1.18, math.sin(k * TAU / 16) * 1.18, 0)
        t.rotation_euler = (0, 0, k * TAU / 16)
    kit.cyl((0, 0, 0), 0.35, 0.4, iron).parent = gear

    # The dead colony beyond the walls: tenements, chimneys and water towers to the north, ruins to the south.
    window = kit.glow("window", "#ffb060", 0.9)
    x = -14.0
    while x < 14.0:
        bw, bd, bh = random.uniform(1.4, 2.6), random.uniform(1.6, 3.2), random.uniform(2.4, 5.2)
        by = north + 1.2 + bd / 2 + random.uniform(0, 0.6)
        if not 2.4 < x + bw / 2 < 5.8:
            kit.box((x + bw / 2, by, bh / 2), (bw - 0.15, bd, bh), iron)
            if random.random() < 0.5:
                kit.cyl((x + bw * 0.3, by, bh + 0.4), 0.14, 0.8, iron, verts=10)
            if random.random() < 0.3:
                tx = x + bw * 0.65
                kit.cyl((tx, by, bh + 0.75), 0.45, 0.7, iron)
                kit.cone((tx, by, bh + 1.25), 0.5, 0.05, 0.3, iron)
                for lx_, ly_ in ((-0.3, -0.3), (0.3, -0.3), (0.0, 0.35)):
                    kit.cyl((tx + lx_, by + ly_, bh + 0.2), 0.04, 0.4, iron, verts=6)
            for wy in range(2):
                for wx in range(int(bw / 0.6)):
                    if random.random() < 0.07:
                        kit.box((x + 0.35 + wx * 0.6, by - bd / 2 - 0.01, 1.0 + wy * 1.2 + 0.9), (0.22, 0.02, 0.32),
                                window)
        x += bw
    for _ in range(18):
        kit.box((random.uniform(-13, 13), random.uniform(south - 1.6, south - 6.0), random.uniform(0.2, 0.7)),
                (random.uniform(0.8, 2.2), random.uniform(0.6, 1.6), random.uniform(0.4, 1.4)), iron,
                rot=(random.uniform(-0.3, 0.3), random.uniform(-0.3, 0.3), random.uniform(0, 0.5)))

    # Stencilled on the deck.
    text3d("JOVIAN COLONIAL Co.  ·  DECK 7", (-4.2, -2.35, 0.005), 0.5, paint)

    # The floor hatch out, with its green lamp.
    hx, hy = hatch
    kit.cyl((hx, hy, 0.03), 0.95, 0.1, iron)
    kit.torus((hx, hy, 0.09), 0.92, 0.07, brass)
    kit.torus((hx, hy, 0.25), 0.45, 0.06, brass)
    for k in range(3):
        kit.cyl((hx, hy, 0.25), 0.035, 0.9, brass, rot=(math.pi / 2, 0, k * math.pi / 3))
    kit.cyl((hx, hy, 0.17), 0.08, 0.16, brass)
    green = kit.glow("green", "#6dffb0", 1.8)
    kit.torus((hx, hy, 0.06), 1.25, 0.03, green)
    kit.cyl((hx + 1.3, hy + 0.9, 0.6), 0.05, 1.2, iron)
    kit.sphere((hx + 1.3, hy + 0.9, 1.25), 0.13, green, segs=16)

    # Something waits in the doorway.
    kit.blobs("lurker", [(4.0, north + 1.1, 0.4, 0.9, (1.0, 1.3, 0.7))], w.toon("lurker", "#040a0b"), resolution=0.1)
    eye = kit.glow("eye", "#ff4a1a", 1.4)
    for dx in (-0.22, 0.22):
        kit.sphere((4.0 + dx, north + 0.55, 0.8), 0.09, eye, scale=(1.3, 0.5, 0.4), segs=12)

    for x, y, c in jellies:
        jelly(w, x, y, c, 0.8)
    w.bathy()
    w.tether(w.toon("cable", "#1a1a1a", "#050505", "#3a3a3a"))
    w.beam("#ffbe6a", 0.12)
    snow("#9fd6e0", 0.4, 90)
    kit.ortho_camera(target=(0.0, 0.5, 0.4), tilt_deg=28.0, scale=24.0)
    kit.outlines(3.6, "#000000", crease=True)
    return "#010304"


# --- 2. The Pleasure Gardens -------------------------------------------------------------------------------------

def pleasure_gardens():
    """A sunken Art Deco promenade from the colony's glamorous years: stepped columns, a sunburst mosaic, terraces
    with balustrades, a fallen chandelier and a stepped archway out. Shot as a tinted silent film."""
    jellies = [(-3.2, -1.6), (1.6, 1.4), (6.4, -1.0)]
    arch = (8.6, 4.4)
    globes = [(x, s * 3.6) for x in (-6.8, -3.4, 0.0, 3.4, 6.8) for s in (-1, 1)]
    lit_globes = [(-3.4, 3.6), (3.4, -3.6), (6.8, 3.6)]
    glows = [(x, y, 2.0, lin("#e8e4f0"), 0.4) for x, y in jellies]
    glows += [(x, y, 2.2, lin("#fff0d0"), 0.45) for x, y in lit_globes] + [(arch[0], arch[1], 2.6, lin("#fff4e0"), 0.6)]
    w = World((-8.4, 0.0), 0, ambient=lin("#3c3c46", 0.6), lamp_color=lin("#fff2d8", 1.35), glows=glows,
              bands=(0.42, 0.8), band_soft=0.03, radial=(1.0, 3.4), cone_half=26, cone_range=11.0)
    cx, cy = 2.0, 0.0

    def mosaic(n, P):
        d = n.vec("SUBTRACT", P, (cx, cy, 0.0))
        sep = n.add("ShaderNodeSeparateXYZ")
        n.feed(sep.inputs[0], d)
        ang = n.math("ARCTAN2", sep.outputs["Y"], sep.outputs["X"])
        rays = n.math("GREATER_THAN", n.math("FRACT", n.math("MULTIPLY", ang, 24 / TAU)), 0.5)
        dist = n.vec("LENGTH", n.flat_xy(d))
        inside = n.remap(dist, 5.4, 5.45, 1.0, 0.0, smooth=False)
        ring = n.math("MAXIMUM", n.remap(n.math("ABSOLUTE", n.math("SUBTRACT", dist, 2.4)), 0.12, 0.07, 0.0, 1.0),
                      n.remap(n.math("ABSOLUTE", n.math("SUBTRACT", dist, 5.55)), 0.14, 0.09, 0.0, 1.0))
        hub = n.remap(dist, 0.9, 0.85, 0.0, 1.0)
        # Outside the sunburst: chevron tiles along the promenade.
        chev = n.math("GREATER_THAN", n.math("FRACT", n.math("ADD", n.math("MULTIPLY", sep.outputs["X"], 0.9),
                                                                   n.math("MULTIPLY", n.math("ABSOLUTE",
                                                                                             sep.outputs["Y"]), 0.9))),
                      0.5)
        dark_c, light_c, gold = rgb("#2a2a30"), rgb("#b8b2a4"), rgb("#d8b860")
        tiles = n.lerp(dark_c, rgb("#6a6660"), chev)
        sun = n.lerp(dark_c, light_c, rays)
        col = n.lerp(tiles, sun, inside)
        return n.lerp(n.lerp(col, gold, ring), gold, hub)

    floor = w.toon("mosaic", "#888888", pattern=mosaic, ao=0.7)
    kit.box((0, 0, -0.05), (40, 9.0, 0.1), floor)
    marble = w.toon("marble", "#d8d2c4", "#5a5650", "#ffffff", patches=(1.8, "#8a8478", 0.66), ao=0.6)
    stone = w.toon("stone", "#8a867c", "#2a2826", "#c0bcb0", ao=0.7)
    gold = w.toon("gold", "#d4b060", "#6a5020", "#fff0b0", ao=0.3)
    dark = w.toon("dark", "#101014", "#050507", "#202028")
    glass = w.toon("crystal", "#e8f0ff", "#8090a0", "#ffffff", ao=0.0)
    globe_on = kit.glow("globe_on", "#fff0d0", 2.0)

    # Terraces stepping up behind the columns, with balustrades.
    for s in (-1, 1):
        for i, (h, d) in enumerate(((0.35, 4.9), (0.7, 6.1), (1.05, 7.3))):
            kit.box((0, s * (d + 0.6), h / 2), (40, 1.2, h), stone)
        for x in [i * 0.42 - 13 for i in range(63)]:
            kit.cyl((x, s * 4.55, 0.55), 0.07, 0.4, stone, verts=12)
        kit.box((0, s * 4.55, 0.78), (40, 0.24, 0.08), marble)

    # Stepped columns with fluting and lamp globes; fan corals grow on some.
    for x, y in globes:
        kit.box((x, y, 0.15), (1.1, 1.1, 0.3), marble)
        kit.box((x, y, 1.4), (0.62, 0.62, 2.2), marble)
        for k in range(4):
            a = k * math.pi / 2
            for f in (-0.18, 0.0, 0.18):
                kit.box((x + math.cos(a) * 0.32 - math.sin(a) * f, y + math.sin(a) * 0.32 + math.cos(a) * f, 1.4),
                        (0.06, 0.06, 2.0), stone, rot=(0, 0, a))
        kit.box((x, y, 2.56), (0.95, 0.95, 0.14), marble)
        kit.box((x, y, 2.7), (0.78, 0.78, 0.14), gold)
        on = (x, y) in lit_globes
        kit.sphere((x, y, 3.0), 0.26, globe_on if on else glass, segs=24)
        if random.random() < 0.5:
            fan(x + 0.35, y - 0.4 * (1 if y > 0 else -1), 0.9, w.toon("fan", "#6a5a5a", "#201818", "#a08a8a"))

    # The fallen chandelier: gilt rings and scattered crystals.
    chx, chy = -2.4, -1.2
    for r, z, t in ((1.3, 0.1, 0.25), (0.85, 0.25, 0.2), (0.4, 0.4, 0.15)):
        kit.torus((chx, chy, z), r, 0.06, gold, rot=(t, 0.1, 0))
    for _ in range(26):
        a, r = random.uniform(0, TAU), random.uniform(0.5, 2.4)
        kit.cone((chx + math.cos(a) * r, chy + math.sin(a) * r, 0.08), 0.06, 0.0, 0.22, glass,
                 rot=(random.uniform(1.2, 1.9), 0, random.uniform(0, TAU)), verts=6)

    # The stepped archway out, with a sunburst crown.
    ax, ay = arch
    for i, (wid, h) in enumerate(((3.6, 3.6), (2.8, 3.2), (2.0, 2.8))):
        y = ay - i * 0.25
        for s in (-1, 1):
            kit.box((ax + s * wid / 2, y, h / 2), (0.45, 0.5, h), marble if i != 1 else gold)
        kit.box((ax, y, h + 0.15), (wid + 0.45, 0.5, 0.3), marble if i != 1 else gold)
    for k in range(11):
        a = math.pi * (k + 0.5) / 11
        beam_between((ax + math.cos(a) * 0.7, ay - 0.6, 3.9 + math.sin(a) * 0.7),
                     (ax + math.cos(a) * 2.2, ay - 0.6, 3.9 + math.sin(a) * 2.2), (0.09, 0.09), gold)
    kit.box((ax, ay + 0.3, 1.35), (1.6, 0.05, 2.7), kit.glow("doorway", "#fff4e0", 1.4))
    kit.no_lines(kit.box((ax, ay - 1.4, 0.02), (1.8, 2.6, 0.03), kit.additive("spill", "#fff4e0", 0.35, apex=(ax, ay),
                                                                            length=3.0)))

    # A lurker in the dark under the terrace, moon jellies drifting.
    kit.blobs("lurker", [(4.6, -3.0, 0.3, 0.8, (1.4, 1.0, 0.6))], w.toon("lurker", "#08080a"), resolution=0.1)
    eye = kit.glow("eye", "#ffffff", 1.2)
    for dx in (-0.2, 0.2):
        kit.sphere((4.8 + dx, -2.55, 0.65), 0.08, eye, scale=(1.3, 0.5, 0.4), segs=12)
    for x, y in jellies:
        jelly(w, x, y, "#e8e4f0", 1.0)

    w.bathy()
    w.tether(w.toon("cable", "#202020", "#080808", "#505050"))
    w.beam("#fff2d8", 0.16)
    snow("#ffffff", 0.5, 80)
    kit.ortho_camera(target=(0.0, 0.0, 0.8), tilt_deg=36.0, scale=24.0)
    kit.outlines(2.2, "#050505", crease=True)
    return "#060608"


def fan(x, y, r, mat):
    """A fan coral: a half-disc of ribs, standing up."""
    bm = bmesh.new()
    c = bm.verts.new((0, 0, 0))
    rim = [bm.verts.new((math.cos(a) * r, 0, math.sin(a) * r)) for a in [math.pi * k / 10 for k in range(11)]]
    for k in range(10):
        bm.faces.new((c, rim[k], rim[k + 1]))
    me = bpy.data.meshes.new("fan")
    bm.to_mesh(me)
    o = bpy.data.objects.new("fan", me)
    bpy.context.scene.collection.objects.link(o)
    o.location = (x, y, 0.3)
    o.rotation_euler = (0, 0, random.uniform(-0.5, 0.5))
    me.materials.append(mat)
    sol = o.modifiers.new("t", "SOLIDIFY")
    sol.thickness = 0.04
    return o


# --- 3. Dead Air -------------------------------------------------------------------------------------------------

def cave_points(side, yc, hw, z=(0.2, 0.7)):
    pts = []
    x = -15.0
    while x < 15.0:
        edge = yc(x) + side * (hw(x) + random.uniform(0.0, 0.5))
        for k in range(5):
            y = edge + side * (k * 1.7 + random.uniform(0.0, 0.6) + (0.9 if k else 0.4))
            r = random.uniform(1.0, 1.6) if k == 0 else random.uniform(1.7, 2.6)
            pts.append((x + random.uniform(-0.3, 0.3), y, random.uniform(*z), r, (1.0, 1.0, 0.8)))
        x += random.uniform(0.75, 1.15)
    return pts


def sonar_material(name, robbie, sweep_deg, line_color, fill="#000000", kind="contour", reach=12.0, k=1.0):
    """What the sonar returns: contour lines on solid things (kind='contour'), or range rings, bearings and a dot
    grid on the floor (kind='floor'). Brightest just behind the sweeping scan line, fading out of range."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    t = m.node_tree
    t.nodes.clear()
    n = kit.Nodes(t)
    geo = n.add("ShaderNodeNewGeometry")
    P = geo.outputs["Position"]
    d = n.flat_xy(n.vec("SUBTRACT", P, (robbie[0], robbie[1], 0.0)))
    sep = n.add("ShaderNodeSeparateXYZ")
    n.feed(sep.inputs[0], d)
    dist = n.vec("LENGTH", d)
    ang = n.math("ARCTAN2", sep.outputs["Y"], sep.outputs["X"])
    behind = n.math("FRACT", n.math("MULTIPLY", n.math("SUBTRACT", math.radians(sweep_deg), ang), 1 / TAU))
    sweep = n.math("ADD", 0.3, n.remap(behind, 0.0, 0.22, 0.7, 0.0))
    inrange = n.remap(dist, reach * 0.75, reach, 1.0, 0.0)
    if kind == "contour":
        zs = n.add("ShaderNodeSeparateXYZ")
        n.feed(zs.inputs[0], P)
        c = n.math("FRACT", n.math("MULTIPLY", zs.outputs["Z"], 4.0))
        dd = n.math("MINIMUM", c, n.math("SUBTRACT", 1.0, c))
        line = n.remap(dd, 0.09, 0.04)
    else:
        rings = n.math("FRACT", n.math("MULTIPLY", dist, 0.5))
        r = n.remap(n.math("MINIMUM", rings, n.math("SUBTRACT", 1.0, rings)), 0.018, 0.008)
        b = n.math("FRACT", n.math("MULTIPLY", ang, 12 / TAU))
        bear = n.remap(n.math("MULTIPLY", n.math("MINIMUM", b, n.math("SUBTRACT", 1.0, b)),
                              n.math("MULTIPLY", dist, TAU / 12)), 0.03, 0.012)
        gx = n.math("FRACT", sep.outputs["X"])
        gy = n.math("FRACT", sep.outputs["Y"])
        dots = n.math("MULTIPLY", n.remap(n.math("MINIMUM", gx, n.math("SUBTRACT", 1.0, gx)), 0.05, 0.02),
                      n.remap(n.math("MINIMUM", gy, n.math("SUBTRACT", 1.0, gy)), 0.05, 0.02))
        line = n.math("MAXIMUM", n.math("MAXIMUM", r, n.math("MULTIPLY", bear, 0.6)), n.math("MULTIPLY", dots, 0.5))
    strength = n.math("MULTIPLY", n.math("MULTIPLY", line, n.math("MULTIPLY", sweep, inrange)), k)
    em = n.add("ShaderNodeEmission")
    n.feed(em.inputs["Color"], n.lerp(rgb(fill), rgb(line_color), n.math("MINIMUM", strength, 1.0)))
    n.feed(em.inputs["Strength"], n.math("ADD", 1.0, strength))
    n.feed(n.add("ShaderNodeOutputMaterial").inputs["Surface"], em.outputs[0])
    return m


def dead_air():
    """No picture at all: only what Robbie's sonar returns, contour lines on the rock, echoes, contacts."""
    def yc(x):
        return 0.9 * math.sin(x * 0.28 + 0.4)

    def hw(x):
        return 3.0 + 0.8 * math.sin(x * 0.19 + 1.0)

    robbie = (-6.6, yc(-6.6))
    sweep = 18.0
    green = "#5aff8a"
    w = World(robbie, 8)
    rock = sonar_material("rock", robbie, sweep, green, "#010402")
    floor = sonar_material("floor", robbie, sweep, green, "#000000", kind="floor", k=0.8)
    kit.box((0, 0, -0.05), (60, 40, 0.1), floor)
    kit.blobs("wall_n", cave_points(+1, yc, hw), rock, resolution=0.14)
    kit.blobs("wall_s", cave_points(-1, yc, hw), rock, resolution=0.14)
    for x in (-3.2, 3.4, 8.2):
        kit.blobs("boulder", [(x, yc(x) + random.uniform(-1.6, 1.6), 0.3, 0.8, (1.0, 0.8, 0.7))], rock, resolution=0.1)

    # Echo returns: specks along the rock face where the pings come back.
    for strength, count in ((2.5, 260), (1.2, 380)):
        m = kit.glow("echo", green, strength)
        for _ in range(count):
            x = random.uniform(-12.5, 12.5)
            if (x - robbie[0]) ** 2 > 12 ** 2:
                continue
            s = random.choice((-1, 1))
            y = yc(x) + s * (hw(x) + random.uniform(-0.1, 0.6))
            kit.no_lines(kit.sphere((x, y, random.uniform(0.2, 0.9)), random.uniform(0.02, 0.05), m, segs=6))

    # Contacts: jellyfish as bright blips with echo rings, the lurker as a faint unknown echo, the beacon pulsing.
    blip = kit.glow("blip", "#d8ffe0", 3.0)
    ring = kit.additive("ring", green, 1.2)
    for x, y in ((-1.4, yc(-1.4) + 0.9), (3.6, yc(3.6) - 1.2), (7.6, yc(7.6) + 1.3)):
        kit.sphere((x, y, 1.2), 0.16, blip, segs=16)
        for r in (0.45, 0.8):
            kit.no_lines(kit.torus((x, y, 1.2), r, 0.015, ring))
        for d in range(1, 6):
            kit.no_lines(kit.sphere((x - d * 0.28, y + 0.05 * d, 1.1), 0.03, blip, segs=6))
    ghost = kit.additive("ghost", green, 0.07)
    kit.no_lines(kit.sphere((-3.0, yc(-3.0) - hw(-3.0) + 0.1, 0.5), 0.9, ghost, scale=(1.5, 1.0, 0.4)))
    ex = (10.2, yc(10.2))
    kit.sphere((ex[0], ex[1], 0.6), 0.2, kit.glow("beacon", "#d8ffe0", 3.0), segs=16)
    for r in (0.5, 1.0, 1.5, 2.0):
        kit.no_lines(kit.torus((ex[0], ex[1], 0.1), r, 0.02, kit.additive("pulse", green, 2.0 - r * 0.7)))

    # The sweep itself: a bright line from Robbie with a fading tail.
    a = math.radians(sweep)
    tail = kit.additive("sweep", green, 0.9, apex=robbie, length=12.0, cone=(sweep - 9, 9, 9))
    bm = bmesh.new()
    verts = [bm.verts.new((robbie[0], robbie[1], 0.05))]
    for k in range(13):
        aa = a - math.radians(18) * k / 12
        verts.append(bm.verts.new((robbie[0] + math.cos(aa) * 12, robbie[1] + math.sin(aa) * 12, 0.05)))
    for k in range(12):
        bm.faces.new((verts[0], verts[k + 1], verts[k + 2]))
    me = bpy.data.meshes.new("sweep")
    bm.to_mesh(me)
    ob = bpy.data.objects.new("sweep", me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(tail)
    kit.no_lines(ob)

    # Robbie as the sonar draws its own hull.
    hull = sonar_material("hull", robbie, sweep + 180, "#d8ffe0", "#020a04", k=1.0, reach=50)
    w.bathy(toon=lambda name, *a, **k: hull)
    kit.ortho_camera(target=(0.0, 0.3, 0.0), tilt_deg=20.0, scale=24.0)
    return "#000000"


# --- 4. The Verdigris Reef ---------------------------------------------------------------------------------------

def verdigris_reef():
    """A living reef at the edge of an abyss, where something enormous swims; the colonists marked a way across it
    with stakes, rope and lanterns, and left a raft-buoy at the far side. Painterly, no outlines."""
    lanterns = [(-4.0, 1.4), (1.6, 2.1), (6.0, 1.1)]
    jellies = [(-1.2, -0.6, "#e0607a"), (3.8, 3.2, "#f0b440"), (8.0, -0.4, "#6ad0c0")]
    raft = (9.8, 1.6)
    glows = [(x, y, 2.0, lin("#ff9a4a"), 0.55) for x, y in lanterns] + [(raft[0], raft[1], 2.6, lin("#ffb060"), 0.6)]
    glows += [(x, y, 2.0, lin(c), 0.5) for x, y, c in jellies]
    w = World((-7.4, 0.6), -4, ambient=lin("#174a48", 0.85), lamp_color=lin("#ffb35c", 1.35), glows=glows,
              bands=(0.4, 0.8), band_soft=0.08, radial=(1.0, 3.2), cone_range=10.0)

    def cliff_edge(x):
        return -2.6 - 0.7 * math.sin(x * 0.35 + 0.5) - 0.3 * math.sin(x * 1.1)

    sand = w.toon("sand", "#2f6a62", "#123432", "#4f9488", waves=(1.2, "#3a7a70", 5.0), noise=(0.5, 0.12))
    kit.paper_sheet("plateau", +1, cliff_edge, 0.0, sand, thickness=4.0, far=12.0)
    abyss = w.toon("abyss", "#06201f", "#020c0c", "#0c3030", ao=0.0)
    kit.box((0, -8, -4.2), (60, 14, 0.2), abyss)

    # Something enormous swims in the abyss below.
    whale = w.toon("whale", "#0e3634", "#041414", "#1e5450", ao=0.0, glow=lin("#0c3a38", 0.9))
    body = []
    for i in range(16):
        t = i / 15
        body.append((-9 + 19 * t, -6.8 + 1.2 * math.sin(t * 3.0), -3.0, 2.0 * math.sin(math.pi * (0.15 + 0.85 * t))
                     * (1.25 - 0.6 * t) + 0.3, (1.3, 0.7, 0.5)))
    kit.blobs("callowhale", body, whale, resolution=0.25)
    kit.blobs("fin", [(-2.0, -4.4, -2.8, 1.4, (1.6, 0.4, 0.2)), (-2.5, -9.2, -2.9, 1.4, (1.6, 0.4, 0.2))], whale,
              resolution=0.25)
    spot = kit.glow("spots", "#7af0d0", 1.4)
    for i in range(14):
        t = 0.1 + i / 18
        kit.sphere((-9 + 19 * t, -6.8 + 1.2 * math.sin(t * 3.0) + 1.0, -2.4), 0.09, spot, segs=8)

    # Reef: coral towers with glowing tips, brain corals, tube worms.
    coral = w.toon("coral", "#3f8a7a", "#123c36", "#7ac0b0", noise=(1.5, 0.15))
    tip = w.toon("tip", "#e07050", "#702818", "#ffb090", glow=scale_rgb(lin("#e07050"), 0.25), ao=0.2)
    for cx, cy, h in ((-10.2, 4.4, 2.8), (-6.2, 4.8, 2.0), (-1.0, 5.2, 3.2), (3.4, 4.6, 2.4), (8.0, 4.4, 3.0),
                      (11.2, 3.2, 2.2), (-3.0, -1.8, 1.4), (5.2, -1.6, 1.6)):
        balls = []
        for k in range(6):
            z = k * h / 5
            balls.append((cx + random.uniform(-0.4, 0.4), cy + random.uniform(-0.4, 0.4), z,
                          random.uniform(0.7, 1.1) * (1.1 - 0.12 * k), None))
        kit.blobs("tower", balls, coral, resolution=0.12)
        for _ in range(5):
            a = random.uniform(0, TAU)
            kit.sphere((cx + math.cos(a) * 0.45, cy + math.sin(a) * 0.45, h * random.uniform(0.6, 1.05)),
                       random.uniform(0.14, 0.24), tip, segs=16)
    brain = w.toon("brain", "#c4a050", "#5a4418", "#ffe0a0", rings=(9.0, "#8a6a28"))
    for bx, by in ((-8.6, -1.9), (0.4, 3.6), (6.8, 3.4), (-5.2, 3.3)):
        kit.sphere((bx, by, -0.1), random.uniform(0.5, 0.8), brain, scale=(1, 1, 0.7))
    worm = w.toon("worm", "#d8d0c0", "#5a5448", "#ffffff")
    red = w.toon("plume", "#d02a2a", "#5a0a0a", "#ff7a6a", glow=scale_rgb(lin("#d02a2a"), 0.3), ao=0.1)
    for wx, wy in ((-9.4, 2.4), (2.6, -1.9), (10.6, -1.4)):
        for _ in range(9):
            x, y, h = wx + random.uniform(-0.5, 0.5), wy + random.uniform(-0.5, 0.5), random.uniform(0.5, 1.1)
            kit.cyl((x, y, h / 2), 0.06, h, worm, verts=10)
            kit.sphere((x, y, h + 0.05), 0.11, red, segs=10)

    # Giant kelp rising out of the reef at the edges.
    kelp = w.toon("kelp", "#7a8a2a", "#2a3008", "#b0c050")
    for kx, ky in ((-11.0, 2.0), (11.6, 4.8), (-2.8, 6.4), (5.6, 6.2)):
        kit.tube([(kx, ky, 0), (kx + 0.3, ky - 0.2, 1.5), (kx - 0.2, ky + 0.1, 3.0), (kx + 0.1, ky, 4.0)], 0.08, kelp)
        for k in range(7):
            a = k * TAU / 7
            kit.tube([(kx, ky, 3.8), (kx + math.cos(a) * 0.8, ky + math.sin(a) * 0.8, 3.9),
                      (kx + math.cos(a + 0.3) * 1.6, ky + math.sin(a + 0.3) * 1.6, 3.6)], 0.05, kelp, flat=0.18)

    # The colonists' way across: stakes, a sagging rope, lanterns; a cache; the raft-buoy at the far side.
    wood = w.toon("wood", "#6b4423", "#2a1608", "#a0703a", noise=(6.0, 0.25))
    rope = w.toon("rope", "#c0a070", "#5a4020", "#e8d0a0")
    lamp = kit.glow("lantern", "#ffb060", 2.2)
    stakes = [(-5.6, 1.0), (-4.0, 1.4), (-1.0, 2.2), (1.6, 2.1), (4.2, 1.3), (6.0, 1.1), (8.2, 1.4)]
    for sx, sy in stakes:
        kit.cyl((sx, sy, 0.5), 0.07, 1.0, wood, verts=8)
    for (ax, ay), (bx, by) in zip(stakes, stakes[1:]):
        pts = [(ax + (bx - ax) * t, ay + (by - ay) * t, 0.95 - 0.35 * math.sin(math.pi * t)) for t in
               (i / 6 for i in range(7))]
        kit.tube(pts, 0.02, rope)
    for lx, ly in lanterns:
        kit.box((lx, ly, 1.15), (0.22, 0.22, 0.28), wood)
        kit.sphere((lx, ly, 1.15), 0.1, lamp, segs=12)
    tarp = w.toon("tarp", "#8a7a5a", "#3a3020", "#c0b090")
    kit.box((-10.0, 3.6, 0.3), (1.0, 0.8, 0.6), wood)
    kit.cone((-10.3, 3.0, 0.55), 1.0, 0.05, 1.1, tarp, verts=4, rot=(0, 0, 0.6))
    rx_, ry_ = raft
    for k in range(5):
        kit.box((rx_, ry_ - 0.8 + k * 0.4, 0.35), (1.8, 0.34, 0.08), wood, rot=(0, 0, random.uniform(-0.05, 0.05)))
    for s in (-1, 1):
        kit.cyl((rx_ + s * 0.6, ry_, 0.15), 0.25, 2.0, w.toon("barrel", "#5a3a1a", "#20120a", "#8a5a2a"),
                rot=(math.pi / 2, 0, 0))
    kit.cyl((rx_, ry_, 1.3), 0.05, 1.9, wood, verts=8)
    kit.box((rx_ + 0.3, ry_, 2.0), (0.55, 0.03, 0.35), w.toon("flag", "#c84a2a", "#5a1a0a", "#ff8a5a"),
            rot=(0, 0, 0.3))
    kit.box((rx_, ry_ - 0.3, 1.0), (0.26, 0.26, 0.32), wood)
    kit.sphere((rx_, ry_ - 0.3, 1.0), 0.12, lamp, segs=12)
    kit.torus((rx_ - 0.4, ry_ + 0.5, 0.42), 0.22, 0.05, rope)

    for x, y, c in jellies:
        jelly(w, x, y, c, 0.9)
    w.bathy()
    w.tether(rope)
    w.beam("#ffb35c", 0.14)
    snow("#d8f0e0", 0.45, 110, z=(3.0, 4.6))
    kit.ortho_camera(target=(0.0, 0.4, 0.0), tilt_deg=34.0, scale=24.0)
    return "#020c0c"


# --- 5. The Red Spot Mine ----------------------------------------------------------------------------------------

def red_spot_mine():
    """A jagged ice canyon gouged by the Company: the colossal drill coming down, chains, mine rails and an ore cart,
    steaming vents, Jupiter's red light through the cracks. Printed as a three-ink woodcut."""
    def yc(x):
        return 0.42 * x + 0.6 * math.sin(x * 0.4)

    def hw(x):
        return 2.9 + 0.5 * math.sin(x * 0.3)

    robbie = (-7.6, yc(-7.6))
    drill = (8.6, yc(8.6) + 0.6)
    vent = (2.2, yc(2.2) - 2.2)
    pools = [(-2.2, yc(-2.2) + 1.6), (5.0, yc(5.0) - 1.4)]
    jellies = [(-3.4, yc(-3.4) - 0.8, "#ffc23a"), (1.0, yc(1.0) + 1.2, "#ff5a3a"), (5.6, yc(5.6) + 0.6, "#ffc23a")]
    glows = [(x, y, 2.4, lin("#ff2a2a"), 0.55) for x, y in pools] + [(vent[0], vent[1], 2.0, lin("#ff6a2a"), 0.6)]
    glows += [(x, y, 2.0, lin(c), 0.45) for x, y, c in jellies] + [(drill[0] + 1.6, drill[1] - 1.4, 2.4,
                                                                     lin("#ffd23a"), 0.55)]
    w = World(robbie, 22, ambient=lin("#1a1a3a", 0.75), lamp_color=lin("#ffd27a", 1.35), glows=glows,
              rim=(lin("#ff3a3a"), 0.4, 0.25, True, (0.5, 0.42)))

    def cracks(n, P):
        vor = n.add("ShaderNodeTexVoronoi", feature="DISTANCE_TO_EDGE")
        n.feed(vor.inputs["Vector"], P)
        vor.inputs["Scale"].default_value = 1.3
        edge = n.remap(vor.outputs["Distance"], 0.02, 0.045)
        return n.lerp(rgb("#0a0a18"), rgb("#7a88a8"), edge)

    ice_floor = w.toon("ice_floor", "#7a88a8", pattern=cracks, ao=0.6)
    kit.box((0, 0, -0.05), (60, 40, 0.1), ice_floor)
    ice = w.toon("ice", "#a8c0d8", "#1a2440", "#e8f4ff")
    deep = w.toon("ice_deep", "#3a4a78", "#0a0e22", "#7088b8")

    # Shards: tilted crystal blades along both canyon walls.
    for side in (-1, 1):
        x = -16.0
        while x < 16.0:
            for k in range(3):
                edge = yc(x) + side * (hw(x) + 0.2 + k * 1.6 + random.uniform(0, 0.7))
                h = random.uniform(1.6, 3.6) * (1 + 0.3 * k)
                bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0, location=(x, edge, h * 0.35))
                o = bpy.context.object
                o.scale = (random.uniform(0.45, 0.8), random.uniform(0.35, 0.6), h * 0.55)
                o.rotation_euler = (side * random.uniform(0.15, 0.5), random.uniform(-0.3, 0.3), random.uniform(0, TAU))
                o.data.materials.append(ice if k == 0 else deep)
                flat(o)
            x += random.uniform(0.7, 1.1)

    # Mine rails down the canyon, sleepers, and an ore cart.
    iron = w.toon("iron", "#2a2a3a", "#08080e", "#5a5a72", patches=(0.8, "#5a2a1a", 0.6))
    wood = w.toon("sleeper", "#4a3020", "#140a06", "#7a5030")
    xs = [x * 0.5 - 14 for x in range(57)]
    for s in (-0.45, 0.45):
        for x0, x1 in zip(xs, xs[1:]):
            beam_between((x0, yc(x0) + s, 0.12), (x1, yc(x1) + s, 0.12), (0.08, 0.1), iron)
    for x in xs[::1]:
        dx = 0.5
        ang = math.atan2(yc(x + dx) - yc(x), dx)
        kit.box((x, yc(x), 0.04), (0.18, 1.3, 0.08), wood, rot=(0, 0, ang))
    cart_x = -1.6
    ang = math.atan2(yc(cart_x + 0.5) - yc(cart_x), 0.5)
    cart = kit.box((cart_x, yc(cart_x), 0.6), (1.3, 0.95, 0.62), iron, bevel=0.05, rot=(0.08, 0, ang))
    for sx in (-0.45, 0.45):
        for sy in (-0.5, 0.5):
            kit.cyl((cart_x + sx * math.cos(ang) - sy * math.sin(ang), yc(cart_x) + sx * math.sin(ang)
                     + sy * math.cos(ang), 0.22), 0.2, 0.08, iron, rot=(math.pi / 2, 0, ang))
    ore = w.toon("ore", "#d09a30", "#5a3a08", "#ffe08a", glow=scale_rgb(lin("#ffc23a"), 0.2))
    for _ in range(9):
        o = kit.sphere((cart_x + random.uniform(-0.4, 0.4), yc(cart_x) + random.uniform(-0.3, 0.3), 0.95), 0.18, ore,
                       segs=6)
        flat(o)

    # The Company's drill, coming down from above, and its chains.
    dx_, dy_ = drill
    kit.cone((dx_, dy_, 4.7), 3.2, 0.05, 8.6, iron, rot=(math.pi, 0, 0))
    steel = w.toon("steel", "#8a8aa0", "#22223a", "#d8d8f0")
    for k in range(17):
        z = 0.9 + k * 0.5
        r = 0.15 + 3.05 * (z - 0.4) / 8.6
        kit.torus((dx_, dy_, z), r, 0.1, steel, rot=(0.14 * math.sin(k * 1.3), 0.14 * math.cos(k * 1.3), 0))
    link = w.toon("chain", "#6a6a80", "#18182a", "#b0b0c8")
    for ax, ay in ((dx_ - 4.2, dy_ + 2.4), (dx_ - 2.6, dy_ + 4.0)):
        for i in range(14):
            t = i / 13
            kit.torus((ax + 1.8 * t, ay - 0.4 * t, 7.0 - 6.0 * t + 1.2 * math.sin(math.pi * t)), 0.16, 0.04, link,
                      rot=(math.pi / 2 if i % 2 else 0, 0, 0.3))

    # A vent chimney, smoking red.
    vx, vy = vent
    lump = w.toon("vent", "#2a2030", "#0a0810", "#5a4060")
    for k in range(5):
        kit.cyl((vx, vy, 0.2 + k * 0.35), 0.55 - k * 0.07, 0.4, lump, verts=9)
    kit.cyl((vx, vy, 1.95), 0.24, 0.05, kit.glow("vent_mouth", "#ff4a1a", 2.4))
    for k in range(6):
        kit.no_lines(kit.sphere((vx + k * 0.15, vy + k * 0.08, 2.2 + k * 0.4), 0.3 + k * 0.12,
                                kit.additive("smoke", "#ff6a3a", 0.25 - k * 0.03)))
    for px, py in pools:
        kit.no_lines(kit.cyl((px, py, 0.03), 2.2, 0.02, kit.additive("red", "#ff2a2a", 0.45, apex=(px, py),
                                                                      length=2.2), verts=48))

    # The way out: a lit elevator ring at the drill's foot.
    gold = kit.glow("gold", "#ffd23a", 2.0)
    ex, ey = dx_ + 1.4, dy_ - 1.6
    kit.torus((ex, ey, 0.06), 1.0, 0.07, gold)
    kit.torus((ex, ey, 0.06), 1.5, 0.03, gold)
    kit.cyl((ex, ey, 0.8), 0.06, 1.6, iron)
    kit.sphere((ex, ey, 1.65), 0.15, gold, segs=12)

    # A lurker in a crevice; ember jellies.
    kit.blobs("lurker", [(-4.6, yc(-4.6) + hw(-4.6) + 0.3, 0.4, 0.9, (1.4, 1.0, 0.6))], w.toon("lurker", "#05040c"),
              resolution=0.1)
    eye = kit.glow("eye", "#ff2a3a", 1.4)
    for d in (-0.22, 0.22):
        kit.sphere((-4.4 + d, yc(-4.6) + hw(-4.6) - 0.3, 0.8), 0.09, eye, scale=(1.3, 0.5, 0.4), segs=12)
    for x, y, c in jellies:
        jelly(w, x, y, c, 0.9)
    w.bathy()
    w.tether(w.toon("cable", "#1a1a24", "#050508", "#3a3a4a"))
    w.beam("#ffd27a", 0.14)
    snow("#ffe0c0", 0.45, 100)
    kit.ortho_camera(target=(0.0, 0.6, 0.3), tilt_deg=26.0, scale=24.0)
    kit.outlines(3.4, "#05040c", crease=True)
    return "#05040c"


BUILDERS = {1: drowned_colony, 2: pleasure_gardens, 3: dead_air, 4: verdigris_reef, 5: red_spot_mine}

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:]
    wid, out = int(argv[0]), argv[1]
    samples = int(argv[2]) if len(argv) > 2 else 48
    random.seed(7 + wid)
    kit.reset()
    background = BUILDERS[wid]()
    kit.render(out, samples=samples, background=background)
