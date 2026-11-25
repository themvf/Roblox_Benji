"""Test textured, 15-bone Sentry skin from a selected source density.

This is a game-visual/animation trial. It does not satisfy Marketplace body,
dynamic head, or cage rules merely by having bones and few triangles.
"""
from pathlib import Path
import json
import math
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/ninja-soldier-skins"
DENSITY = int(sys.argv[sys.argv.index("--") + 1]) if "--" in sys.argv else 3
assert DENSITY in (3, 10)
TRIAL = PKG / ("trials/SciFiSentrySkinnedScan" + ("10" if DENSITY == 10 else ""))
TRIAL.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(PKG / f"trials/SciFiSentry-decimate-{DENSITY}.glb"))
texture_dir = TRIAL / "textures"
texture_dir.mkdir(parents=True, exist_ok=True)
for index, image in enumerate(sorted(bpy.data.images, key=lambda img: img.name)):
    if image.source == "GENERATED":
        continue
    image.filepath_raw = str(texture_dir / f"SciFiSentry_SourceMap_{index:02d}.png")
    bpy.context.scene.render.image_settings.file_format = "PNG"
    image.save_render(image.filepath_raw, scene=bpy.context.scene)
    image.source = "FILE"
    image.reload()
source = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
old = source.data
old_uv = old.uv_layers.active
assert old_uv

faces = []
removed = {"left_weapon_arm": 0, "rifle_barrel": 0, "hanging_cable": 0}
for face in old.polygons:
    x, y, z = face.center
    if x < -.14 and -.19 < z < .29:
        removed["left_weapon_arm"] += 1
        continue
    if x < -.19 and z <= -.15 and y < -.08:
        removed["rifle_barrel"] += 1
        continue
    if abs(x) < .09 and z < -.19 and y > .07:
        removed["hanging_cable"] += 1
        continue
    if y > .09 and z < -.04 and abs(x) < .30:
        removed["hanging_cable"] += 1
        continue
    if x < -.18 and -.28 < z < -.14 and y < .02:
        removed["rifle_barrel"] += 1
        continue
    if z < -.15 and abs(x) > .295 or (x < -.24 and z < -.22):
        removed["rifle_barrel"] += 1
        continue
    faces.append((face, False))
    # The inner edge of the source forearm includes a loose plate near the hip.
    # Mirroring it produces a large floating slab on the opposite thigh.
    if x > .14 and -.19 < z < .29 and (z >= -.04 or x > .22):
        faces.append((face, True))

parts = []
for chunk_number, start in enumerate(range(0, len(faces), 7800), 1):
    verts, polygons, uv_rows, mat_rows = [], [], [], []
    index_map = {}
    for face, mirror in faces[start:start+7800]:
        polygon, row = [], []
        for loop_index in face.loop_indices:
            old_index = old.loops[loop_index].vertex_index
            key = (old_index, mirror)
            if key not in index_map:
                co = old.vertices[old_index].co
                index_map[key] = len(verts)
                verts.append(((-co.x if mirror else co.x) * 5.5,
                              co.y * 5.5, (co.z + .5) * 5.5))
            polygon.append(index_map[key])
            row.append(tuple(old_uv.data[loop_index].uv))
        polygons.append(list(reversed(polygon)) if mirror else polygon)
        uv_rows.append(list(reversed(row)) if mirror else row)
        mat_rows.append(face.material_index)
    mesh = bpy.data.meshes.new(f"Sentry scan {chunk_number:02d}")
    mesh.from_pydata(verts, [], polygons)
    mesh.update()
    mesh.uv_layers.new(name="UVMap")
    for face, row, material_index in zip(mesh.polygons, uv_rows, mat_rows):
        face.material_index = material_index
        for loop_index, uv in zip(face.loop_indices, row):
            mesh.uv_layers.active.data[loop_index].uv = uv
    for mat in old.materials:
        mesh.materials.append(mat)
    obj = bpy.data.objects.new(f"SciFiSentrySkinnedMesh_{chunk_number:02d}", mesh)
    bpy.context.collection.objects.link(obj)
    parts.append(obj)
