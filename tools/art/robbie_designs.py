"""Five very different Robbies, each drawn twice: a big three-quarter view (the Lab) and the top-down view the game
uses, so we can judge both the character and how it reads at play size.

Every design faces +x (its lamp at the front) and is built from separate parts (lamp, propulsion, sensor, body), so
the Lab can later swap one part and redraw Robbie.

Designs 1-5 are round 1 (cute). Designs 6-10 are round 2: machines of a steampunk colony, darker and less cute,
drawn on a dark sheet in the comic style Albert chose ("dark" mode, also usable for Bathy).

Run: blender -b --factory-startup -P tools/art/robbie_designs.py -- <design 1-10> <out_prefix> [samples] [light|dark]
  writes <out_prefix>_lab.png (720x720) and <out_prefix>_top.png (360x360)
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

DESIGNS = {1: "Bathy", 2: "Squidge", 3: "Tug", 4: "Puff", 5: "Bell", 6: "Boiler", 7: "Hardsuit", 8: "Lighthouse",
           9: "Scaphe", 10: "Phono"}
TAU = 2 * math.pi


def along(v):
    """Euler rotation turning +Z towards v (for cones, cylinders and tubes pointing somewhere)."""
    return Vector((0, 0, 1)).rotation_difference(Vector(v).normalized()).to_euler()


def facing_x():
    return (0, math.pi / 2, 0)


def on_sphere(center, radius, direction):
    return Vector(center) + Vector(direction).normalized() * radius


def bathy(M):
    """A brass diving bell with one big porthole: a little face glows on the screen inside."""
    c = (0, 0, 1.0)
    brass = M("brass", "#d39b45", "#8c5a24", "#ffe1a0")
    copper = M("copper", "#9a5a2c", "#5a3216", "#d08a5a")
    dark = M("screen", "#1c2a3a", "#101822", "#2c4058")
    eye = kit.glow("eye", "#7af0ff", 2.2)
    blush = M("blush", "#ff9aa8", lit=0.6, ao=0.0)
    glass = kit.glass("glass", "#e8f8ff", "#ffffff", 0.9, 0.03)
    lens = kit.glow("lens", "#ffd77a", 1.4)
    kit.sphere(c, 0.72, brass)
    kit.torus((0, 0, 0.78), 0.69, 0.04, copper)
    # Porthole: copper ring, dark screen, two glowing eyes, glass on top.
    kit.torus((0.69, 0, 1.1), 0.34, 0.075, copper, rot=facing_x())
    kit.sphere((0.68, 0, 1.1), 0.31, dark, scale=(0.3, 1, 1))
    for s in (-1, 1):
        kit.sphere((0.77, s * 0.11, 1.14), 0.07, eye, scale=(0.4, 0.75, 1.25), segs=24)
        kit.sphere((0.75, s * 0.21, 0.99), 0.05, blush, scale=(0.4, 1, 0.7), segs=16)
    kit.no_lines(kit.sphere((0.72, 0, 1.1), 0.3, glass, scale=(0.35, 1, 1)))
    for k in range(12):
        a = k * 2 * math.pi / 12
        kit.sphere(on_sphere(c, 0.71, (0.78, 0.46 * math.cos(a), 0.1 + 0.46 * math.sin(a))), 0.033, copper, segs=12)
    # Headlamp under the porthole.
    kit.cyl((0.62, 0, 0.58), 0.12, 0.14, copper, rot=(0, math.pi / 2 + 0.35, 0))
    kit.sphere((0.69, 0, 0.555), 0.1, lens, scale=(0.4, 1, 1), rot=(0, 0.35, 0), segs=24)
    # Propeller pods on both sides.
    for s in (-1, 1):
        kit.cyl((-0.05, s * 0.8, 0.92), 0.15, 0.5, copper, rot=facing_x())
        kit.sphere((0.2, s * 0.8, 0.92), 0.15, brass, scale=(0.6, 1, 1), segs=24)
        for k in range(3):
            kit.sphere((-0.33, s * 0.8, 0.92), 0.17, brass, scale=(0.08, 0.35, 1.0), rot=(k * math.pi / 1.5, 0, 0),
                       segs=16)
    # Hatch with a handle, and an antenna.
    kit.cyl((0, 0, 1.7), 0.22, 0.08, copper)
    kit.torus((0, 0, 1.82), 0.12, 0.03, brass, rot=(math.pi / 2, 0, 0))
    kit.cyl((-0.3, 0.15, 1.75), 0.018, 0.45, copper)
    kit.sphere((-0.3, 0.15, 2.0), 0.055, kit.glow("tip", "#8cff9a", 2.5), segs=16)
    return ["Headlamp under the porthole", "Two propeller pods", "Hatch on top: a sensor or antenna",
            "Belly band: battery and CPU"]


def squidge(M):
    """A soft squid: tall mantle with ear-fins, huge eyes, curly tentacles; the lamp is a glowing photophore."""
    coral = M("coral", "#ff8fa3", "#d65a72", "#ffc4cf")
    pale = M("pale", "#ffd9df", "#e8a0ae", "#ffffff")
    ring = M("ring", "#ff6b88", "#c94060", "#ffa0b4")
    white = M("white", "#ffffff", "#d8dde8", "#ffffff", ao=0.0)
    pupil = M("pupil", "#1d1630", lit=0.0, ao=0.0)
    spark = kit.glow("spark", "#ffffff", 1.5)
    lamp = kit.glow("lamp", "#fff0a0", 3.0)
    kit.sphere((-0.12, 0, 1.45), 0.55, coral, scale=(0.9, 0.9, 1.35), rot=(0, -0.35, 0))
    kit.sphere((0.05, 0, 0.86), 0.52, coral, scale=(1.0, 1.0, 0.8))
    kit.sphere((0.16, 0, 0.8), 0.42, pale, scale=(0.95, 0.85, 0.7))
    for s in (-1, 1):
        kit.sphere((-0.42, s * 0.42, 1.95), 0.32, coral, scale=(0.75, 0.22, 0.9), rot=(s * 0.5, -0.4, 0))
        kit.sphere((0.4, s * 0.22, 0.98), 0.2, white)
        kit.sphere((0.55, s * 0.23, 1.0), 0.11, pupil, segs=24)
        kit.sphere((0.62, s * 0.19, 1.07), 0.035, spark, segs=12)
    kit.cyl((0.58, 0, 0.74), 0.07, 0.06, ring, rot=facing_x())
    kit.sphere((0.62, 0, 0.74), 0.075, lamp, segs=24)
    for k in range(8):
        a = (k - 3.5) * 0.42 + math.pi
        pts = []
        for i in range(7):
            t = i / 6
            pts.append((0.05 + math.cos(a) * (0.25 + 0.3 * t) - 0.25 * t * t,
                        math.sin(a) * (0.25 + 0.35 * t), 0.5 - 0.42 * t + 0.1 * math.sin(4 * t + k)))
        kit.tube(pts, 0.065, coral, taper=0.35)
        for i in (2, 4):
            p = pts[i]
            kit.sphere(p, 0.06, ring, segs=12)
    return ["Lamp: the glowing spot under the eyes", "Eight tentacles: grabbers or fins",
            "Ear-fins: steering or sonar", "Mantle: battery and CPU"]


def tug(M):
    """A wind-up tin toy tugboat: boxy, headlamp eyes, a grille smile, a key in its back."""
    teal = M("teal", "#3fb0a8", "#1f7570", "#8fe0d8")
    red = M("red", "#e5484d", "#a02a30", "#ff8a8e")
    cream = M("cream", "#f4ead2", "#c9b892", "#ffffff")
    brass = M("brass", "#d8a440", "#94681e", "#ffe09a")
    rubber = M("rubber", "#2a2f3a", "#171a22", "#4a5262")
    pupil = M("pupil", "#1d1630", lit=0.0, ao=0.0)
    lens = kit.glow("lens", "#fff2a8", 2.2)
    kit.box((0, 0, 0.85), (1.5, 1.0, 0.72), teal, bevel=0.18)
    kit.box((0, 0, 1.06), (1.54, 1.04, 0.09), red, bevel=0.04)
    kit.box((-0.25, 0, 1.42), (0.72, 0.74, 0.5), cream, bevel=0.12)
    kit.box((0.12, 0, 1.48), (0.04, 0.5, 0.2), M("window", "#9fd8ff", "#5a9ac8", "#ffffff"), bevel=0.02)
    for s in (-1, 1):
        kit.torus((0.76, s * 0.24, 0.9), 0.15, 0.04, cream, rot=facing_x())
        kit.sphere((0.76, s * 0.24, 0.9), 0.14, lens, scale=(0.35, 1, 1), segs=24)
        kit.sphere((0.8, s * 0.22, 0.9), 0.06, pupil, scale=(0.5, 1, 1), segs=16)
        kit.cyl((0, s * 0.54, 0.62), 0.07, 1.2, rubber, rot=facing_x())
    for i in range(3):
        kit.cyl((0.76, 0, 0.6 + i * 0.065), 0.022, 0.38, cream, rot=(math.pi / 2, 0, 0))
    kit.cyl((-0.35, 0, 1.85), 0.1, 0.4, red)
    kit.cyl((-0.35, 0, 2.06), 0.12, 0.06, rubber)
    kit.cyl((-0.86, 0, 1.0), 0.04, 0.25, brass, rot=facing_x())
    for s in (-1, 1):
        kit.torus((-1.0, s * 0.11, 1.0), 0.11, 0.035, brass, rot=(math.pi / 2, 0, 0))
    kit.cone((-0.82, 0, 0.55), 0.09, 0.02, 0.2, brass, rot=(0, -math.pi / 2, 0))
    for k in range(3):
        kit.sphere((-0.9, 0, 0.55), 0.17, brass, scale=(0.07, 0.35, 1.0), rot=(k * math.pi / 1.5, 0, 0), segs=16)
    return ["Headlamp eyes (two lamps)", "Screw propeller", "Smokestack: periscope or antenna",
            "Wind-up key: the battery"]


def puff(M):
    """A spiky puffer with a big grin; its lamp dangles in front like an anglerfish's lure."""
    purple = M("purple", "#8e6bd8", "#5a3fa0", "#c0a8f5")
    spike = M("spike", "#c3aef5", "#8a70d0", "#ffffff")
    belly = M("belly", "#f2e6ff", "#c8b4e8", "#ffffff")
    white = M("white", "#ffffff", "#d8dde8", "#ffffff", ao=0.0)
    pupil = M("pupil", "#1d1630", lit=0.0, ao=0.0)
    ink = M("ink", "#2a1a40", lit=0.2, ao=0.0)
    spark = kit.glow("spark", "#ffffff", 1.5)
    lure = kit.glow("lure", "#ffe27a", 3.2)
    c = Vector((0, 0, 1.0))
    kit.sphere(c, 0.68, purple)
    kit.sphere((0.14, 0, 0.88), 0.6, belly, scale=(0.9, 0.86, 0.8))
    golden = math.pi * (3 - math.sqrt(5))
    for i in range(60):  # blunt spikes over the back and top, not on the face
        z = 1 - 2 * (i + 0.5) / 60
        r = math.sqrt(1 - z * z)
        d = Vector((math.cos(golden * i) * r, math.sin(golden * i) * r, z))
        if d.x > 0.35 or d.z < -0.35:
            continue
        kit.cone(c + d * 0.7, 0.07, 0.015, 0.2, spike, rot=along(d), verts=12)
    for s in (-1, 1):
        kit.sphere((0.5, s * 0.25, 1.18), 0.17, white)
        kit.sphere((0.63, s * 0.25, 1.2), 0.095, pupil, segs=24)
        kit.sphere((0.69, s * 0.22, 1.26), 0.03, spark, segs=12)
        kit.sphere((-0.05, s * 0.68, 0.92), 0.25, spike, scale=(0.5, 0.12, 0.35), rot=(s * 0.3, 0, 0), segs=24)
    mouth = []
    for i in range(9):
        y = -0.26 + 0.52 * i / 8
        z = 0.86 - 0.07 * (1 - (y / 0.26) ** 2)
        x = math.sqrt(max(0.0, 0.69 ** 2 - y * y - (z - 1.0) ** 2))
        mouth.append((x, y, z))
    kit.tube(mouth, 0.022, ink)
    for y in (-0.08, 0.08):
        kit.cone((0.64, y, 0.815), 0.028, 0.0, 0.06, white, verts=10)
    for s in (-1, 1):
        kit.sphere((-0.72, s * 0.12, 1.02), 0.3, spike, scale=(0.35, 0.1, 0.6), rot=(s * 0.4, 0.3, 0), segs=24)
    stalk = [(0.15, 0, 1.62), (0.35, 0, 2.08), (0.8, 0, 2.2), (1.06, 0, 2.02), (1.1, 0, 1.9)]
    kit.tube(stalk, 0.028, purple, taper=0.7)
    kit.sphere((1.1, 0, 1.8), 0.11, lure, segs=24)
    return ["Lamp: the lure on its stalk", "Side fins and tail: propulsion", "Spikes: armour or sensors",
            "Belly: battery and CPU"]


