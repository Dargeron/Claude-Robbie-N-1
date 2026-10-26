"""Concept sheets: five styles for the console's hand parts, for Albert to choose from (2026-10-26).

He found the 2D desk not "steampunky enough": too shiny, and the red handles too clean and round (a glossy red bubble
on every lever). Each sheet shows the same six parts in one style, matte and worn, on a swatch of panel in that
style, lit like the console: the dispatch lever, the PRINT pull, a selector wheel, a knob, a toggle and a push key.
Red stays the mark of what the hand works; how it is red changes with the style.

  blender -b --factory-startup -P tools/art/handle_styles.py -- <out_dir> [1-5|all] [preview]

Writes style_<n>.png (1600x760) into out_dir.
"""
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import console_scene as cs  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else os.path.join(cs.ROOT, "out/art/handles")
WHICH = argv[1] if len(argv) > 1 else "all"
PREVIEW = "preview" in argv
os.makedirs(OUT, exist_ok=True)

W, H = 1600, 760
XS = [170, 420, 680, 950, 1190, 1420]      # where each part sits on the sheet
CY = 380


# ------------------------------------------------------------------ materials with a pattern in them

pmat = cs.pmat


# ------------------------------------------------------------------ helpers

def pivot(name, x, y, z=0.0, angle=0.0):
    e = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(e)
    e.location = (x / 100.0, -y / 100.0, z)
    e.rotation_euler = (0, 0, math.radians(angle))
    return e


def under(parent, objs, ox, oy):
    """Parent objects built around screen (ox, oy) to an empty, keeping where they are."""
    for o in objs:
        o.parent = parent
        o.matrix_parent_inverse = parent.matrix_world.inverted()
    return objs


star = cs.star
scallops = cs.scallops


def spokes(cx, cy, r0, r1, n, w, z0, z1, mat, rot=0.0, name="spoke"):
    out = []
    for k in range(n):
        a = rot + 2 * math.pi * k / n
        o = cs.slab(name, (cx - w / 2, cy - r1, w, r1 - r0), z0, z1, mat, r=w * 0.3, bevel=0.006)
        o.location = (0, 0, 0)
        # Turn about the wheel's centre.
        e = pivot(name + "_p", cx, cy, 0.0, math.degrees(a))
        o.parent = e
        o.location = (-cx / 100.0, cy / 100.0, 0)
        out.append(o)
    return out


# ------------------------------------------------------------------ the five styles

def panel(mat, trim=None, rivets=None):
    cs.slab("panel", (-40, -40, W + 80, H + 80), -0.3, 0.0, mat, r=0, bevel=0)
    for x in XS:
        # Each part on a raised mounting plate of its own.
        cs.slab("mount", (x - 110, 120, 220, 520), 0.0, 0.03, trim or mat, r=14, bevel=0.01)
        if rivets is not None:
            cs.rivets_around((x - 110, 120, 220, 520), rivets, step=70, inset=10, z=0.03)


