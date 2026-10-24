"""Style concepts: the same stretch of a dive, drawn in five candidate art styles.

The layout is shared so the styles can be compared like for like: a winding passage, Robbie (a neutral stand-in,
not one of the Robbie designs) lighting the way, three jellyfish, a lurker half-hidden in the rock, the valve, plants
and the exit beacon. The game's top-down view, tilted a little so walls show their faces.

Run: blender -b --factory-startup -P tools/art/concept_scene.py -- <style 1-5> <out.png> [samples]
"""
import math
import os
import random
import sys

import bmesh
import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402
from kit import rgb, scale_rgb  # noqa: E402


def yc(x):
    """The passage's centre line."""
    return 0.9 * math.sin(x * 0.28 + 0.4)


def hw(x):
    """The passage's half width."""
    return 3.0 + 0.8 * math.sin(x * 0.19 + 1.0)


ROBBIE = (-7.0, yc(-7.0))
LAMP_ANGLE = math.degrees(math.atan2(yc(-1.0) + 0.5 - ROBBIE[1], 6.0))
JELLIES = [(-1.2, yc(-1.2) + 0.9), (3.6, yc(3.6) - 1.3), (7.8, yc(7.8) + 1.4)]
LURKER = (-3.4, yc(-3.4) - hw(-3.4) - 0.2)
EXIT = (10.2, yc(10.2))

