"""The operator's console in Blender: the desk plate and the parts that move, at 2x the game's 1280x720.

Everything is placed from game/content/console_layout.json (screen pixels), so the Godot console lines up with the art.
One Blender unit is 100 screen pixels; x to the right, screen y down is Blender -y, and the camera looks down -z
at the panel face (z = 0). Materials are physically lit (Cycles, CPU): enamelled steel, brass, bakelite, rubber.

  blender -b --factory-startup -P tools/art/console_scene.py -- <out_dir> [plate|sprites|all] [preview]

Writes plate.png (2560x1440) and the sprites (reel.png, knob_*.png, lever_*.png, ...) into out_dir.
"""
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
L = json.load(open(os.path.join(ROOT, "game/content/console_layout.json")))
S = 2  # render scale: pixels per screen pixel

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else os.path.join(ROOT, "out/art/console")
WHAT = argv[1] if len(argv) > 1 else "all"
PREVIEW = "preview" in argv
GRIMY = "grimy" in argv      # art-direction variant B: lived-in, patched, rusting, cabled
os.makedirs(OUT, exist_ok=True)


# ------------------------------------------------------------------ basics

def lin(hexs):
    h = hexs.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c) + (1.0,)


def P(x, y):
    """Screen pixels to Blender x, y."""
    return x / 100.0, -y / 100.0


def link(tree, a, b):
    tree.links.new(a, b)


def node(tree, kind, **kw):
    n = tree.nodes.new(kind)
    for k, v in kw.items():
        setattr(n, k, v)
    return n


def math_node(tree, op, a, b=None):
    n = node(tree, "ShaderNodeMath", operation=op)
    for i, v in enumerate((a, b)):
        if v is None:
            continue
        if isinstance(v, bpy.types.NodeSocket):
            link(tree, v, n.inputs[i])
        else:
            n.inputs[i].default_value = v
    return n.outputs[0]


def mix_color(tree, fac, a, b):
    n = node(tree, "ShaderNodeMix", data_type="RGBA")
    for sock, v in ((n.inputs[0], fac), (n.inputs[6], a), (n.inputs[7], b)):
        if isinstance(v, bpy.types.NodeSocket):
            link(tree, v, sock)
        else:
            sock.default_value = v
    return n.outputs[2]


_mats = {}