def style_1():
    """Foundry: blackened cast iron, grips in red-oxide paint worn through to the iron, knurled."""
    iron = pmat("iron", "#3a3833", metal=0.75, rough=0.72, kind="hammer", scale=70, strength=0.25)
    oxide = pmat("oxide", "#5e1b10", metal=0.0, rough=0.88, kind="knurl", scale=55, strength=0.6, chip="#3a3632", chip_amount=0.55)
    oxide_flat = pmat("oxide_flat", "#5e1b10", metal=0.0, rough=0.9, chip="#3a3632", chip_amount=0.45)
    plate = pmat("plate_iron", "#2b2e2b", metal=0.3, rough=0.85, kind="hammer", scale=25, strength=0.15, chip="#5b4a3a", chip_amount=0.2)
    panel(plate, iron, iron)
    x = XS[0]   # dispatch lever: a flat cast bar, the grip a knurled sleeve
    cs.disc("boss", x, 560, 30, 0.03, 0.12, iron, bevel=0.02)
    cs.slab("bar", (x - 9, 230, 18, 335), 0.1, 0.18, iron, r=6, bevel=0.012)
    cs.cylinder_y("grip", 160, 250, x, 15, 0.26, oxide)
    cs.disc("cap", x, 158, 12, 0.18, 0.32, iron, bevel=0.01, n=6)
    cs.disc("pin", x, 560, 9, 0.12, 0.2, iron, n=6)
    x = XS[1]   # PRINT pull: a T-bar on a square shaft
    cs.slab("shaft", (x - 8, 300, 16, 280), 0.03, 0.12, iron, r=2, bevel=0.006)
    cs.cylinder_x("tbar", x - 70, x + 70, 290, 15, 0.22, oxide)
    for sx in (x - 74, x + 74):
        cs.disc("tcap", sx, 290, 10, 0.12, 0.32, iron, n=6)
    x = XS[2]   # wheel: cast spokes, an oxide rim, a knurled peg to turn it by
    cs.ring_obj("rim", x, CY, 92, 74, 0.03, 0.17, oxide_flat, bevel=0.02)
    for o in spokes(x, CY, 20, 78, 5, 14, 0.04, 0.12, iron):
        pass
    cs.disc("hub", x, CY, 26, 0.04, 0.2, iron, n=6, bevel=0.015)
    cs.cylinder_y("peg", CY - 95, CY - 70, x, 13, 0.32, oxide)
    x = XS[3]   # knob: fluted cast, oxide, with a filed pointer
    cs.prism("knob", star(x, CY, 56, 48, 12), 0.03, 0.3, oxide_flat, 0.02)
    cs.disc("knob_top", x, CY, 30, 0.3, 0.36, iron, bevel=0.01)
    cs.slab("pointer", (x - 4, CY - 54, 8, 30), 0.36, 0.38, pmat("bright", "#b9b0a0", metal=1.0, rough=0.5), r=1, bevel=0)
    x = XS[4]   # toggle: a forged paddle
    cs.disc("nut", x, CY + 60, 30, 0.03, 0.12, iron, n=6)
    cs.slab("bat", (x - 10, CY - 120, 20, 180), 0.12, 0.2, iron, r=8, bevel=0.01)
    cs.slab("paddle", (x - 22, CY - 140, 44, 60), 0.18, 0.28, oxide, r=10, bevel=0.015)
    x = XS[5]   # key: a square cast key, oxide top, dished
    cs.slab("key_skirt", (x - 70, CY - 50, 140, 100), 0.03, 0.12, iron, r=10, bevel=0.015)
    cs.slab("key_top", (x - 62, CY - 42, 124, 84), 0.12, 0.2, oxide, r=8, bevel=0.02)


def style_2():
    """Admiralty: ship's bronze gone dark, the handwheels and pulls in navy valve red, chipped to the bronze."""
    bronze = pmat("bronze", "#5b4426", metal=1.0, rough=0.62, kind="hammer", scale=40, strength=0.12, chip="#3f5a48", chip_metal=0.0, chip_amount=0.35)
    vred = pmat("valve_red", "#74170e", metal=0.0, rough=0.72, chip="#6e5430", chip_amount=0.5)
    enamel = pmat("navy_grey", "#3a423f", metal=0.0, rough=0.8, chip="#56473a", chip_amount=0.2)
    panel(enamel, pmat("bronze_trim", "#33281a", metal=0.6, rough=0.78, kind="hammer", scale=30, strength=0.1), bronze)
    x = XS[0]   # dispatch lever: a bronze rod with a red T-handle
    cs.disc("boss", x, 560, 32, 0.03, 0.14, bronze, bevel=0.02)
    cs.cylinder_y("rod", 230, 560, x, 9, 0.16, bronze)
    cs.cylinder_x("t", x - 58, x + 58, 220, 16, 0.26, vred)
    cs.ring_obj("collar", x, 470, 16, 9, 0.12, 0.22, bronze)
    x = XS[1]   # PRINT pull: a red flat pull-knob with a scalloped edge, like a sea-cock
    cs.cylinder_y("stem", 300, 560, x, 10, 0.12, bronze)
    cs.prism("pull", scallops(x, 280, 50, 6, 12), 0.12, 0.26, vred, 0.02)
    cs.disc("pull_nut", x, 280, 16, 0.26, 0.34, bronze, n=6)
    x = XS[2]   # wheel: a valve handwheel, red, its rim knuckled where the hand goes
    cs.prism("rim", scallops(x, CY, 86, 6, 10), 0.03, 0.18, vred, 0.025, holes=[cs.circle_pts(x, CY, 70, 96)])
    spokes(x, CY, 20, 74, 3, 18, 0.05, 0.14, vred, rot=math.pi / 6)
    cs.disc("hub", x, CY, 28, 0.05, 0.22, bronze, bevel=0.02)
    cs.disc("hub_nut", x, CY, 14, 0.22, 0.3, bronze, n=6)
    x = XS[3]   # knob: a wing knob, bronze hub, red wing
    cs.disc("hub", x, CY, 34, 0.03, 0.18, bronze, bevel=0.02)
    cs.prism("wing", [cs.P(x - 70, CY - 12), cs.P(x - 30, CY - 22), cs.P(x + 30, CY - 22), cs.P(x + 70, CY - 12),
                      cs.P(x + 70, CY + 12), cs.P(x + 30, CY + 22), cs.P(x - 30, CY + 22), cs.P(x - 70, CY + 12)], 0.12, 0.34, vred, 0.025)
    x = XS[4]   # toggle: a bronze lever with a red spoon tip
    cs.disc("nut", x, CY + 60, 30, 0.03, 0.12, bronze, n=6)
    cs.cylinder_y("bat", CY - 110, CY + 60, x, 8, 0.16, bronze)
    cs.slab("spoon", (x - 18, CY - 150, 36, 56), 0.14, 0.24, vred, r=17, bevel=0.015)
    x = XS[5]   # key: a bronze ring with a red enamel button
    cs.ring_obj("ring", x, CY, 62, 46, 0.03, 0.16, bronze, bevel=0.015)
    cs.disc("button", x, CY, 46, 0.03, 0.12, vred, bevel=0.02)


