"""Build armor-only GLBs and editable Blender scenes from the shared R15 specs."""
import json
import math
from pathlib import Path
import sys

import bpy

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/ninja-soldier-skins"
spec = json.loads((PKG / "source/armor_specs.json").read_text(encoding="utf-8"))
variant_id = sys.argv[sys.argv.index("--") + 1]
variant = spec["variants"][variant_id]

# Roblox R15 reference pose in studs. Blender is Z up; Roblox's -Z forward
# becomes Blender -Y forward.
CENTERS = {
    "Head": (0, 4.78, 0),
    "UpperTorso": (0, 3.75, 0),
    "LowerTorso": (0, 2.85, 0),
    "LeftUpperArm": (-1.44, 3.66, 0), "RightUpperArm": (1.44, 3.66, 0),
    "LeftLowerArm": (-1.44, 2.79, 0), "RightLowerArm": (1.44, 2.79, 0),
    "LeftHand": (-1.44, 2.10, 0), "RightHand": (1.44, 2.10, 0),
    "LeftUpperLeg": (-.53, 1.91, 0), "RightUpperLeg": (.53, 1.91, 0),
    "LeftLowerLeg": (-.53, 1.03, 0), "RightLowerLeg": (.53, 1.03, 0),
    "LeftFoot": (-.53, .38, -.14), "RightFoot": (.53, .38, -.14),
}


def blender_xyz(roblox):
    return (roblox[0], -roblox[2], roblox[1])


def rgb(hex_color):
    # Blender shader values are linear; the shared Roblox swatches are sRGB.
    channels = (int(hex_color[i:i + 2], 16) / 255 for i in (1, 3, 5))
    return tuple(c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4
                 for c in channels)


bpy.ops.wm.read_factory_settings(use_empty=True)
materials = {}
for entry in variant["pieces"]:
    key = (entry["color"], entry["material"])
    if key in materials:
        continue
    mat = bpy.data.materials.new(f"{entry['material']}_{entry['color'][1:]}")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb(entry["color"]), 1)
    bsdf.inputs["Roughness"].default_value = .33 if entry["material"] == "Metal" else .49
    bsdf.inputs["Metallic"].default_value = .62 if entry["material"] == "Metal" else 0
    if entry["material"] == "Neon":
        bsdf.inputs["Emission Color"].default_value = (*rgb(entry["color"]), 1)
        bsdf.inputs["Emission Strength"].default_value = .75
    materials[key] = mat

for entry in variant["pieces"]:
    pos = [CENTERS[entry["attach"]][i] + entry["offset"][i] for i in range(3)]
    shape = entry["shape"]
    if shape == "ball":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8)
    elif shape == "cylinder":
        bpy.ops.mesh.primitive_cylinder_add(vertices=12)
    else:
        bpy.ops.mesh.primitive_cube_add()
    obj = bpy.context.object
    obj.name = f"{entry['attach']}__{entry['name']}"
    size = blender_xyz(entry["size"])
    obj.dimensions = tuple(abs(x) for x in size)
    obj.location = blender_xyz(pos)
    rx, ry, rz = [math.radians(v) for v in entry["rotation"]]
    obj.rotation_euler = (rx, -rz, ry)
    obj.data.materials.append(materials[(entry["color"], entry["material"])])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if shape != "block":
        for face in obj.data.polygons:
            face.use_smooth = True

blend = PKG / "source" / f"{variant_id}Armor.blend"
output = PKG / "exports" / f"{variant_id}Armor.glb"
blend.parent.mkdir(parents=True, exist_ok=True)
output.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=str(output), export_format="GLB", use_selection=True,
                          export_yup=True, export_apply=True)
print("EXPORTED", output)
