"""Bathy on the hangar's bench, for the Lab (2026-10-28/29): the stock hull, or fitted with upgrades.

Bathy is the brass diving bell from robbie_designs.py (round 1, design 1). The Company's parts are Admiralty
(docs/design/art-direction.md): navy grey-green enamel, dark bronze, chipped valve red on what moves. They hang off
him, so you can tell at a glance what a hull carries.

Two modes:
  blender -b --factory-startup -P tools/art/lab_bathy.py -- <out.png> [stock|all|part,part] [samples] [size]
      one picture of him with those parts (the mock-ups)
  blender -b --factory-startup -P tools/art/lab_bathy.py -- --layers <out_dir> [samples] [size]
      the game's Lab art: bathy_body.png and one bathy_<layer>.png per part (and per stock part), all from the
      same camera, each with the body as a holdout so it hides what is behind him. The Lab stacks the body and
      one layer per socket (game/console/lab_view.gd).
"""
import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kit  # noqa: E402
import robbie_designs as rd  # noqa: E402

# Socket -> layers that can sit in it (the first is the stock part).
LAYERS = {
    "lamp": ["lamp_std", "spotlight", "floodlight", "red_lamp"],
    "drive": ["pods_std", "twin_screws", "silent_fins"],
    "hatch": ["antenna_std", "hydrophone"],
    "belly": ["battery_bank", "reserve_cell"],
    "hull": ["plating", "insulated"],
    "tool": ["laser_std", "flares"],
}
STOCK = ["lamp_std", "pods_std", "antenna_std", "laser_std"]
ALL = ["spotlight", "twin_screws", "battery_bank", "plating", "laser_std", "hydrophone"]


def body(M):
    """Bathy without the parts the Lab swaps: the bell, its band, the porthole and face, the hatch."""
    c = (0, 0, 1.0)
    brass = M("brass", "#d39b45", "#8c5a24", "#ffe1a0")
    copper = M("copper", "#9a5a2c", "#5a3216", "#d08a5a")
    dark = M("screen", "#1c2a3a", "#101822", "#2c4058")
    eye = kit.glow("eye", "#7af0ff", 2.2)
    blush = M("blush", "#ff9aa8", lit=0.6, ao=0.0)
    glass = kit.glass("glass", "#e8f8ff", "#ffffff", 0.9, 0.03)
    kit.sphere(c, 0.72, brass)
    kit.torus((0, 0, 0.78), 0.69, 0.04, copper)
    kit.torus((0.69, 0, 1.1), 0.34, 0.075, copper, rot=rd.facing_x())
    kit.sphere((0.68, 0, 1.1), 0.31, dark, scale=(0.3, 1, 1))
    for s in (-1, 1):
        kit.sphere((0.77, s * 0.11, 1.14), 0.07, eye, scale=(0.4, 0.75, 1.25), segs=24)
        kit.sphere((0.75, s * 0.21, 0.99), 0.05, blush, scale=(0.4, 1, 0.7), segs=16)
    kit.no_lines(kit.sphere((0.72, 0, 1.1), 0.3, glass, scale=(0.35, 1, 1)))
    for k in range(12):
        a = k * 2 * math.pi / 12
        kit.sphere(rd.on_sphere(c, 0.71, (0.78, 0.46 * math.cos(a), 0.1 + 0.46 * math.sin(a))), 0.033, copper, segs=12)
    kit.cyl((0, 0, 1.7), 0.22, 0.08, copper)
    kit.torus((0, 0, 1.82), 0.12, 0.03, brass, rot=(math.pi / 2, 0, 0))


def mats(M):
    return dict(
        brass=M("brass", "#d39b45", "#8c5a24", "#ffe1a0"),
        copper=M("copper", "#9a5a2c", "#5a3216", "#d08a5a"),
        navy=M("navy", "#3b4f4f", "#1d2828", "#6b8580"),
        bronze=M("bronze", "#6e5230", "#36261a", "#a8844e"),
        red=M("valve_red", "#9c2a1a", "#521108", "#d0503a"),
        steel=M("steel", "#5b5f60", "#2a2c2e", "#9aa0a0"),
        rubber=M("rubber", "#262626", "#101010", "#4a4a4a"),
    )


