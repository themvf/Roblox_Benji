"""Create an editable first-pass body from Roblox's blocky reference.

Run with Blender background mode. This is an authoring base, not an export.
"""
import json
from pathlib import Path
import bpy

root = Path(__file__).resolve().parent
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.fbx(filepath=str(root / "roblox-blocky-reference.fbx"))

def material(name, rgba, metallic=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = rgba
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = 0.48
    return m

black = material("Oni outfit - preliminary black", (0.018, 0.018, 0.022, 1))
gold = material("Oni hands - preliminary gold", (0.52, 0.30, 0.07, 1), 0.55)
parts = [o for o in bpy.data.objects if o.type == "MESH" and o.name.endswith("_Geo")]
for part in parts:
    # Keep the facial head's existing materials and facial rig untouched.
    if part.name == "Head_Geo":
        continue
    part.data.materials.clear()
    part.data.materials.append(gold if part.name in ("LeftHand_Geo", "RightHand_Geo") else black)

report = {
    "purpose": "Unfinished clean authoring base, not a playable or Marketplace deliverable",
    "source": "roblox-blocky-reference.fbx",
    "bodyRegions": sorted(o.name for o in parts),
    "armatures": {o.name: len(o.data.bones) for o in bpy.data.objects if o.type == "ARMATURE"},
    "bodyCages": sorted(o.name for o in bpy.data.objects if o.name.endswith("_OuterCage")),
    "limitations": ["Mask, horns, robe and textures not authored", "Skinning and facial animation not tested", "Cage fit and Marketplace readiness not validated"],
}
(root / "base-inventory.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
bpy.ops.wm.save_as_mainfile(filepath=str(root / "oni-body-base.blend"), compress=True)
print("Created preliminary Oni body base with", len(parts), "body regions")