def style_3():
    """Telegraph: black crackle enamel, dull nickel, oxblood Bakelite with flutes and finger grips."""
    crackle = pmat("crackle", "#141413", metal=0.0, rough=0.6, kind="crackle", scale=14, strength=0.6, grime=0.9)
    nickel = pmat("nickel", "#8d8a80", metal=1.0, rough=0.55, kind="hammer", scale=90, strength=0.05, chip="#4d4232", chip_amount=0.3)
    oxblood = pmat("oxblood", "#4e130d", metal=0.0, rough=0.42, kind="flute", scale=6, strength=0.25, grime=0.6)
    oxblood_s = pmat("oxblood_s", "#4e130d", metal=0.0, rough=0.45, grime=0.6)
    panel(crackle, crackle, nickel)
    x = XS[0]   # dispatch lever: a nickel arm with a pistol grip
    cs.disc("boss", x, 560, 28, 0.03, 0.12, nickel, bevel=0.02)
    cs.slab("arm", (x - 7, 300, 14, 265), 0.1, 0.16, nickel, r=6, bevel=0.01)
    grip = [(x - 18, 300), (x - 24, 250), (x - 22, 200), (x - 14, 165), (x + 4, 150), (x + 22, 160), (x + 26, 200), (x + 22, 260), (x + 16, 300)]
    cs.prism("grip", [cs.P(*p) for p in grip], 0.08, 0.32, oxblood_s, 0.03)
    for k in range(4):
        cs.slab("finger", (x - 26, 182 + k * 26, 6, 14), 0.1, 0.3, crackle, r=3, bevel=0.005)
    x = XS[1]   # PRINT pull: a fluted oxblood drawer pull on a nickel stem
    cs.cylinder_y("stem", 300, 560, x, 8, 0.12, nickel)
    cs.prism("pull", star(x, 280, 44, 38, 14), 0.1, 0.32, oxblood, 0.02)
    cs.disc("pull_face", x, 280, 26, 0.32, 0.35, nickel, bevel=0.008)
    x = XS[2]   # wheel: an oxblood rim with finger dimples, black spokes
    cs.ring_obj("rim", x, CY, 90, 72, 0.03, 0.18, oxblood_s, bevel=0.03)
    for k in range(10):
        a = 2 * math.pi * k / 10
        cs.disc("dimple", x + 81 * math.cos(a), CY + 81 * math.sin(a), 6, 0.16, 0.185, crackle, bevel=0.004)
    spokes(x, CY, 20, 76, 4, 10, 0.04, 0.12, nickel)
    cs.disc("hub", x, CY, 26, 0.04, 0.22, oxblood, bevel=0.02)
    x = XS[3]   # knob: a chickenhead pointer knob
    cs.disc("skirt", x, CY, 52, 0.03, 0.08, nickel, bevel=0.01)
    cs.prism("chicken", [cs.P(x, CY - 70), cs.P(x + 16, CY - 30), cs.P(x + 34, CY + 10), cs.P(x + 30, CY + 34), cs.P(x, CY + 44),
                         cs.P(x - 30, CY + 34), cs.P(x - 34, CY + 10), cs.P(x - 16, CY - 30)], 0.08, 0.34, oxblood_s, 0.03)
    cs.slab("line", (x - 2.5, CY - 64, 5, 50), 0.34, 0.35, pmat("ivory", "#cbbf9f", rough=0.5), r=1, bevel=0)
    x = XS[4]   # toggle: a nickel bat with an oxblood sleeve
    cs.disc("nut", x, CY + 60, 28, 0.03, 0.12, nickel, n=6)
    cs.cylinder_y("bat", CY - 70, CY + 60, x, 7, 0.16, nickel)
    cs.cylinder_y("sleeve", CY - 140, CY - 64, x, 15, 0.2, oxblood)
    x = XS[5]   # key: an oxblood piano key
    cs.slab("key_bed", (x - 60, CY - 70, 120, 150), 0.0, 0.05, crackle, r=6, bevel=0.01)
    cs.slab("key", (x - 50, CY - 60, 100, 130), 0.05, 0.2, oxblood_s, r=12, bevel=0.03)


