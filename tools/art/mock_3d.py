"""Art-direction mock-up A: the console in 3D, seen from the operator's chair.

Builds the same desk as tools/art/console_scene.py (its plate geometry and moving parts, at their layout places),
folds the lower half into a sloping desk, maps what the game draws (from a screenshot, via mock_decal.py) onto
it, and puts the operator's room around it: a work lamp, pipes, a desk edge with a mug and papers.
  blender -b --factory-startup -P tools/art/mock_3d.py -- <out_dir> <decal_dir> [preview]
"""
import math
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import console_scene as cs  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:]
OUT = argv[0]
DECALS = argv[1]
PREVIEW = "preview" in argv
L = cs.L
HINGE_Y = 476          # screen y where the upright panel meets the sloping desk
SLOPE = -58.0          # degrees the lower half leans towards the operator


def image_material(name, path, emit=0.0, alpha=True, rough=0.6):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    t = m.node_tree
    t.nodes.clear()
    out = t.nodes.new("ShaderNodeOutputMaterial")
    tex = t.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(path)
    tex.interpolation = "Smart"
    bsdf = t.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Roughness"].default_value = rough
    t.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if emit > 0:
        t.links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emit
    if alpha:
        t.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    t.links.new(bsdf.outputs[0], out.inputs[0])
    return m


def plane_px(name, x, y, w, h, z, mat, u0=0.0, v0=0.0, u1=1.0, v1=1.0):
    """A plane over a screen-pixel rect at height z, its UVs a sub-rect of the texture (v up)."""
    import bmesh
    bm = bmesh.new()
    X0, Y0 = cs.P(x, y)
    X1, Y1 = cs.P(x + w, y + h)
    vs = [bm.verts.new((X0, Y1, z)), bm.verts.new((X1, Y1, z)), bm.verts.new((X1, Y0, z)), bm.verts.new((X0, Y0, z))]
    f = bm.faces.new(vs)
    uv = bm.loops.layers.uv.new()
    for loop, (u, v) in zip(f.loops, ((u0, v0), (u1, v0), (u1, v1), (u0, v1))):
        loop[uv].uv = (u, v)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    o.data.materials.append(mat)
    return o


def place(builder, x, y, rot=0.0, z=0.0):
    """Run a sprite builder (it builds at the origin) and move what it made to screen point (x, y)."""
    before = set(bpy.data.objects)
    builder(bpy.context.scene.collection)
    made = [o for o in bpy.data.objects if o not in before]
    pivot = bpy.data.objects.new("pivot", None)
    bpy.context.scene.collection.objects.link(pivot)
    for o in made:
        o.parent = pivot
    X, Y = cs.P(x, y)
    pivot.location = (X, Y, z)
    pivot.rotation_euler = (0, 0, -math.radians(rot))
    return pivot


def aim(o, at):
    """Point a camera or a light at a spot, with world up as up."""
    t = bpy.data.objects.new("aim_" + o.name, None)
    bpy.context.scene.collection.objects.link(t)
    t.location = at
    # The scene's up is +Y (the console stands in the XY plane): turn the target so its Z points that way.
    t.rotation_euler = (math.radians(-90), 0, 0)
    c = o.constraints.new("TRACK_TO")
    c.target = t
    c.track_axis = "TRACK_NEGATIVE_Z"
    c.up_axis = "UP_Y"
    c.use_target_z = True


