"""Repair the articulated Sentry trial with closed arm, waist, and thigh armor.

This is an isolated game-skin trial. The source scan, previously imported GLB,
and rejected simple armor exports are not overwritten.
"""
from pathlib import Path
import hashlib
import json
import math
import random

import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/ninja-soldier-skins"
BASE = PKG / "trials/SciFiSentrySkinnedScan10/SciFiSentrySkinnedScan.blend"
TRIAL = PKG / "trials/SciFiSentryRebuiltArmor"
TEXTURES = TRIAL / "textures"
TRIAL.mkdir(parents=True, exist_ok=True)
TEXTURES.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.open_mainfile(filepath=str(BASE))
scene = bpy.context.scene
rig = bpy.data.objects["SciFiSentryR15"]
scans = [ob for ob in scene.objects if ob.type == "MESH" and ob.name.startswith("SciFiSentrySkinnedMesh_")]
assert len(scans) == 4, [ob.name for ob in scans]

# Whole connected scan islands were rigidly assigned to bones. Remove the
# islands at failed joints; leaving a few vertices would retain floating shards.
replaced_bones = {"LowerTorso"}
for side in ("Left", "Right"):
    replaced_bones.update({side + "UpperLeg", side + "LowerArm", side + "Hand"})
removed = {}
for ob in scans:
    mesh = ob.data
    group_names = {group.index: group.name for group in ob.vertex_groups}
    doomed = set()
    for poly in mesh.polygons:
        votes = {}
        for index in poly.vertices:
            for weight in mesh.vertices[index].groups:
                name = group_names[weight.group]
                votes[name] = votes.get(name, 0.0) + weight.weight
        if votes:
            region = max(votes, key=votes.get)
            if region in replaced_bones:
                doomed.add(poly.index)
            elif region.endswith("UpperArm"):
                bone = rig.data.bones[region]
                a, b = bone.head_local, bone.tail_local
                center = poly.center
                t = max(0, min(1, (center - a).dot(b - a) / (b - a).length_squared))
                if (center - a.lerp(b, t)).length > .52:
                    doomed.add(poly.index)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[index] for index in doomed], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    removed[ob.name] = len(doomed)


def image_material(name, rgb, roughness, metal=0.0, glow=0.0):
    """Small reproducible mapped finish, with restrained noise and scratches."""
    image = bpy.data.images.new(name + " color", width=128, height=128, alpha=True)
    seed = random.Random(name)
    pixels = []
    scratches = {(seed.randrange(128), seed.randrange(128)) for _ in range(115)}
    for y in range(128):
        for x in range(128):
            noise = seed.uniform(-.045, .045)
            if (x, y) in scratches:
                noise += .13
            pixels.extend((max(0, min(1, rgb[0] * (1 + noise))),
                           max(0, min(1, rgb[1] * (1 + noise))),
                           max(0, min(1, rgb[2] * (1 + noise))), 1.0))
    image.pixels = pixels
    path = TEXTURES / (name.replace(" ", "_") + "_Color.png")
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metal
    if glow:
        bsdf.inputs["Emission Color"].default_value = (*rgb, 1)
        bsdf.inputs["Emission Strength"].default_value = glow
    node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = image
    mat.node_tree.links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
    return mat


armor = image_material("Sentry dark ceramic", (.027, .035, .045), .28, .54)
raised = image_material("Sentry faceted gunmetal", (.037, .047, .057), .36, .58)
under = image_material("Sentry joint undersuit", (.008, .011, .016), .64, .02)
edge = image_material("Sentry worn steel edge", (.085, .105, .12), .32, .64)
gold = image_material("Sentry muted gold fastener", (.39, .22, .055), .29, .7)
cyan = image_material("Sentry cyan status light", (.01, .50, .68), .22, .15, .55)


def rig_piece(ob, bone):
    ob.parent = rig
    ob.vertex_groups.new(name=bone).add(list(range(len(ob.data.vertices))), 1, "REPLACE")
    modifier = ob.modifiers.new("Rigid skinned armor", "ARMATURE")
    modifier.object = rig
    uv = ob.data.uv_layers.active or ob.data.uv_layers.new(name="UVMap")
    for poly in ob.data.polygons:
        for index in poly.loop_indices:
            vertex = ob.data.vertices[ob.data.loops[index].vertex_index].co
            uv.data[index].uv = ((vertex.x * .21) % 1, (vertex.z * .21) % 1)
    return ob