def bell(M):
    """A glass jellyfish: a glowing little brain with a face under a clear dome, trailing cable tentacles."""
    collar = M("collar", "#f4f4f8", "#b8bccc", "#ffffff")
    plate = M("plate", "#2a3a5a", "#16203a", "#4a6088")
    core = kit.glow("core", "#7affd4", 1.6)
    ink = M("ink", "#0a2a2a", lit=0.0, ao=0.0)
    cable = M("cable", "#c8d0e0", "#8890a8", "#ffffff")
    tip = kit.glow("tip", "#ff9ad5", 2.4)
    jet = kit.glow("jet", "#7ae8ff", 2.0)
    lens = kit.glow("lens", "#fff2b8", 3.0)
    glass = kit.glass("dome", "#d8fbff", "#9be7ff", 1.6, 0.1)
    kit.sphere((0, 0, 1.45), 0.32, core)
    for s in (-1, 1):
        kit.sphere((0.29, s * 0.1, 1.5), 0.045, ink, segs=16)
    kit.tube([(0.3, -0.07, 1.38), (0.32, 0, 1.35), (0.3, 0.07, 1.38)], 0.014, ink)
    kit.cyl((0, 0, 1.05), 0.06, 0.4, collar)
    kit.no_lines(kit.sphere((0, 0, 1.4), 0.72, glass, scale=(1, 1, 0.82)))
    kit.torus((0, 0, 0.92), 0.64, 0.1, collar)
    kit.cyl((0, 0, 0.84), 0.6, 0.12, plate)
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        kit.cyl((math.cos(a) * 0.4, math.sin(a) * 0.4, 0.74), 0.08, 0.12, plate)
        kit.cyl((math.cos(a) * 0.4, math.sin(a) * 0.4, 0.675), 0.06, 0.02, jet)
    kit.cyl((0.7, 0, 0.92), 0.1, 0.14, plate, rot=facing_x())
    kit.sphere((0.77, 0, 0.92), 0.085, lens, scale=(0.4, 1, 1), segs=24)
    for k in range(7):
        a = math.pi + (k - 3) * 0.5
        pts = [(math.cos(a) * 0.5 - 0.35 * t * t, math.sin(a) * (0.5 + 0.15 * t), 0.78 - 0.5 * t
                + 0.06 * math.sin(5 * t + k)) for t in (i / 6 for i in range(7))]
        kit.tube(pts, 0.03, cable)
        kit.sphere(pts[-1], 0.06, tip, segs=16)
    return ["Lamp on the collar", "Four jets under the plate", "Cable tentacles: grabbers or antennae",
            "The brain in the dome: CPU"]


