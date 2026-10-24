"""Blender helpers for Robbie N+1 art: node building, cartoon shading, the fake lamp light, outlines, primitives.

Scenes are shaded with emission only. The lamp, the creatures' glow and the shape-reading light are computed in the
shader from world position, so a frame converges in a few dozen samples on a CPU and the look stays exactly as
designed (no stray bounce light, no noise in the dark).

Run scenes with: blender -b --factory-startup -P <scene.py> -- <args>
"""
import math

import bpy
from mathutils import Vector


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return bpy.context.scene


def rgb(hex_or_tuple):
    """'#rrggbb' or (r, g, b) in sRGB 0..1 -> linear (r, g, b), which is what shader sockets expect."""
    if isinstance(hex_or_tuple, str):
        h = hex_or_tuple.lstrip("#")
        c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    else:
        c = list(hex_or_tuple)[:3]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


def scale_rgb(c, k):
    return tuple(min(1.0, x * k) for x in c)


def mix_rgb(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def mix_hex(a, b, t):
    """Blend two '#rrggbb' colours in sRGB."""
    ca = [int(a.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)]
    cb = [int(b.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)]
    return "#" + "".join("%02x" % round(x + (y - x) * t) for x, y in zip(ca, cb))


class Nodes:
    """A small builder over a node tree, so shading reads as arithmetic instead of node plumbing."""

    def __init__(self, tree):
        self.t = tree

    def add(self, kind, **props):
        node = self.t.nodes.new(kind)
        for k, v in props.items():
            setattr(node, k, v)
        return node

    def feed(self, socket, value):
        if isinstance(value, bpy.types.NodeSocket):
            self.t.links.new(value, socket)
        elif socket.type == "VECTOR":
            socket.default_value = tuple(value)[:3]
        elif socket.type == "RGBA":
            v = tuple(value)
            socket.default_value = v if len(v) == 4 else v + (1.0,)
        else:
            socket.default_value = value

    def math(self, op, a, b=None):
        n = self.add("ShaderNodeMath", operation=op)
        self.feed(n.inputs[0], a)
        if b is not None:
            self.feed(n.inputs[1], b)
        return n.outputs[0]

    def vec(self, op, a, b=None, scale=None):
        n = self.add("ShaderNodeVectorMath", operation=op)
        self.feed(n.inputs[0], a)
        if b is not None:
            self.feed(n.inputs[1], b)
        if scale is not None:
            self.feed(n.inputs[3], scale)
        return n.outputs[1] if op in ("DOT_PRODUCT", "LENGTH", "DISTANCE") else n.outputs[0]

    def remap(self, x, lo, hi, out_lo=0.0, out_hi=1.0, smooth=True):
        """Clamped remap of x from [lo, hi] to [out_lo, out_hi], smoothstep by default."""
        n = self.add("ShaderNodeMapRange", interpolation_type="SMOOTHSTEP" if smooth else "LINEAR", clamp=True)
        self.feed(n.inputs[0], x)
        n.inputs[1].default_value, n.inputs[2].default_value = lo, hi
        n.inputs[3].default_value, n.inputs[4].default_value = out_lo, out_hi
        return n.outputs[0]

    def lerp(self, a, b, t):
        return self.vec("ADD", a, self.vec("SCALE", self.vec("SUBTRACT", b, a), scale=t))

    def flat_xy(self, v):
        return self.vec("MULTIPLY", v, (1.0, 1.0, 0.0))


def lighting_group(cfg):
    """The shared light model, as a shader node group with inputs Base/Shade/High/Glow/Lit/AO.

    cfg keys: robbie (x, y), lamp_angle (deg), cone_half (deg), cone_soft (deg), cone_range, radial (r_in, r_out),
    radial_gain, ambient, lamp_color, glows [(x, y, radius, color, strength)], sun (vector), bands (t1, t2), band_soft,
    sky (dir, color, lo, hi, z_lo, z_hi) or None, rim (color, strength, ambient) or None.
    """
    g = bpy.data.node_groups.new("Lighting", "ShaderNodeTree")
    for name, kind, default in (("Base", "NodeSocketColor", (0.5, 0.5, 0.5, 1)),
                                ("Shade", "NodeSocketColor", (0.2, 0.2, 0.2, 1)),
                                ("High", "NodeSocketColor", (0.8, 0.8, 0.8, 1)),
                                ("Glow", "NodeSocketColor", (0, 0, 0, 1)),
                                ("Lit", "NodeSocketFloat", 1.0),
                                ("AO", "NodeSocketFloat", 0.5)):
        s = g.interface.new_socket(name=name, in_out="INPUT", socket_type=kind)
        s.default_value = default
    g.interface.new_socket(name="Color", in_out="OUTPUT", socket_type="NodeSocketColor")
    n = Nodes(g)
    gin, gout = n.add("NodeGroupInput"), n.add("NodeGroupOutput")
    geo = n.add("ShaderNodeNewGeometry")
    P, N = geo.outputs["Position"], geo.outputs["Normal"]

    # Shape light: two soft-edged bands from a fixed direction, so forms read the same everywhere.
    t = n.remap(n.vec("DOT_PRODUCT", N, Vector(cfg["sun"]).normalized()), -1.0, 1.0, smooth=False)
    w = cfg.get("band_soft", 0.02)
    t1, t2 = cfg["bands"]
    s1 = n.remap(t, t1 - w, t1 + w)
    s2 = n.remap(t, t2 - w, t2 + w)
    toon = n.lerp(n.lerp(gin.outputs["Shade"], gin.outputs["Base"], s1), gin.outputs["High"], s2)

    # Robbie's lamp: a glow around Robbie plus the cone ahead of it.
    rx, ry = cfg["robbie"]
    d = n.flat_xy(n.vec("SUBTRACT", P, (rx, ry, 0.0)))
    dist = n.vec("LENGTH", d)
    r_in, r_out = cfg["radial"]
    radial = n.math("MULTIPLY", n.remap(dist, r_in, r_out, 1.0, 0.0), cfg.get("radial_gain", 0.8))
    a = math.radians(cfg["lamp_angle"])
    along = n.vec("DOT_PRODUCT", d, (math.cos(a), math.sin(a), 0.0))
    cosang = n.math("DIVIDE", along, n.math("MAXIMUM", dist, 0.001))
    half, soft = math.radians(cfg["cone_half"]), math.radians(cfg["cone_soft"])
    cone = n.math("MULTIPLY", n.remap(cosang, math.cos(half + soft), math.cos(half)),
                  n.math("MULTIPLY", n.remap(along, cfg["cone_range"] * 0.55, cfg["cone_range"], 1.0, 0.0),
                         n.remap(along, -0.3, 0.5)))
    lamp = n.math("MAXIMUM", radial, cone)
    light = n.vec("ADD", cfg["ambient"], n.vec("SCALE", cfg["lamp_color"], scale=lamp))

    # Bioluminescence: each glowing creature lights a little pool around itself.
    for gx, gy, radius, color, strength in cfg.get("glows", []):
        dg = n.vec("LENGTH", n.flat_xy(n.vec("SUBTRACT", P, (gx, gy, 0.0))))
        fall = n.remap(dg, 0.0, radius, strength, 0.0)
        light = n.vec("ADD", light, n.vec("SCALE", color, scale=fall))

    # Optional rim light on steep edges: strongest where the lamp touches, faint everywhere (rim ambient). Added to
    # the light (it takes the surface's colour), or with additive=True on top of the result (it keeps its own).
    rim_add = None
    if cfg.get("rim"):
        rcol, rstrength, rambient = cfg["rim"][:3]
        additive_rim = len(cfg["rim"]) > 3 and cfg["rim"][3]
        r_lo, r_hi = cfg["rim"][4] if len(cfg["rim"]) > 4 else (0.6, 0.15)
        facing = n.math("ABSOLUTE", n.vec("DOT_PRODUCT", N, (0.0, 0.0, 1.0)))
        rim = n.math("MULTIPLY", n.remap(facing, r_lo, r_hi), n.math("ADD", n.math("MULTIPLY", lamp, rstrength),
                                                                         rambient))
        if additive_rim:
            rim_add = n.vec("SCALE", rcol, scale=rim)
        else:
            light = n.vec("ADD", light, n.vec("SCALE", rcol, scale=rim))

    # Materials that must always read (UI-like props) can ask to be lit regardless of the lamp.
    light = n.lerp((1.0, 1.0, 1.0), light, gin.outputs["Lit"])
    ao = n.add("ShaderNodeAmbientOcclusion", samples=12)
    ao.inputs["Distance"].default_value = 0.9
    occl = n.math("SUBTRACT", 1.0, n.math("MULTIPLY", gin.outputs["AO"], n.math("SUBTRACT", 1.0, ao.outputs["AO"])))
    lit = n.vec("SCALE", n.vec("MULTIPLY", toon, light), scale=occl)
    lit = n.vec("ADD", lit, gin.outputs["Glow"])
    if rim_add is not None:
        lit = n.vec("ADD", lit, n.vec("SCALE", rim_add, scale=n.math("MULTIPLY", gin.outputs["Lit"], occl)))

    # Optional light from above (Jupiter through the ice), added on top so it stays its own colour: it catches
    # surfaces facing sky_dir that stand higher than z_lo (wall tops, not the floor).
    if cfg.get("sky"):
        sdir, scol, lo, hi, z_lo, z_hi = cfg["sky"]
        z = n.add("ShaderNodeSeparateXYZ")
        n.feed(z.inputs[0], P)
        f = n.math("MULTIPLY", n.remap(n.vec("DOT_PRODUCT", N, Vector(sdir).normalized()), lo, hi),
                   n.remap(z.outputs["Z"], z_lo, z_hi))
        lit = n.vec("ADD", lit, n.vec("SCALE", scol, scale=f))
    n.feed(gout.inputs["Color"], lit)
    return g


def toon(name, group, base, shade=None, high=None, glow=(0, 0, 0), lit=1.0, ao=0.55, noise=None, waves=None,
         rings=None):
    """A cartoon material through the Lighting group. Colours are '#hex'. noise=(scale, amount) varies the base;
    waves=(scale, colour2, distortion) paints ripples between base and colour2 (sand); rings=(scale, colour2) paints
    concentric rings around the object's own centre, seen from above (jellyfish bells)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    tree = m.node_tree
    tree.nodes.clear()
    n = Nodes(tree)
    b = rgb(base)
    sh = rgb(shade) if shade else scale_rgb(b, 0.5)
    hi = rgb(high) if high else scale_rgb(b, 1.3)
    gnode = n.add("ShaderNodeGroup", node_tree=group)
    base_sock = b
    if waves:
        geo = n.add("ShaderNodeNewGeometry")
        wav = n.add("ShaderNodeTexWave", wave_type="BANDS", bands_direction="DIAGONAL")
        n.feed(wav.inputs["Vector"], geo.outputs["Position"])
        wav.inputs["Scale"].default_value = waves[0]
        wav.inputs["Distortion"].default_value = waves[2]
        base_sock = n.lerp(b, rgb(waves[1]), n.remap(wav.outputs["Factor"], 0.35, 0.75))
    if rings:
        tc = n.add("ShaderNodeTexCoord")
        wav = n.add("ShaderNodeTexWave", wave_type="RINGS", rings_direction="SPHERICAL")
        n.feed(wav.inputs["Vector"], n.flat_xy(tc.outputs["Object"]))
        wav.inputs["Scale"].default_value = rings[0]
        wav.inputs["Distortion"].default_value = 0.0
        base_sock = n.lerp(base_sock, rgb(rings[1]), n.remap(wav.outputs["Factor"], 0.55, 0.8))
    if noise:
        geo = n.add("ShaderNodeNewGeometry")
        tex = n.add("ShaderNodeTexNoise")
        n.feed(tex.inputs["Vector"], geo.outputs["Position"])
        tex.inputs["Scale"].default_value = noise[0]
        tex.inputs["Detail"].default_value = 3.0
        k = n.remap(tex.outputs["Factor"], 0.3, 0.7, 1.0 - noise[1], 1.0 + noise[1], smooth=False)
        base_sock = n.vec("SCALE", base_sock, scale=k)
        sh = n.vec("SCALE", sh, scale=k)
    n.feed(gnode.inputs["Base"], base_sock)
    n.feed(gnode.inputs["Shade"], sh)
    n.feed(gnode.inputs["High"], hi)
    n.feed(gnode.inputs["Glow"], rgb(glow) if isinstance(glow, str) else glow)
    gnode.inputs["Lit"].default_value = lit
    gnode.inputs["AO"].default_value = ao
    em = n.add("ShaderNodeEmission")
    n.feed(em.inputs["Color"], gnode.outputs["Color"])
    out = n.add("ShaderNodeOutputMaterial")
    n.feed(out.inputs["Surface"], em.outputs["Emission"])
    return m


def glow(name, color, strength=1.0):
    """Pure light, untouched by the lamp: lenses, beacons, creature cores."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    tree = m.node_tree
    tree.nodes.clear()
    n = Nodes(tree)
    em = n.add("ShaderNodeEmission")
    n.feed(em.inputs["Color"], rgb(color))
    em.inputs["Strength"].default_value = strength
    n.feed(n.add("ShaderNodeOutputMaterial").inputs["Surface"], em.outputs["Emission"])
    return m


def additive(name, color, strength, apex=None, length=1.0, alpha=1.0, cone=None):
    """See-through light added on top of what is behind it (beams, halos). With apex=(x, y) it fades with distance
    from that point over `length`; with cone=(angle, half, soft) in degrees it also fades towards the cone's sides."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    tree = m.node_tree
    tree.nodes.clear()
    n = Nodes(tree)
    em = n.add("ShaderNodeEmission")
    n.feed(em.inputs["Color"], rgb(color))
    k = strength
    if apex is not None:
        geo = n.add("ShaderNodeNewGeometry")
        d = n.flat_xy(n.vec("SUBTRACT", geo.outputs["Position"], (apex[0], apex[1], 0.0)))
        dist = n.vec("LENGTH", d)
        k = n.math("MULTIPLY", n.remap(dist, 0.0, length, 1.0, 0.0), strength)
        if cone is not None:
            a, half, soft = (math.radians(v) for v in cone)
            cosang = n.math("DIVIDE", n.vec("DOT_PRODUCT", d, (math.cos(a), math.sin(a), 0.0)),
                            n.math("MAXIMUM", dist, 0.001))
            k = n.math("MULTIPLY", k, n.remap(cosang, math.cos(half), math.cos(max(0.0, half - soft))))
    n.feed(em.inputs["Strength"], k)
    tr = n.add("ShaderNodeBsdfTransparent")
    add = n.add("ShaderNodeAddShader")
    n.feed(add.inputs[0], tr.outputs[0])
    n.feed(add.inputs[1], em.outputs[0])
    if alpha < 1.0:
        mixn = n.add("ShaderNodeMixShader")
        mixn.inputs[0].default_value = alpha
        n.feed(mixn.inputs[1], tr.outputs[0])
        n.feed(mixn.inputs[2], add.outputs[0])
        add = mixn
    n.feed(n.add("ShaderNodeOutputMaterial").inputs["Surface"], add.outputs[0])
    return m


def glass(name, tint, rim_color, rim_strength=1.5, body_alpha=0.12):
    """See-through glass: almost clear in the middle, a bright rim where it turns away from the eye."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    tree = m.node_tree
    tree.nodes.clear()
    n = Nodes(tree)
    lw = n.add("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.35
    rim = n.remap(lw.outputs["Facing"], 0.45, 0.95)
    em = n.add("ShaderNodeEmission")
    n.feed(em.inputs["Color"], n.lerp(rgb(tint), rgb(rim_color), rim))
    n.feed(em.inputs["Strength"], n.math("ADD", n.math("MULTIPLY", rim, rim_strength), 0.4))
    tr = n.add("ShaderNodeBsdfTransparent")
    n.feed(tr.inputs["Color"], rgb(tint))
    mixn = n.add("ShaderNodeMixShader")
    n.feed(mixn.inputs[0], n.math("ADD", n.math("MULTIPLY", rim, 1.0 - body_alpha), body_alpha))
    n.feed(mixn.inputs[1], tr.outputs[0])
    n.feed(mixn.inputs[2], em.outputs[0])
    n.feed(n.add("ShaderNodeOutputMaterial").inputs["Surface"], mixn.outputs[0])
    return m


def shadow(name, color="#000000", alpha=0.35):
    """A flat translucent shadow (paper drop shadows)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    tree = m.node_tree
    tree.nodes.clear()
    n = Nodes(tree)
    em = n.add("ShaderNodeEmission")
    n.feed(em.inputs["Color"], rgb(color))
    tr = n.add("ShaderNodeBsdfTransparent")
    mixn = n.add("ShaderNodeMixShader")
    mixn.inputs[0].default_value = alpha
    n.feed(mixn.inputs[1], tr.outputs[0])
    n.feed(mixn.inputs[2], em.outputs[0])
    n.feed(n.add("ShaderNodeOutputMaterial").inputs["Surface"], mixn.outputs[0])
    return m


# --- primitives -------------------------------------------------------------------------------------------------

def _finish(obj, mat, smooth=True, name=None):
    if name:
        obj.name = name
    if mat is not None:
        obj.data.materials.clear()
        obj.data.materials.append(mat)
    if smooth and obj.type == "MESH":
        for p in obj.data.polygons:
            p.use_smooth = True
    return obj


def sphere(loc, r, mat, scale=(1, 1, 1), rot=(0, 0, 0), segs=48, name=None):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=segs // 2, radius=r, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = scale
    return _finish(o, mat, name=name)


def cyl(loc, r, depth, mat, rot=(0, 0, 0), verts=40, scale=(1, 1, 1), smooth=True, name=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = scale
    return _finish(o, mat, smooth=smooth, name=name)


def cone(loc, r1, r2, depth, mat, rot=(0, 0, 0), verts=32, name=None):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    return _finish(bpy.context.object, mat, name=name)


def torus(loc, major, minor, mat, rot=(0, 0, 0), name=None):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, location=loc, rotation=rot,
                                     major_segments=48, minor_segments=16)
    return _finish(bpy.context.object, mat, name=name)


def box(loc, size, mat, rot=(0, 0, 0), bevel=0.0, name=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object
    o.scale = size
    if bevel:
        bpy.ops.object.transform_apply(scale=True)
        mod = o.modifiers.new("bevel", "BEVEL")
        mod.width, mod.segments = bevel, 4
    return _finish(o, mat, smooth=bool(bevel), name=name)


def tube(points, radius, mat, name="tube", taper=None, flat=0.0):
    """A smooth curve through points (x, y, z) with a round (or flat ribbon) cross-section."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 4
    cu.extrude = flat
    cu.use_fill_caps = True
    sp = cu.splines.new("NURBS")
    sp.points.add(len(points) - 1)
    for p, co in zip(sp.points, points):
        p.co = (co[0], co[1], co[2], 1.0)
    sp.use_endpoint_u = True
    sp.order_u = min(4, len(points))
    if taper is not None:
        for i, p in enumerate(sp.points):
            p.radius = 1.0 + (taper - 1.0) * i / max(1, len(points) - 1)
    o = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(o)
    cu.materials.append(mat)
    return o


def blobs(name, balls, mat, resolution=0.12, threshold=0.6):
    """Organic shapes from metaballs: balls = [(x, y, z, radius, (sx, sy, sz) or None)]."""
    mb = bpy.data.metaballs.new(name)
    mb.render_resolution = resolution
    mb.resolution = resolution * 2
    mb.threshold = threshold
    for x, y, z, r, size in balls:
        e = mb.elements.new()
        e.co = (x, y, z)
        e.radius = r
        if size:
            e.type = "ELLIPSOID"
            e.size_x, e.size_y, e.size_z = size
    o = bpy.data.objects.new(name, mb)
    bpy.context.scene.collection.objects.link(o)
    mb.materials.append(mat)
    return o


def paper_sheet(name, side, edge, z, mat, thickness=0.1, x_range=(-15.0, 15.0), far=14.0, step=0.2):
    """A flat cut-paper sheet: everything beyond the wavy line y = edge(x), on the north (side=+1) or south (-1)
    of it, lying at height z."""
    import bmesh
    bm = bmesh.new()
    xs = [x_range[0] + i * step for i in range(int((x_range[1] - x_range[0]) / step) + 1)]
    ring = [(x, edge(x)) for x in xs] + [(x_range[1], side * far), (x_range[0], side * far)]
    if side < 0:
        ring.reverse()
    verts = [bm.verts.new((x, y, z)) for x, y in ring]
    bm.faces.new(verts)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    sol = o.modifiers.new("thickness", "SOLIDIFY")
    sol.thickness = thickness
    me.materials.append(mat)
    return o


def group_under(parent_name, objs, loc=(0, 0, 0)):
    """Parent objects to an empty so a model moves and turns as one."""
    root = bpy.data.objects.new(parent_name, None)
    bpy.context.scene.collection.objects.link(root)
    root.location = loc
    for o in objs:
        o.parent = root
    return root


# --- camera, outlines, render ------------------------------------------------------------------------------------

def ortho_camera(target=(0, 0, 0), tilt_deg=25.0, heading_deg=0.0, scale=24.0, dist=40.0):
    """An orthographic camera looking down at target, tilted tilt_deg from vertical, from the side heading_deg
    (0 = from the south, so north walls show their faces)."""
    scene = bpy.context.scene
    tilt, head = math.radians(tilt_deg), math.radians(heading_deg)
    offset = Vector((math.sin(head) * math.sin(tilt), -math.cos(head) * math.sin(tilt), math.cos(tilt))) * dist
    cam = bpy.data.objects.new("camera", bpy.data.cameras.new("camera"))
    scene.collection.objects.link(cam)
    cam.location = Vector(target) + offset
    cam.rotation_euler = (tilt, 0.0, head)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = scale
    cam.data.clip_end = dist * 3
    scene.camera = cam
    return cam


def look_camera(location, target, lens=50.0):
    """A perspective camera at location aimed at target."""
    scene = bpy.context.scene
    cam = bpy.data.objects.new("camera", bpy.data.cameras.new("camera"))
    scene.collection.objects.link(cam)
    cam.location = location
    cam.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
    scene.camera = cam
    return cam


def no_lines(*objs):
    """Keep objects out of the ink outlines (light, shadows, specks)."""
    col = bpy.data.collections.get("NoLines")
    if col is None:
        col = bpy.data.collections.new("NoLines")
        bpy.context.scene.collection.children.link(col)
    for o in objs:
        for c in list(o.users_collection):
            c.objects.unlink(o)
        col.objects.link(o)
    return objs[0] if objs else None


def outlines(thickness, color, crease=False, contour=True):
    scene = bpy.context.scene
    scene.render.use_freestyle = True
    scene.render.line_thickness_mode = "ABSOLUTE"
    scene.render.line_thickness = 1.0
    fs = scene.view_layers[0].freestyle_settings
    fs.crease_angle = math.radians(120)
    ls = fs.linesets[0]
    ls.select_by_visibility = True
    ls.select_by_edge_types = True
    ls.select_silhouette = True
    ls.select_border = True
    ls.select_crease = crease
    ls.select_external_contour = contour
    if bpy.data.collections.get("NoLines"):
        ls.select_by_collection = True
        ls.collection = bpy.data.collections["NoLines"]
        ls.collection_negation = "EXCLUSIVE"
    if ls.linestyle is None:
        ls.linestyle = bpy.data.linestyles.new("ink")
    st = ls.linestyle
    st.color = rgb(color)
    st.thickness = thickness
    st.caps = "ROUND"
    return st


def render(path, width=1280, height=720, samples=40, background="#000000", transparent=False):
    scene = bpy.context.scene
    scene.render.film_transparent = transparent
    scene.render.image_settings.color_mode = "RGBA" if transparent else "RGB"
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = samples
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 4
    scene.cycles.transparent_max_bounces = 16
    scene.render.resolution_x, scene.render.resolution_y = width, height
    scene.render.resolution_percentage = 100
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("world")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = rgb(background) + (1.0,)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 1.0
    scene.render.filepath = path
    scene.render.image_settings.file_format = "PNG"
    bpy.ops.render.render(write_still=True)