STYLES = {
    1: dict(name="Brass & Ink", background="#0b1d24",
            floor=("#3d676b", "#4b7975", "#1d3942"), rock=("#5b7883", "#263845", "#9cbab4", None),
            rock_south=None, ambient=("#2f5664", 1.2), lamp=("#ffd38a", 1.25), radial=(0.8, 3.2), radial_gain=0.85,
            cone=(27, 9, 10.5), sun=(-0.45, -0.55, 0.7), bands=(0.42, 0.8), band_soft=0.03, ao=0.6,
            robbie=("#c8893a", "#7a4a22", "#e8c27a"), eye="#fff8e8", pupil="#1b1410",
            jelly=["#f3a6c8", "#a6e3f3", "#f6d58a"], jelly_glow=0.9, glow_strength=0.55,
            anemone="#e0745a", kelp="#7aa35a", brass="#b8862f", pipe="#6f5532", beacon="#7ef0a0",
            lurker="#1e2b33", lurker_eye="#ffb84a", snow=("#cfe9e4", 0.55),
            lines=(2.2, "#0e171b"), beam=("#ffd38a", 0.22), walls="blobs", shadow=0.35),
    2: dict(name="Glow Abyss", background="#02040a",
            floor=("#101c30", "#15253c", "#070c16"), rock=("#1f3454", "#0c1426", "#3d6290", None),
            rock_south=None, ambient=("#17284a", 1.0), lamp=("#fff1d6", 1.15), radial=(0.6, 2.4), radial_gain=0.7,
            cone=(22, 6, 12.0), sun=(-0.3, -0.5, 0.8), bands=(0.45, 0.86), band_soft=0.04, ao=0.4,
            robbie=("#e9eff6", "#2ad4ff", "#ffffff"), eye="#e8fbff", pupil="#04121c",
            jelly=["#ff4fd8", "#3ff0ff", "#a6ff4f"], jelly_glow=2.2, glow_strength=1.1,
            anemone="#ff7a3f", kelp="#2bd9a0", brass="#4a6a8a", pipe="#22344a", beacon="#4fff9a",
            lurker="#0a0f18", lurker_eye="#ff3f5a", snow=("#7fdfff", 1.4),
            lines=None, beam=("#fff1d6", 0.45), walls="blobs", shadow=0.5, rim=("#3ff0ff", 1.6, 0.55),
            glow_plants=True, glow_nubs="#3ff0ff"),
    3: dict(name="Toy Aquarium", background="#bfe7df",
            floor=("#f3e3c3", "#ead1a2", "#cdb48a"), rock=("#b7a6e0", "#8b78c4", "#ddd2fa", None),
            rock_south=("#f2b8a0", "#cf8a74", "#ffd7c7", None), ambient=("#eef6f3", 0.66),
            lamp=("#fff2b0", 0.55), radial=(1.0, 4.0), radial_gain=0.7,
            cone=(30, 12, 10.0), sun=(-0.4, -0.6, 0.7), bands=(0.32, 0.82), band_soft=0.14, ao=0.85,
            robbie=("#ffd23f", "#ff6b6b", "#fff4c2"), eye="#ffffff", pupil="#2a2340",
            jelly=["#ff9ecf", "#9ed8ff", "#c7f59e"], jelly_glow=0.35, glow_strength=0.25,
            anemone="#ff7a8a", kelp="#58c98c", brass="#ffb347", pipe="#9a7ad1", beacon="#36d17c",
            lurker="#6b5a8c", lurker_eye="#ffe066", snow=("#ffffff", 0.9),
            lines=None, beam=None, walls="pebbles", shadow=0.18,
            pebbles=["#b7a6e0", "#f2b8a0", "#a8dcc8", "#f7d58a", "#9fc4f0"]),
    4: dict(name="Paper Cut", background="#1b1838",
            floor=("#2a2756", "#302d62", "#211e48"), rock=("#3a3778", "#3a3778", "#3a3778", None),
            rock_south=None, layers_n=["#3a3778", "#524ea0", "#6e69c2", "#8e88dc"],
            layers_s=["#4a3470", "#674a92", "#8762b4", "#a985d2"],
            ambient=("#7470b0", 0.75), lamp=("#ffe7a8", 0.95), radial=(0.9, 3.4), radial_gain=0.8,
            cone=(28, 10, 10.0), sun=(-0.4, -0.5, 0.7), bands=(-0.1, 1.1), band_soft=0.01, ao=0.25,
            robbie=("#ff8a5c", "#ffd25c", "#ffe4c9"), eye="#fff9ef", pupil="#2a1b3a",
            jelly=["#ffb3d1", "#b3e5ff", "#fff0a8"], jelly_glow=0.8, glow_strength=0.45,
            anemone="#ff6b5c", kelp="#7ad1a8", brass="#ffc65c", pipe="#c98a3c", beacon="#8cf0b0",
            lurker="#161430", lurker_eye="#ffd25c", snow=("#f5ead8", 0.5),
            lines=None, beam=None, walls="paper", shadow=0.5, valve_pipe=False),
    5: dict(name="Jovian Comic", background="#06222b",
            floor=("#0f4c55", "#145f68", "#082d35"), rock=("#1b6e73", "#0b3942", "#3db0aa", None),
            rock_south=None, ambient=("#145060", 1.45), lamp=("#fff0b3", 1.1), radial=(0.8, 3.0), radial_gain=0.85,
            cone=(26, 4, 10.5), sun=(-0.45, -0.55, 0.7), bands=(0.5, 0.86), band_soft=0.006, ao=0.5,
            rim=("#ff8a2a", 0.5, 0.42, True, (0.5, 0.42)), rock_noise=(0.6, 0.06),
            robbie=("#f3efe4", "#ff6a2a", "#ffffff"), eye="#ffffff", pupil="#101820",
            jelly=["#ff5fa2", "#ffd23f", "#7af0ff"], jelly_glow=1.0, glow_strength=0.6,
            anemone="#ff6a2a", kelp="#9be15d", brass="#ffb02a", pipe="#7a3a1a", beacon="#7dff6a",
            lurker="#0b2328", lurker_eye="#ff4a2a", snow=("#bff3ff", 0.7),
            lines=(3.2, "#071015"), beam=("#fff0b3", 0.16), walls="blobs", shadow=0.45),
}


def lin(hex_color, k=1.0):
    return scale_rgb(rgb(hex_color), k)