def part(name, m):
    """Build one part (a layer)."""
    navy, bronze, red, steel, copper, brass = m["navy"], m["bronze"], m["red"], m["steel"], m["copper"], m["brass"]
    if name == "lamp_std":
        kit.cyl((0.62, 0, 0.58), 0.12, 0.14, copper, rot=(0, math.pi / 2 + 0.35, 0))
        kit.sphere((0.69, 0, 0.555), 0.1, kit.glow("lens", "#ffd77a", 1.4), scale=(0.4, 1, 1), rot=(0, 0.35, 0), segs=24)
    elif name == "red_lamp":
        kit.cyl((0.62, 0, 0.58), 0.12, 0.14, navy, rot=(0, math.pi / 2 + 0.35, 0))
        kit.sphere((0.69, 0, 0.555), 0.1, kit.glow("red_lens", "#ff3a22", 2.0), scale=(0.4, 1, 1), rot=(0, 0.35, 0), segs=24)
    elif name == "spotlight":
        kit.cyl((0.7, 0, 0.56), 0.11, 0.36, navy, rot=(0, math.pi / 2 + 0.3, 0))
        kit.torus((0.86, 0, 0.51), 0.11, 0.025, bronze, rot=(0, math.pi / 2 + 0.3, 0))
        kit.sphere((0.87, 0, 0.505), 0.09, kit.glow("spot", "#fff0b0", 2.4), scale=(0.3, 1, 1), rot=(0, 0.3, 0), segs=24)
    elif name == "floodlight":
        kit.cone((0.68, 0, 0.56), 0.08, 0.24, 0.16, navy, rot=(0, math.pi / 2 + 0.3, 0))
        kit.sphere((0.76, 0, 0.535), 0.21, kit.glow("flood", "#ffe7a0", 1.8), scale=(0.15, 1, 1), rot=(0, 0.3, 0), segs=32)
        kit.torus((0.76, 0, 0.535), 0.23, 0.02, bronze, rot=(0, math.pi / 2 + 0.3, 0))
    elif name == "pods_std":
        for s in (-1, 1):
            kit.cyl((-0.05, s * 0.8, 0.92), 0.15, 0.5, copper, rot=rd.facing_x())
            kit.sphere((0.2, s * 0.8, 0.92), 0.15, brass, scale=(0.6, 1, 1), segs=24)
            for k in range(3):
                kit.sphere((-0.33, s * 0.8, 0.92), 0.17, brass, scale=(0.08, 0.35, 1.0), rot=(k * math.pi / 1.5, 0, 0), segs=16)
    elif name == "twin_screws":
        for s in (-1, 1):
            kit.cyl((-0.15, s * 0.86, 0.92), 0.17, 0.75, navy, rot=rd.facing_x())
            kit.sphere((0.24, s * 0.86, 0.92), 0.17, bronze, scale=(0.6, 1, 1), segs=24)
            for k in range(4):
                kit.sphere((-0.55, s * 0.86, 0.92), 0.21, bronze, scale=(0.07, 0.3, 1.0), rot=(k * math.pi / 2, 0, 0), segs=16)
            kit.sphere((-0.57, s * 0.86, 0.92), 0.06, red, segs=12)
    elif name == "silent_fins":
        for s in (-1, 1):
            kit.sphere((-0.05, s * 0.78, 0.92), 0.13, navy, scale=(1.6, 1, 0.9), segs=24)
            kit.sphere((-0.42, s * 0.8, 0.92), 0.28, kit.toon("fin", bpy.data.node_groups["Lighting"], "#4f6a66", "#22302e", "#86a29c"),
                       scale=(0.9, 0.08, 0.6), segs=24)
    elif name == "antenna_std":
        kit.cyl((-0.3, 0.15, 1.75), 0.018, 0.45, copper)
        kit.sphere((-0.3, 0.15, 2.0), 0.055, kit.glow("tip", "#8cff9a", 2.5), segs=16)
    elif name == "hydrophone":
        kit.cyl((-0.3, 0.15, 1.75), 0.018, 0.45, copper)
        kit.sphere((-0.3, 0.15, 2.0), 0.055, kit.glow("tip", "#8cff9a", 2.5), segs=16)
        kit.cone((0.1, -0.1, 1.95), 0.03, 0.2, 0.45, bronze, rot=rd.along((0.5, -0.2, 0.8)))
        kit.torus((0.22, -0.15, 2.13), 0.19, 0.02, red, rot=rd.along((0.5, -0.2, 0.8)))
    elif name == "battery_bank":
        for s in (-1, 1):
            kit.cyl((-0.05, s * 0.24, 0.3), 0.14, 0.7, navy, rot=rd.facing_x())
            kit.cyl((0.32, s * 0.24, 0.3), 0.09, 0.06, red, rot=rd.facing_x())
            for x in (-0.25, 0.15):
                kit.torus((x, s * 0.24, 0.3), 0.145, 0.02, bronze, rot=rd.facing_x())
        kit.torus((0, 0, 0.86), 0.74, 0.035, bronze)
    elif name == "reserve_cell":
        kit.cyl((-0.3, -0.62, 1.32), 0.12, 0.42, navy, rot=(0.45, 0.0, 0))
        kit.cyl((-0.3, -0.71, 1.51), 0.07, 0.06, red, rot=(0.45, 0.0, 0))
        kit.torus((-0.3, -0.62, 1.32), 0.125, 0.02, bronze, rot=(0.45, 0.0, 0))
    elif name == "plating":
        kit.torus((0, 0, 0.98), 0.71, 0.085, navy)
        for k in range(16):
            a = k * 2 * math.pi / 16
            if math.cos(a) > 0.93:
                continue
            kit.sphere((0.79 * math.cos(a), 0.79 * math.sin(a), 0.98), 0.03, bronze, segs=10)
    elif name == "insulated":
        kit.torus((0, 0, 0.98), 0.715, 0.06, m["rubber"])
        kit.torus((0, 0, 0.62), 0.6, 0.05, m["rubber"])
    elif name == "laser_std":
        kit.cyl((0.72, 0.28, 0.42), 0.05, 0.7, steel, rot=rd.facing_x())
        kit.cyl((0.5, 0.28, 0.42), 0.09, 0.22, navy, rot=rd.facing_x())
        kit.sphere((1.08, 0.28, 0.42), 0.045, kit.glow("laser_tip", "#ff4a2a", 3.0), segs=16)
    elif name == "flares":
        for k in range(3):
            kit.cyl((0.5, -0.2 - k * 0.12, 0.44), 0.05, 0.34, navy, rot=rd.facing_x())
            kit.sphere((0.68, -0.2 - k * 0.12, 0.44), 0.05, red, segs=12)
        kit.box((0.36, -0.32, 0.44), (0.1, 0.4, 0.14), bronze)