# --- Round 2: machines of the steam colony ------------------------------------------------------------------------

def metals(M):
    return dict(
        iron=M("iron", "#3a4046", "#111518", "#6a767e", patches=(1.4, "#6a2e14", 0.63)),
        brass=M("brass", "#b8862f", "#5a3c12", "#f0c878"),
        copper=M("copper", "#a0522d", "#4a200c", "#e08a5a"),
        dark=M("dark", "#101418", "#050708", "#262c32"),
        wood=M("wood", "#5a3418", "#1e0e04", "#8a5a30", noise=(8.0, 0.25)),
        cream=M("dial", "#e8dcc0", "#a09070", "#ffffff", ao=0.0),
        ink=M("ink", "#1a1010", lit=0.0, ao=0.0),
    )


def paddle_wheel(x, y, z, r, mat_rim, mat_paddle, side):
    kit.cyl((x, y, z), 0.08, 0.14, mat_rim, rot=(math.pi / 2, 0, 0))
    kit.torus((x, y + side * 0.04, z), r, 0.025, mat_rim, rot=(math.pi / 2, 0, 0))
    for k in range(8):
        a = k * TAU / 8
        kit.box((x + math.cos(a) * r * 0.72, y + side * 0.04, z + math.sin(a) * r * 0.72), (r * 0.62, 0.16, 0.05),
                mat_paddle, rot=(0, -a, 0))


