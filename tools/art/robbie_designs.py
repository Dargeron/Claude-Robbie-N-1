"""Five very different Robbies, each drawn twice: a big three-quarter view (the Lab) and the top-down view the game
uses, so we can judge both the character and how it reads at play size.

Every design faces +x (its lamp at the front) and is built from separate parts (lamp, propulsion, sensor, body), so
the Lab can later swap one part and redraw Robbie.

Run: blender -b --factory-startup -P tools/art/robbie_designs.py -- <design 1-5> <out_prefix> [samples]
  writes <out_prefix>_lab.png (720x720) and <out_prefix>_top.png (360x360)
"""
import math
import os
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402

DESIGNS = {1: "Bathy", 2: "Squidge", 3: "Tug", 4: "Puff", 5: "Bell"}


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


BUILDERS = {1: bathy, 2: squidge, 3: tug, 4: puff, 5: bell}


def build(design):
    scene = kit.reset()
    cfg = dict(robbie=(0, 0), lamp_angle=0, cone_half=30, cone_soft=10, cone_range=10, radial=(40, 50),
               radial_gain=1.0, ambient=kit.scale_rgb(kit.rgb("#f2ece4"), 0.62), lamp_color=(0.42, 0.42, 0.42),
               glows=[], sun=(0.25, -0.75, 0.65), bands=(0.42, 0.82), band_soft=0.02, sky=None, rim=None)
    light = kit.lighting_group(cfg)

    def M(name, base, shade=None, high=None, **kw):
        kw.setdefault("ao", 0.45)
        return kit.toon(name, light, base, shade, high, **kw)

    parts = BUILDERS[design](M)
    floor = kit.no_lines(kit.cyl((0, 0, -0.02), 40.0, 0.04, kit.glow("floor", "#e9eff3", 1.0), verts=96))
    kit.no_lines(kit.sphere((0.05, -0.15, 0.03), 0.95, kit.shadow("shadow", "#3a4660", 0.22), scale=(1.15, 0.9, 0.03)))
    return scene, parts, floor


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    design, prefix = int(argv[0]), argv[1]
    samples = int(argv[2]) if len(argv) > 2 else 40
    scene, parts, floor = build(design)
    kit.outlines(2.4, "#1a1f2e")
    kit.look_camera((4.4, -2.6, 1.9), (0.1, 0, 0.92), lens=54)
    kit.render(prefix + "_lab.png", 720, 720, samples=samples, background="#e9eff3")
    bpy.data.objects.remove(scene.camera)
    kit.ortho_camera(target=(0.05, 0.0, 0.9), tilt_deg=24.0, scale=3.2)
    scene.render.line_thickness = 0.6
    floor.hide_render = True
    kit.render(prefix + "_top.png", 360, 360, samples=samples, background="#e9eff3", transparent=True)
    with open(prefix + "_parts.txt", "w") as f:
        f.write("\n".join(parts) + "\n")


if __name__ == "__main__":
    main()
