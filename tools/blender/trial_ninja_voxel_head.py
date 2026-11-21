"""Probe whether a closed retopology guide preserves the source helmet shape."""
from pathlib import Path
import json

import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/ninja-soldier-skins"
TRIAL = PKG / "trials/SciFiSentryVoxelHead"
TRIAL.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(PKG / "source/SciFiSentrySource.glb"))
obj = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
bm = bmesh.new()
bm.from_mesh(obj.data)
discard = [f for f in bm.faces if f.calc_center_median().z < .30]
bmesh.ops.delete(bm, geom=discard, context="FACES")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
bm.to_mesh(obj.data)
bm.free()
obj.name = "Helmet source crop"
obj.scale = (5.5, 5.5, 5.5)
obj.location.z = 2.75
bpy.context.view_layer.objects.active = obj
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Thin broken scan sheets need volume before voxel remeshing. This is only a
# topology probe; the source texture remains in the original file for baking.
solid = obj.modifiers.new("Give source sheets thickness", "SOLIDIFY")
solid.thickness = .025
solid.offset = 0
bpy.ops.object.modifier_apply(modifier=solid.name)
obj.data.remesh_voxel_size = .035
obj.data.remesh_voxel_adaptivity = 0
bpy.ops.object.voxel_remesh()

decimate = obj.modifiers.new("Helmet study reduction", "DECIMATE")
decimate.ratio = min(1.0, 3500 / max(1, len(obj.data.polygons)*2))
bpy.ops.object.modifier_apply(modifier=decimate.name)

mat = bpy.data.materials.new("Helmet topology review")
mat.use_nodes = True
mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.035, .05, .06, 1)
mat.node_tree.nodes["Principled BSDF"].inputs["Metallic"].default_value = .45
mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = .4
obj.data.materials.clear()
obj.data.materials.append(mat)

bm = bmesh.new()
bm.from_mesh(obj.data)
report = {"triangles": sum(len(f.verts)-2 for f in bm.faces),
          "nonManifoldEdges": sum(not e.is_manifold for e in bm.edges),
          "componentsUntested": True,
          "status": "closed-shape helmet retopology probe only; no texture, rig, face or cage"}
bm.free()

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.render.resolution_x = 700
scene.render.resolution_y = 700
scene.render.resolution_percentage = 100
world = bpy.data.worlds.new("Review")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (.35, .4, .45, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = .8
for name, position, energy in (("Key", (-3, -4, 8), 600), ("Rim", (3, 3, 7), 800)):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.size = 4
    light = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(light)
    light.location = position
    light.rotation_euler = (Vector((0, 0, 4.8)) - light.location).to_track_quat("-Z", "Y").to_euler()
bpy.ops.wm.save_as_mainfile(filepath=str(TRIAL / "SciFiSentryVoxelHead.blend"))
bpy.ops.object.camera_add(location=(5, -7, 6))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 4.8)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 2.2
scene.camera = camera
scene.render.filepath = str(TRIAL / "front.png")
bpy.ops.render.render(write_still=True)
(TRIAL / "validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print("HEAD PROBE", report)