def propeller(x, y, z, r, mat, blades=3):
    kit.cone((x, y, z), 0.07, 0.02, 0.16, mat, rot=(0, -math.pi / 2, 0))
    for k in range(blades):
        kit.sphere((x - 0.05, y, z), r, mat, scale=(0.07, 0.35, 1.0), rot=(k * TAU / blades, 0, 0), segs=16)


def boiler(M):
    """A riveted steam boiler on paddle wheels; its eye is a pressure gauge, its furnace glows through the grate."""
    m = metals(M)
    fire = kit.glow("fire", "#ff6a1a", 2.4)
    lens = kit.glow("lens", "#ffd77a", 1.6)
    kit.cyl((0, 0, 1.0), 0.55, 1.3, m["iron"], rot=facing_x())
    kit.sphere((0.65, 0, 1.0), 0.55, m["iron"], scale=(0.42, 1, 1))
    kit.sphere((-0.65, 0, 1.0), 0.55, m["iron"], scale=(0.32, 1, 1))
    for x in (-0.5, 0.0, 0.5):
        kit.torus((x, 0, 1.0), 0.56, 0.035, m["brass"], rot=facing_x())
        for k in range(18):
            a = k * TAU / 18
            kit.sphere((x + 0.05, 0.575 * math.cos(a), 1.0 + 0.575 * math.sin(a)), 0.02, m["brass"], segs=6)
    kit.cyl((0.86, 0, 1.12), 0.24, 0.06, m["cream"], rot=facing_x())
    kit.torus((0.89, 0, 1.12), 0.24, 0.045, m["brass"], rot=facing_x())
    for k in range(7):
        a = math.radians(210 - k * 40)
        kit.box((0.9, math.cos(a) * 0.17, 1.12 + math.sin(a) * 0.17), (0.01, 0.025, 0.05), m["ink"],
                rot=(a - math.pi / 2, 0, 0))
    kit.cyl((0.91, 0.06, 1.18), 0.014, 0.19, m["ink"], rot=(math.radians(-45), 0, 0))
    kit.sphere((0.91, 0, 1.12), 0.03, m["brass"], segs=10)
    kit.cyl((0.8, 0, 0.66), 0.11, 0.2, m["brass"], rot=(0, math.pi / 2 + 0.3, 0))
    kit.sphere((0.9, 0, 0.63), 0.09, lens, scale=(0.4, 1, 1), rot=(0, 0.3, 0), segs=24)
    kit.cyl((0.3, 0, 1.75), 0.11, 0.6, m["iron"])
    kit.cone((0.3, 0, 2.1), 0.1, 0.2, 0.16, m["iron"])
    kit.torus((0.3, 0, 2.18), 0.19, 0.03, m["brass"])
    bub = kit.glass("bubble", "#e8f8ff", "#ffffff", 0.9, 0.03)
    for i, r in enumerate((0.06, 0.05, 0.04)):
        kit.no_lines(kit.sphere((0.32 - 0.03 * i, 0.02 * (-1) ** i, 2.42 + 0.22 * i), r, bub, segs=16))
    for sd in (-1, 1):
        paddle_wheel(-0.05, sd * 0.62, 0.95, 0.44, m["iron"], m["wood"], sd)
    kit.torus((-0.82, 0, 0.95), 0.22, 0.03, m["brass"], rot=facing_x())
    for k in range(4):
        kit.box((-0.86, 0, 0.83 + k * 0.08), (0.03, 0.3, 0.03), fire)
    kit.tube([(-0.4, 0.2, 1.5), (-0.55, 0.3, 1.85), (-0.85, 0.25, 1.65), (-0.92, 0.2, 1.25)], 0.04, m["copper"])
    return ["Carbide lamp under the gauge", "Paddle wheels", "Pressure gauge: its eye and its sensor",
            "Furnace and boiler: battery and CPU"]


