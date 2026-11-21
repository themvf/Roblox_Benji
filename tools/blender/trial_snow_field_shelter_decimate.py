"""Test whether the textured TRELLIS shelter survives a Roblox-size reduction."""
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/snow-field-shelter"
SOURCE = PKG / "source/trellis-original.glb"
OUTPUT = PKG / "trials/decimate-9000.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
assert len(meshes) == 1
ob = meshes[0]
before = len(ob.data.polygons)
bpy.context.view_layer.objects.active = ob
mod = ob.modifiers.new("Source preservation test", "DECIMATE")
mod.ratio = 0.032
mod.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier=mod.name)
after = len(ob.data.polygons)
assert after <= 10_000, (before, after)
bpy.ops.object.select_all(action="DESELECT")
ob.select_set(True)
bpy.context.view_layer.objects.active = ob
bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_format="GLB",
                          export_image_format="AUTO", use_selection=True,
                          export_yup=True)
print("TRIAL", before, after, OUTPUT)