bpy.data.objects.remove(source, do_unlink=True)

armature_data = bpy.data.armatures.new("SentryR15Bones")
armature = bpy.data.objects.new("SciFiSentryR15", armature_data)
bpy.context.collection.objects.link(armature)
bpy.context.view_layer.objects.active = armature
armature.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")

def bone(name, start, end, parent=None):
    b = armature_data.edit_bones.new(name)
    b.head = start
    b.tail = end
    if parent:
        b.parent = armature_data.edit_bones[parent]
    return b

bone("LowerTorso", (0, 0, 2.45), (0, 0, 3.25))
bone("UpperTorso", (0, 0, 3.25), (0, 0, 4.30), "LowerTorso")
bone("Head", (0, 0, 4.30), (0, 0, 5.30), "UpperTorso")
for side, sign in (("Left", -1), ("Right", 1)):
    bone(side+"UpperArm", (sign*.65, 0, 4.12), (sign*1.10, 0, 3.25), "UpperTorso")
    bone(side+"LowerArm", (sign*1.10, 0, 3.25), (sign*1.20, 0, 2.48), side+"UpperArm")
    bone(side+"Hand", (sign*1.20, 0, 2.48), (sign*1.20, 0, 2.10), side+"LowerArm")
    bone(side+"UpperLeg", (sign*.50, 0, 2.57), (sign*.88, 0, 1.50), "LowerTorso")
    bone(side+"LowerLeg", (sign*.88, 0, 1.50), (sign*.90, 0, .50), side+"UpperLeg")
    bone(side+"Foot", (sign*.90, 0, .50), (sign*.90, -.40, .20), side+"LowerLeg")
bpy.ops.object.mode_set(mode="OBJECT")

weights = {name: 0 for name in armature_data.bones.keys()}
component_counts = {}
for obj in parts:
    groups = {name: obj.vertex_groups.new(name=name) for name in weights}
    parent = list(range(len(obj.data.vertices)))

    def find(index):
        while parent[index] != index:
            parent[index] = parent[parent[index]]
            index = parent[index]
        return index

    for face in obj.data.polygons:
        first = face.vertices[0]
        for other in face.vertices[1:]:
            parent[find(other)] = find(first)

    raw_names = []
    for vert in obj.data.vertices:
        x, y, z = vert.co
        side = "Left" if x < 0 else "Right"
        if z >= 4.35:
            name = "Head"
        elif abs(x) > .73 and z >= 2.05:
            if z >= 3.25:
                name = side+"UpperArm"
            elif z >= 2.48:
                name = side+"LowerArm"
            else:
                name = side+"Hand"
        elif z >= 3.25:
            name = "UpperTorso"
        elif z >= 2.56:
            name = "LowerTorso"
        elif z >= 1.50:
            name = side+"UpperLeg"
        elif z >= .49:
            name = side+"LowerLeg"
        else:
            name = side+"Foot"
        raw_names.append(name)
    components = {}
    for index in range(len(obj.data.vertices)):
        components.setdefault(find(index), []).append(index)
    component_counts[obj.name] = len(components)
    for indices in components.values():
        votes = {}
        for index in indices:
            name = raw_names[index]
            votes[name] = votes.get(name, 0) + 1
        name = max(votes, key=votes.get)
        groups[name].add(indices, 1, "REPLACE")
        weights[name] += len(indices)
    modifier = obj.modifiers.new("R15 articulated scan", "ARMATURE")
    modifier.object = armature
    obj.parent = armature

# A fitted dark layer bridges the scan's tiny open surfaces at elbows, knees,
# and the waist. It follows the exact same bone pose and is kept separate from
# the textured surface so the latter's source UVs remain untouched.
underlay_material = bpy.data.materials.new("Deep black undersuit")
underlay_material.use_nodes = True
underlay_nodes = underlay_material.node_tree.nodes
underlay_nodes.clear()
underlay_output = underlay_nodes.new("ShaderNodeOutputMaterial")
underlay_emission = underlay_nodes.new("ShaderNodeEmission")
underlay_emission.inputs["Color"].default_value = (.0002, .00025, .0003, 1)
underlay_material.node_tree.links.new(underlay_emission.outputs["Emission"],
                                      underlay_output.inputs["Surface"])