def hardsuit(M):
    """An armoured diving suit with nobody inside: claws, three portholes, two dim lights behind the glass."""
    m = metals(M)
    suit = M("suit", "#2c3238", "#0c0f12", "#58626c", patches=(1.6, "#5a2a14", 0.64))
    eye = kit.glow("eye", "#ff3a2a", 2.2)
    lens = kit.glow("lens", "#ffd77a", 1.6)
    kit.sphere((0, 0, 1.0), 0.5, suit, scale=(0.85, 1.0, 1.05))
    kit.torus((0, 0, 0.78), 0.45, 0.04, m["brass"])
    kit.box((0.36, 0, 1.08), (0.14, 0.5, 0.42), suit, bevel=0.05)
    kit.sphere((0.05, 0, 1.62), 0.36, m["copper"])
    kit.torus((0.05, 0, 1.33), 0.31, 0.07, m["brass"])
    for k in range(10):
        a = k * TAU / 10
        kit.sphere((0.05 + math.cos(a) * 0.33, math.sin(a) * 0.33, 1.38), 0.03, m["iron"], segs=8)
    kit.sphere((0.34, 0, 1.64), 0.16, m["dark"], scale=(0.3, 1, 1))
    for sd in (-1, 1):
        kit.sphere((0.385, sd * 0.045, 1.67), 0.036, eye, segs=12)
    kit.torus((0.38, 0, 1.64), 0.17, 0.04, m["brass"], rot=facing_x())
    for y in (-0.08, 0.0, 0.08):
        kit.cyl((0.41, y, 1.64), 0.012, 0.32, m["brass"])
    for sd in (-1, 1):
        kit.torus((0.05, sd * 0.34, 1.66), 0.1, 0.03, m["brass"], rot=(math.pi / 2, 0, 0))
        kit.sphere((0.05, sd * 0.32, 1.66), 0.09, m["dark"], scale=(1, 0.3, 1), segs=16)
        sh, el, wr = Vector((0.05, sd * 0.5, 1.22)), Vector((0.22, sd * 0.66, 0.9)), Vector((0.52, sd * 0.6, 0.78))
        kit.sphere(sh, 0.15, m["brass"], segs=24)
        kit.tube([sh, (sh + el) / 2, el], 0.09, suit)
        kit.sphere(el, 0.11, m["brass"], segs=20)
        kit.tube([el, (el + wr) / 2, wr], 0.075, suit)
        kit.torus(wr, 0.08, 0.025, m["brass"], rot=along(wr - el))
        for c in (-1, 1):
            kit.cone(wr + Vector((0.12, 0, c * 0.05)), 0.04, 0.005, 0.22, m["iron"],
                     rot=along((1, 0, -c * 0.4)), verts=10)
    kit.cone((0, 0, 0.5), 0.28, 0.42, 0.3, suit)
    jet = kit.glow("jet", "#7ae8ff", 1.4)
    for x, y in ((0.14, 0.14), (0.14, -0.14), (-0.14, 0.14), (-0.14, -0.14)):
        kit.cone((x, y, 0.3), 0.04, 0.07, 0.14, m["iron"], verts=12)
        kit.cyl((x, y, 0.22), 0.035, 0.01, jet, verts=12)
    kit.cyl((0.24, -0.42, 1.45), 0.08, 0.22, m["brass"], rot=facing_x())
    kit.sphere((0.36, -0.42, 1.45), 0.065, lens, scale=(0.4, 1, 1), segs=20)
    kit.box((-0.42, 0, 1.05), (0.26, 0.5, 0.56), m["iron"], bevel=0.05)
    hose = M("hose", "#1a1a1a", "#050505", "#3a3a3a")
    pts = [(-0.55, 0, 1.25), (-0.8, 0.1, 1.55), (-1.05, 0.2, 1.35), (-1.3, 0.25, 1.7)]
    kit.tube(pts, 0.05, hose)
    for p in pts[1:3]:
        kit.sphere(p, 0.065, m["brass"], scale=(1, 1, 0.5), segs=12)
    return ["Shoulder lamp", "Thruster skirt", "Claws: grabbers", "Backpack and air hose: battery and CPU"]


