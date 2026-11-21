"""Render neutral and reflective reviews from the written glossy GLB."""
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/bluetube-glossy"
args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
glb = Path(args[0]) if args else PKG / "exports/BlueTube_Glossy.glb"
prefix = args[1] if len(args) > 1 else ""
night_only = "--night-only" in args
damage_only = "--damage-only" in args
front_only = "--front-only" in args

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(glb))
scene = bpy.context.scene

ground = bpy.data.materials.new("Neutral blue-grey floor")
ground.use_nodes = True
ground.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.24, .28, .32, 1)
ground.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = .75
bpy.ops.mesh.primitive_plane_add(size=100)
bpy.context.object.location.z = -.06
bpy.context.object.data.materials.append(ground)

world = bpy.data.worlds.new("Neutral studio")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (.30, .36, .42, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = .7

def softbox(name, xyz, power, width, height):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = power
    data.shape = "RECTANGLE"
    data.size = width
    data.size_y = height
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    obj.location = xyz
    obj.rotation_euler = (Vector((0, 0, 6)) - obj.location).to_track_quat("-Z", "Y").to_euler()

softbox("Long white reflection", (9, -7, 13), 2500, 2.2, 12)
softbox("Cool side reflection", (-8, 4, 10), 1900, 2.0, 10)
softbox("Overhead fill", (0, 1, 18), 2300, 9, 4)
softbox("Front fill", (1, -11, 7), 750, 5, 8)

cam_data = bpy.data.cameras.new("Camera")
cam = bpy.data.objects.new("Camera", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x = 900
scene.render.resolution_y = 900
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"

views = {
    "front": ((0, -25, 8), (0, 0, 5.7), 43),
    "side": ((25, 0, 8), (0, 0, 5.7), 43),
    "rear": ((0, 25, 8), (0, 0, 5.7), 43),
    "quarter": ((19, -22, 10), (0, 0, 5.7), 51),
    "top": ((8, -10, 24), (0, 0, 10.5), 55),
}
if night_only:
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = .06
    ground.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.06, .075, .09, 1)
    for ob in scene.objects:
        if ob.type == "LIGHT" and ob.data.type == "AREA":
            ob.data.energy *= .06
    views = {"night": ((19, -22, 10), (0, 0, 5.7), 51)}
if damage_only:
    views = {"damage": ((9, -12, 9), (1.7, -2.4, 6.2), 64)}
if front_only:
    views = {"front": views["front"]}
for name, (eye, look, lens) in views.items():
    cam.location = eye
    cam.rotation_euler = (Vector(look) - cam.location).to_track_quat("-Z", "Y").to_euler()
    cam_data.lens = lens
    scene.render.filepath = str(PKG / "review" / f"{prefix}{name}.png")
    bpy.ops.render.render(write_still=True)
    print("RENDERED", scene.render.filepath)