def material(name, base, metal=0.0, rough=0.5, wear=None, grime=0.6, streaks=0.0, bump=0.15, noise_scale=40.0,
             coat=0.0, emit=None, emit_strength=0.0, bevel=0.012, spots=0.0):
    """A hard-surface material: two-tone noise on the base colour, rounded edges from the Bevel node, worn edges
    showing `wear` (another colour, metallic), grime in the crevices (AO), vertical damp streaks, a fine bump."""
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    t = m.node_tree
    t.nodes.clear()
    out = node(t, "ShaderNodeOutputMaterial")
    bsdf = node(t, "ShaderNodeBsdfPrincipled")
    link(t, bsdf.outputs[0], out.inputs[0])
    tex = node(t, "ShaderNodeTexCoord")
    noise = node(t, "ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = noise_scale
    noise.inputs["Detail"].default_value = 6.0
    link(t, tex.outputs["Object"], noise.inputs["Vector"])
    base_c = lin(base)
    dark_c = tuple(c * 0.62 for c in base_c[:3]) + (1.0,)
    col = mix_color(t, noise.outputs["Fac"], dark_c, base_c)
    # Damp streaks: noise stretched along y.
    if streaks > 0:
        mapn = node(t, "ShaderNodeMapping")
        mapn.inputs["Scale"].default_value = (14.0, 0.6, 1.0)
        link(t, tex.outputs["Object"], mapn.inputs["Vector"])
        sn = node(t, "ShaderNodeTexNoise")
        sn.inputs["Scale"].default_value = 3.0
        sn.inputs["Detail"].default_value = 3.0
        link(t, mapn.outputs[0], sn.inputs["Vector"])
        sf = math_node(t, "MULTIPLY", math_node(t, "SUBTRACT", sn.outputs["Fac"], 0.45), streaks * 3.0)
        sf = math_node(t, "MINIMUM", math_node(t, "MAXIMUM", sf, 0.0), 1.0)
        col = mix_color(t, sf, col, (0.0, 0.0, 0.0, 1.0))
    # Grime in the crevices.
    ao = node(t, "ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = 0.08
    ao.samples = 8
    g = math_node(t, "MULTIPLY", math_node(t, "SUBTRACT", 1.0, ao.outputs["AO"]), grime)
    col = mix_color(t, g, col, (0.005, 0.004, 0.003, 1.0))
    # Spots (rust bloom, condensation marks).
    if spots > 0:
        vor = node(t, "ShaderNodeTexVoronoi")
        vor.inputs["Scale"].default_value = 90.0
        link(t, tex.outputs["Object"], vor.inputs["Vector"])
        sp = math_node(t, "LESS_THAN", vor.outputs["Distance"], 0.08)
        sp = math_node(t, "MULTIPLY", sp, math_node(t, "GREATER_THAN", noise.outputs["Fac"], 0.55))
        col = mix_color(t, math_node(t, "MULTIPLY", sp, spots), col, lin("#3a2414"))
    metal_s = metal
    rough_s = rough
    # Rounded edges and edge wear.
    bev = node(t, "ShaderNodeBevel")
    bev.inputs["Radius"].default_value = bevel
    bev.samples = 6
    normal = bev.outputs[0]
    if bump > 0:
        bn = node(t, "ShaderNodeBump")
        bn.inputs["Strength"].default_value = bump
        bn.inputs["Distance"].default_value = 0.002
        n2 = node(t, "ShaderNodeTexNoise")
        n2.inputs["Scale"].default_value = noise_scale * 6
        n2.inputs["Detail"].default_value = 4.0
        link(t, tex.outputs["Object"], n2.inputs["Vector"])
        link(t, n2.outputs["Fac"], bn.inputs["Height"])
        link(t, bev.outputs[0], bn.inputs["Normal"])
        normal = bn.outputs[0]
    link(t, normal, bsdf.inputs["Normal"])
    if wear is not None:
        geo = node(t, "ShaderNodeNewGeometry")
        dot = node(t, "ShaderNodeVectorMath", operation="DOT_PRODUCT")
        link(t, bev.outputs[0], dot.inputs[0])
        link(t, geo.outputs["Normal"], dot.inputs[1])
        edge = math_node(t, "SUBTRACT", 1.0, dot.outputs["Value"])
        edge = math_node(t, "MULTIPLY", edge, 9.0)
        edge = math_node(t, "MULTIPLY", edge, math_node(t, "ADD", noise.outputs["Fac"], 0.2))
        edge = math_node(t, "MINIMUM", math_node(t, "MAXIMUM", math_node(t, "SUBTRACT", edge, 0.25), 0.0), 1.0)
        col = mix_color(t, edge, col, lin(wear))
        mt = math_node(t, "ADD", metal, math_node(t, "MULTIPLY", edge, 1.0 - metal))
        link(t, mt, bsdf.inputs["Metallic"])
        rt = math_node(t, "SUBTRACT", rough, math_node(t, "MULTIPLY", edge, 0.25))
        link(t, rt, bsdf.inputs["Roughness"])
    else:
        bsdf.inputs["Metallic"].default_value = metal_s
        rn = math_node(t, "ADD", rough_s, math_node(t, "MULTIPLY", math_node(t, "SUBTRACT", noise.outputs["Fac"], 0.5), 0.2))
        link(t, rn, bsdf.inputs["Roughness"])
    link(t, col, bsdf.inputs["Base Color"])
    if coat > 0:
        bsdf.inputs["Coat Weight"].default_value = coat
        bsdf.inputs["Coat Roughness"].default_value = 0.12
    if emit is not None:
        bsdf.inputs["Emission Color"].default_value = lin(emit)
        bsdf.inputs["Emission Strength"].default_value = emit_strength
    _mats[name] = m
    return m


def emission(name, color, strength):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    t = m.node_tree
    t.nodes.clear()
    out = node(t, "ShaderNodeOutputMaterial")
    e = node(t, "ShaderNodeEmission")
    e.inputs["Color"].default_value = lin(color)
    e.inputs["Strength"].default_value = strength
    link(t, e.outputs[0], out.inputs[0])
    _mats[name] = m
    return m


def pmat(name, base, metal=0.0, rough=0.7, kind=None, scale=30.0, strength=0.5, chip=None, chip_metal=1.0,
         chip_amount=0.0, grime=0.8, axis="Z"):
    """A worn hard-surface material. kind: None, 'knurl' (diamond knurling), 'wrap' (tape or leather wound round),
    'crackle' (crackle enamel), 'flute' (vertical flutes), 'hammer' (hammered). chip: the colour under worn paint."""
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    t = m.node_tree
    t.nodes.clear()
    out = node(t, "ShaderNodeOutputMaterial")
    bsdf = node(t, "ShaderNodeBsdfPrincipled")
    link(t, bsdf.outputs[0], out.inputs[0])
    tc = node(t, "ShaderNodeTexCoord")
    noise = node(t, "ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 18.0
    noise.inputs["Detail"].default_value = 8.0
    link(t, tc.outputs["Object"], noise.inputs["Vector"])
    bc = lin(base)
    col = mix_color(t, noise.outputs["Fac"], tuple(c * 0.6 for c in bc[:3]) + (1.0,), bc)
    metal_s = metal
    # Paint worn through to what is under it, at the edges and in patches.
    if chip is not None and chip_amount > 0:
        n2 = node(t, "ShaderNodeTexNoise")
        n2.inputs["Scale"].default_value = 9.0
        n2.inputs["Detail"].default_value = 12.0
        n2.inputs["Roughness"].default_value = 0.7
        link(t, tc.outputs["Object"], n2.inputs["Vector"])
        geo = node(t, "ShaderNodeNewGeometry")
        bev = node(t, "ShaderNodeBevel")
        bev.inputs["Radius"].default_value = 0.02
        dot = node(t, "ShaderNodeVectorMath", operation="DOT_PRODUCT")
        link(t, bev.outputs[0], dot.inputs[0])
        link(t, geo.outputs["Normal"], dot.inputs[1])
        edge = math_node(t, "MULTIPLY", math_node(t, "SUBTRACT", 1.0, dot.outputs["Value"]), 14.0)
        f = math_node(t, "ADD", edge, math_node(t, "MULTIPLY", math_node(t, "SUBTRACT", n2.outputs["Fac"], 0.62 - 0.2 * chip_amount), 6.0))
        f = math_node(t, "MINIMUM", math_node(t, "MAXIMUM", f, 0.0), 1.0)
        col = mix_color(t, f, col, lin(chip))
        mt = math_node(t, "ADD", metal, math_node(t, "MULTIPLY", f, chip_metal - metal))
        link(t, mt, bsdf.inputs["Metallic"])
        link(t, math_node(t, "SUBTRACT", rough, math_node(t, "MULTIPLY", f, 0.2)), bsdf.inputs["Roughness"])
    else:
        bsdf.inputs["Metallic"].default_value = metal_s
        link(t, math_node(t, "ADD", rough, math_node(t, "MULTIPLY", math_node(t, "SUBTRACT", noise.outputs["Fac"], 0.5), 0.25)),
                bsdf.inputs["Roughness"])
    # Grime in the crevices.
    ao = node(t, "ShaderNodeAmbientOcclusion")
    ao.inputs["Distance"].default_value = 0.06
    col = mix_color(t, math_node(t, "MULTIPLY", math_node(t, "SUBTRACT", 1.0, ao.outputs["AO"]), grime), col, (0.01, 0.008, 0.006, 1.0))
    link(t, col, bsdf.inputs["Base Color"])
    # The pattern, as a bump.
    height = None
    if kind == "knurl":
        a = node(t, "ShaderNodeTexWave", wave_type="BANDS", bands_direction="DIAGONAL")
        a.inputs["Scale"].default_value = scale
        link(t, tc.outputs["Object"], a.inputs["Vector"])
        mp = node(t, "ShaderNodeMapping")
        mp.inputs["Scale"].default_value = (-1.0, 1.0, 1.0)
        link(t, tc.outputs["Object"], mp.inputs["Vector"])
        b = node(t, "ShaderNodeTexWave", wave_type="BANDS", bands_direction="DIAGONAL")
        b.inputs["Scale"].default_value = scale
        link(t, mp.outputs[0], b.inputs["Vector"])
        height = math_node(t, "MULTIPLY", a.outputs["Fac"], b.outputs["Fac"])
    elif kind == "wrap":
        a = node(t, "ShaderNodeTexWave", wave_type="BANDS", bands_direction=axis)
        a.inputs["Scale"].default_value = scale
        a.inputs["Distortion"].default_value = 1.5
        a.inputs["Detail Scale"].default_value = 2.0
        link(t, tc.outputs["Object"], a.inputs["Vector"])
        height = a.outputs["Fac"]
    elif kind == "flute":
        a = node(t, "ShaderNodeTexWave", wave_type="RINGS", rings_direction="SPHERICAL")
        a.inputs["Scale"].default_value = scale
        link(t, tc.outputs["Object"], a.inputs["Vector"])
        height = a.outputs["Fac"]
    elif kind == "crackle":
        v = node(t, "ShaderNodeTexVoronoi", feature="DISTANCE_TO_EDGE")
        v.inputs["Scale"].default_value = scale
        link(t, tc.outputs["Object"], v.inputs["Vector"])
        height = math_node(t, "MINIMUM", math_node(t, "MULTIPLY", v.outputs["Distance"], 12.0), 1.0)
    elif kind == "hammer":
        v = node(t, "ShaderNodeTexVoronoi")
        v.inputs["Scale"].default_value = scale
        link(t, tc.outputs["Object"], v.inputs["Vector"])
        height = v.outputs["Distance"]
    bev = node(t, "ShaderNodeBevel")
    bev.inputs["Radius"].default_value = 0.012
    normal = bev.outputs[0]
    if height is not None:
        bump = node(t, "ShaderNodeBump")
        bump.inputs["Strength"].default_value = strength
        bump.inputs["Distance"].default_value = 0.01
        link(t, height, bump.inputs["Height"])
        link(t, normal, bump.inputs["Normal"])
        normal = bump.outputs[0]
    link(t, normal, bsdf.inputs["Normal"])
    _mats[name] = m
    return m


def star(cx, cy, r_out, r_in, n, rot=0.0):
    pts = []
    for i in range(n * 2):
        a = math.pi * i / n + rot
        r = r_out if i % 2 == 0 else r_in
        pts.append(P(cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def scallops(cx, cy, r, bumps, depth, n=128):
    return [P(cx + (r + depth * max(0.0, math.cos(bumps * 2 * math.pi * i / n)) ** 3) * math.cos(2 * math.pi * i / n),
                 cy + (r + depth * max(0.0, math.cos(bumps * 2 * math.pi * i / n)) ** 3) * math.sin(2 * math.pi * i / n)) for i in range(n)]


def M():
    """The console's materials: the base set, the lived-in overrides (GRIMY), and over both the Admiralty style
    Albert chose on 2026-10-26: ship's bronze gone dark, navy grey-green enamel, and valve red, chipped to the bronze,
    on everything the hand works. Matte throughout."""
    return dict(_m_grimy() if GRIMY else _m_base(), **_m_admiralty())


def _m_admiralty():
    red = pmat("valve_red", "#74170e", metal=0.0, rough=0.72, chip="#6e5430", chip_amount=0.5)
    return {
        "enamel": pmat("navy", "#323a36", metal=0.0, rough=0.8, kind="hammer", scale=6, strength=0.12, chip="#55463a",
                       chip_amount=0.18, grime=0.95),
        "enamel_pale": pmat("navy_pale", "#3e4741", metal=0.0, rough=0.82, kind="hammer", scale=5, strength=0.14,
                            chip="#5e4c3c", chip_amount=0.25, grime=0.95),
        "enamel_dark": pmat("navy_dark", "#262c29", metal=0.0, rough=0.8, chip="#4a3d31", chip_amount=0.2),
        "brass": pmat("bronze", "#5b4426", metal=1.0, rough=0.62, kind="hammer", scale=40, strength=0.12, chip="#3f5a48",
                      chip_metal=0.0, chip_amount=0.3),
        "brass_dark": pmat("bronze_dark", "#3e2e1a", metal=0.9, rough=0.68, kind="hammer", scale=40, strength=0.1),
        "steel": pmat("galv", "#4d4b45", metal=0.8, rough=0.62, kind="hammer", scale=60, strength=0.08),
        "chrome": pmat("nickel_dull", "#77736a", metal=1.0, rough=0.48),
        # Name plates are kept rubbed bright, so their engraving can be read.
        "plaque": pmat("bronze_rubbed", "#8a6a3c", metal=1.0, rough=0.45, chip="#4a3a22", chip_metal=1.0, chip_amount=0.15),
        "red": red, "red_ball": red, "red_enamel": red, "red_bakelite": red,
        "bakelite": pmat("bakelite_matte", "#24140d", rough=0.6),
    }


def _m_grimy():
        return dict(_m_base(), **{
            "enamel": material("enamel_g", "#232b26", rough=0.6, wear="#9a8e7a", grime=0.95, streaks=0.95, noise_scale=9,
                               coat=0.15, spots=1.8, bump=0.35),
            "enamel_pale": material("enamel_pale", "#3a423b", rough=0.7, wear="#a89c84", grime=0.95, streaks=1.0,
                                    noise_scale=7, spots=1.4, bump=0.4),
            "enamel_rust": material("enamel_rust", "#4b2618", rough=0.85, wear="#2a1a10", grime=0.9, streaks=0.8,
                                    noise_scale=11, spots=2.0, bump=0.6),
            "brass": material("brass_g", "#7e6136", metal=1.0, rough=0.55, grime=1.0, noise_scale=22, bevel=0.008, spots=1.4),
            "wall": material("wall_g", "#0b0e0d", rough=0.8, grime=1.0, streaks=1.0, noise_scale=4, bump=0.5),
            "cloth": material("cloth", "#3c3a33", rough=0.95, grime=0.8, noise_scale=140, bump=0.7),
        })


def _m_base():
    return {
        "enamel": material("enamel", "#1e2623", metal=0.0, rough=0.52, wear="#8a8478", grime=0.75, streaks=0.35,
                           noise_scale=18, coat=0.25, spots=0.6),
        "enamel_dark": material("enamel_dark", "#1b2220", rough=0.6, wear="#6e6a62", grime=0.8, streaks=0.5,
                                noise_scale=14, spots=0.4),
        "wall": material("wall", "#0d1110", rough=0.7, grime=0.9, streaks=0.8, noise_scale=6, bump=0.3),
        "brass": material("brass", "#9a7843", metal=1.0, rough=0.42, grime=0.95, noise_scale=30, bevel=0.008, spots=0.5),
        "brass_dark": material("brass_dark", "#7d6235", metal=1.0, rough=0.42, grime=0.9, noise_scale=30, bevel=0.008),
        "steel": material("steel", "#8b9192", metal=1.0, rough=0.3, grime=0.8, noise_scale=40, bevel=0.006),
        "chrome": material("chrome", "#c9ced0", metal=1.0, rough=0.16, grime=0.6, noise_scale=60, bevel=0.004, bump=0.05),
        "bakelite": material("bakelite", "#2b1810", rough=0.28, grime=0.5, noise_scale=25, coat=0.6, bevel=0.01, bump=0.05),
        "bakelite_black": material("bakelite_black", "#0d0c0b", rough=0.3, grime=0.4, noise_scale=25, coat=0.5,
                                   bevel=0.008, bump=0.04),
        "rubber": material("rubber", "#0a0a0a", rough=0.85, grime=0.3, noise_scale=80, bump=0.3),
        "recess": material("recess", "#050606", rough=0.9, grime=0.95, noise_scale=10, bump=0.05),
        "felt": material("felt", "#16211b", rough=0.98, grime=0.9, noise_scale=120, bump=0.6),
        "red": material("red", "#8e1f16", rough=0.35, wear="#b9b2a6", grime=0.6, noise_scale=20, coat=0.4),
        "red_ball": material("red_ball", "#a2251b", rough=0.22, grime=0.3, noise_scale=20, coat=0.8, bevel=0.004),
        # Red marks everything the hand works: rims, grips, knobs, key tops. Worn to the brass where it's held.
        "red_enamel": material("red_enamel", "#9a2418", rough=0.4, wear="#b08a4e", grime=0.55, noise_scale=26, coat=0.35,
                               bevel=0.012),
        "red_bakelite": material("red_bakelite", "#8a1e14", rough=0.26, grime=0.35, noise_scale=25, coat=0.7, bevel=0.01,
                                 bump=0.05),
        "ivory": material("ivory", "#cfc4a8", rough=0.45, grime=0.6, noise_scale=30, bevel=0.004),
        "cork": material("cork", "#6a4a2c", rough=0.9, grime=0.6, noise_scale=160, bump=0.8),
        "leather": material("leather", "#3b2417", rough=0.6, wear="#6e4a30", grime=0.7, noise_scale=90, bump=0.4),
        "wood": material("wood", "#3a2516", rough=0.55, grime=0.6, noise_scale=12, coat=0.3),
        "paper": material("paper", "#b9b19c", rough=0.9, grime=0.3, noise_scale=50, bump=0.1),
        "glow_green": emission("glow_green", "#38ff8a", 0.6),
        "glow_amber": emission("glow_amber", "#ffb050", 0.8),
        "glow_cyan": emission("glow_cyan", "#5fe8ff", 0.5),
    }


# ------------------------------------------------------------------ geometry

def _obj(name, mesh, mat, coll=None):
    o = bpy.data.objects.new(name, mesh)
    (coll or bpy.context.scene.collection).objects.link(o)
    if mat is not None:
        o.data.materials.append(mat)
    return o


def rr_outline(x, y, w, h, r, segs=8):
    """Rounded rectangle outline in screen pixels -> list of Blender (x, y)."""
    r = min(r, w / 2, h / 2)
    pts = []
    corners = [(x + w - r, y + r, -90), (x + w - r, y + h - r, 0), (x + r, y + h - r, 90), (x + r, y + r, 180)]
    for cx, cy, a0 in corners:
        for i in range(segs + 1):
            a = math.radians(a0 + 90 * i / segs)
            pts.append(P(cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def prism(name, outline, z0, z1, mat, bevel=0.0, holes=(), coll=None):
    """Extrude a 2D outline (Blender xy) from z0 to z1; optional inner outlines are cut through as holes."""
    bm = bmesh.new()

    def ring(pts, z):
        return [bm.verts.new((px, py, z)) for px, py in pts]

    rings = [(outline, False)] + [(h, True) for h in holes]
    tops, bots = [], []
    for pts, is_hole in rings:
        b = ring(pts, z0)
        t = ring(pts, z1)
        n = len(pts)
        for i in range(n):
            j = (i + 1) % n
            f = bm.faces.new((b[i], b[j], t[j], t[i]))
            if is_hole:
                f.normal_flip()
        tops.append(t)
        bots.append(b)
    if not holes:
        bm.faces.new(tops[0])
        f = bm.faces.new(list(reversed(bots[0])))
    else:
        # Bridge the outer and inner rings with a triangulated face (via edgenet fill).
        edges = []
        for t in tops:
            n = len(t)
            edges += [bm.edges.get((t[i], t[(i + 1) % n])) or bm.edges.new((t[i], t[(i + 1) % n])) for i in range(n)]
        bmesh.ops.triangle_fill(bm, use_beauty=True, use_dissolve=False, edges=edges)
        edges = []
        for b in bots:
            n = len(b)
            edges += [bm.edges.get((b[i], b[(i + 1) % n])) or bm.edges.new((b[i], b[(i + 1) % n])) for i in range(n)]
        bmesh.ops.triangle_fill(bm, use_beauty=True, use_dissolve=False, edges=edges)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = _obj(name, me, mat, coll)
    if bevel > 0:
        m = o.modifiers.new("bevel", "BEVEL")
        m.width = bevel
        m.segments = 3
        m.limit_method = "ANGLE"
        m.angle_limit = math.radians(40)
        m.harden_normals = False
    for p in o.data.polygons:
        p.use_smooth = False
    return o


def slab(name, rect, z0, z1, mat, r=6, bevel=0.02, coll=None):
    x, y, w, h = rect[:4]
    return prism(name, rr_outline(x, y, w, h, r), z0, z1, mat, bevel, coll=coll)


def frame(name, outer, inner, z0, z1, mat, r_out=10, r_in=8, bevel=0.02, coll=None):
    return prism(name, rr_outline(*outer[:4], r_out), z0, z1, mat, bevel,
                 holes=[rr_outline(*inner[:4], r_in)], coll=coll)


def circle_pts(cx, cy, r, n=64):
    return [P(cx + r * math.cos(2 * math.pi * i / n), cy + r * math.sin(2 * math.pi * i / n)) for i in range(n)]


def disc(name, cx, cy, r, z0, z1, mat, bevel=0.01, n=64, coll=None):
    return prism(name, circle_pts(cx, cy, r, n), z0, z1, mat, bevel, coll=coll)


def ring_obj(name, cx, cy, r_out, r_in, z0, z1, mat, bevel=0.01, n=96, coll=None):
    return prism(name, circle_pts(cx, cy, r_out, n), z0, z1, mat, bevel, holes=[circle_pts(cx, cy, r_in, n)], coll=coll)


def uv_sphere(name, cx, cy, z, r, mat, flat=1.0, coll=None):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=24, v_segments=12, radius=r / 100.0)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = _obj(name, me, mat, coll)
    x, y = P(cx, cy)
    o.location = (x, y, z)
    o.scale = (1, 1, flat)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def cylinder_x(name, x0, x1, cy, r, z, mat, coll=None, n=48):
    """A cylinder lying along screen x, from x0 to x1, at screen y cy, radius r (pixels), axis at height z."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=n, radius1=r / 100, radius2=r / 100, depth=(x1 - x0) / 100)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = _obj(name, me, mat, coll)
    x, y = P((x0 + x1) / 2, cy)
    o.location = (x, y, z)
    o.rotation_euler = (0, math.radians(90), 0)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def cylinder_y(name, y0, y1, cx, r, z, mat, coll=None, n=48):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=n, radius1=r / 100, radius2=r / 100, depth=(y1 - y0) / 100)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = _obj(name, me, mat, coll)
    x, y = P(cx, (y0 + y1) / 2)
    o.location = (x, y, z)
    o.rotation_euler = (math.radians(90), 0, 0)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def rivet(cx, cy, mat, r=2.6, z=0.0, coll=None):
    return uv_sphere("rivet", cx, cy, z, r, mat, flat=0.45, coll=coll)


def screw(cx, cy, mat, r=3.2, z=0.0, angle=0.0, coll=None):
    o = uv_sphere("screw", cx, cy, z, r, mat, flat=0.35, coll=coll)
    # The slot: a thin dark box across the head.
    s = slab("slot", (cx - r, cy - 0.45, 2 * r, 0.9), z + 0.006, z + 0.016, M()["recess"], r=0.3, bevel=0, coll=coll)
    s.rotation_euler = (0, 0, angle)
    return o


def rivets_around(rect, mat, step=46, inset=7, z=0.0, coll=None):
    x, y, w, h = rect[:4]
    nx = max(2, int(w / step) + 1)
    ny = max(2, int(h / step) + 1)
    for i in range(nx):
        px = x + inset + (w - 2 * inset) * i / (nx - 1)
        rivet(px, y + inset, mat, z=z, coll=coll)
        rivet(px, y + h - inset, mat, z=z, coll=coll)
    for j in range(1, ny - 1):
        py = y + inset + (h - 2 * inset) * j / (ny - 1)
        rivet(x + inset, py, mat, z=z, coll=coll)
        rivet(x + w - inset, py, mat, z=z, coll=coll)


def housing(name, rect, r=8, depth=0.22, rivet_step=46, mats=None):
    """A machine's housing: an enamelled steel slab with a bevelled lip and riveted edges."""
    mats = mats or M()
    x, y, w, h = rect[:4]
    mat = mats["enamel"]
    if GRIMY:
        # Panels replaced over the years, none quite matching.
        mat = {"recorder": mats["enamel_pale"], "trials": mats["enamel_pale"], "chute": mats["enamel_rust"],
               "shift": mats["enamel_pale"]}.get(name, mat)
    slab(name, rect, -depth, 0.0, mat, r=r, bevel=0.03)
    rivets_around(rect, mats["steel"], step=rivet_step, z=0.0)


def recess(name, rect, r=4, depth=0.06, mat=None):
    x, y, w, h = rect[:4]
    return slab(name, rect, -depth, 0.002, mat or M()["recess"], r=r, bevel=0.004)


def plaque(rect, mats=None):
    mats = mats or M()
    x, y, w, h = rect[:4]
    slab("plaque", (x, y, w, h), 0.0, 0.025, mats.get("plaque", mats["brass"]), r=3, bevel=0.006)
    for px in (x + 5, x + w - 5):
        screw(px, y + h / 2, mats["brass_dark"], r=2.0, z=0.025, angle=0.7)


# ------------------------------------------------------------------ the plate

def build_plate():
    mats = M()
    W, H = 1280, 720
    # The bulkhead behind everything, with a seam grid and a few pipes showing in the gaps.
    slab("bulkhead", (-20, -20, W + 40, H + 40), -0.6, -0.3, mats["wall"], r=0, bevel=0)
    for gx in range(0, W, 160):
        slab("seam", (gx, 0, 3, H), -0.3, -0.29, mats["recess"], r=0, bevel=0)
    cylinder_y("pipe_v", -10, 730, 645, 6, -0.26, mats["brass_dark"])
    cylinder_x("pipe_h", -10, 1290, 130, 5, -0.27, mats["steel"])
    cylinder_x("pipe_h2", -10, 1290, 475, 4, -0.27, mats["brass_dark"])

    # Scope.
    sc = L["scope"]
    housing("scope", sc, r=14, rivet_step=60)
    scr = L["screen"]
    sx, sy, sw, sh = scr
    frame("scope_bezel", (sx - 10, sy - 10, sw + 20, sh + 20), scr, 0.0, 0.07, mats["brass"], r_out=26, r_in=22, bevel=0.012)
    frame("scope_lip", (sx - 4, sy - 4, sw + 8, sh + 8), scr, 0.0, 0.09, mats["bakelite_black"], r_out=24, r_in=22, bevel=0.01)
    recess("screen_well", (sx, sy, sw, sh), r=22, depth=0.12)
    slab("screen_glow", (sx + 6, sy + 6, sw - 12, sh - 12), -0.11, -0.1, mats["glow_green"], r=18, bevel=0)
    for (cx, cy) in ((sc[0] + 14, sc[1] + 14), (sc[0] + sc[2] - 14, sc[1] + 14), (sc[0] + 14, sc[1] + sc[3] - 14),
                     (sc[0] + sc[2] - 14, sc[1] + sc[3] - 14)):
        screw(cx, cy, mats["brass_dark"], r=4.5, angle=0.4)
    plaque(L["plaques"]["scope"][:4])
    # Bottom rim: the LIVE lamp socket on the left, the GAIN knob (sound) on the right.
    ring_obj("live_socket", 44, 390, 6, 3.5, 0.0, 0.03, mats["chrome"])
    disc("live_lamp", 44, 390, 3.5, -0.01, 0.01, mats["recess"])
    for i, kx in enumerate((566, 600)):
        disc("rim_knob_skirt", kx, 390, 8, 0.0, 0.03, mats["brass_dark"])
        disc("rim_knob", kx, 390, 6, 0.03, 0.09, mats["red_bakelite" if kx == 566 else "bakelite"], bevel=0.02)
    # The magnify toggle's bed.
    recess("magnify_bed", L["magnify"], r=4, depth=0.02)
    mgx, mgy, mgw, mgh = L["magnify"]
    slab("magnify_paint", (mgx + 2, mgy + 2, mgw - 4, mgh - 4), -0.02, -0.012, mats["red_enamel"], r=3, bevel=0.003)

    # Wire recorder.
    rc = L["recorder"]
    housing("recorder", rc, r=10)
    for key in ("reel_a", "reel_b"):
        x, y, w, h = L[key]
        cx, cy = x + w / 2, y + h / 2
        disc("reel_well", cx, cy, w / 2 + 2, -0.05, 0.002, mats["recess"])
        ring_obj("reel_rim", cx, cy, w / 2 + 5, w / 2 + 1, 0.0, 0.02, mats["steel"])
    tx, ty, tw, th = L["track"]
    recess("track", L["track"], r=3, depth=0.04)
    slab("track_rail_top", (tx - 4, ty - 4, tw + 8, 3), 0.0, 0.02, mats["brass"], r=1, bevel=0.003)
    slab("track_rail_bot", (tx - 4, ty + th + 1, tw + 8, 3), 0.0, 0.02, mats["brass"], r=1, bevel=0.003)
    recess("keys_bed", L["keys"], r=4, depth=0.03, mat=mats["felt"])
    kx, ky, kw, kh = L["speed_knob"]
    disc("speed_escutcheon", kx + kw / 2, ky + kh / 2, kw / 2 - 1, 0.0, 0.012, mats["enamel_dark"], bevel=0.004)
    ring_obj("speed_ring", kx + kw / 2, ky + kh / 2, kw / 2 + 1, kw / 2 - 3, 0.0, 0.02, mats["brass"], bevel=0.004)
    plaque(L["plaques"]["recorder"][:4])

    # Teleprinter.
    tp = L["teleprinter"]
    housing("teleprinter", tp, r=10)
    px, py, pw, ph = L["paper"]
    recess("paper_well", (px - 4, py - 4, pw + 8, ph + 20), r=6, depth=0.08)
    bx, by, bw, bh = L["binder"]
    recess("binder_shelf", (bx - 4, by - 4, bw + 8, bh + 8), r=5, depth=0.06)
    slab("binder", (bx + 4, by + 2, bw - 8, bh - 4), -0.04, 0.05, mats["leather"], r=4, bevel=0.01)
    for i in range(3):
        cylinder_x("binder_ring", bx + 4, bx + 12, by + 16 + i * 25, 3, 0.05, mats["brass"])
    slab("binder_label", (bx + 26, by + 22, bw - 40, 30), 0.05, 0.065, mats["brass"], r=2, bevel=0.003)
    slab("binder_label_card", (bx + 29, by + 25, bw - 46, 24), 0.065, 0.068, mats["paper"], r=1, bevel=0)
    # A red ribbon marker hanging out of the binder, to pull it open by.
    slab("binder_ribbon", (bx + bw - 26, by + bh - 10, 9, 24), 0.03, 0.04, mats["red_enamel"], r=1, bevel=0.002)
    wx, wy, ww, wh = L["wall"]
    slab("wall_frame", (wx, wy, ww, wh), -0.03, 0.03, mats["wood"], r=3, bevel=0.008)
    slab("wall_cork", (wx + 6, wy + 6, ww - 12, wh - 12), -0.02, 0.032, mats["cork"], r=1, bevel=0)
    for i, (sx2, sy2, sw2, sh2, rot) in enumerate(((wx + 14, wy + 12, 40, 22, 0.08), (wx + 58, wy + 16, 38, 20, -0.12),
                                                   (wx + 18, wy + 44, 44, 18, -0.05), (wx + 64, wy + 46, 34, 26, 0.1))):
        o = slab("wall_tape", (sx2, sy2, sw2, sh2), 0.032, 0.036, mats["paper"], r=0.5, bevel=0)
        uv_sphere("pin", sx2 + sw2 / 2, sy2 + 3, 0.04, 2.4, mats["red_ball"], flat=0.6)
    # The platen and its cover sit over the paper: rendered as a sprite (build_sprites), with a shadow here.
    pl = L["platen"]
    slab("platen_shadow", (pl[0], pl[1] - 2, pl[2], pl[3] + 2), -0.07, -0.05, mats["recess"], r=6, bevel=0)

    # Company tube.
    tb = L["tube"]
    cylinder_y("tube_pipe", -10, tb[1] + 40, tb[0] + tb[2] / 2, 15, 0.05, mats["brass"])
    for fy in (12, 30):
        cylinder_y("tube_flange", fy, fy + 5, tb[0] + tb[2] / 2, 18, 0.05, mats["brass_dark"])
    slab("tube_body", (tb[0] + 4, 36, tb[2] - 8, 84), -0.05, 0.08, mats["brass"], r=8, bevel=0.015)
    recess("tube_window", L["tube_window"], r=10, depth=0.04)
    slab("tube_foot", (tb[0], 116, tb[2], 10), 0.0, 0.06, mats["brass_dark"], r=3, bevel=0.01)
    plaque(L["plaques"]["tube"][:4])

    # Sector selector.
    se = L["sector"]
    housing("sector", se, r=10, rivet_step=80)
    kx, ky, kw, kh = L["sector_knob"]
    cx, cy = kx + kw / 2, ky + kh / 2
    disc("sector_escutcheon", cx, cy, 46, 0.0, 0.015, mats["enamel_dark"], bevel=0.004)
    ring_obj("sector_ring", cx, cy, 48, 44, 0.0, 0.025, mats["brass"], bevel=0.004)
    for i in range(13):
        a = math.radians(-180 + 15 * i)
        tx2, ty2 = cx + 42 * math.cos(a), cy + 42 * math.sin(a)
        slab("tick", (tx2 - 1, ty2 - 1, 2, 2), 0.02, 0.026, mats["recess"], r=1, bevel=0)
    plaque(L["plaques"]["sector"][:4])

    # Shift nixies.
    sh_ = L["shift"]
    housing("shift", sh_, r=10, rivet_step=80)
    for i in range(2):
        nx = sh_[0] + 14 + i * 34
        recess("nixie_well", (nx, 18, 30, 82), r=12, depth=0.05)
        slab("nixie_base", (nx + 2, 92, 26, 10), 0.0, 0.04, mats["bakelite_black"], r=3, bevel=0.006)
    plaque(L["plaques"]["shift"][:4])

    # Mood porthole.
    po = L["porthole"]
    housing("porthole", po, r=10, rivet_step=80)
    pcx, pcy, pr = L["porthole_c"]
    disc("porthole_well", pcx, pcy, pr - 10, -0.06, 0.002, mats["recess"])
    disc("porthole_glow", pcx, pcy, pr - 16, -0.059, -0.05, mats["glow_cyan"])
    ring_obj("porthole_ring", pcx, pcy, pr, pr - 10, 0.0, 0.08, mats["brass"], bevel=0.02)
    for i in range(8):
        a = 2 * math.pi * i / 8 + math.pi / 8
        uv_sphere("porthole_bolt", pcx + (pr - 5) * math.cos(a), pcy + (pr - 5) * math.sin(a), 0.08, 2.6, mats["brass_dark"], 0.5)
    plaque(L["plaques"]["porthole"][:4])

    # Hangar window.
    hg = L["hangar"]
    housing("hangar", hg, r=10, rivet_step=80)
    hx, hy, hw, hh = L["hangar_view"]
    frame("hangar_frame", (hx - 6, hy - 6, hw + 12, hh + 12), (hx, hy, hw, hh), 0.0, 0.06, mats["brass_dark"], r_out=8, r_in=4)
    recess("hangar_well", L["hangar_view"], r=4, depth=0.1)
    plaque(L["plaques"]["hangar"][:4])

    # The card reader: a felt bed with the slots' rails, and the pilot lamps down its left.
    ra = L["rack"]
    housing("rack", ra, r=10)
    recess("card_bed", L["card_bed"], r=4, depth=0.04, mat=mats["felt"])
    lr = L["lamp_rail"]
    slab("lamp_rail", lr, 0.0, 0.03, mats["brass_dark"], r=4, bevel=0.006)
    lamps = L["lamps"]
    for i in range(lamps["count"]):
        ly = lamps["first_y"] + i * lamps["pitch"]
        ring_obj("lamp_socket", lamps["rail_x"], ly, 10, 6.5, 0.03, 0.06, mats["chrome"], bevel=0.004)
        disc("lamp_glass", lamps["rail_x"], ly, 6.5, 0.0, 0.035, mats["recess"])
    plaque(L["plaques"]["rack"][:4])

    # The pulp chute: a brass hopper that eats spoiled cards.
    ch = L["chute"]
    housing("chute", ch, r=10, rivet_step=70)
    mx, my, mw, mh = L["chute_mouth"]
    frame("chute_lip", (mx - 8, my - 8, mw + 16, mh + 16), (mx, my, mw, mh), 0.0, 0.06, mats["brass"], r_out=10, r_in=6, bevel=0.01)
    recess("chute_throat", (mx, my, mw, mh), r=6, depth=0.4)
    for i in range(5):
        slab("chute_tooth", (mx + 6 + i * (mw - 12) / 4.0 - 2, my + mh - 10, 4, 10), -0.3, -0.05, mats["steel"], r=1, bevel=0)
    plaque(L["plaques"]["chute"][:4])

    # The Company's counter: what the operator owes, on rolling wheels.
    co = L["counter"]
    housing("counter", co, r=10, rivet_step=70)
    recess("counter_window", (co[0] + 10, co[1] + 34, co[2] - 20, 38), r=3, depth=0.06)
    frame("counter_bezel", (co[0] + 6, co[1] + 30, co[2] - 12, 46), (co[0] + 10, co[1] + 34, co[2] - 20, 38), 0.0, 0.04,
          mats["brass"], r_out=5, r_in=3, bevel=0.006)
    recess("counter_window2", (co[0] + 26, co[1] + 84, co[2] - 52, 24), r=3, depth=0.05)
    plaque(L["plaques"]["counter"][:4])

    # Sea trials.
    tr = L["trials"]
    housing("trials", tr, r=10, rivet_step=70)
    tl = L["trial_lamps"]
    for j in range(tl["rows"]):
        for i in range(tl["cols"]):
            lx, ly = tl["x"] + i * tl["dx"], tl["y"] + j * tl["dy"]
            ring_obj("tlamp_socket", lx, ly, 6, 3.8, 0.0, 0.025, mats["chrome"], bevel=0.003)
            disc("tlamp_glass", lx, ly, 3.8, -0.01, 0.012, mats["recess"])
    ccx, ccy, cr = L["crank"]
    disc("crank_boss", ccx, ccy, cr, 0.0, 0.03, mats["brass_dark"], bevel=0.008)
    plaque(L["plaques"]["trials"][:4])

    # Dispatch.
    di = L["dispatch"]
    housing("dispatch", di, r=10, rivet_step=70)
    dpx, dpy, dlen = L["dispatch_pivot"]
    # The lever's quadrant: an arc slot from -42 to +42 degrees around the pivot.
    slot_o, slot_i = [], []
    for i in range(33):
        a = math.radians(-90 - 46 + 92 * i / 32)
        slot_o.append(P(dpx + (dlen + 6) * math.cos(a), dpy + (dlen + 6) * math.sin(a)))
    for i in range(33):
        a = math.radians(-90 + 46 - 92 * i / 32)
        slot_o.append(P(dpx + (dlen - 18) * math.cos(a), dpy + (dlen - 18) * math.sin(a)))
    prism("lever_quadrant", slot_o, -0.02, 0.025, mats["steel"], 0.006)
    slot_i = []
    for i in range(33):
        a = math.radians(-90 - 42 + 84 * i / 32)
        slot_i.append(P(dpx + (dlen - 2) * math.cos(a), dpy + (dlen - 2) * math.sin(a)))
    for i in range(33):
        a = math.radians(-90 + 42 - 84 * i / 32)
        slot_i.append(P(dpx + (dlen - 10) * math.cos(a), dpy + (dlen - 10) * math.sin(a)))
    prism("lever_slot", slot_i, 0.02, 0.028, mats["recess"], 0.0)
    for k, a in enumerate((-42, 0, 42)):
        aa = math.radians(-90 + a)
        slab("quad_mark", (dpx + (dlen + 12) * math.cos(aa) - 2, dpy + (dlen + 12) * math.sin(aa) - 2, 4, 4),
             0.0, 0.03, mats["brass"], r=1, bevel=0)
    disc("pivot_boss", dpx, dpy, 15, 0.0, 0.05, mats["brass"], bevel=0.012)
    cvx, cvy, cvw, cvh = L["cover"]
    slab("cover_base", (cvx - 3, cvy - 3, cvw + 6, cvh + 6), 0.0, 0.02, mats["steel"], r=5, bevel=0.005)
    recess("cover_well", (cvx + 6, cvy + 8, cvw - 12, cvh - 14), r=4, depth=0.03)
    cylinder_x("cover_hinge", cvx + 4, cvx + cvw - 4, cvy + 1, 3.5, 0.03, mats["chrome"])
    plaque(L["plaques"]["dispatch"][:4])

    # The press: a split-flap readout, two selector wheels, the NOT switch and value wheel, the tray the
    # printed cards fall into, and the PRINT lever.
    pr = L["press"]
    housing("press", pr, r=12, rivet_step=60)
    # The two printed drums the wheels turn, behind one glass: ORDER on the left, CONDITION on the right.
    fx, fy, fw, fh = L["drum_window"]
    prism("drum_bezel", rr_outline(fx - 6, fy - 6, fw + 12, fh + 12, 8), 0.0, 0.05, mats["brass"], 0.008,
          holes=[rr_outline(*L[k], 4) for k in ("order_drum", "cond_drum")])
    for key in ("order_drum", "cond_drum"):
        recess(key + "_well", L[key], r=3, depth=0.12)
    ex, ey, ew, eh = L["card_exit"]
    recess("card_exit", (ex + 6, ey + 4, ew - 12, 5), r=2, depth=0.08)
    nx2, ny2, nw2, nh2 = L["not_switch"]
    slab("not_plate", (nx2 + 2, ny2 + 2, nw2 - 4, nh2 - 4), 0.0, 0.02, mats["brass_dark"], r=4, bevel=0.005)
    ring_obj("not_bushing", nx2 + nw2 / 2, ny2 + nh2 / 2 - 6, 9, 5, 0.02, 0.05, mats["chrome"])
    vx, vy, vw, vh = L["value_wheel"]
    frame("value_frame", (vx - 4, vy - 4, vw + 8, vh + 8), (vx, vy, vw, vh), 0.0, 0.04, mats["brass"], r_out=6, r_in=4, bevel=0.006)
    recess("value_well", (vx, vy, vw, vh), r=4, depth=0.1)
    tx, ty, tw, th = L["tray"]
    recess("tray", (tx, ty, tw, th), r=6, depth=0.06, mat=mats["felt"])
    for gx in range(int(tx) + 14, int(tx + tw) - 6, 18):
        slab("tray_wire", (gx, ty + 4, 2, th - 8), -0.055, -0.04, mats["steel"], r=0.8, bevel=0)
    slab("tray_lip", (tx - 4, ty + th - 6, tw + 8, 8), 0.0, 0.05, mats["brass"], r=3, bevel=0.008)
    for key in ("order_wheel", "cond_wheel"):
        wx, wy, wr = L[key]
        disc(key + "_well", wx, wy, wr + 6, -0.04, 0.002, mats["recess"])
        ring_obj(key + "_ring", wx, wy, wr + 10, wr + 5, 0.0, 0.04, mats["brass"], bevel=0.006)
        for i in range(24):
            a = 2 * math.pi * i / 24
            tl2 = 5 if i % 2 == 0 else 3
            slab("wheel_tick", (wx + (wr + 7.5) * math.cos(a) - 1, wy + (wr + 7.5) * math.sin(a) - 1, 2, 2), 0.04, 0.046, mats["recess"], r=1, bevel=0)
        plaque(L["plaques"][key][:4])
    lx2, ly2, lw2, lh2 = L["print_slot"]
    slab("print_track", (lx2 - 6, ly2 - 8, lw2 + 12, lh2 + 16), 0.0, 0.025, mats["steel"], r=7, bevel=0.006)
    recess("print_slot", L["print_slot"], r=6, depth=0.06)
    plaque(L["plaques"]["print"][:4])
    plaque(L["plaques"]["tray"][:4])
    # The steam pipe behind the press, where it vents when it prints.
    cylinder_y("press_pipe", 470, 500, 1182, 5, 0.04, mats["brass_dark"])


# ------------------------------------------------------------------ sprites (each drawn on its own, at the origin)

def build_reel(c):
    m = M()
    r = 41
    ring_obj("reel_flange", 0, 0, r, r - 4, 0.0, 0.03, m["steel"], coll=c)
    disc("reel_wire", 0, 0, r - 4, -0.01, 0.02, m["brass_dark"], coll=c)
    # The flange's face with three windows, the wound wire showing through.
    outer = circle_pts(0, 0, r - 2, 96)
    holes = []
    for k in range(3):
        a0 = 2 * math.pi * k / 3 + 0.35
        pts = []
        for i in range(17):
            a = a0 + 1.4 * i / 16
            pts.append(P(29 * math.cos(a), 29 * math.sin(a)))
        for i in range(17):
            a = a0 + 1.4 - 1.4 * i / 16
            pts.append(P(14 * math.cos(a), 14 * math.sin(a)))
        holes.append(pts)
    prism("reel_face", outer, 0.02, 0.04, m["steel"], 0.004, holes=holes, coll=c)
    disc("reel_hub", 0, 0, 9, 0.04, 0.07, m["red_enamel"], bevel=0.008, coll=c)
    slab("reel_key", (-1.5, -7, 3, 14), 0.07, 0.075, m["recess"], r=1, bevel=0, coll=c)


def build_knob(c, r, pointer="line", mat="red_bakelite"):
    """A wing knob: a bronze hub with a valve-red wing across it, one end drawn to a point (the pointer, up)."""
    m = M()
    disc("knob_skirt", 0, 0, r * 0.8, 0.0, 0.035, m["brass_dark"], bevel=0.008, coll=c)
    disc("knob_hub", 0, 0, r * 0.46, 0.03, 0.15, m["brass"], bevel=0.015, coll=c)
    w = r * 0.34
    tip = r + (4 if pointer == "arrow" else 1)
    wing = [P(0, -tip), P(w * 0.7, -r * 0.62), P(w, 0), P(w * 0.8, r * 0.78), P(0, r * 0.86),
            P(-w * 0.8, r * 0.78), P(-w, 0), P(-w * 0.7, -r * 0.62)]
    prism("knob_wing", wing, 0.08, 0.22, m[mat], 0.02, coll=c)
    disc("knob_nut", 0, 0, r * 0.2, 0.22, 0.27, m["brass"], n=6, bevel=0.004, coll=c)


def build_lever(c, length, ball=13):
    """A lever pointing up (screen -y) from a pivot at the origin: a bronze rod with a valve-red T-handle."""
    m = M()
    cylinder_y("lever_rod", -length + 4, 0, 0, 3.4, 0.09, m["brass"], coll=c)
    ring_obj("lever_collar_t", 0, -length + 12, 5.5, 3.0, 0.04, 0.15, m["brass_dark"], coll=c)
    cylinder_x("lever_t", -17, 17, -length, 6.2, 0.14, m["red"], coll=c)
    for sx in (-18, 18):
        disc("lever_t_cap", sx, -length, 3.2, 0.06, 0.2, m["brass_dark"], n=6, coll=c)
    disc("lever_collar", 0, 0, 10, 0.06, 0.11, m["brass_dark"], bevel=0.008, coll=c)
    disc("lever_nut", 0, 0, 5, 0.11, 0.15, m["brass"], n=6, coll=c)


def build_punch_knob(c):
    """The PRINT pull: a valve-red pull-knob with a scalloped edge, like a sea-cock's, on a bronze stem."""
    m = M()
    slab("pk_stem", (-3, -4, 6, 26), 0.03, 0.08, m["brass_dark"], r=2, bevel=0.004, coll=c)
    prism("pk_pull", scallops(0, -6, 13, 6, 4), 0.06, 0.16, m["red"], 0.012, coll=c)
    disc("pk_nut", 0, -6, 4.6, 0.16, 0.21, m["brass"], n=6, bevel=0.003, coll=c)


def build_cover(c, open_):
    m = M()
    w, h = L["cover"][2], L["cover"][3]
    if not open_:
        slab("cover", (-w / 2, 0, w, h), 0.03, 0.09, m["red"], r=6, bevel=0.012, coll=c)
        slab("cover_stripe", (-w / 2 + 6, h - 14, w - 12, 6), 0.09, 0.095, m["ivory"], r=1, bevel=0, coll=c)
    else:
        # Lifted: seen nearly edge-on above the hinge, its underside showing.
        slab("cover", (-w / 2, -16, w, 16), 0.03, 0.14, m["red"], r=4, bevel=0.01, coll=c)
    cylinder_x("hinge", -w / 2 + 4, w / 2 - 4, 1, 3.5, 0.03, m["chrome"], coll=c)


def build_toggle(c, up):
    """A bronze toggle with a valve-red spoon on its end."""
    m = M()
    disc("tg_nut", 0, 0, 8, 0.0, 0.04, m["brass"], n=6, coll=c)
    d = -1 if up else 1
    cylinder_y("tg_bat", min(0, d * 18), max(0, d * 18), 0, 2.6, 0.07, m["brass"], coll=c)
    slab("tg_spoon", (-5.5, d * 24 - 10, 11, 20), 0.05, 0.11, m["red"], r=5, bevel=0.01, coll=c)


def build_capsule(c):
    m = M()
    slab("cap_body", (-15, -26, 30, 52), 0.0, 0.2, m["brass"], r=14, bevel=0.06, coll=c)
    for y in (-12, 12):
        slab("cap_band", (-16, y - 3, 32, 6), 0.0, 0.21, m["red_enamel"], r=2, bevel=0.01, coll=c)


def build_crank(c):
    m = M()
    r = L["crank"][2]
    disc("crank_hub", 0, 0, 9, 0.03, 0.08, m["brass"], bevel=0.01, coll=c)
    slab("crank_arm", (-4, -r + 2, 8, r), 0.06, 0.1, m["steel"], r=4, bevel=0.01, coll=c)
    disc("crank_grip", 0, -r + 6, 6.5, 0.1, 0.22, m["red_bakelite"], bevel=0.02, coll=c)


def build_key(c, down):
    """A recorder key: a bronze bezel round a valve-red enamel button."""
    m = M()
    z = 0.02 if down else 0.07
    slab("key_bezel", (-30, -16, 60, 32), 0.0, z, m["brass_dark"], r=6, bevel=0.01, coll=c)
    slab("key_top", (-26, -12, 52, 24), z, z + 0.025, m["red"], r=5, bevel=0.01, coll=c)


def build_platen(c):
    m = M()
    x, y, w, h = L["platen"]
    ox, oy = x + w / 2, y + h / 2
    cylinder_x("platen_roll", -w / 2 + 6, w / 2 - 6, -h / 2 + 7, 7, 0.02, m["rubber"], coll=c)
    slab("platen_cover", (-w / 2, -h / 2 + 8, w, h - 8), 0.0, 0.12, m["enamel_dark"], r=6, bevel=0.02, coll=c)
    for kx in (-w / 2 + 14, w / 2 - 14):
        disc("platen_knob", kx, -h / 2 + 7, 9, 0.02, 0.12, m["red_bakelite"], bevel=0.02, coll=c)
    slab("tear_bar", (-w / 2 + 20, -h / 2 + 4, w - 40, 4), 0.06, 0.09, m["chrome"], r=1, bevel=0.003, coll=c)


def build_wheel(c, r, spokes, knob=True):
    """A selector wheel like a valve handwheel: a valve-red rim knuckled for the fingers, three red spokes, a bronze
    hub and nut. A bronze notch on the rim shows it turn."""
    m = M()
    prism("wheel_rim", scallops(0, 0, r - 3, 6, 6), 0.0, 0.11, m["red"], 0.02, holes=[circle_pts(0, 0, r - 13, 96)], coll=c)
    for k in range(3):
        sp = slab("spoke", (-4.5, -(r - 8), 9, r - 14), 0.02, 0.08, m["red"], r=3, bevel=0.01, coll=c)
        sp.rotation_euler = (0, 0, math.pi / 6 + 2 * math.pi * k / 3)
    disc("wheel_hub", 0, 0, r * 0.3, 0.03, 0.15, m["brass"], bevel=0.02, coll=c)
    disc("wheel_nut", 0, 0, r * 0.15, 0.15, 0.21, m["brass_dark"], n=6, bevel=0.006, coll=c)
    slab("wheel_mark", (-2.5, r - 12, 5, 8), 0.11, 0.115, m["brass"], r=1, bevel=0, coll=c)


def build_chute_flap(c):
    m = M()
    w, h = L["chute_mouth"][2], L["chute_mouth"][3]
    slab("flap", (-w / 2, 0, w, h * 0.55), 0.0, 0.05, m["steel"], r=3, bevel=0.01, coll=c)
    cylinder_x("flap_hinge", -w / 2 + 2, w / 2 - 2, 1, 3, 0.04, m["chrome"], coll=c)
    for i in range(3):
        slab("flap_rib", (-w / 2 + 10, 8 + i * 8, w - 20, 2), 0.05, 0.06, m["brass_dark"], r=1, bevel=0, coll=c)


SPRITES = {
    "wheel_order": (lambda c: build_wheel(c, L["order_wheel"][2], 6), (L["order_wheel"][2] + 10, L["order_wheel"][2] + 10)),
    "wheel_cond": (lambda c: build_wheel(c, L["cond_wheel"][2], 5), (L["cond_wheel"][2] + 10, L["cond_wheel"][2] + 10)),
    "chute_flap": (build_chute_flap, (L["chute_mouth"][2] / 2 + 4, L["chute_mouth"][3] * 0.6 + 4)),
    # name: (builder, half-size in screen pixels (w, h), origin offset)
    "reel": (build_reel, (46, 46)),
    "knob_speed": (lambda c: build_knob(c, 30, "line"), (36, 36)),
    "knob_sector": (lambda c: build_knob(c, 26, "arrow"), (36, 36)),
    "lever_dispatch": (lambda c: build_lever(c, L["dispatch_pivot"][2]), (22, 98)),
    "punch_knob": (build_punch_knob, (22, 26)),
    "cover_closed": (lambda c: build_cover(c, False), (48, 66)),
    "cover_open": (lambda c: build_cover(c, True), (48, 66)),
    "toggle_up": (lambda c: build_toggle(c, True), (14, 32)),
    "toggle_down": (lambda c: build_toggle(c, False), (14, 32)),
    "capsule": (build_capsule, (20, 30)),
    "crank": (build_crank, (14, 28)),
    "key_up": (lambda c: build_key(c, False), (34, 20)),
    "key_down": (lambda c: build_key(c, True), (34, 20)),
    "platen": (build_platen, (252, 24)),
}


# ------------------------------------------------------------------ lights, camera, render

def lights(cx=6.4, cy=-3.6, scale=1.0):
    def area(name, loc, rot, size, size_y, energy, color):
        ld = bpy.data.lights.new(name, "AREA")
        ld.shape = "RECTANGLE"
        ld.size = size
        ld.size_y = size_y
        ld.energy = energy * scale
        ld.color = color
        o = bpy.data.objects.new(name, ld)
        bpy.context.scene.collection.objects.link(o)
        o.location = loc
        o.rotation_euler = rot
        return o
    # The work lamp above and in front of the desk: grazing from the top, so upper edges catch the light.
    area("key", (cx, cy + 6.6, 5.5), (math.radians(-35), 0, 0), 9.0, 1.2, 1500, (1.0, 0.86, 0.66))
    # A cold bounce from the room, low and from the left.
    area("fill", (cx - 9.4, cy - 5.4, 6.0), (math.radians(40), math.radians(-30), 0), 6.0, 6.0, 260, (0.55, 0.75, 0.8))
    # A thin rim from the right, for brass edges.
    area("rim", (cx + 9.6, cy, 2.5), (0, math.radians(70), 0), 1.0, 8.0, 500, (1.0, 0.8, 0.6))


def setup_render(w_px, h_px, cx, cy, samples):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = samples
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 4
    sc.render.resolution_x = int(w_px * S)
    sc.render.resolution_y = int(h_px * S)
    sc.render.resolution_percentage = 50 if PREVIEW else 100
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"
    sc.view_settings.exposure = 0.0
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.004, 0.005, 0.005, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    sc.world = world
    cam_d = bpy.data.cameras.new("cam")
    cam_d.type = "ORTHO"
    cam_d.ortho_scale = max(w_px, h_px) / 100.0
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    x, y = P(cx, cy)
    cam.location = (x, y, 20.0)
    cam_d.clip_end = 50.0
    sc.camera = cam


def render(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()


def cable(points, r, mat, name="cable"):
    """A sagging cable through screen-pixel points (x, y, z)."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r / 100.0
    cu.bevel_resolution = 4
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(len(points) - 1)
    for bp, (x, y, z) in zip(sp.bezier_points, points):
        X, Y = P(x, y)
        bp.co = (X, Y, z)
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    o = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def add_clutter():
    """Variant B: what years of use leave on a console: cables, a pipe run, patches, tape, a tag."""
    m = M()
    # Cables: down the left edge, across the gap under the scope, looping over the top row, down the right.
    cable([(4, -20, 0.1), (5, 200, 0.18), (3, 420, 0.12), (6, 740, 0.1)], 4.5, m["rubber"])
    cable([(2, 380, 0.12), (160, 404, 0.2), (330, 410, 0.22), (500, 405, 0.2), (648, 396, 0.15)], 3.5, m["cloth"])
    cable([(2, 390, 0.1), (200, 407, 0.18), (420, 403, 0.2), (650, 400, 0.12)], 2.5, m["red"])
    cable([(690, -20, 0.2), (720, 6, 0.3), (860, 2, 0.28), (1010, 4, 0.26), (1140, 1, 0.24), (1290, -6, 0.2)], 4.0, m["rubber"])
    cable([(1277, -20, 0.1), (1275, 260, 0.2), (1278, 480, 0.15), (1276, 740, 0.1)], 5.0, m["cloth"])
    # A pipe run along the seam under the top row, with flanges and a valve wheel.
    cylinder_x("pipe_run", 646, 1290, 129, 7, 0.12, m["brass_dark"])
    for fx in (700, 900, 1100):
        cylinder_x("pipe_flange", fx, fx + 6, 129, 10, 0.12, m["brass"])
    ring_obj("valve_wheel", 1004, 129, 13, 10, 0.2, 0.26, m["red"], bevel=0.01)
    disc("valve_hub", 1004, 129, 4, 0.2, 0.28, m["steel"])
    # A pressure gauge clamped to the upright pipe.
    disc("pg_body", 645, 300, 14, 0.1, 0.24, m["brass"], bevel=0.02)
    disc("pg_face", 645, 300, 11, 0.24, 0.25, m["ivory"])
    slab("pg_needle", (644, 291, 2, 10), 0.25, 0.255, m["recess"], r=1, bevel=0)
    # Patches welded over old damage.
    for (px, py, pw, ph) in ((14, 8, 46, 26), (1236, 690, 32, 20), (12, 452, 18, 36), (612, 700, 26, 14)):
        slab("patch", (px, py, pw, ph), 0.0, 0.03, m["enamel_rust"], r=2, bevel=0.006)
        for k in range(int(pw / 7)):
            uv_sphere("weld", px + 3 + k * 7, py + 1, 0.03, 2.0, m["steel"], 0.4)
            uv_sphere("weld", px + 3 + k * 7, py + ph - 1, 0.03, 2.0, m["steel"], 0.4)
    # Cloth tape over a cracked corner, and a tag on a string from the tube.
    for (tx, ty, tw, th, rot) in ((1128, 6, 30, 9, 0.5), (640, 470, 30, 8, -0.4), (1036, 466, 26, 8, 0.7)):
        o = slab("tape", (tx, ty, tw, th), 0.05, 0.058, m["cloth"], r=1, bevel=0)
        o.rotation_euler = (0, 0, rot)
    cable([(712, 60, 0.12), (718, 90, 0.16), (721, 112, 0.18)], 0.6, m["paper"], "string")
    slab("tag", (712, 110, 18, 26), 0.17, 0.18, m["paper"], r=2, bevel=0)


def do_plate():
    reset()
    build_plate()
    if GRIMY:
        add_clutter()
    lights()
    if GRIMY:
        # The work lamp is a single bulb up and to the left: a pool of light, and dark beyond it.
        for o in bpy.data.objects:
            if o.type == "LIGHT":
                o.data.energy *= 0.35
        spot = bpy.data.lights.new("pool", "SPOT")
        spot.energy = 9000
        spot.spot_size = math.radians(70)
        spot.spot_blend = 0.9
        spot.color = (1.0, 0.78, 0.5)
        spot.shadow_soft_size = 0.25
        so = bpy.data.objects.new("pool", spot)
        bpy.context.scene.collection.objects.link(so)
        so.location = (8.2, 1.5, 6.5)
        tgt = bpy.data.objects.new("pool_target", None)
        bpy.context.scene.collection.objects.link(tgt)
        tgt.location = (8.0, -4.2, 0.0)
        tgt.rotation_euler = (math.radians(-90), 0, 0)
        c = so.constraints.new("TRACK_TO")
        c.target = tgt
        c.track_axis = "TRACK_NEGATIVE_Z"
        c.up_axis = "UP_Y"
        c.use_target_z = True
    setup_render(1280, 720, 640, 360, 24 if PREVIEW else 96)
    bpy.context.scene.render.film_transparent = False
    render(os.path.join(OUT, "plate_grimy.png" if GRIMY else "plate.png"))


def do_sprites():
    for name, (builder, half) in SPRITES.items():
        reset()
        c = bpy.context.scene.collection
        builder(c)
        # A shadow catcher behind the part, so it casts its shadow onto whatever Godot draws it over.
        catcher = slab("catcher", (-400, -400, 800, 800), -0.31, -0.3, M()["enamel"], r=0, bevel=0)
        catcher.is_shadow_catcher = True
        lights(0.0, 0.0)
        w, h = half[0] * 2, half[1] * 2
        setup_render(w, h, 0, 0, 16 if PREVIEW else 64)
        render(os.path.join(OUT, name + ".png"))


if __name__ == "__main__":
    if WHAT in ("plate", "all"):
        do_plate()
    if WHAT in ("sprites", "all"):
        do_sprites()
    elif WHAT not in ("plate",):
        # A single sprite by name.
        _all = dict(SPRITES)
        SPRITES.clear()
        SPRITES.update({k: v for k, v in _all.items() if k in WHAT.split(",")})
        do_sprites()
    print("console art written to", OUT)