def lighthouse(M):
    """A streamlined Art Deco beacon: a lantern room on top, a glowing visor slit for an eye, red fins."""
    m = metals(M)
    gun = M("gunmetal", "#2c3238", "#0c0f12", "#5c6872")
    chrome = M("chrome", "#b8c0c8", "#4a5058", "#ffffff", ao=0.2)
    red = M("enamel", "#8a1e1e", "#3a0808", "#d05050")
    visor = kit.glow("visor", "#ffb050", 2.0)
    lamp = kit.glow("lamp", "#ffe6a0", 2.6)
    kit.sphere((0, 0, 1.05), 0.42, gun, scale=(1, 1, 1.6))
    for z in (0.72, 0.8, 0.88):
        r = 0.42 * math.sqrt(max(0.0, 1 - ((z - 1.05) / 0.672) ** 2))
        kit.torus((0, 0, z), r + 0.005, 0.012, chrome)
    zr = 1.3
    rr = 0.42 * math.sqrt(1 - ((zr - 1.05) / 0.672) ** 2)
    kit.torus((0, 0, zr + 0.06), rr - 0.01, 0.03, chrome)
    kit.torus((0, 0, zr), rr + 0.0, 0.03, visor)
    kit.torus((0, 0, zr - 0.06), rr + 0.01, 0.03, chrome)
    kit.torus((0, 0, 1.72), 0.3, 0.02, chrome)
    for k in range(10):
        a = k * TAU / 10
        kit.cyl((math.cos(a) * 0.3, math.sin(a) * 0.3, 1.66), 0.01, 0.12, chrome, verts=6)
    kit.cyl((0, 0, 1.73), 0.31, 0.03, gun)
    kit.no_lines(kit.cyl((0, 0, 1.9), 0.21, 0.32, kit.glass("lantern", "#fff4d8", "#ffffff", 1.0, 0.08)))
    kit.sphere((0, 0, 1.9), 0.11, lamp, segs=20)
    kit.cyl((0.18, 0, 1.9), 0.09, 0.04, lamp, rot=facing_x())
    kit.sphere((0, 0, 2.08), 0.24, m["brass"], scale=(1, 1, 0.55))
    kit.cone((0, 0, 2.3), 0.05, 0.0, 0.28, m["brass"], verts=12)
    for a in (math.radians(110), math.pi, math.radians(250)):  # swept fins, like a 1930s rocket's
        kit.sphere((math.cos(a) * 0.46, math.sin(a) * 0.46, 0.58), 1.0, red, scale=(0.3, 0.03, 0.42),
                   rot=(0, 0.35, a), segs=32)
    kit.cone((0, 0, 0.32), 0.14, 0.22, 0.16, chrome)
    kit.cyl((0, 0, 0.23), 0.12, 0.02, kit.glow("jet", "#7ae8ff", 1.6))
    return ["The lantern room: its lamp", "Three fins and a jet", "Visor slit: its eye and sensor",
            "Hull: battery and CPU"]