def style_4():
    """Brass & leather: aged brass with turned collars; every grip wrapped in stitched red leather."""
    brass = pmat("brass_aged", "#7a5e30", metal=1.0, rough=0.5, kind="hammer", scale=60, strength=0.08, chip="#2e3a2a", chip_metal=0.0, chip_amount=0.25)
    leather = pmat("leather_red", "#5c160f", metal=0.0, rough=0.75, kind="wrap", scale=26, strength=0.7, axis="Y", grime=0.9)
    leather_x = pmat("leather_red_x", "#5c160f", metal=0.0, rough=0.75, kind="wrap", scale=26, strength=0.7, axis="X", grime=0.9)
    green = pmat("bottle_green", "#1f2c25", metal=0.0, rough=0.62, chip="#6a5536", chip_amount=0.2)
    panel(green, pmat("brass_trim", "#3d311d", metal=0.6, rough=0.75, kind="hammer", scale=30, strength=0.1), brass)
    x = XS[0]   # dispatch lever: a brass rod, collars, a leather-wrapped grip, a turned finial
    cs.disc("boss", x, 560, 30, 0.03, 0.14, brass, bevel=0.02)
    cs.cylinder_y("rod", 260, 560, x, 8, 0.16, brass)
    for yy in (470, 380):
        cs.ring_obj("collar", x, yy, 14, 7, 0.1, 0.24, brass)
    cs.cylinder_y("grip", 170, 265, x, 16, 0.26, leather)
    for yy in (166, 268):
        cs.cylinder_y("ferrule", yy - 6, yy + 6, x, 18, 0.26, brass)
    cs.prism("finial", [cs.P(x - 14, 160), cs.P(x, 120), cs.P(x + 14, 160)], 0.14, 0.38, brass, 0.02)
    x = XS[1]   # PRINT pull: a leather-wrapped handle across, brass end caps
    cs.cylinder_y("stem", 300, 560, x, 9, 0.12, brass)
    cs.cylinder_x("handle", x - 64, x + 64, 285, 16, 0.24, leather_x)
    for sx in (x - 70, x + 70):
        cs.disc("endcap", sx, 285, 18, 0.1, 0.38, brass, bevel=0.02)
    x = XS[2]   # wheel: brass with eight thin spokes, the top of the rim wrapped in leather
    cs.ring_obj("rim", x, CY, 90, 76, 0.03, 0.16, brass, bevel=0.02)
    arc = [cs.P(x + 93 * math.cos(a), CY + 93 * math.sin(a)) for a in [math.radians(-150 + i * 4) for i in range(31)]]
    arc += [cs.P(x + 73 * math.cos(a), CY + 73 * math.sin(a)) for a in [math.radians(-30 - i * 4) for i in range(31)]]
    cs.prism("wrap", arc, 0.02, 0.2, leather, 0.02)
    spokes(x, CY, 18, 78, 8, 6, 0.04, 0.1, brass)
    cs.disc("hub", x, CY, 24, 0.04, 0.2, brass, bevel=0.02)
    for k in range(6):
        a = 2 * math.pi * k / 6
        cs.rivet(x + 16 * math.cos(a), CY + 16 * math.sin(a), brass, z=0.2)
    x = XS[3]   # knob: knurled brass with a leather band
    cs.prism("knob", star(x, CY, 50, 47, 40), 0.03, 0.32, brass, 0.01)
    cs.ring_obj("band", x, CY, 53, 44, 0.12, 0.22, leather_x)
    cs.disc("top", x, CY, 32, 0.32, 0.36, brass, bevel=0.01)
    x = XS[4]   # toggle: a brass bat, a leather pad on the end
    cs.disc("nut", x, CY + 60, 28, 0.03, 0.12, brass, n=6)
    cs.cylinder_y("bat", CY - 100, CY + 60, x, 7, 0.16, brass)
    cs.slab("pad", (x - 20, CY - 150, 40, 60), 0.12, 0.26, leather, r=14, bevel=0.02)
    x = XS[5]   # key: a typewriter key: brass ring, leather face
    cs.ring_obj("ring", x, CY, 60, 48, 0.03, 0.18, brass, bevel=0.015)
    cs.disc("face", x, CY, 48, 0.03, 0.14, pmat("leather_flat", "#5c160f", rough=0.8, kind="hammer", scale=120, strength=0.2), bevel=0.02)


