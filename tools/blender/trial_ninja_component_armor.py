"""Assign intact scan components to articulated regions over a clean underbody.

This is a fidelity/pose experiment. Disconnected scan components remain open
surfaces and cannot be promoted directly to an avatar body or accessory.
"""
from collections import defaultdict
from pathlib import Path
import json

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/ninja-soldier-skins"
TRIAL = PKG / "trials/SciFiSentryComponentArmor"
TRIAL.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(PKG / "trials/SciFiSentryCleanBody/SciFiSentryCleanBody.blend"))

# Use the clean shell as the dark joint bridge. The square armor in that scene
# was only a proportion placeholder and is removed for this comparison.
for obj in list(bpy.data.objects):
    if "__" in obj.name or obj.name in {"Head", "UpperTorso", "LowerTorso"} or any(
        obj.name.startswith(side + part) for side in ("Left", "Right")
        for part in ("UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot")
    ) or "articulation" in obj.name or obj.name == "Neck guide":
        bpy.data.objects.remove(obj, do_unlink=True)

bpy.ops.import_scene.gltf(filepath=str(PKG / "source/SciFiSentrySource.glb"))
source = [obj for obj in bpy.context.selected_objects if obj.type == "MESH"][0]
decimate = source.modifiers.new("Quarter-density intact components", "DECIMATE")
decimate.ratio = .25
bpy.context.view_layer.objects.active = source
bpy.ops.object.modifier_apply(modifier=decimate.name)
mesh = source.data
uv = mesh.uv_layers.active
assert uv

parent = list(range(len(mesh.vertices)))

def root(i):
    while parent[i] != i:
        parent[i] = parent[parent[i]]
        i = parent[i]
    return i

for edge in mesh.edges:
    a, b = edge.vertices
    ra, rb = root(a), root(b)
    if ra != rb:
        parent[rb] = ra

components = defaultdict(list)
for face in mesh.polygons:
    components[root(face.vertices[0])].append(face)

def classify(x, z):
    side = "Left" if x < 0 else "Right"
    if z >= .295:
        return "Head"
    if z >= .075:
        return side + "UpperArm" if abs(x) >= .145 else "UpperTorso"
    if z >= -.075:
        return side + "LowerArm" if abs(x) >= .145 else "LowerTorso"
    if z >= -.155 and abs(x) >= .145:
        return side + "Hand"
    if z >= -.28:
        return side + "UpperLeg"
    if z >= -.43:
        return side + "LowerLeg"
    return side + "Foot"

selected = defaultdict(list)
skipped = defaultdict(int)
for faces in components.values():
    xs = [face.center.x for face in faces]
    zs = [face.center.z for face in faces]
    x = sum(xs) / len(xs)
    z = sum(zs) / len(zs)
    region = classify(x, z)
    # Held rifle, long cable and bridging shards must stay out of the wearable.
    if max(zs) - min(zs) > .17:
        skipped["joint_spanning"] += len(faces)
        continue
    if x < -.18 and z < .25:
        skipped["held_weapon"] += len(faces)
        continue
    if region.startswith("Left"):
        continue  # Mirror the clearer right-side armor instead.
    selected[region].extend(faces)

regions = ["Head", "UpperTorso", "LowerTorso"]
for side in ("Left", "Right"):
    regions += [side + part for part in ("UpperArm", "LowerArm", "Hand",
                                          "UpperLeg", "LowerLeg", "Foot")]
counts = {}
skin = bpy.data.materials.new("Fitted carbon joint underbody")
skin.use_nodes = True
skin.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.008, .011, .014, 1)
skin.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = .83

def quantile(values, q):
    values = sorted(values)
    return values[min(len(values)-1, int((len(values)-1)*q))]

def fitted_body(name, source_points):
    # A slim black bridge derived from the source surface bounds. It is a visual
    # study only; this is not retopology of the original scan.
    xs, ys, zs = ([v[i] for v in source_points] for i in range(3))
    x = quantile(xs, .5)
    y = quantile(ys, .5)
    z0, z1 = quantile(zs, .06), quantile(zs, .94)
    rx = max(.10, (quantile(xs, .8)-quantile(xs, .2))*.39)
    ry = max(.10, (quantile(ys, .8)-quantile(ys, .2))*.39)
    vertices = []
    from math import cos, sin, tau
    sides = 12
    for z in (z0, z1):
        for i in range(sides):
            a = tau*i/sides
            vertices.append((x+rx*cos(a), y+ry*sin(a), z))
    faces = [tuple(reversed(range(sides))), tuple(range(sides, 2*sides))]
    faces += [(i, (i+1)%sides, sides+(i+1)%sides, sides+i) for i in range(sides)]
    out = bpy.data.meshes.new(name)
    out.from_pydata(vertices, [], faces)
    out.update()
    out.materials.append(skin)
    obj = bpy.data.objects.new(name, out)
    bpy.context.collection.objects.link(obj)

for region in regions:
    mirror = region.startswith("Left")
    source_region = region.replace("Left", "Right", 1) if mirror else region
    faces = selected[source_region]
    if not faces:
        continue
    index_map = {}
    vertices = []
    polygons = []
    uv_rows = []
    material_rows = []
    for face in faces:
        poly, row = [], []
        for loop_index in face.loop_indices:
            old = mesh.loops[loop_index].vertex_index
            if old not in index_map:
                co = mesh.vertices[old].co
                world = ((-co.x if mirror else co.x) * 5.5, co.y * 5.5,
                         (co.z + .5) * 5.5)
                index_map[old] = len(vertices)
                vertices.append(world)
            poly.append(index_map[old])
            row.append(tuple(uv.data[loop_index].uv))
        polygons.append(list(reversed(poly)) if mirror else poly)
        uv_rows.append(list(reversed(row)) if mirror else row)
        material_rows.append(face.material_index)
    out_mesh = bpy.data.meshes.new(region + " source armor")
    out_mesh.from_pydata(vertices, [], polygons)
    out_mesh.update()
    out_mesh.uv_layers.new(name="UVMap")
    for face, row in zip(out_mesh.polygons, uv_rows):
        for loop_index, texcoord in zip(face.loop_indices, row):
            out_mesh.uv_layers.active.data[loop_index].uv = texcoord
    for face, material_index in zip(out_mesh.polygons, material_rows):
        face.material_index = material_index
    for mat in mesh.materials:
        out_mesh.materials.append(mat)
    obj = bpy.data.objects.new(region + "__intact source components", out_mesh)
    bpy.context.collection.objects.link(obj)
    fitted_body(region, vertices)
    counts[region] = len(polygons)

bpy.data.objects.remove(source, do_unlink=True)
scene = bpy.context.scene
bpy.ops.wm.save_as_mainfile(filepath=str(TRIAL / "SciFiSentryComponentArmor.blend"))

for label, at in (("front", (7, -11, 6)), ("side", (12, 0, 5)),
                  ("rear", (7, 11, 6))):
    bpy.ops.object.camera_add(location=at)
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, 2.7)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 6.7
    scene.camera = camera
    scene.render.filepath = str(TRIAL / (label + ".png"))
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera, do_unlink=True)

(TRIAL / "manifest.json").write_text(json.dumps({
    "status": "source-surface fidelity and articulation trial, not delivery",
    "trianglesByRegion": counts,
    "skippedTriangles": skipped,
    "limitations": ["scan shell is open and fragmented", "no true rig or cages",
                    "not Marketplace compliant", "pose appearance still needs review"],
}, indent=2) + "\n", encoding="utf-8")
print("REGIONS", counts, "SKIPPED", dict(skipped))
