"""Visual audit renders for a skinned look prepared for Avatar Setup.

    blender -b -noaudio --python tools/blender/audit_skinned.py -- <folder>

Loads Body.glb, Hair.glb and Headgear.glb together as written (front = Blender +Y after import)
and renders into <folder>/audit/:
- front, back, left, right and three-quarter views;
- close-ups of the head, chest, each hand, the hips and the boots, front and back;
- each accessory alone, front and side, in a flat colour per accessory so nothing hides.

A review sheet is only as good as the views it shows: the back and the accessories were the ones
skipped on the DarkArmour trial.
"""
import math
import os
import sys

import bpy

folder = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
out = os.path.join(folder, "audit")
os.makedirs(out, exist_ok=True)
for stale in os.listdir(out):  # a part removed since the last run must not leave its old renders
    if stale.endswith(".png"):
        os.remove(os.path.join(out, stale))

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 16
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.64, 0.68, 1)
world.node_tree.nodes["Background"].inputs[1].default_value = 1.1

parts = {}
for name in ("Body", "Hair", "Headgear"):
    path = os.path.join(folder, f"{name}.glb")
    if not os.path.exists(path):
        continue
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    meshes = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    for o in bpy.data.objects:
        o.select_set(o in meshes)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(obj.data.polygons):
        parts[name] = obj
    else:
        bpy.data.objects.remove(obj)

sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 2.2
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.type = "ORTHO"
cam.data.clip_start = 0.1
cam.data.clip_end = 200

zs = [(o.matrix_world @ v.co).z for o in parts.values() for v in o.data.vertices]
bottom = min(zs)
top = max(zs)
xs = [abs((parts["Body"].matrix_world @ v.co).x) for v in parts["Body"].data.vertices]
span = max(xs)


def shot(file, yaw, centre, size, res=(700, 800)):
    """yaw 0 looks at the front (+Y face) from +Y; 180 the back; 90 from +X."""
    scene.render.resolution_x, scene.render.resolution_y = res
    cam.data.ortho_scale = size
    a = math.radians(yaw)
    d = 40
    cx, cz = centre
    cam.location = (cx + d * math.sin(a), d * math.cos(a), cz)
    # pitched 90 the camera looks along +Y; yawed by (pi - a) it looks back at the origin
    cam.rotation_euler = (math.radians(90), 0, math.pi - a)
    sun.rotation_euler = (math.radians(55), 0, math.pi - a - math.radians(25))
    scene.render.filepath = os.path.join(out, file)
    bpy.ops.render.render(write_still=True)


full = max(top, 2 * span) * 1.1
views = {"front": 0, "back": 180, "right": 90, "left": -90, "three-quarter": 35, "back-three-quarter": 145}
for name, yaw in views.items():
    shot(f"view-{name}.png", yaw, (0, (top + bottom) / 2), full)
arm_x = span - 0.55  # the hand's centre, half a hand in from the fingertips
# match-body heights above the feet (MATCH_BODY.md); hands at the T-pose shoulder line
b = bottom
closeups = {"head": (0, b + 5.35, 1.9), "chest": (0, b + 3.9, 2.4), "hips": (0, b + 2.8, 2.4),
            "boots": (0, b + 0.7, 2.2), "hand-left": (arm_x, b + 4.55, 1.8), "hand-right": (-arm_x, b + 4.55, 1.8)}
for name, (x, z, size) in closeups.items():
    for side, yaw in (("front", 0), ("back", 180)):
        shot(f"close-{name}-{side}.png", yaw, (x, z), size, (600, 600))

# each accessory alone, flat colour, so its whole shape shows
for name in [n for n in parts if n != "Body"]:
    for other, o in parts.items():
        o.hide_render = other != name
    flat = bpy.data.materials.new(name + "Flat")
    flat.diffuse_color = (0.9, 0.5, 0.2, 1)
    flat.use_nodes = True
    flat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.9, 0.5, 0.2, 1)
    keep = list(parts[name].data.materials)
    parts[name].data.materials.clear()
    parts[name].data.materials.append(flat)
    for side, yaw in (("front", 0), ("side", 90), ("top", 0)):
        if side == "top":
            cam.location = (0, 0, top + 20)
            cam.rotation_euler = (0, 0, 0)
            cam.data.ortho_scale = 2.4
            scene.render.resolution_x = scene.render.resolution_y = 600
            scene.render.filepath = os.path.join(out, f"alone-{name}-top.png")
            bpy.ops.render.render(write_still=True)
        else:
            shot(f"alone-{name}-{side}.png", yaw, (0, top - 0.9), 2.6, (600, 600))
    parts[name].data.materials.clear()
    for m in keep:
        parts[name].data.materials.append(m)
for o in parts.values():
    o.hide_render = False
print("AUDIT", out, sorted(os.listdir(out)))
