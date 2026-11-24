"""Write the Avatar Setup FBX from a prepared folder's Body/Hair/Headgear GLBs, then read it back.

    blender -b -noaudio --python tools/blender/write_fbx.py -- <folder> <name.fbx>

Run by `kit_look.py skinned`, `character` and `fbx` after prepare_avatar_setup.py. Two things the first
Studio trial (Bouncer, 2026-11-20) showed, and this file now settles instead of a person in Studio:

- Size. Blender writes centimetres by default, so the 6.05 m body was 605 units, and Studio's importer
  read 605 studs. Written at 0.01 scale, the numbers in the file are studs (6.05), the usual Blender ->
  Roblox setting.
- Front. Written with Blender's default axes the body arrived facing away; the trial turned each part
  180 degrees by hand, which (each about its own centre) left the hair over the face. The front is
  written to +Z in the file, which Studio's importer shows facing the camera.

The read-back imports the FBX fresh and fails (exit 1) unless the height is 6.05 studs within 2% and
the toes point the way the file's front says. Studio itself is the final check: STUDIO.md says what to
look at.
"""
import json
import math
import sys
from pathlib import Path

import bpy

folder, fbx_name = sys.argv[sys.argv.index("--") + 1:][:2]
folder = Path(folder).resolve()
out = folder / fbx_name


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def toes_y(objs):
    """Mean y of the toes minus the mean y of the shins: positive when the feet point to +y."""
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    h = max(p.z for p in pts) - min(p.z for p in pts)
    base = min(p.z for p in pts)
    toes = [p.y for p in pts if p.z < base + 0.04 * h]
    shins = [p.y for p in pts if base + 0.1 * h < p.z < base + 0.2 * h]
    shin = sum(shins) / len(shins)
    lean = sum(toes) / len(toes) - shin
    # Block boots with hardly any toe overhang (HornedFeatherMeshy's taloned boots, 2026-11-22) put the mean of
    # the toes level with the shins, or a hair behind them. The foot still reaches further forward than back:
    # judge by that reach when the mean is within 1% of the height.
    # A long coat hem or wide boot tops bulging forward in the shin band pull the shins' mean ahead of the
    # toes (TrenchFedoraMeshy, lean -2% of the height). What the foot always does is stick out past the leg
    # at the front, not the back: judge by that overhang when it is clear. Signed either way, since this also
    # reads the turned-round FBX, where the front is -y.
    overhang = (max(toes) - max(shins)) - (min(shins) - min(toes))
    if abs(overhang) > 0.02 * h:
        return overhang, h
    if abs(lean) < 0.01 * h:
        mid =(max(shins) + min(shins)) / 2  # a lopsided boot trim pulls the mean forward; the midpoint holds
        reach = (max(toes) - mid) - (mid - min(toes))
        if abs(reach) > 0.005 * h:
            return reach, h
    return lean, h


clear()
parts = []
for name in ("Body", "Hair", "Headgear"):
    glb = folder / f"{name}.glb"
    if not glb.exists():
        continue
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(glb))
    for o in set(bpy.data.objects) - before:
        if o.type == "MESH":
            o.name = name
            parts.append(o)
body = next(o for o in parts if o.name == "Body")
glb_toes, glb_height = toes_y([body])  # the GLB's front is -Z in glTF, +y once imported

# Two more things the BouncerAuto/DarkArmourAuto Studio trial (2026-11-20) showed:
# - Faceted. The prepared GLBs keep every triangle as its own three vertices with flat normals, so Studio
#   drew hard triangles everywhere. Weld coincident vertices (UVs live on the corners, so seams survive)
#   and shade smooth, keeping edges sharper than SHARP_DEG hard so armour plates stay crisp.
# - Hair untextured. The GLB textures are packed with no file name, so the exporter wrote both under one
#   name and the hair material pointed at the body's picture. Each texture gets its own name first.
SHARP_DEG = 60.0
for o in parts:
    for other in bpy.data.objects:
        other.select_set(other is o)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=1e-5 * glb_height)
    bpy.ops.object.mode_set(mode="OBJECT")
    if o.data.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(SHARP_DEG), keep_sharp_edges=False)
    for slot in o.material_slots:
        if not (slot.material and slot.material.use_nodes):
            continue
        for node in slot.material.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image and not node.image.filepath:
                node.image.filepath_raw = str(folder / f"{o.name}Color.png")

# The mesh itself is turned to face -y, Blender's own front, so the file keeps the standard axis
# declaration (Y up, front +Z) and its numbers face +Z whether or not an importer reads that declaration.
# Writing axis_forward="Z" instead flips the declared axes, and Studio may or may not read them.
from mathutils import Matrix

turn = Matrix.Rotation(math.pi, 4, "Z")
for o in parts:
    o.data.transform(turn)
    o.data.update()
for o in bpy.data.objects:
    o.select_set(o in parts)
bpy.ops.export_scene.fbx(filepath=str(out), use_selection=True, path_mode="COPY", embed_textures=True,
                         axis_forward="-Z", axis_up="Y", apply_unit_scale=True, global_scale=0.01,
                         mesh_smooth_type="FACE")

# read it back the way a plain importer does: Y up, -Z forward, the file's own axis declaration ignored.
# Blender then converts the file's centimetres to metres (x 0.01) and a +Z front to -y.
clear()
bpy.ops.import_scene.fbx(filepath=str(out), use_manual_orientation=True, axis_forward="-Z", axis_up="Y")
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
fbx_body = next(o for o in meshes if o.name.startswith("Body"))
fbx_toes, fbx_height = toes_y([fbx_body])
studs = fbx_height * 100
checks = {
    "file": out.name,
    "parts": sorted(o.name for o in meshes),
    "heightStuds": round(studs, 3),
    "expectedStuds": round(glb_height, 3),
    "frontInFile": "+Z" if fbx_toes < 0 else "-Z",
}
problems = []
if abs(studs - glb_height) > 0.02 * glb_height:
    problems.append(f"height {studs:.2f} studs in the file, expected {glb_height:.2f}")
if glb_toes <= 0:
    problems.append("the GLB's toes do not point to its front; cannot tell the front")
elif fbx_toes >= 0:
    problems.append("the file's front is -Z; Studio shows that from behind")


def flat_share(o):
    """Share of corners whose normal equals its face normal: 1.0 means every triangle is drawn flat."""
    me = o.data
    corners = [(p.normal, li) for p in me.polygons for li in p.loop_indices]
    return sum(1 for n, li in corners if n.dot(me.corner_normals[li].vector) > 0.9999) / max(len(corners), 1)


def textures(o):
    return sorted({Path(n.image.filepath).name for s in o.material_slots if s.material and s.material.use_nodes
                   for n in s.material.node_tree.nodes if n.type == "TEX_IMAGE" and n.image})


checks["flatShare"] = {o.name: round(flat_share(o), 3) for o in meshes}
checks["textures"] = {o.name: textures(o) for o in meshes}
for name, share in checks["flatShare"].items():
    if share > 0.5:
        problems.append(f"{name} is {share:.0%} flat-shaded; Studio will draw it faceted")
seen = {}
for name, files in checks["textures"].items():
    if not files:
        problems.append(f"{name} has no texture in the file")
    for f in files:
        if f in seen:
            problems.append(f"{name} and {seen[f]} share the texture {f}; one of them lost its own")
        seen[f] = name
checks["problems"] = problems
(folder / "fbx-check.json").write_text(json.dumps(checks, indent=1))
print("FBX", json.dumps(checks))
if problems:
    sys.exit(1)
