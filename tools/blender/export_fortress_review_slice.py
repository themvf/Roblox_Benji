"""One-file import of the walkable Blender review assembly, not the live map."""
import bpy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/environment/snow-fortress/entrance-kit-v1"
bpy.ops.wm.open_mainfile(filepath=str(OUT / "SnowFortress_EntranceKit_v1.blend"))
stage = bpy.data.collections["REVIEW ONLY / assembly and scale references"]
bpy.ops.object.select_all(action="DESELECT")
count = 0
for obj in stage.objects:
    if obj.type != "MESH" or obj.name.startswith("Scale reference"):
        continue
    obj.hide_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    count += 1
    # The very large backdrop is for rendering only; use a bounded test floor.
    if obj.name == "Review snow ground":
        obj.dimensions = (110, 110, obj.dimensions.z)
        bpy.context.view_layer.update()
    # Staging materials use procedural shaders. Give these few test primitives
    # flat, portable materials; all architectural meshes retain baked PBR.
    if not obj.name.startswith("SF_"):
        old = obj.data.materials[0]
        principled = old.node_tree.nodes.get("Principled BSDF")
        mat = bpy.data.materials.new("ReviewOnly_" + old.name)
        mat.use_nodes = True
        shader = mat.node_tree.nodes.get("Principled BSDF")
        shader.inputs["Base Color"].default_value = principled.inputs["Base Color"].default_value
        shader.inputs["Roughness"].default_value = principled.inputs["Roughness"].default_value
        obj.data = obj.data.copy()
        obj.data.materials.clear()
        obj.data.materials.append(mat)
path = OUT / "exports" / "SnowFortress_ReviewSlice.glb"
bpy.ops.export_scene.gltf(filepath=str(path), use_selection=True, export_format="GLB",
                         export_yup=True, export_texcoords=True, export_normals=True)
print("Exported one-file review slice:", path, "mesh instances:", count)