def scaphe(M):
    """A little bathyscaphe: a long float, a pressure sphere hanging below with one small window, a guide chain."""
    m = metals(M)
    hull = M("hull", "#8a877c", "#2c2a24", "#c8c4b6", patches=(1.2, "#6a3a1a", 0.66))
    window = kit.glow("window", "#ffb050", 1.2)
    lens = kit.glow("lens", "#ffd77a", 1.6)
    kit.sphere((0, 0, 1.38), 0.5, hull, scale=(2.0, 1.0, 0.78))
    kit.box((0.05, 0, 1.73), (1.0, 0.28, 0.04), m["iron"])
    kit.box((0.25, 0, 1.95), (0.42, 0.3, 0.34), hull, bevel=0.06)
    kit.torus((0.25, 0, 2.13), 0.09, 0.025, m["brass"])
    kit.cyl((0.12, 0, 2.24), 0.012, 0.28, m["iron"], verts=6)
    kit.sphere((0.12, 0, 2.38), 0.035, kit.glow("tip", "#ff4a2a", 2.0), segs=8)
    kit.box((-1.0, 0, 1.38), (0.32, 0.03, 0.55), m["iron"], bevel=0.01)
    kit.box((-1.0, 0, 1.38), (0.32, 0.6, 0.03), m["iron"], bevel=0.01)
    propeller(-1.12, 0, 1.38, 0.2, m["brass"])
    kit.sphere((0.2, 0, 0.62), 0.36, m["iron"])
    kit.torus((0.2, 0, 0.62), 0.355, 0.02, m["brass"], rot=facing_x())
    kit.torus((0.2, 0, 0.62), 0.355, 0.02, m["brass"])
    kit.torus((0.54, 0, 0.66), 0.08, 0.025, m["brass"], rot=facing_x())
    kit.sphere((0.54, 0, 0.66), 0.065, window, scale=(0.3, 1, 1), segs=16)
    for x, y in ((0.05, 0.15), (0.05, -0.15), (0.35, 0.15), (0.35, -0.15)):
        kit.cyl((x, y, 0.98), 0.025, 0.36, m["iron"], verts=8)
    for x in (0.75, -0.5):
        kit.cyl((x, 0, 1.0), 0.13, 0.36, m["dark"])
    kit.cyl((0.5, 0, 0.36), 0.07, 0.14, m["brass"], rot=(0, math.pi / 2 + 0.5, 0))
    kit.sphere((0.56, 0, 0.33), 0.06, lens, scale=(0.4, 1, 1), rot=(0, 0.5, 0), segs=16)
    for i in range(5):
        kit.torus((0.18, 0, 0.22 - i * 0.07), 0.035, 0.012, m["iron"], rot=(math.pi / 2 if i % 2 else 0, 0, 0))
    return ["Lamp under the gondola", "Stern screw and rudders", "Mast: antenna and sensors",
            "The float: ballast, battery and CPU"]


def lathe(path, radii, mat, segs=32, name="horn"):
    """A surface of revolution along a path, open at both ends (horns, funnels)."""
    bm = bmesh.new()
    rings = []
    for i, (p, r) in enumerate(zip(path, radii)):
        p = Vector(p)
        t = (Vector(path[min(i + 1, len(path) - 1)]) - Vector(path[max(i - 1, 0)])).normalized()
        up = Vector((0, 1, 0)) if abs(t.y) < 0.9 else Vector((1, 0, 0))
        a = t.cross(up).normalized()
        b = t.cross(a).normalized()
        rings.append([bm.verts.new(p + (a * math.cos(k * TAU / segs) + b * math.sin(k * TAU / segs)) * r)
                      for k in range(segs)])
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(segs):
            bm.faces.new((r0[k], r0[(k + 1) % segs], r1[(k + 1) % segs], r1[k]))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    for poly in me.polygons:
        poly.use_smooth = True
    me.materials.append(mat)
    o.modifiers.new("rim", "SOLIDIFY").thickness = 0.02
    return o


