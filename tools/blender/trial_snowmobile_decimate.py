"""Visual-only 25% reduction trial for the textured snowmobile source."""
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/snowmobile"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(PKG / "source/trellis-original.glb"))
ob = next(ob for ob in bpy.context.scene.objects if ob.type == "MESH")
before = len(ob.data.polygons)
bpy.context.view_layer.objects.active = ob
mod = ob.modifiers.new("Visual reduction test", "DECIMATE")
mod.ratio = .25
mod.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier=mod.name)
after = len(ob.data.polygons)
bpy.ops.object.select_all(action="DESELECT")
ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(PKG / "trials/decimate-25pct.glb"),
                          export_format="GLB", export_image_format="AUTO",
                          use_selection=True, export_yup=True)
print("TRIAL", before, after)
