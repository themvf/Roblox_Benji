"""Render the written glossy black-box GLB under broad studio reflections."""
from pathlib import Path
import math
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/black-box"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(PKG / "exports/GlossyBlackBox.glb"))
scene = bpy.context.scene

ground = bpy.data.materials.new("Neutral_ground")
ground.use_nodes = True
ground.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.21,.23,.26,1)
ground.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = .75
bpy.ops.mesh.primitive_plane_add(size=200)
bpy.context.object.data.materials.append(ground)
bpy.context.object.location.z = -.055

world = bpy.data.worlds.new("Studio")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (.19,.21,.25,1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = .4

def softbox(name, location, power, shape, width, height):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = power
    data.shape = shape
    data.size = width
    if shape == "RECTANGLE":
        data.size_y = height
    light = bpy.data.objects.new(name, data)
    scene.collection.objects.link(light)
    light.location = location
    light.rotation_euler = (Vector((0,0,2.2))-light.location).to_track_quat("-Z","Y").to_euler()

softbox("Tall softbox left", (6,-3,6), 1100, "RECTANGLE", 1.3, 8)
softbox("Tall softbox right", (-3,6,5), 850, "RECTANGLE", 1.2, 7)
softbox("Large roof card", (0,0,10), 1300, "RECTANGLE", 5, 2)
softbox("Front fill", (7,8,4), 450, "RECTANGLE", 4, 4)

camera_data = bpy.data.cameras.new("Camera")
camera = bpy.data.objects.new("Camera",camera_data)
scene.collection.objects.link(camera)
scene.camera = camera
camera.location = (8,7,8)
camera.rotation_euler = (Vector((0,0,2.15))-camera.location).to_track_quat("-Z","Y").to_euler()
camera_data.lens = 44

scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.render.resolution_x = 960
scene.render.resolution_y = 720
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = "PNG"
scene.render.filepath = str(PKG / "review/gloss-study.png")
bpy.ops.render.render(write_still=True)