def phono(M):
    """A mahogany valve-radio cabinet with a brass gramophone horn that throws the light (and could listen)."""
    m = metals(M)
    bak = M("bakelite", "#2a140a", "#0c0402", "#4a2a18")
    valve = kit.glow("valve", "#ff9a3a", 2.2)
    lamp = kit.glow("lamp", "#ffe6a0", 2.4)
    kit.box((-0.1, 0, 0.85), (0.95, 0.8, 0.62), m["wood"], bevel=0.04)
    for x in (-0.57, 0.37):
        for y in (-0.4, 0.4):
            for z in (0.54, 1.16):
                kit.sphere((x, y, z), 0.05, m["brass"], segs=10)
    kit.box((0.38, 0, 0.8), (0.02, 0.6, 0.36), bak)
    for y in (-0.18, 0.0, 0.18):
        kit.sphere((0.37, y, 0.82), 0.06, valve, scale=(0.5, 0.5, 1.2), segs=12)
    for y in (-0.24, -0.12, 0.0, 0.12, 0.24):
        kit.cyl((0.4, y, 0.8), 0.012, 0.34, m["brass"], verts=6)
    kit.cyl((0.38, 0.3, 1.06), 0.07, 0.02, m["cream"], rot=facing_x())
    kit.torus((0.39, 0.3, 1.06), 0.07, 0.015, m["brass"], rot=facing_x())
    path, radii = [], []
    for i in range(17):
        t = i / 16
        p0, p1, p2 = Vector((-0.2, 0, 1.15)), Vector((-0.2, 0, 1.8)), Vector((0.75, 0, 1.78))
        path.append((1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2)
        radii.append(0.05 + 0.43 * t ** 3)
    lathe(path, radii, m["brass"])
    kit.sphere((0.55, 0, 1.76), 0.15, lamp, segs=20)
    kit.cyl((-0.1, 0.44, 0.9), 0.025, 0.12, m["brass"], rot=(math.pi / 2, 0, 0))
    kit.box((-0.02, 0.5, 0.82), (0.2, 0.03, 0.05), m["brass"], rot=(0, 0.6, 0))
    kit.sphere((0.06, 0.5, 0.76), 0.05, m["wood"], segs=12)
    kit.cyl((-0.5, 0.28, 1.6), 0.012, 0.9, m["iron"], verts=6)
    kit.sphere((-0.5, 0.28, 2.06), 0.035, kit.glow("tip", "#8cff9a", 2.0), segs=8)
    for y in (-0.25, 0.25):
        propeller(-0.62, y, 0.66, 0.14, m["brass"])
    return ["The horn: lamp, and ears for eels", "Two screws at the back", "Aerial: radio and sensors",
            "The valves in the cabinet: CPU, the crank: battery"]


BUILDERS = {1: bathy, 2: squidge, 3: tug, 4: puff, 5: bell, 6: boiler, 7: hardsuit, 8: lighthouse, 9: scaphe,
            10: phono}


YAW = {9: -45.0}
SHEET = {"light": dict(background="#e9eff3", shadow=("#3a4660", 0.22), lines=(2.4, "#1a1f2e")),
         "dark": dict(background="#12161c", shadow=("#000000", 0.5), lines=(2.8, "#030405"))}


def build(design, mode="light"):
    scene = kit.reset()
    cfg = dict(robbie=(0, 0), lamp_angle=0, cone_half=30, cone_soft=10, cone_range=10, radial=(40, 50),
               radial_gain=1.0, ambient=kit.scale_rgb(kit.rgb("#f2ece4"), 0.62), lamp_color=(0.42, 0.42, 0.42),
               glows=[], sun=(0.25, -0.75, 0.65), bands=(0.42, 0.82), band_soft=0.02, sky=None, rim=None)
    if mode == "dark":  # the chosen comic look: hard bands, darker, a warm rim light
        cfg.update(ambient=kit.scale_rgb(kit.rgb("#d8d0c8"), 0.5), lamp_color=(0.32, 0.32, 0.32), bands=(0.5, 0.86),
                   band_soft=0.006, sky=((-0.6, 0.6, 0.35), kit.scale_rgb(kit.rgb("#ff8a2a"), 0.7), 0.5, 0.62, -1.0,
                                         0.0))
    light = kit.lighting_group(cfg)

    def M(name, base, shade=None, high=None, **kw):
        kw.setdefault("ao", 0.45)
        return kit.toon(name, light, base, shade, high, **kw)

    before = set(bpy.data.objects)
    parts = BUILDERS[design](M)
    if design in YAW:  # long designs turn a little so the sheet shows their length
        root = kit.group_under("yaw", [o for o in bpy.data.objects if o not in before and o.parent is None])
        root.rotation_euler = (0, 0, math.radians(YAW[design]))
    sheet = SHEET[mode]
    floor = kit.no_lines(kit.cyl((0, 0, -0.02), 40.0, 0.04, kit.glow("floor", sheet["background"], 1.0), verts=96))
    kit.no_lines(kit.sphere((0.05, -0.15, 0.03), 0.95, kit.shadow("shadow", *sheet["shadow"]), scale=(1.15, 0.9, 0.03)))
    return scene, parts, floor


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    design, prefix = int(argv[0]), argv[1]
    samples = int(argv[2]) if len(argv) > 2 else 40
    mode = argv[3] if len(argv) > 3 else ("dark" if design > 5 else "light")
    scene, parts, floor = build(design, mode)
    bg = SHEET[mode]["background"]
    kit.outlines(*SHEET[mode]["lines"])
    kit.look_camera((4.4, -2.6, 1.9), (0.1, 0, 0.92), lens=54)
    kit.render(prefix + "_lab.png", 720, 720, samples=samples, background=bg)
    bpy.data.objects.remove(scene.camera)
    kit.ortho_camera(target=(0.05, 0.0, 0.9), tilt_deg=24.0, scale=3.2)
    scene.render.line_thickness = 0.6
    floor.hide_render = True
    kit.render(prefix + "_top.png", 360, 360, samples=samples, background=bg, transparent=True)
    with open(prefix + "_parts.txt", "w") as f:
        f.write("\n".join(parts) + "\n")


if __name__ == "__main__":
    main()
