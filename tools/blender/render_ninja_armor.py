"""Render the saved armor GLB on a neutral R15 scale stand-in, not source scene."""
import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/ninja-soldier-skins"
args = sys.argv[sys.argv.index("--") + 1:]
variant = args[0]
front_only = "--front-only" in args
glb = PKG / "exports" / f"{variant}Armor.glb"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(glb))
scene = bpy.context.scene

mannequin = bpy.data.materials.new("Neutral under-armor R15 mannequin")
mannequin.diffuse_color = (.045, .065, .073, 1)
mannequin.use_nodes = True
bsdf = mannequin.node_tree.nodes["Principled BSDF"]
bsdf.inputs["Base Color"].default_value = (.045, .065, .073, 1)
bsdf.inputs["Roughness"].default_value = .67


def body(name, xyz, dimensions, ball=False):
    if ball:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8)
    else:
        bpy.ops.mesh.primitive_cube_add()
    obj = bpy.context.object
    obj.name = name
    obj.location = xyz
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mannequin)
    if ball:
        for face in obj.data.polygons:
            face.use_smooth = True


body("mannequin head", (0, 0, 4.78), (1.06, 1.02, 1.04), True)
body("mannequin upper torso", (0, 0, 3.75), (1.82, .72, 1.32))
body("mannequin lower torso", (0, 0, 2.85), (1.58, .67, .69))
for x in (-1.44, 1.44):
    for z, height in ((3.66, .92), (2.79, .84), (2.10, .30)):
        body("mannequin arm", (x, 0, z), (.52, .52, height), True)
for x in (-.53, .53):
    for z, height in ((1.91, .89), (1.03, .82)):
        body("mannequin leg", (x, 0, z), (.66, .63, height), True)
    body("mannequin foot", (x, .14, .38), (.75, 1.0, .28), True)

floor = bpy.data.materials.new("Slate floor")
floor.use_nodes = True
floor.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.22, .25, .29, 1)
bpy.ops.mesh.primitive_plane_add(size=60)
bpy.context.object.location.z = -.05
bpy.context.object.data.materials.append(floor)

world = bpy.data.worlds.new("Studio neutral")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (.25, .30, .34, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = .8


def light(name, xyz, energy, size):
    lamp = bpy.data.lights.new(name, "AREA")
    lamp.energy = energy
    lamp.shape = "RECTANGLE"
    lamp.size = size
    lamp.size_y = size * 1.8
    obj = bpy.data.objects.new(name, lamp)
    scene.collection.objects.link(obj)
    obj.location = xyz
    obj.rotation_euler = (Vector((0, 0, 2.8)) - obj.location).to_track_quat("-Z", "Y").to_euler()


light("front softbox", (5, -6, 8), 1800, 4)
light("rear rim", (-5, 4, 7), 2200, 3)
light("overhead", (0, 1, 10), 1700, 5)

camera_data = bpy.data.cameras.new("Camera")
camera = bpy.data.objects.new("Camera", camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera_data.lens = 48
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.cycles.use_denoising = True
scene.render.resolution_x = scene.render.resolution_y = 800
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
views = {"front": (0, 12, 5), "side": (12, 0, 5),
         "rear": (0, -12, 5), "quarter": (8, 10, 6)}
if front_only:
    views = {"front": views["front"]}
for name, eye in views.items():
    camera.location = eye
    camera.rotation_euler = (Vector((0, 0, 2.75)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = str(PKG / "review" / f"{variant}-{name}.png")
    bpy.ops.render.render(write_still=True)
    print("RENDERED", scene.render.filepath)