def style_5():
    """Jury-rigged: forty years of repairs. Pipe for levers, red tape and rags for grips, welds, wire."""
    steel = pmat("steel_old", "#4a4a46", metal=0.9, rough=0.7, kind="hammer", scale=50, strength=0.15, chip="#5b2e18", chip_metal=0.0, chip_amount=0.4)
    rust = pmat("rust_plate", "#4b2a1a", metal=0.0, rough=0.9, kind="hammer", scale=20, strength=0.3, chip="#2f2f2c", chip_amount=0.3)
    tape = pmat("red_tape", "#741910", metal=0.0, rough=0.8, kind="wrap", scale=18, strength=0.9, axis="Y", grime=1.0)
    tape_x = pmat("red_tape_x", "#741910", metal=0.0, rough=0.8, kind="wrap", scale=18, strength=0.9, axis="X", grime=1.0)
    rag = pmat("rag", "#6a1810", metal=0.0, rough=0.95, kind="hammer", scale=80, strength=0.6, grime=1.0)
    paint = pmat("red_dab", "#781a10", metal=0.0, rough=0.7, chip="#4a4a46", chip_amount=0.6)
    panel(rust, pmat("patch", "#3c3d39", metal=0.6, rough=0.8, chip="#5a2c18", chip_amount=0.4), steel)
    x = XS[0]   # dispatch lever: a length of pipe, taped, with a hose clamp; a bolt for a pivot
    cs.disc("bolt", x, 560, 24, 0.03, 0.16, steel, n=6)
    cs.cylinder_y("pipe", 180, 560, x, 12, 0.18, steel)
    cs.cylinder_y("tape", 160, 290, x, 15, 0.2, tape)
    cs.ring_obj("clamp", x, 300, 17, 12, 0.04, 0.34, steel)
    cs.slab("clamp_screw", (x + 14, 293, 16, 14), 0.12, 0.26, steel, r=2, bevel=0.004)
    x = XS[1]   # PRINT pull: a spanner welded on, its handle taped
    jaw = [(x - 30, 250), (x - 34, 220), (x - 14, 200), (x - 8, 226), (x + 8, 226), (x + 14, 200), (x + 34, 220), (x + 30, 250), (x + 12, 270), (x - 12, 270)]
    cs.prism("jaw", [cs.P(*p) for p in jaw], 0.06, 0.16, steel, 0.01)
    cs.slab("handle", (x - 12, 265, 24, 300), 0.06, 0.16, steel, r=10, bevel=0.01)
    cs.cylinder_y("tape", 330, 470, x, 16, 0.12, tape)
    for k in range(5):
        cs.uv_sphere("weld", x - 14 + k * 7, 560, 0.08, 5, steel, 0.5)
    x = XS[2]   # wheel: a bent rebar ring welded to odd spokes, a red rag tied on where you grab it
    cs.ring_obj("rim", x, CY, 88, 78, 0.03, 0.15, steel, bevel=0.01)
    for k, (a, w) in enumerate(((0.3, 10), (2.0, 16), (3.9, 8), (5.1, 12))):
        sp = cs.slab("spoke", (x - w / 2, CY - 80, w, 60), 0.04, 0.12, steel, r=2, bevel=0.005)
        e = pivot("sp_p", x, CY, 0.0, math.degrees(a))
        sp.parent = e
        sp.location = (-x / 100.0, CY / 100.0, 0)
    cs.disc("hub", x, CY, 24, 0.04, 0.2, steel, n=6)
    for k in range(4):
        # Each strip of rag made at the origin, then turned and put where it is tied.
        r = cs.slab("rag", (-12, -17, 24, 34), 0.0, 0.05, rag, r=8, bevel=0.01)
        r.location = (x / 100.0 + (k - 1.5) * 0.09, -(CY - 90 + (k % 2) * 8) / 100.0, 0.14 + k * 0.03)
        r.rotation_euler = (0.25 * (k - 1.5), 0.2, 0.4 * (k - 1.5))
    x = XS[3]   # knob: two hex nuts welded on a bolt, a dab of red paint
    cs.disc("nut1", x, CY, 52, 0.03, 0.16, steel, n=6, bevel=0.01)
    cs.disc("nut2", x, CY, 40, 0.16, 0.3, steel, n=6, bevel=0.01)
    cs.disc("paint", x, CY, 26, 0.3, 0.33, paint, bevel=0.01)
    for k in range(8):
        a = 2 * math.pi * k / 8
        cs.uv_sphere("weld", x + 40 * math.cos(a), CY + 40 * math.sin(a), 0.16, 5, steel, 0.6)
    x = XS[4]   # toggle: a bent bolt with a flag of red tape
    cs.disc("nut", x, CY + 60, 26, 0.03, 0.12, steel, n=6)
    cs.cylinder_y("bolt", CY - 110, CY + 60, x, 7, 0.16, steel)
    cs.slab("flag", (x, CY - 120, 50, 26), 0.16, 0.18, tape_x, r=2, bevel=0)
    cs.cylinder_y("wrap", CY - 125, CY - 95, x, 10, 0.18, tape)
    x = XS[5]   # key: a red-painted cap on a spring, in a scrap ring
    cs.ring_obj("ring", x, CY, 60, 50, 0.03, 0.14, steel, bevel=0.01)
    cs.prism("cap", star(x, CY, 48, 44, 21), 0.05, 0.18, paint, 0.01)


