"""Experimental rigid R15 segmentation of the textured source character.

Keeps source UVs and material, reduces the dense scan to 25%, and groups triangles
near R15 body joints. This is an art/animation candidate, not a proven game skin.
"""
import json
import sys
from collections import defaultdict
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/ninja-soldier-skins"
variant = sys.argv[sys.argv.index("--") + 1]
SOURCE = PKG / "source" / f"{variant}Source.glb"
OUTPUT = PKG / "trials" / f"{variant}DetailedSegmented.glb"
MANIFEST = PKG / "trials" / f"{variant}DetailedSegmented.json"
BLEND = PKG / "trials" / f"{variant}DetailedSegmented.blend"
SCALE = 5.5
MAX_TRIANGLES = 8000
CENTERS = {
    "Head": (0, 4.78, 0), "UpperTorso": (0, 3.75, 0),
    "LowerTorso": (0, 2.85, 0),
    "LeftUpperArm": (-1.44, 3.66, 0), "RightUpperArm": (1.44, 3.66, 0),
    "LeftLowerArm": (-1.44, 2.79, 0), "RightLowerArm": (1.44, 2.79, 0),
    "LeftHand": (-1.44, 2.10, 0), "RightHand": (1.44, 2.10, 0),
    "LeftUpperLeg": (-.53, 1.91, 0), "RightUpperLeg": (.53, 1.91, 0),
    "LeftLowerLeg": (-.53, 1.03, 0), "RightLowerLeg": (.53, 1.03, 0),
    "LeftFoot": (-.53, .38, -.14), "RightFoot": (.53, .38, -.14),
}


def region(x, z):
    # The generated source includes a held rifle. Carve its outboard portion
    # away from the wearable candidate; a real game gun remains a separate Tool.
    rifle_edge = -.215 if variant == "SciFiSentry" else -.17
    if x < rifle_edge and z < .25:
        return "WeaponOffcut"
    side = "Left" if x < 0 else "Right"
    arm_threshold = .145 if variant == "SciFiSentry" else .135
    if z >= .30:
        return "Head"
    if z >= .08:
        return side + "UpperArm" if abs(x) >= arm_threshold else "UpperTorso"
    if z >= -.08:
        return side + "LowerArm" if abs(x) >= arm_threshold else "LowerTorso"
    if z >= -.16 and abs(x) >= arm_threshold:
        return side + "Hand"
    if z >= -.28:
        return side + "UpperLeg"
    if z >= -.44:
        return side + "LowerLeg"
    return side + "Foot"


def to_blender(co):
    return (co.x * SCALE, co.y * SCALE, (co.z + .5) * SCALE)


bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
objects = [o for o in bpy.context.scene.objects if o.type == "MESH"]
assert len(objects) == 1, objects
source_obj = objects[0]
modifier = source_obj.modifiers.new("Quarter density trial", "DECIMATE")
modifier.ratio = .25
bpy.context.view_layer.objects.active = source_obj
bpy.ops.object.modifier_apply(modifier=modifier.name)
source_mesh = source_obj.data
source_uv = source_mesh.uv_layers.active
assert source_uv

faces = defaultdict(list)
for face in source_mesh.polygons:
    anchor = region(face.center.x, face.center.z)
    faces[anchor].append(face)

manifest = {"variant": variant, "source": str(SOURCE.relative_to(ROOT)),
            "status": "trial: verify segmentation and animation in Studio",
            "scaleStuds": SCALE, "triangleLimitPerMesh": MAX_TRIANGLES,
            "parts": []}

for anchor in sorted(faces):
    if anchor == "WeaponOffcut":
        manifest["weaponOffcutTriangles"] = len(faces[anchor])
        continue
    # The held gun contaminates the entire left-side limb segmentation. Reuse
    # intact right-side limb geometry across the centerline as a trial repair.
    mirrored = anchor.startswith("Left")
    source_anchor = anchor.replace("Left", "Right", 1) if mirrored else anchor
    face_list = faces[source_anchor]
    origin = CENTERS[anchor]
    blender_origin = (origin[0], -origin[2], origin[1])
    for part_number, start in enumerate(range(0, len(face_list), MAX_TRIANGLES), 1):
        selection = face_list[start:start + MAX_TRIANGLES]
        mapping = {}
        vertices = []
        polygons = []
        uv_rows = []
        for face in selection:
            poly = []
            uv_row = []
            for loop_index in face.loop_indices:
                old_index = source_mesh.loops[loop_index].vertex_index
                if old_index not in mapping:
                    world = to_blender(source_mesh.vertices[old_index].co)
                    if mirrored:
                        world = (-world[0], world[1], world[2])
                    mapping[old_index] = len(vertices)
                    vertices.append(tuple(world[i] - blender_origin[i] for i in range(3)))
                poly.append(mapping[old_index])
                uv_row.append(tuple(source_uv.data[loop_index].uv))
            polygons.append(list(reversed(poly)) if mirrored else poly)
            uv_rows.append(list(reversed(uv_row)) if mirrored else uv_row)
        name = f"{anchor}__{part_number:02d}"
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata(vertices, [], polygons)
        mesh.update()
        mesh.uv_layers.new(name="UVMap")
        for poly, uv_row in zip(mesh.polygons, uv_rows):
            for loop_index, uv in zip(poly.loop_indices, uv_row):
                mesh.uv_layers.active.data[loop_index].uv = uv
        for mat in source_mesh.materials:
            mesh.materials.append(mat)
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.collection.objects.link(obj)
        obj.location = blender_origin
        manifest["parts"].append({"name": name, "attach": anchor,
                                  "triangles": sum(len(p) - 2 for p in polygons),
                                  "originStuds": list(origin),
                                  "mirroredFrom": source_anchor if mirrored else None})
print("BUILT", variant, "parts", len(manifest["parts"]), "triangles",
      sum(p["triangles"] for p in manifest["parts"]))

bpy.data.objects.remove(source_obj, do_unlink=True)
OUTPUT.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
bpy.ops.export_scene.gltf(filepath=str(OUTPUT), export_format="GLB", export_yup=True)
MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
print("EXPORTED", OUTPUT)
