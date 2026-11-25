"""Render a held weapon with its glow parts lit, as Roblox shows a Neon MeshPart, because the audit
sheets render everything matte and a Neon core never shows there (the Plasma Blaster, 2026-11-23).

    blender -b -noaudio --python tools/blender/render_glow_preview.py -- <export.glb> <out.png> \
        --glow Core=255,120,24 [--glow Name=r,g,b ...]

Lays out four shots in one sheet: side, three-quarter front, muzzle head-on and three-quarter back.
Cycles on the CPU (EEVEE crashes headless without a GPU), with a fog-glow pass standing in for Roblox
bloom. It is a preview of intent, not of Studio: check the real thing in a playtest.
"""

import math
import sys

import bpy
import mathutils

argv = sys.argv[sys.argv.index("--") + 1 :]
src, out = argv[0], argv[1]
glows = {}
for i, a in enumerate(argv):
    if a == "--glow":
        name, rgb = argv[i + 1].split("=")
        glows[name] = tuple(int(c) / 255 for c in rgb.split(","))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
for ob in meshes:
    if ob.name in glows:
        mat = bpy.data.materials.new(ob.name + "_glow")
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*glows[ob.name], 1)
        bsdf.inputs["Emission Color"].default_value = (*glows[ob.name], 1)
        bsdf.inputs["Emission Strength"].default_value = 6.0
        ob.data.materials.clear()
        ob.data.materials.append(mat)

lo = mathutils.Vector([min((o.matrix_world @ v.co)[i] for o in meshes for v in o.data.vertices) for i in range(3)])
hi = mathutils.Vector([max((o.matrix_world @ v.co)[i] for o in meshes for v in o.data.vertices) for i in range(3)])
centre, size = (lo + hi) / 2, (hi - lo).length

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 48
scene.render.resolution_x, scene.render.resolution_y = 900, 560
scene.view_settings.view_transform = "Standard"
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.32, 0.34, 0.38, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
scene.world = world
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35))
scene.collection.objects.link(sun)

scene.use_nodes = True
tree = scene.node_tree
layers = tree.nodes["Render Layers"]
glare = tree.nodes.new("CompositorNodeGlare")
glare.glare_type = "FOG_GLOW"
glare.threshold = 0.9
glare.size = 7
tree.links.new(layers.outputs["Image"], glare.inputs["Image"])
tree.links.new(glare.outputs["Image"], tree.nodes["Composite"].inputs["Image"])

cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.clip_start, cam.data.clip_end = size * 0.01, size * 20
cam.data.lens = 50
scene.collection.objects.link(cam)
scene.camera = cam

# Blender frame: Z up, muzzle toward -Y.
shots = [
    ("side", (1, 0, 0.12), 1.15, None),
    ("front34", (0.8, -0.9, 0.35), 0.8, None),
    ("muzzle", (0.12, -1, 0.08), 0.22, (0, lo.y, 0.25)),
    ("back34", (-0.8, 0.9, 0.35), 0.8, None),
]
from pathlib import Path

frames = []
for name, direction, dist, target in shots:
    aim = mathutils.Vector(target) if target else centre
    d = mathutils.Vector(direction).normalized()
    cam.location = aim + d * size * dist
    cam.rotation_euler = (aim - cam.location).to_track_quat("-Z", "Y").to_euler()
    path = str(Path(out).with_name(Path(out).stem + "_" + name + ".png"))
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    frames.append(path)
    print("rendered", path)

# Stitch 2x2.
imgs = [bpy.data.images.load(p) for p in frames]
w, h = imgs[0].size
sheet = bpy.data.images.new("sheet", w * 2, h * 2)
pix = [0.0] * (w * 2 * h * 2 * 4)
for idx, im in enumerate(imgs):
    ox, oy = (idx % 2) * w, (1 - idx // 2) * h
    p = im.pixels[:]
    for row in range(h):
        start = ((oy + row) * w * 2 + ox) * 4
        pix[start : start + w * 4] = p[row * w * 4 : (row + 1) * w * 4]
sheet.pixels[:] = pix
sheet.filepath_raw = out
sheet.file_format = "PNG"
sheet.save()
print("sheet", out)