def build(style_id):
    st = STYLES[style_id]
    random.seed(11)
    kit.reset()

    glows = [(x, y, 2.4, lin(c), st["glow_strength"]) for (x, y), c in zip(JELLIES, st["jelly"])]
    glows.append((EXIT[0], EXIT[1], 2.6, lin(st["beacon"]), st["glow_strength"] * 0.9))
    cfg = dict(robbie=ROBBIE, lamp_angle=LAMP_ANGLE, cone_half=st["cone"][0], cone_soft=st["cone"][1],
               cone_range=st["cone"][2], radial=st["radial"], radial_gain=st["radial_gain"],
               ambient=lin(*st["ambient"]), lamp_color=lin(*st["lamp"]), glows=glows, sun=st["sun"],
               bands=st["bands"], band_soft=st["band_soft"], sky=None, rim=None)
    if st.get("sky"):
        d, c, lo, hi, z_lo, z_hi, k = st["sky"]
        cfg["sky"] = (d, lin(c, k), lo, hi, z_lo, z_hi)
    if st.get("rim"):
        cfg["rim"] = (lin(st["rim"][0]),) + tuple(st["rim"][1:])
    light = kit.lighting_group(cfg)

    def toon(name, base, shade=None, high=None, **kw):
        kw.setdefault("ao", st["ao"])
        return kit.toon(name, light, base, shade, high, **kw)

    shadow_mat = kit.shadow("shadow", "#000000", st["shadow"])

    # Sea floor with sand ripples, pebbles and shells.
    f = st["floor"]
    floor = toon("floor", f[0], f[2], f[1], waves=(1.6, f[1], 6.0), noise=(0.35, 0.12), ao=st["ao"] * 0.8)
    kit.box((0, 0, -0.05), (60, 40, 0.1), floor)
    pebble = toon("pebble", f[1], f[2])
    for _ in range(46):
        x = random.uniform(-12, 12)
        y = yc(x) + random.uniform(-hw(x) + 0.6, hw(x) - 0.6)
        r = random.uniform(0.07, 0.2)
        kit.sphere((x, y, 0.02), r, pebble, scale=(1, random.uniform(0.6, 1.0), 0.45), segs=16)

    # Rock walls: organic blobs either side of the passage (or stacked paper layers).
    def wall_points(side, layer_extra=0.0, z=(0.2, 0.7), size_z=0.75):
        pts = []
        x = -15.0
        while x < 15.0:
            edge = yc(x) + side * (hw(x) + random.uniform(0.0, 0.5) + layer_extra)
            for k in range(5):
                y = edge + side * (k * 1.7 + random.uniform(0.0, 0.6) + (0.9 if k else 0.4))
                r = random.uniform(1.0, 1.6) if k == 0 else random.uniform(1.7, 2.6)
                pts.append((x + random.uniform(-0.3, 0.3), y, random.uniform(*z), r, (1.0, 1.0, size_z)))
            x += random.uniform(0.75, 1.15)
        return pts

    if st["walls"] == "blobs":
        r = st["rock"]
        rn = st.get("rock_noise", (0.9, 0.18))
        rock_n = toon("rock_n", r[0], r[1], r[2], noise=rn)
        rs = st["rock_south"] or r
        rock_s = toon("rock_s", rs[0], rs[1], rs[2], noise=rn) if st["rock_south"] else rock_n
        kit.blobs("wall_n", wall_points(+1), rock_n, resolution=0.16)
        kit.blobs("wall_s", wall_points(-1), rock_s, resolution=0.16)
        for x in (-5.2, 2.6, 8.6):  # a few boulders in the passage
            kit.blobs("boulder", [(x, yc(x) + random.uniform(-1.8, 1.8), 0.25, 0.75, (1.0, 0.8, 0.6))], rock_n,
                      resolution=0.12)
        # Barnacles and nubs along the rock edge, so the walls read as rock and not as cloud.
        nub_glow = scale_rgb(lin(st["glow_nubs"]), 0.8) if st.get("glow_nubs") else (0, 0, 0)
        nub = toon("nub", r[2], r[1], "#ffffff", noise=(3.0, 0.2), glow=nub_glow)
        for _ in range(70):
            x = random.uniform(-12.5, 12.5)
            side = random.choice((-1, 1))
            y = yc(x) + side * (hw(x) + random.uniform(0.3, 1.4))
            kit.sphere((x, y, random.uniform(0.6, 1.1)), random.uniform(0.08, 0.2), nub, scale=(1, 1, 0.6), segs=12)
    elif st["walls"] == "pebbles":  # toy rocks: a heap of rounded pebbles in candy colours
        mats = [toon("pebble_%d" % i, c, kit.mix_hex(c, "#5a4a7a", 0.35), kit.mix_hex(c, "#ffffff", 0.45))
                for i, c in enumerate(st["pebbles"])]
        for side in (+1, -1):
            for x, y, z, rr, _ in wall_points(side):
                kit.sphere((x, y, z), rr * random.uniform(0.5, 0.62), random.choice(mats),
                           scale=(1.0, random.uniform(0.85, 1.1), random.uniform(0.6, 0.8)), segs=32)
    else:  # paper: each wall is four cut sheets stacked upwards, each casting a soft drop shadow on the one below
        for side, colors in ((+1, st["layers_n"]), (-1, st["layers_s"])):
            for i, c in enumerate(colors):
                mat = toon("paper_%d_%d" % (side, i), c, c, c, ao=0.1)
                seed = random.uniform(0, 6.3)
                offset = (0.0, 0.9, 1.9, 3.0)[i]
                z = 0.12 + i * 0.28
                kit.paper_sheet("paper_%d_%d" % (side, i), side, lambda x, o=offset, sd=seed: yc(x) + side * (
                    hw(x) + o + 0.28 * math.sin(x * 1.3 + sd) + 0.12 * math.sin(x * 3.1 + 2 * sd)), z, mat)
                kit.no_lines(kit.paper_sheet("paper_shadow_%d_%d" % (side, i), side, lambda x, o=offset, sd=seed: (
                    yc(x - 0.16) + side * (hw(x - 0.16) + o + 0.28 * math.sin((x - 0.16) * 1.3 + sd)
                                           + 0.12 * math.sin((x - 0.16) * 3.1 + 2 * sd))) - 0.24,
                    z - 0.06, shadow_mat))

    # Plants: anemones at the wall foot, kelp ribbons.
    glow_plants = st.get("glow_plants", False)
    anem = toon("anemone", st["anemone"], glow=scale_rgb(lin(st["anemone"]), 0.5) if glow_plants else (0, 0, 0))
    for ax, side in ((-9.6, -1), (1.2, +1), (6.2, -1), (-0.6, -1)):
        ay = yc(ax) + side * (hw(ax) - 0.25)
        kit.cyl((ax, ay, 0.15), 0.18, 0.3, anem)
        for k in range(9):
            a = k * 2 * math.pi / 9
            tip = (ax + math.cos(a) * 0.55, ay + math.sin(a) * 0.55, 0.45 + 0.15 * math.sin(3 * a))
            kit.tube([(ax, ay, 0.3), ((ax + tip[0]) / 2, (ay + tip[1]) / 2, 0.55), tip], 0.06, anem, taper=0.35)
    kelp = toon("kelp", st["kelp"], glow=scale_rgb(lin(st["kelp"]), 0.4) if glow_plants else (0, 0, 0))
    for kx, side in ((-4.6, +1), (4.6, +1), (-10.5, +1)):
        ky = yc(kx) + side * (hw(kx) + 0.1)
        for s in range(4):
            pts = [(kx + s * 0.25 + 0.4 * math.sin(i * 1.3 + s), ky - side * i * 0.55, 0.3 + i * 0.25) for i in range(6)]
            kit.tube(pts, 0.045, kelp, flat=0.09, taper=0.5)

    # The valve: a brass wheel lying on top of a pipe stub, the pipe running back into the north wall.
    vx = -2.6
    vy = yc(vx) + hw(vx) - 0.9
    brass = toon("brass", st["brass"], high="#fff1c4", ao=0.3)
    pipe = toon("pipe", st["pipe"], ao=0.4)
    if st.get("valve_pipe", True):
        kit.cyl((vx, vy + 1.3, 0.25), 0.22, 2.6, pipe, rot=(math.pi / 2, 0, 0))
    kit.cyl((vx, vy, 0.45), 0.24, 0.6, pipe)
    kit.cyl((vx, vy, 0.78), 0.3, 0.08, brass)
    kit.torus((vx, vy, 0.95), 0.62, 0.08, brass)
    for k in range(3):
        kit.cyl((vx, vy, 0.95), 0.05, 1.2, brass, rot=(math.pi / 2, 0, k * math.pi / 3))
    kit.cyl((vx, vy, 0.97), 0.13, 0.12, brass)
    kit.no_lines(kit.sphere((vx + 0.15, vy - 0.4, 0.03), 0.7, shadow_mat, scale=(1, 0.9, 0.05), segs=24))

    # The exit beacon: a glowing ring on the floor with a post.
    bglow = kit.glow("beacon", st["beacon"], 1.6)
    halo = kit.additive("beacon_halo", st["beacon"], 0.5, apex=EXIT, length=1.8)
    kit.torus((EXIT[0], EXIT[1], 0.05), 0.95, 0.07, bglow)
    kit.torus((EXIT[0], EXIT[1], 0.05), 1.55, 0.03, bglow)
    kit.no_lines(kit.cyl((EXIT[0], EXIT[1], 0.02), 1.6, 0.02, halo))
    kit.cyl((EXIT[0], EXIT[1], 0.6), 0.09, 1.2, toon("post", st["pipe"]))
    kit.sphere((EXIT[0], EXIT[1], 1.25), 0.17, bglow)

    # Jellyfish: a soft bell, a bright core, frilly rim and trailing tentacles.
    for i, ((jx, jy), c) in enumerate(zip(JELLIES, st["jelly"])):
        bell = toon("jelly_%d" % i, c, high="#ffffff", glow=scale_rgb(lin(c), 0.35 * st["jelly_glow"]), ao=0.1,
                    rings=(7.0, kit.mix_hex(c, "#ffffff", 0.6)))
        frill = toon("frill_%d" % i, kit.mix_hex(c, "#ffffff", 0.35), glow=scale_rgb(lin(c), 0.5 * st["jelly_glow"]),
                     ao=0.0)
        core = kit.glow("jelly_core_%d" % i, kit.mix_hex(c, "#ffffff", 0.5), 1.3 * st["jelly_glow"])
        kit.no_lines(kit.sphere((jx + 0.15, jy - 0.45, 0.03), 0.6, shadow_mat, scale=(1.1, 0.9, 0.05), segs=24))
        kit.sphere((jx, jy, 1.4), 0.6, bell, scale=(1, 1, 0.45))
        kit.sphere((jx - 0.04, jy + 0.02, 1.62), 0.16, core, scale=(1, 1, 0.5), segs=24)
        for k in range(10):  # scalloped rim
            a = k * 2 * math.pi / 10
            kit.sphere((jx + math.cos(a) * 0.6, jy + math.sin(a) * 0.6, 1.3), 0.13, frill, scale=(1, 1, 0.5), segs=12)
        drift = random.uniform(-0.6, 0.6) + math.pi
        for k in range(6):
            a = drift + (k - 2.5) * 0.18
            pts = [(jx + math.cos(a) * (0.35 + d * 0.5) + 0.08 * math.sin(d * 2.2 + k),
                    jy + math.sin(a) * (0.35 + d * 0.5) + 0.08 * math.cos(d * 2.0 + k), 1.15 - d * 0.12)
                   for d in range(6)]
            kit.tube(pts, 0.035, bell, taper=0.3)

    # The lurker: a dark lump at the wall foot, two eyes barely open.
    lk = toon("lurker", st["lurker"], ao=0.5)
    kit.blobs("lurker", [(LURKER[0], LURKER[1], 0.3, 1.0, (1.4, 1.0, 0.6)),
                         (LURKER[0] + 0.7, LURKER[1] - 0.2, 0.3, 0.8, (1.0, 1.0, 0.6))], lk, resolution=0.1)
    leye = kit.glow("lurker_eye", st["lurker_eye"], 1.3)
    for dx in (-0.25, 0.25):
        kit.sphere((LURKER[0] + 0.35 + dx, LURKER[1] + 0.55, 0.75), 0.11, leye, scale=(1.2, 0.5, 0.35), segs=16)

    # Robbie (stand-in): a round little sub with big eyes on top, side fins, a propeller and the lamp.
    rx, ry = ROBBIE
    body_c, accent_c, dome_c = st["robbie"]
    body = toon("robbie_body", body_c, high=dome_c, ao=0.25)
    accent = toon("robbie_accent", accent_c, ao=0.3)
    eye_w = toon("eye_white", st["eye"], lit=0.25, ao=0.0)
    pupil = toon("pupil", st["pupil"], lit=0.0, ao=0.0)
    lens = kit.glow("lens", st["lamp"][0], 2.5)
    parts = [kit.sphere((0, 0, 0), 0.62, body, scale=(1.15, 1.0, 0.85)),
             kit.sphere((-0.05, 0, 0.32), 0.42, body, scale=(1.0, 0.95, 0.7))]
    for side in (-1, 1):
        parts.append(kit.sphere((0.28, side * 0.24, 0.5), 0.17, eye_w, scale=(1, 1, 0.9), segs=24))
        parts.append(kit.sphere((0.36, side * 0.25, 0.6), 0.085, pupil, segs=16))
        parts.append(kit.sphere((-0.1, side * 0.66, -0.05), 0.24, accent, scale=(1.3, 0.5, 0.4), segs=24))
    parts.append(kit.cyl((0.78, 0, 0.0), 0.2, 0.18, accent, rot=(0, math.pi / 2, 0)))
    parts.append(kit.sphere((0.86, 0, 0.0), 0.15, lens, scale=(0.5, 1, 1), segs=24))
    parts.append(kit.cyl((-0.78, 0, 0.0), 0.08, 0.2, accent, rot=(0, math.pi / 2, 0)))
    for k in range(3):
        parts.append(kit.sphere((-0.9, 0, 0), 0.2, accent, scale=(0.12, 1.0, 0.35),
                                rot=(k * math.pi / 3, 0, 0), segs=16))
    parts.append(kit.cyl((-0.25, 0, 0.75), 0.025, 0.35, accent))
    parts.append(kit.sphere((-0.25, 0, 0.95), 0.07, kit.glow("antenna", st["beacon"], 2.0), segs=16))
    robbie = kit.group_under("robbie", parts, loc=(rx, ry, 1.0))
    robbie.rotation_euler = (0, 0, math.radians(LAMP_ANGLE))
    kit.no_lines(kit.sphere((rx + 0.2, ry - 0.45, 0.04), 0.75, shadow_mat, scale=(1.2, 0.95, 0.05), segs=24))

    # The lamp's beam, drawn as light on the water for styles that want it.
    if st["beam"]:
        bm = bmesh.new()
        a0 = math.radians(LAMP_ANGLE)
        half = math.radians(st["cone"][0])
        apex = (rx + math.cos(a0) * 0.85, ry + math.sin(a0) * 0.85)
        verts = [bm.verts.new((apex[0], apex[1], 1.0))]
        steps = 24
        for k in range(steps + 1):
            a = a0 - half + 2 * half * k / steps
            verts.append(bm.verts.new((apex[0] + math.cos(a) * st["cone"][2], apex[1] + math.sin(a) * st["cone"][2],
                                       0.9)))
        for k in range(steps):
            bm.faces.new((verts[0], verts[k + 1], verts[k + 2]))
        me = bpy.data.meshes.new("beam")
        bm.to_mesh(me)
        ob = bpy.data.objects.new("beam", me)
        bpy.context.scene.collection.objects.link(ob)
        kit.no_lines(ob)
        me.materials.append(kit.additive("beam", st["beam"][0], st["beam"][1], apex=apex,
                                         length=st["cone"][2], cone=(LAMP_ANGLE, st["cone"][0], st["cone"][0] * 0.8)))

    # Marine snow drifting above everything.
    snow = kit.glow("snow", st["snow"][0], st["snow"][1])
    for _ in range(150):
        x = random.uniform(-13, 13)
        kit.no_lines(kit.sphere((x, random.uniform(-9, 9), random.uniform(2.2, 3.2)), random.uniform(0.02, 0.05),
                                snow, segs=8))

    kit.ortho_camera(target=(0.0, 0.3, 0.0), tilt_deg=24.0, scale=24.0)
    if st["lines"]:
        kit.outlines(st["lines"][0], st["lines"][1])
    return st


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:]
    sid, out = int(argv[0]), argv[1]
    samples = int(argv[2]) if len(argv) > 2 else 40
    st = build(sid)
    kit.render(out, samples=samples, background=st["background"])