def closed_shell(name, bone, a, b, radii_a, radii_b, mat, facets=10):
    a, b = Vector(a), Vector(b)
    direction = (b - a).normalized()
    front = Vector((0, -1, 0))
    axis_x = direction.cross(front).normalized()
    axis_y = direction.cross(axis_x).normalized()
    vertices = []
    for center, (rx, ry) in ((a, radii_a), (b, radii_b)):
        for i in range(facets):
            angle = 2 * math.pi * i / facets
            vertices.append(tuple(center + axis_x * math.cos(angle) * rx
                                  + axis_y * math.sin(angle) * ry))
    faces = [tuple(reversed(range(facets))), tuple(range(facets, 2*facets))]
    faces += [(i, (i + 1) % facets, (i + 1) % facets + facets, i + facets)
              for i in range(facets)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    mesh.materials.append(mat)
    ob = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(ob)
    return rig_piece(ob, bone)


def block(name, bone, center, scale, mat, bevel=.015, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    ob = bpy.context.object
    ob.name = name
    ob.dimensions = scale
    if rotation is not None:
        ob.rotation_euler = rotation
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = ob.modifiers.new("Machined edge", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.modifier_apply(modifier=mod.name)
    ob.data.materials.append(mat)
    return rig_piece(ob, bone)


def angular_plate(name, bone, outline_xz, front_y, thickness, mat):
    """Closed irregular armor face; its facets add silhouette without shards."""
    count = len(outline_xz)
    vertices = [(x, front_y, z) for x, z in outline_xz]
    vertices += [(x, front_y + thickness, z) for x, z in outline_xz]
    faces = [tuple(range(count - 1, -1, -1)),
             tuple(range(count, 2 * count))]
    faces += [(i, (i + 1) % count, (i + 1) % count + count, i + count)
              for i in range(count)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    mesh.materials.append(mat)
    ob = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(ob)
    return rig_piece(ob, bone)


for side, sign in (("Left", -1), ("Right", 1)):
    arm = (Vector((sign*.65, 0, 4.12)), Vector((sign*1.10, 0, 3.25)),
           Vector((sign*1.20, 0, 2.48)), Vector((sign*1.20, 0, 2.10)))
    thigh = (Vector((sign*.50, 0, 2.57)), Vector((sign*.88, 0, 1.50)))

    # Dark continuous segments hide articulation gaps. Layered closed shells
    # sit on each bone, so none of their panels can split during animation.
    for bone, a, b, ra, rb in (
        ("UpperArm", arm[0], arm[1], (.20, .20), (.16, .16)),
        ("LowerArm", arm[1], arm[2], (.145, .15), (.125, .13)),
        ("Hand", arm[2], arm[3], (.12, .12), (.11, .11)),
        ("UpperLeg", thigh[0], thigh[1], (.25, .23), (.21, .20))):
        name = side + bone
        closed_shell(name + " undersuit", name, a, b, ra, rb, under)

    closed_shell(side + " shoulder armor", side + "UpperArm",
                 arm[0] + Vector((0, 0, -.03)), arm[1] + Vector((0, 0, .22)),
                 (.31, .27), (.23, .22), armor)
    closed_shell(side + " outer pauldron", side + "UpperArm",
                 arm[0] + Vector((sign*.04, -.02, .06)),
                 arm[0] + Vector((sign*.14, -.015, -.30)),
                 (.37, .31), (.27, .25), raised)
    angular_plate(side + " split shoulder face", side + "UpperArm",
                  [(sign*.56, 4.06), (sign*.85, 4.17), (sign*1.05, 3.97),
                   (sign*1.11, 3.70), (sign*.86, 3.62), (sign*.62, 3.77)],
                  -.31, .07, armor)
    closed_shell(side + " forearm shield", side + "LowerArm",
                 arm[1] + Vector((0, -.035, -.10)),
                 arm[2] + Vector((0, -.06, .05)),
                 (.245, .23), (.20, .21), armor)
    closed_shell(side + " wrist cuff", side + "Hand",
                 arm[2] + Vector((0, 0, .045)), arm[2] + Vector((0, 0, -.095)),
                 (.21, .19), (.19, .17), edge)
    closed_shell(side + " gauntlet", side + "Hand",
                 arm[2] + Vector((0, -.025, -.09)), arm[3] + Vector((0, -.02, .025)),
                 (.17, .16), (.15, .145), armor)

    for index, z in enumerate((3.90, 3.70, 3.51)):
        block(side + f" upper arm plate {index}", side + "UpperArm",
              (sign*(.77 + index*.105), -.235, z), (.33, .075, .13),
              raised if index % 2 == 0 else armor, .025)
    for index, z in enumerate((3.10, 2.89, 2.68)):
        block(side + f" forearm rib {index}", side + "LowerArm",
              (sign*(1.12 + index*.03), -.215, z), (.29, .07, .07), edge, .014)
    block(side + " shoulder gold pin", side + "UpperArm",
          (sign*.81, -.33, 3.91), (.07, .05, .07), gold, .012)
    block(side + " forearm cyan bar", side + "LowerArm",
          (sign*1.17, -.26, 2.85), (.05, .03, .24), cyan, .012)

    closed_shell(side + " thigh inner", side + "UpperLeg",
                 thigh[0], thigh[1], (.33, .30), (.28, .26), armor)
    closed_shell(side + " upper thigh raised shell", side + "UpperLeg",
                 thigh[0] + Vector((0, -.035, -.07)),
                 thigh[1] + Vector((0, -.01, .24)),
                 (.38, .33), (.31, .28), raised)
    angular_plate(side + " sweeping thigh face", side + "UpperLeg",
                  [(sign*.31, 2.42), (sign*.59, 2.55), (sign*.91, 2.34),
                   (sign*1.10, 2.03), (sign*1.03, 1.79),
                   (sign*.70, 1.65), (sign*.51, 1.85)],
                  -.35, .055, armor)
    for index, z in enumerate((2.32, 2.06, 1.80)):
        block(side + f" thigh inset {index}", side + "UpperLeg",
              (sign*(.61 + index*.09), -.34 + index*.025, z),
              (.41 - index*.035, .08, .15), armor if index != 1 else edge, .026)
    block(side + " thigh signal", side + "UpperLeg",
          (sign*.70, -.395, 2.31), (.05, .035, .11), cyan, .009)

# The pelvis has closed overlapping panels instead of the scan's dangling
# floating plate. Its central belt and side flaps all follow LowerTorso.
closed_shell("Sentry waist sealed undersuit", "LowerTorso",
             (0, 0, 2.40), (0, 0, 3.27), (.43, .30), (.46, .28), under, 12)
closed_shell("Sentry waist armor", "LowerTorso",
             (0, 0, 2.58), (0, 0, 3.20), (.50, .34), (.49, .31), armor, 12)
block("Sentry armored belt", "LowerTorso", (0, -.025, 2.83), (1.19, .66, .17), raised, .045)
block("Sentry central cod plate", "LowerTorso", (0, -.345, 2.51),
      (.34, .10, .58), armor, .045)
for side, sign in (("Left", -1), ("Right", 1)):
    block(side + " waist flank", "LowerTorso", (sign*.48, -.10, 2.67),
          (.29, .46, .42), raised, .04)
    block(side + " belt latch", "LowerTorso", (sign*.44, -.37, 2.86),
          (.11, .045, .09), gold, .012)
for index, z in enumerate((3.09, 2.98)):
    block(f"Sentry abdominal vent {index}", "LowerTorso", (0, -.36, z),
          (.50 - index*.05, .035, .045), edge, .012)

# Save the editable unposed scene, then export only the rig and mesh children.
closed_checks = {}
for ob in scene.objects:
    if ob.type != "MESH" or ob.parent != rig or ob in scans or ob.name == "SciFiSentryUndersuit":
        continue
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bad_edges = sum(not edge.is_manifold for edge in bm.edges)
    bm.free()
    assert bad_edges == 0, (ob.name, bad_edges)
    closed_checks[ob.name] = len(ob.data.polygons)
blend = TRIAL / "SciFiSentryRebuiltArmor.blend"
bpy.ops.wm.save_as_mainfile(filepath=str(blend))
bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
meshes = [ob for ob in scene.objects if ob.type == "MESH" and ob.parent == rig]
for ob in meshes:
    ob.select_set(True)
bpy.context.view_layer.objects.active = rig
out = TRIAL / "SciFiSentryRebuiltArmor.glb"
bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB",
                          export_image_format="AUTO", use_selection=True,
                          export_yup=True)
(TRIAL / "manifest.json").write_text(json.dumps({
    "status": "isolated articulation repair trial; not a Marketplace body",
    "sourceBlendSha256": hashlib.sha256(BASE.read_bytes()).hexdigest(),
    "removedScanFacesByPart": removed,
    "replacedBones": sorted(replaced_bones),
    "meshObjects": len(meshes),
    "newTextureFiles": sorted(p.name for p in TEXTURES.glob("*.png")),
    "closedRebuiltObjects": len(closed_checks),
    "nonmanifoldEdgesInRebuiltObjects": 0,
    "limitations": ["helmet, torso and lower legs retain fragmented scan components",
                    "no dynamic head, cages or Avatar Setup result",
                    "game and Marketplace acceptance require posed visual and Studio tests"],
}, indent=2) + "\n", encoding="utf-8")
print("REBUILT", out, len(meshes), "meshes", sum(removed.values()), "scan faces replaced")
