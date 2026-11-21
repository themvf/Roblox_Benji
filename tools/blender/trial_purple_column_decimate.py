"""Visual-only source preservation trials for the purple column."""
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/purple-column"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(PKG / "source/trellis-original.glb"))
source = next(ob for ob in bpy.context.scene.objects if ob.type == "MESH")
for ratio, name in ((.08, "decimate-08pct"), (.15, "decimate-15pct")):
    ob = source.copy()
    ob.data = source.data.copy()
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    mod = ob.modifiers.new("Visual reduction test", "DECIMATE")
    mod.ratio = ratio
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(PKG / "trials" / (name + ".glb")),
                              export_format="GLB", export_image_format="AUTO",
                              use_selection=True, export_yup=True)
    print("TRIAL", name, len(ob.data.polygons))
    bpy.data.objects.remove(ob, do_unlink=True)