def build():
    cs.reset()
    m = cs.M()
    cs.build_plate()
    # The moving parts, where the game draws them.
    for key in ("reel_a", "reel_b"):
        r = cs.L[key]
        place(cs.build_reel, r[0] + r[2] / 2, r[1] + r[3] / 2, 30)
    k = L["speed_knob"]
    place(lambda c: cs.build_knob(c, 19, "line"), k[0] + k[2] / 2, k[1] + k[3] / 2, 40)
    k = L["sector_knob"]
    place(lambda c: cs.build_knob(c, 24, "arrow"), k[0] + k[2] / 2, k[1] + k[3] / 2, -30)
    dp = L["dispatch_pivot"]
    place(lambda c: cs.build_lever(c, dp[2]), dp[0], dp[1], -38)
    cv = L["cover"]
    place(lambda c: cs.build_cover(c, False), cv[0] + cv[2] / 2, cv[1] + 1)
    for key, rad in (("order_wheel", 0), ("cond_wheel", 0)):
        w = L[key]
        place(lambda c, rr=w[2]: cs.build_wheel(c, rr, 6 if rr > 55 else 5), w[0], w[1], 20)
    ps = L["print_slot"]
    place(cs.build_punch_knob, ps[0] + ps[2] / 2, ps[1] + 18)
    cr = L["crank"]
    place(cs.build_crank, cr[0], cr[1], 60)
    pl = L["platen"]
    place(cs.build_platen, pl[0] + pl[2] / 2, pl[1] + pl[3] / 2)
    km = L["keys"]
    for i, wkey in enumerate((58, 70, 58, 122)):
        x0 = km[0] + 4 + sum(([58, 70, 58, 122][j] + 6) for j in range(i))
        place(lambda c, ww=wkey: cs.slab("key", (-ww / 2, -16, ww, 32), 0.0, 0.07, m["bakelite_black"], r=6, bevel=0.012, coll=c),
              x0 + wkey / 2, km[1] + km[3] / 2)
    cm = L["chute_mouth"]
    place(cs.build_chute_flap, cm[0] + cm[2] / 2, cm[1])
    # What the game draws: the decal over everything, the scope's picture as light.
    dec = image_material("decal", os.path.join(DECALS, "decal.png"))
    v_h = 1.0 - HINGE_Y / 720.0
    upper = plane_px("decal_upper", 0, 0, 1280, HINGE_Y, 0.2, dec, 0.0, v_h, 1.0, 1.0)
    lower = plane_px("decal_lower", 0, HINGE_Y, 1280, 720 - HINGE_Y, 0.2, dec, 0.0, 0.0, 1.0, v_h)
    scr = L["screen"]
    plane_px("screen", scr[0], scr[1], scr[2], scr[3], 0.004, image_material("screen", os.path.join(DECALS, "screen.png"), emit=4.0, alpha=False))
    # Fold the lower half into a sloping desk.
    hinge = bpy.data.objects.new("hinge", None)
    bpy.context.scene.collection.objects.link(hinge)
    hx, hy = cs.P(640, HINGE_Y)
    hinge.location = (hx, hy, 0)
    bpy.context.view_layer.update()
    for o in list(bpy.data.objects):
        if o.parent is not None or o.type not in ("MESH", "EMPTY") or o == hinge or o.name.startswith("bulkhead") or o.name.startswith("seam"):
            continue
        if o.name == "decal_lower":
            below = True
        elif o.name == "decal_upper":
            below = False
        else:
            # Where is it? Use the centre of its bounding box (mesh) or its location (empty pivots).
            if o.type == "MESH":
                ys = [(o.matrix_world @ v.co).y for v in o.data.vertices] or [o.location.y]
                cy = (max(ys) + min(ys)) / 2
            else:
                cy = o.location.y
            below = cy < hy
        if below:
            mw = o.matrix_world.copy()
            o.parent = hinge
            o.matrix_parent_inverse = hinge.matrix_world.inverted()
            o.matrix_world = mw
    hinge.rotation_euler = (math.radians(SLOPE), 0, 0)
    bpy.context.view_layer.update()
    # The room: a desk top in front of the slope, a floor, side walls with pipes, a hanging work lamp.
    drop = 2.4 * math.cos(math.radians(-SLOPE))
    out_z = 2.4 * math.sin(math.radians(-SLOPE))
    top = hy - drop

    def obj(mat, op, **kw):
        op(**kw)
        o = bpy.context.active_object
        o.data.materials.append(mat)
        return o

    d = obj(m["wood"], bpy.ops.mesh.primitive_cube_add, size=1.0, location=(6.4, top - 0.09, out_z + 1.55))
    d.scale = (14.0, 0.18, 3.2)
    bev = d.modifiers.new("bev", "BEVEL")
    bev.width = 0.03
    bev.segments = 3
    # Clutter: a chipped enamel mug, a saucer of cigarette ends, papers, a pencil.
    obj(m["enamel_dark"], bpy.ops.mesh.primitive_cylinder_add, radius=0.26, depth=0.62, location=(1.5, top + 0.31, out_z + 1.25))
    obj(m["rubber"], bpy.ops.mesh.primitive_cylinder_add, radius=0.22, depth=0.02, location=(1.5, top + 0.6, out_z + 1.25))
    obj(m["steel"], bpy.ops.mesh.primitive_cylinder_add, radius=0.45, depth=0.04, location=(11.3, top + 0.02, out_z + 1.0))
    for i in range(4):
        c2 = obj(m["paper"], bpy.ops.mesh.primitive_cylinder_add, radius=0.03, depth=0.3,
                 location=(11.15 + i * 0.1, top + 0.07, out_z + 0.95 + (i % 2) * 0.12), rotation=(0, math.radians(90), 0.4 * i))
    for i, (px, pz, rot) in enumerate(((3.8, 1.4, 0.2), (4.7, 1.0, -0.35), (8.7, 1.5, 0.1))):
        pp = obj(m["paper"], bpy.ops.mesh.primitive_cube_add, size=1.0, location=(px, top + 0.005 + i * 0.007, out_z + pz),
                 rotation=(0, rot, 0))
        pp.scale = (1.5, 0.006, 2.0)
    obj(m["red"], bpy.ops.mesh.primitive_cylinder_add, radius=0.035, depth=1.4, location=(6.6, top + 0.04, out_z + 0.8),
        rotation=(0, math.radians(90), math.radians(20)))
    # Floor, and pipes running up the walls on either side.
    fl = obj(m["wall"], bpy.ops.mesh.primitive_cube_add, size=1.0, location=(6.4, top - 3.0, 6))
    fl.scale = (40, 0.2, 30)
    for sx in (-0.9, 13.7):
        for k, pr in enumerate((0.2, 0.11, 0.15)):
            obj(m["brass_dark"] if k else m["steel"], bpy.ops.mesh.primitive_cylinder_add, radius=pr, depth=20.0,
                location=(sx + k * 0.42 * (1 if sx < 0 else -1), -4.0, 0.6 + k * 0.3))
    # The work lamp: a green enamel shade over the desk, its bulb, and its light.
    shade = obj(cs.material("shade_green", "#1f3a2c", rough=0.4, coat=0.5), bpy.ops.mesh.primitive_cone_add,
                radius1=1.1, radius2=0.25, depth=0.7, location=(6.4, 1.75, 5.0))
    obj(cs.emission("bulb", "#ffd9a0", 30.0), bpy.ops.mesh.primitive_uv_sphere_add, radius=0.2, location=(6.4, 1.45, 5.0))
    obj(m["rubber"], bpy.ops.mesh.primitive_cylinder_add, radius=0.02, depth=6.0, location=(6.4, 5.0, 5.0))
    sp = bpy.data.lights.new("lamp", "SPOT")
    sp.energy = 2600
    sp.spot_size = math.radians(95)
    sp.spot_blend = 0.7
    sp.color = (1.0, 0.8, 0.55)
    sp.shadow_soft_size = 0.4
    so = bpy.data.objects.new("lamp", sp)
    bpy.context.scene.collection.objects.link(so)
    so.location = (6.4, 1.4, 5.0)
    aim(so, (6.4, -5.2, 2.0))
    # The console's own key light, dimmer than on the flat plate.
    cs.lights(scale=0.45)
    # A faint cold bounce, and the scope's green spill.
    fill = bpy.data.lights.new("fill", "AREA")
    fill.energy = 120
    fill.size = 6
    fill.color = (0.5, 0.7, 0.75)
    fo = bpy.data.objects.new("fill", fill)
    bpy.context.scene.collection.objects.link(fo)
    fo.location = (6.4, -9.0, 9.0)
    aim(fo, (6.4, -4.0, 0.0))
    gl = bpy.data.lights.new("scope_glow", "AREA")
    gl.energy = 60
    gl.size = 5.5
    gl.size_y = 3.2
    gl.shape = "RECTANGLE"
    gl.color = (0.3, 1.0, 0.55)
    go = bpy.data.objects.new("scope_glow", gl)
    bpy.context.scene.collection.objects.link(go)
    sx0, sy0 = cs.P(326, 203)
    go.location = (sx0, sy0, 0.3)


def render():
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 24 if PREVIEW else 64
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 4
    sc.render.resolution_x = 1920
    sc.render.resolution_y = 1080
    sc.render.resolution_percentage = 50 if PREVIEW else 100
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Medium High Contrast"
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.002, 0.003, 0.003, 1)
    sc.world = world
    cam_d = bpy.data.cameras.new("cam")
    cam_d.lens = 27
    cam_d.clip_end = 100
    cam = bpy.data.objects.new("cam", cam_d)
    sc.collection.objects.link(cam)
    cam.location = (6.4, -2.6, 12.5)
    # Look slightly down at the middle of the console.
    aim(cam, (6.4, -4.3, 0.8))
    sc.camera = cam
    os.makedirs(OUT, exist_ok=True)
    sc.render.filepath = os.path.join(OUT, "mock-3d.png")
    bpy.ops.render.render(write_still=True)


build()
render()
print("mock-up written to", OUT)
