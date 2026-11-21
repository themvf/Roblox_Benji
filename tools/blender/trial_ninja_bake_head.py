"""Bake the original Sentry helmet color onto the closed voxel head probe."""
from pathlib import Path
import json

import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/ninja-soldier-skins"
TRIAL = PKG / "trials/SciFiSentryVoxelHead"
bpy.ops.wm.open_mainfile(filepath=str(TRIAL / "SciFiSentryVoxelHead.blend"))
target = bpy.data.objects["Helmet source crop"]

# Unwrap the new closed mesh. UV and texture will remain saved for inspection.
bpy.ops.object.select_all(action="DESELECT")
target.select_set(True)
bpy.context.view_layer.objects.active = target
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(island_margin=.02)
bpy.ops.object.mode_set(mode="OBJECT")
image = bpy.data.images.new("SciFiSentry_helmet_color_trial", width=1024,
                            height=1024, alpha=False)
image.filepath_raw = str(TRIAL / "helmet-color.png")
image.file_format = "PNG"
image.generated_color = (.02, .026, .03, 1)

mat = bpy.data.materials.new("Baked original helmet color")
mat.use_nodes = True
nodes = mat.node_tree.nodes
tex = nodes.new("ShaderNodeTexImage")
tex.image = image
nodes.active = tex
bsdf = nodes.get("Principled BSDF")
mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Metallic"].default_value = .35
bsdf.inputs["Roughness"].default_value = .42
target.data.materials.clear()
target.data.materials.append(mat)

bpy.ops.import_scene.gltf(filepath=str(PKG / "source/SciFiSentrySource.glb"))
source = [o for o in bpy.context.selected_objects if o.type == "MESH"][0]
bm = bmesh.new()
bm.from_mesh(source.data)
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().z < .30],
                 context="FACES")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
bm.to_mesh(source.data)
bm.free()
source.scale = (5.5, 5.5, 5.5)
source.location.z = 2.75
bpy.context.view_layer.objects.active = source
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.render.bake.use_selected_to_active = True
scene.render.bake.cage_extrusion = .08
scene.render.bake.margin = 4
scene.render.bake.use_pass_direct = False
scene.render.bake.use_pass_indirect = False
scene.render.bake.use_pass_color = True
bpy.ops.object.select_all(action="DESELECT")
source.select_set(True)
target.select_set(True)
bpy.context.view_layer.objects.active = target
bpy.ops.object.bake(type="DIFFUSE")
image.save()
bpy.data.objects.remove(source, do_unlink=True)
bpy.ops.wm.save_as_mainfile(filepath=str(TRIAL / "SciFiSentryVoxelHeadBaked.blend"))

for obj in list(bpy.data.objects):
    if obj.type == "CAMERA":
        bpy.data.objects.remove(obj, do_unlink=True)
bpy.ops.object.camera_add(location=(5, -7, 6))
camera = bpy.context.object
camera.rotation_euler = (Vector((0, 0, 4.8)) - camera.location).to_track_quat("-Z", "Y").to_euler()
camera.data.type = "ORTHO"
camera.data.ortho_scale = 2.2
scene.camera = camera
scene.render.filepath = str(TRIAL / "baked-front.png")
bpy.ops.render.render(write_still=True)
(TRIAL / "bake-result.json").write_text(json.dumps({
    "status": "helmet color bake trial; inspect visually before using",
    "resolution": [1024, 1024], "source": "source/SciFiSentrySource.glb",
    "target": "SciFiSentryVoxelHead.blend",
    "unvalidated": ["bake artifacts", "dynamic face", "cage", "rig", "Marketplace"],
}, indent=2) + "\n", encoding="utf-8")
print("BAKED", image.filepath_raw)