def setup():
    """The scene from robbie_designs (light rig, materials, floor, shadow), with the body only."""
    scene, _names, floor = rd.build(1, "dark")
    # rd.build made the whole stock Bathy: clear it and keep the rig, the floor and the shadow.
    keep = {floor.name}
    for o in list(bpy.data.objects):
        if o.name not in keep and not o.name.lower().startswith("shadow") and o.type == "MESH":
            if o.active_material is None or "shadow" not in o.active_material.name:
                bpy.data.objects.remove(o)
    light = bpy.data.node_groups["Lighting"]

    def M(name, base, shade=None, high=None, **kw):
        kw.setdefault("ao", 0.45)
        return kit.toon(name, light, base, shade, high, **kw)

    return scene, floor, M


def build_layers(M):
    """Every layer in one scene, each a list of objects."""
    layers = {}
    before = set(bpy.data.objects)
    body(M)
    layers["body"] = [o for o in bpy.data.objects if o not in before]
    m = mats(M)
    for socket in LAYERS.values():
        for name in socket:
            before = set(bpy.data.objects)
            part(name, m)
            layers[name] = [o for o in bpy.data.objects if o not in before]
    return layers


def camera():
    kit.look_camera((4.6, -2.9, 2.2), (0.0, 0, 1.0), lens=60)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    layers_mode = argv[0] == "--layers"
    if layers_mode:
        out_dir = argv[1]
        samples = int(argv[2]) if len(argv) > 2 else 32
        px = int(argv[3]) if len(argv) > 3 else 512
    else:
        out = argv[0]
        which = argv[1] if len(argv) > 1 else "stock"
        samples = int(argv[2]) if len(argv) > 2 else 40
        px = int(argv[3]) if len(argv) > 3 else 720
    scene, floor, M = setup()
    layers = build_layers(M)
    shadows = [o for o in bpy.data.objects if o.active_material is not None and "shadow" in o.active_material.name]
    kit.outlines(2.8, "#030405")
    floor.hide_render = True
    camera()
    if not layers_mode:
        fit = ALL if which == "all" else (STOCK if which == "stock" else which.split(","))
        for name, objs in layers.items():
            for o in objs:
                o.hide_render = not (name == "body" or name in fit)
        kit.render(out, px, px, samples=samples, background="#12161c", transparent=True)
        return
    os.makedirs(out_dir, exist_ok=True)
    # For a part layer the body wears a holdout material: still solid to the camera and to the ink lines (so
    # what is behind him stays hidden), but it renders as nothing. Its own lines are left out of the line set.
    hold = bpy.data.collections.new("BodyLines")
    scene.collection.children.link(hold)
    for o in layers["body"]:
        if o.name in scene.collection.objects:
            scene.collection.objects.unlink(o)
            hold.objects.link(o)
    holdout = bpy.data.materials.new("holdout")
    holdout.use_nodes = True
    nt = holdout.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out_node = nt.nodes.new("ShaderNodeOutputMaterial")
    hn = nt.nodes.new("ShaderNodeHoldout")
    nt.links.new(hn.outputs[0], out_node.inputs[0])
    originals = {o.name: [sl.material for sl in o.material_slots] for o in layers["body"]}
    for target in layers:
        for name, objs in layers.items():
            if name == "body":
                continue
            for o in objs:
                o.hide_render = name != target
        for o in shadows:
            o.hide_render = target != "body"
        for o in layers["body"]:
            for i, sl in enumerate(o.material_slots):
                sl.material = originals[o.name][i] if target == "body" else holdout
        kit.outlines(2.8, "#030405")
        ls = scene.view_layers[0].freestyle_settings.linesets[0]
        ls.select_by_collection = True
        if target == "body":
            ls.collection = bpy.data.collections.get("NoLines") or hold
            ls.collection_negation = "EXCLUSIVE"
        else:
            ls.collection = hold
            ls.collection_negation = "EXCLUSIVE"
        kit.render(os.path.join(out_dir, "bathy_%s.png" % target), px, px, samples=samples, background="#12161c", transparent=True)
        print("layer", target)


if __name__ == "__main__":
    main()