radii = {"Head": (.30, .28), "UpperTorso": (.48, .26), "LowerTorso": (.42, .24),
         "UpperArm": (.20, .18), "LowerArm": (.15, .15), "Hand": (.12, .11),
         "UpperLeg": (.25, .23), "LowerLeg": (.18, .17), "Foot": (.20, .19)}
underlay_vertices, underlay_faces = [], []
underlay_indices = {}
for name in armature_data.bones.keys():
    if name not in ("UpperTorso", "LowerTorso"):
        continue
    b = armature_data.bones[name]
    a, c = b.head_local.copy(), b.tail_local.copy()
    direction = (c-a).normalized()
    u = direction.cross(Vector((0, 1, 0))).normalized()
    v = direction.cross(u).normalized()
    kind = name.replace("Left", "").replace("Right", "")
    rx, ry = radii[kind]
    rx *= .56
    ry *= .56
    first = len(underlay_vertices)
    for point in (a, c):
        for j in range(12):
            angle = 2*math.pi*j/12
            p = point + u*(rx*math.cos(angle)) + v*(ry*math.sin(angle))
            underlay_vertices.append(tuple(p))
    underlay_faces.append(tuple(first+j for j in reversed(range(12))))
    underlay_faces.append(tuple(first+12+j for j in range(12)))
    for j in range(12):
        k = (j+1) % 12
        underlay_faces.append((first+j, first+k, first+12+k, first+12+j))
    underlay_indices[name] = list(range(first, first+24))
underlay_mesh = bpy.data.meshes.new("Continuous dark joint fill")
underlay_mesh.from_pydata(underlay_vertices, [], underlay_faces)
underlay_mesh.update()
underlay_mesh.materials.append(underlay_material)
underlay_obj = bpy.data.objects.new("SciFiSentryUndersuit", underlay_mesh)
bpy.context.collection.objects.link(underlay_obj)
for name, indices in underlay_indices.items():
    underlay_obj.vertex_groups.new(name=name).add(indices, 1, "REPLACE")
underlay_modifier = underlay_obj.modifiers.new("R15 under armor", "ARMATURE")
underlay_modifier.object = armature
underlay_obj.parent = armature

bpy.ops.wm.save_as_mainfile(filepath=str(TRIAL / "SciFiSentrySkinnedScan.blend"))
bpy.ops.object.select_all(action="DESELECT")
armature.select_set(True)
for obj in parts:
    obj.select_set(True)
underlay_obj.select_set(True)
bpy.context.view_layer.objects.active = armature
bpy.ops.export_scene.gltf(filepath=str(TRIAL / "SciFiSentrySkinnedScan.glb"),
                          export_format="GLB", export_image_format="AUTO",
                          use_selection=True, export_yup=True)

(TRIAL / "manifest.json").write_text(json.dumps({
    "status": "skinned source trial; pose and source cleanup must be visually checked",
    "triangles": sum(sum(len(face.vertices)-2 for face in obj.data.polygons) for obj in parts),
    "partTriangles": {obj.name: sum(len(face.vertices)-2 for face in obj.data.polygons)
                      for obj in parts},
    "bones": list(groups), "verticesPerBone": weights,
    "connectedComponentsPerMesh": component_counts,
    "removedFaces": removed,
    "source": f"trials/SciFiSentry-decimate-{DENSITY}.glb",
    "limitations": ["open disconnected source surfaces", "binary provisional skin weights",
                    "no dynamic face", "no cages", "no Studio test", "no Marketplace validation"],
}, indent=2) + "\n", encoding="utf-8")
print("SKINNED", len(parts), "parts", sum(len(obj.data.vertices) for obj in parts),
      "vertices", sum(len(obj.data.polygons) for obj in parts), "faces")
