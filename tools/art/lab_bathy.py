"""Bathy on the hangar's bench, for the Lab drafts (2026-10-28): the stock hull, or fitted with upgrades.

Bathy is the brass diving bell from robbie_designs.py (round 1, design 1). The Company's parts are Admiralty
(docs/design/art-direction.md): navy grey-green enamel, dark bronze, chipped valve red on what moves. They hang off
him, so you can tell at a glance what a hull carries.

Run: blender -b --factory-startup -P tools/art/lab_bathy.py -- <out.png> [parts,comma,separated|stock|all] [samples] [size]
Parts: battery, plating, screws, spotlight, laser, hydrophone, grapple, flares
"""
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402
import robbie_designs as rd  # noqa: E402

ALL = ["battery", "plating", "screws", "spotlight", "laser", "hydrophone", "grapple", "flares"]


def parts(M, fit):
    navy = M("navy", "#3b4f4f", "#1d2828", "#6b8580")
    bronze = M("bronze", "#6e5230", "#36261a", "#a8844e")
    red = M("valve_red", "#9c2a1a", "#521108", "#d0503a")
    steel = M("steel", "#5b5f60", "#2a2c2e", "#9aa0a0")
    if "battery" in fit:
        # Two spare cells slung under his belly, a red cap on each.
        for s in (-1, 1):
            kit.cyl((-0.05, s * 0.24, 0.3), 0.14, 0.7, navy, rot=rd.facing_x())
            kit.cyl((0.32, s * 0.24, 0.3), 0.09, 0.06, red, rot=rd.facing_x())
            for x in (-0.25, 0.15):
                kit.torus((x, s * 0.24, 0.3), 0.145, 0.02, bronze, rot=rd.facing_x())
        kit.torus((0, 0, 0.86), 0.74, 0.035, bronze)
    if "plating" in fit:
        # A riveted belt of armour round his middle.
        kit.torus((0, 0, 0.98), 0.71, 0.085, navy)
        for k in range(16):
            a = k * 2 * math.pi / 16
            if abs(math.cos(a)) > 0.93 and math.cos(a) > 0:
                continue          # leave his face clear
            kit.sphere((0.79 * math.cos(a), 0.79 * math.sin(a), 0.98), 0.03, bronze, segs=10)
    if "screws" in fit:
        # Twin screws: longer pods, four blades, a red hub.
        for s in (-1, 1):
            kit.cyl((-0.15, s * 0.86, 0.92), 0.17, 0.75, navy, rot=rd.facing_x())
            kit.sphere((0.24, s * 0.86, 0.92), 0.17, bronze, scale=(0.6, 1, 1), segs=24)
            for k in range(4):
                kit.sphere((-0.55, s * 0.86, 0.92), 0.21, bronze, scale=(0.07, 0.3, 1.0), rot=(k * math.pi / 2, 0, 0),
                           segs=16)
            kit.sphere((-0.57, s * 0.86, 0.92), 0.06, red, segs=12)
    if "spotlight" in fit:
        # A searchlight on the hatch, on a yoke.
        kit.cyl((0.12, 0, 1.92), 0.05, 0.22, bronze)
        kit.cyl((0.22, 0, 2.08), 0.16, 0.3, navy, rot=(0, math.pi / 2 - 0.2, 0))
        kit.sphere((0.37, 0, 2.11), 0.14, kit.glow("spot", "#fff0b0", 2.2), scale=(0.3, 1, 1), rot=(0, -0.2, 0))
    if "laser" in fit:
        # The Company's laser, slung under his chin: a long barrel, a red-hot tip.
        kit.cyl((0.72, 0.28, 0.42), 0.05, 0.7, steel, rot=rd.facing_x())
        kit.cyl((0.5, 0.28, 0.42), 0.09, 0.22, navy, rot=rd.facing_x())
        kit.sphere((1.08, 0.28, 0.42), 0.045, kit.glow("laser_tip", "#ff4a2a", 3.0), segs=16)
    if "hydrophone" in fit:
        # An ear trumpet on the hatch, for hearing what can't be seen.
        kit.cone((-0.32, -0.12, 2.0), 0.03, 0.2, 0.45, bronze, rot=rd.along((-0.6, -0.2, 0.8)))
        kit.torus((-0.46, -0.17, 2.18), 0.19, 0.02, red, rot=rd.along((-0.6, -0.2, 0.8)))
    if "grapple" in fit:
        # A harpoon and its coil of line on his left side.
        kit.cyl((0.35, -0.72, 0.6), 0.035, 0.6, steel, rot=rd.facing_x())
        kit.cone((0.7, -0.72, 0.6), 0.07, 0.0, 0.16, red, rot=rd.facing_x())
        kit.torus((0.05, -0.74, 0.6), 0.12, 0.03, bronze, rot=(math.pi / 2, 0, 0))
    if "flares" in fit:
        # A rack of flares on his right: red-capped tubes.
        for k in range(3):
            kit.cyl((-0.2 + k * 0.14, 0.72, 0.52), 0.05, 0.26, navy, rot=(0.3, 0, 0))
            kit.sphere((-0.2 + k * 0.14, 0.76, 0.66), 0.05, red, segs=12)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    out = argv[0]
    which = argv[1] if len(argv) > 1 else "stock"
    fit = ALL if which == "all" else ([] if which == "stock" else which.split(","))
    samples = int(argv[2]) if len(argv) > 2 else 40
    px = int(argv[3]) if len(argv) > 3 else 720
    scene, _names, floor = rd.build(1, "dark")
    # The same toon materials as Bathy's own, from the same light rig.
    light = bpy.data.node_groups["Lighting"]

    def M(name, base, shade=None, high=None, **kw):
        kw.setdefault("ao", 0.45)
        return kit.toon(name, light, base, shade, high, **kw)

    parts(M, fit)
    kit.outlines(2.8, "#030405")
    floor.hide_render = True
    kit.look_camera((4.6, -2.9, 2.2), (0.0, 0, 1.0), lens=60)
    kit.render(out, px, px, samples=samples, background="#12161c", transparent=True)


if __name__ == "__main__":
    main()