STYLES = {"1": style_1, "2": style_2, "3": style_3, "4": style_4, "5": style_5}


def render_style(k):
    cs.reset()
    STYLES[k]()
    # The console's light: a warm work lamp from above and to the left, a dim cold fill, a pool.
    cs.lights(cx=8.0, cy=-3.8, scale=0.75)
    spot = bpy.data.lights.new("pool", "SPOT")
    spot.energy = 9000
    spot.spot_size = math.radians(80)
    spot.spot_blend = 0.9
    spot.color = (1.0, 0.8, 0.55)
    spot.shadow_soft_size = 0.4
    so = bpy.data.objects.new("pool", spot)
    bpy.context.scene.collection.objects.link(so)
    so.location = (6.0, 2.0, 7.0)
    tgt = bpy.data.objects.new("pool_t", None)
    bpy.context.scene.collection.objects.link(tgt)
    tgt.location = (8.0, -3.8, 0.0)
    tgt.rotation_euler = (math.radians(-90), 0, 0)
    c = so.constraints.new("TRACK_TO")
    c.target = tgt
    c.track_axis = "TRACK_NEGATIVE_Z"
    c.up_axis = "UP_Y"
    c.use_target_z = True
    cs.setup_render(W, H, W / 2, H / 2, 16 if PREVIEW else 80)
    sc = bpy.context.scene
    sc.render.film_transparent = False
    sc.view_settings.exposure = -0.2
    sc.render.resolution_x = W
    sc.render.resolution_y = H
    # A slight three-quarter view from below, so the parts show their depth.
    cam = sc.camera
    cam.data.type = "PERSP"
    cam.data.lens = 40
    cam.data.sensor_width = 36
    cam.location = (8.0, -3.8 - 5.6, 16.6)
    ct = bpy.data.objects.new("cam_t", None)
    sc.collection.objects.link(ct)
    ct.location = (8.0, -3.8, 0.0)
    ct.rotation_euler = (math.radians(-90), 0, 0)
    cc = cam.constraints.new("TRACK_TO")
    cc.target = ct
    cc.track_axis = "TRACK_NEGATIVE_Z"
    cc.up_axis = "UP_Y"
    cc.use_target_z = True
    cs.render(os.path.join(OUT, "style_%s.png" % k))


if __name__ == "__main__":
    for k in (STYLES.keys() if WHICH == "all" else WHICH.split(",")):
        render_style(k)
    print("handle styles written to", OUT)
