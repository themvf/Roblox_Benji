"""Clean hard-surface rebuild of the surgeon's table from its supplied references.

Coordinates are Blender Z-up, with the bed along X and its head at +X.
The single TRELLIS source is reference only: its open, entangled topology is not
used in the export. This script is the authoritative editable source.
"""
from pathlib import Path
import json
import math
import bpy

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/surgical-table"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
for sub in ("source", "exports", "textures", "review"):
    (PKG / sub).mkdir(parents=True, exist_ok=True)


def material(name, color, metallic=0, roughness=.42, texture=None, emission=None):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = roughness
    if texture:
        node = mat.node_tree.nodes.new("ShaderNodeTexImage")
        node.image = bpy.data.images.load(str(PKG / "textures" / texture))
        mat.node_tree.links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1)
        bsdf.inputs["Emission Strength"].default_value = .65
    return mat


M = {
    "vinyl": material("Blue medical vinyl", (.24, .46, .61), roughness=.60,
                      texture="SurgicalTable_BlueVinyl_Color.png"),
    "frame": material("Powder-coated blue steel", (.20, .38, .52), metallic=.55, roughness=.35),
    "metal": material("Brushed stainless steel", (.67, .73, .76), metallic=.76, roughness=.26),
    "white": material("Cool white medical polymer", (.79, .84, .85), metallic=.12, roughness=.32),
    "rubber": material("Charcoal rubber", (.085, .115, .135), roughness=.78),
    "screen": material("Dark monitor glass", (.025, .055, .075), metallic=.12, roughness=.14),
    "light": material("Surgical light lens", (.88, .96, .95), roughness=.19,
                      emission=(.75, .94, .96)),
    "accent": material("Cyan controls", (.055, .54, .70), metallic=.25, roughness=.30,
                       emission=(.06, .40, .53)),
}
ITEMS = {
    "table": "SurgicalTable",
    "lights": "SurgicalLights",
    "monitor": "PatientMonitor",
    "iv": "IVStand",
}
objects = {item: {key: [] for key in M} for item in ITEMS}
ACTIVE_ITEM = "table"


def keep(obj, name, group):
    obj.name = name
    obj.data.materials.clear()
    obj.data.materials.append(M[group])
    objects[ACTIVE_ITEM][group].append(obj)
    return obj


def box(name, loc, size, group, bevel=0, angle=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    ob = bpy.context.object
    ob.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = ob.modifiers.new("rounded manufactured edge", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    if angle:
        ob.rotation_euler[1] = math.radians(angle)
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return keep(ob, name, group)


def cylinder(name, loc, radius, depth, group, vertices=20, rotation=None):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth,
                                        location=loc)
    ob = bpy.context.object
    if rotation:
        ob.rotation_euler = rotation
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return keep(ob, name, group)


def tube_between(name, a, b, radius, group, vertices=12):
    from mathutils import Vector
    start, end = Vector(a), Vector(b)
    mid = (start + end) / 2
    ob = cylinder(name, mid, radius, (end - start).length, group, vertices)
    ob.rotation_euler = (end - start).to_track_quat("Z", "Y").to_euler()
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return ob


def torus(name, loc, major, minor, group):
    bpy.ops.mesh.primitive_torus_add(major_segments=32, minor_segments=6,
                                     location=loc, major_radius=major,
                                     minor_radius=minor)
    return keep(bpy.context.object, name, group)


# Five-wheel base and a real-looking lift column anchor the assembly.
box("low mobile base", (.40, 0, .37), (3.45, 2.50, .48), "frame", .16)
box("base top inset", (.40, 0, .63), (2.28, 1.48, .10), "metal", .04)
for x in (-1.10, 1.82):
    for y in (-1.08, 1.08):
        box("caster fork", (x, y, .25), (.35, .22, .20), "metal", .025)
        cylinder("rubber caster", (x, y, .15), .19, .16, "rubber", 16,
                 rotation=(math.pi / 2, 0, 0))
box("pedestal housing", (.30, 0, 1.25), (1.48, 1.46, 1.55), "frame", .13)
box("pedestal front panel", (.30, -.743, 1.30), (1.10, .035, .99), "white", .025)
for z in (1.12, 1.24, 1.36):
    box("pedestal service grille", (.25, -.77, z), (.78, .018, .028), "rubber")
cylinder("height actuator", (.30, 0, 2.48), .27, 1.58, "metal", 24)
cylinder("lift collar", (.30, 0, 3.10), .39, .21, "frame", 24)
box("underbed longitudinal beam", (0, 0, 3.20), (8.95, .72, .28), "frame", .07)
for y in (-1.40, 1.40):
    box("side support rail", (0, y, 3.38), (9.65, .10, .12), "metal", .04)
    for x in (-3.45, -1.15, 1.30, 3.75):
        box("rail mount", (x, y * .78, 3.29), (.22, .30, .18), "frame", .025)

# Three articulated, cushion-topped panels; the head/back end angles upward.
segments = [
    ("foot", -3.35, 2.80, 3.61, 0),
    ("middle", -.25, 3.25, 3.61, 0),
    ("back", 3.02, 2.93, 4.11, -22),
]
for label, x, length, z, angle in segments:
    box(label + " table pan", (x, 0, z - .20), (length, 3.23, .22), "frame", .055, angle)
    box(label + " cushion", (x, 0, z), (length - .10, 3.09, .24), "vinyl", .105, angle)
    # Thin seam at each upholstered edge reads clearly without fragile geometry.
    for side in (-1, 1):
        box(label + " edge piping", (x, side * 1.565, z - .035),
            (length - .12, .028, .025), "white", .009, angle)
    for end in (-1, 1):
        end_dx = end * (length / 2 - .075)
        end_z = z - .035 - math.sin(math.radians(angle)) * end_dx
        box(label + " end piping", (x + end_dx, 0, end_z),
            (.028, 3.02, .025), "white", .009, angle)

# Backrest hinge and visible actuator replace the source's melted support mass.
for y in (-1.26, 1.26):
    cylinder("back hinge", (1.66, y, 3.46), .15, .16, "metal", 20,
             rotation=(math.pi / 2, 0, 0))
tube_between("back lift ram", (1.38, -.52, 2.83), (3.43, -.52, 3.58), .12, "metal")
tube_between("back ram sleeve", (1.45, -.52, 2.86), (2.43, -.52, 3.22), .17, "frame")
box("foot pad pull handle", (-4.88, 0, 3.45), (.14, 1.25, .10), "metal", .04)
for x in (-3.5, -.4, 2.7):
    box("underside rib", (x, 0, 3.29), (.12, 3.11, .10), "metal", .02)

# Slim side accessory rail stays with the operating table.
for x in (1.55, 3.80):
    tube_between("head-side rail post", (x, 1.72, 3.28), (x, 1.72, 4.18), .055, "metal")
tube_between("head-side rail", (1.55, 1.72, 4.18), (3.80, 1.72, 4.18), .052, "metal")

# The monitor has its own wheeled cart so it can be placed independently.
ACTIVE_ITEM = "monitor"
box("monitor cart base", (4.42, 2.53, .25), (1.00, .82, .28), "frame", .07)
for x in (4.07, 4.77):
    for y in (2.22, 2.84):
        cylinder("monitor cart caster", (x, y, .105), .105, .11, "rubber", 12,
                 rotation=(math.pi / 2, 0, 0))
box("monitor cart cabinet", (4.42, 2.53, 1.32), (.78, .66, 1.87), "white", .065)
box("monitor cabinet panel", (4.42, 2.19, 1.36), (.59, .019, 1.40), "frame", .025)
for height in (.94, 1.06, 1.18):
    box("monitor cabinet vent", (4.42, 2.175, height), (.44, .011, .025), "rubber")
tube_between("monitor mast", (4.42, 2.53, 2.29), (4.42, 2.53, 4.64), .10, "metal")
box("monitor swivel", (4.42, 2.63, 4.77), (.25, .20, .20), "frame", .025)
box("monitor body", (4.42, 2.53, 4.90), (1.34, .17, .92), "white", .07)
box("monitor dark display", (4.42, 2.43, 4.92), (1.16, .025, .70), "screen", .018)
for i, height in enumerate((4.78, 4.87, 4.80, 4.98, 4.84)):
    box("monitor trace %02d" % i, (3.99 + .20 * i, 2.412, height),
        (.17, .009, .018), "accent")
for x in (4.68, 4.82, 4.96):
    cylinder("monitor control", (x, 2.413, 4.52), .025, .016, "accent", 12,
             rotation=(math.pi / 2, 0, 0))

# IV pole and bag live at the head of the bed, distinct from the light gantry.
ACTIVE_ITEM = "iv"
box("IV rolling hub", (4.32, -1.98, .30), (.25, .25, .25), "metal", .04)
for x, y in ((4.82, -1.98), (4.07, -1.55), (4.07, -2.41)):
    tube_between("IV tripod foot", (4.32, -1.98, .23), (x, y, .14), .045, "metal")
    cylinder("IV caster", (x, y, .09), .09, .10, "rubber", 12,
             rotation=(math.pi / 2, 0, 0))
tube_between("IV upright", (4.32, -1.98, .40), (4.32, -1.98, 6.20), .047, "metal")
tube_between("IV crossbar", (3.99, -1.98, 6.15), (4.65, -1.98, 6.15), .04, "metal")
for x in (4.00, 4.64):
    tube_between("IV hook", (x, -1.98, 6.15), (x, -1.98, 5.98), .027, "metal")
box("sealed infusion bag", (4.00, -1.98, 5.62), (.31, .11, .51), "white", .035)
box("bag fluid label", (4.00, -2.04, 5.62), (.21, .013, .19), "accent", .008)
tube_between("short drip line", (4.00, -1.98, 5.34), (3.86, -1.77, 4.87), .012, "rubber", 8)

# Clean freestanding light boom with two downward-facing surgical lamps.
ACTIVE_ITEM = "lights"
box("lighting stand base", (5.60, 2.65, .25), (1.10, 1.08, .28), "frame", .09)
tube_between("lighting mast", (5.60, 2.65, .40), (5.60, 2.65, 7.45), .12, "white", 16)
for z in (1.35, 5.95, 7.24):
    cylinder("mast collar", (5.60, 2.65, z), .18, .15, "metal", 20)
tube_between("upper boom", (5.60, 2.65, 7.32), (1.10, 2.10, 7.32), .095, "white", 12)
tube_between("light one arm", (1.10, 2.10, 7.32), (.65, .20, 7.06), .07, "metal")
tube_between("light two arm", (2.75, 2.34, 7.32), (2.95, -1.16, 6.97), .07, "metal")
for label, cx, cy, z, radius in (("primary", .65, .20, 6.88, 1.05),
                                  ("secondary", 2.95, -1.16, 6.79, .78)):
    cylinder(label + " lamp casing", (cx, cy, z + .14), radius, .22, "white", 32)
    cylinder(label + " dark lamp recess", (cx, cy, z + .015), radius * .82, .035,
             "rubber", 32)
    torus(label + " polished rim", (cx, cy, z + .02), radius * .91, .055, "metal")
    cylinder(label + " lens center", (cx, cy, z - .014), radius * .19, .055,
             "light", 20)
    for k in range(8):
        a = 2 * math.pi * k / 8
        x, y = cx + radius * .58 * math.cos(a), cy + radius * .58 * math.sin(a)
        cylinder(label + " LED %02d" % k, (x, y, z - .015),
                 radius * .105, .045, "light", 12)
    tube_between(label + " grip", (cx, cy, z - .04), (cx, cy, z - .34), .055,
                 "metal", 12)

# Join within each item and material. Each export has its own centered ground pivot.
export_parts = {item: [] for item in ITEMS}
for item, groups in objects.items():
    for group, group_objects in groups.items():
        batches, batch, triangles = [], [], 0
        for ob in group_objects:
            ob.data.calc_loop_triangles()
            count = len(ob.data.loop_triangles)
            if batch and triangles + count > 9000:
                batches.append(batch)
                batch, triangles = [], 0
            batch.append(ob)
            triangles += count
        if batch:
            batches.append(batch)
        for index, chunk in enumerate(batches, 1):
            bpy.ops.object.select_all(action="DESELECT")
            for ob in chunk:
                ob.select_set(True)
            bpy.context.view_layer.objects.active = chunk[0]
            if len(chunk) > 1:
                bpy.ops.object.join()
            part = bpy.context.view_layer.objects.active
            part.name = "%s_%s_%02d" % (ITEMS[item], group, index)
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
            part.data.validate(clean_customdata=False)
            part.data.calc_loop_triangles()
            count = len(part.data.loop_triangles)
            assert 0 < count < 10000, (part.name, count)
            export_parts[item].append(part)

# Save the editable assembled source before centering individual delivery items.
bpy.ops.wm.save_as_mainfile(filepath=str(PKG / "source/SurgicalTable.blend"))
layout = {}
for item, parts in export_parts.items():
    assert parts, item
    low = [min(v.co[i] for part in parts for v in part.data.vertices) for i in range(3)]
    high = [max(v.co[i] for part in parts for v in part.data.vertices) for i in range(3)]
    center_x, center_y = (low[0] + high[0]) / 2, (low[1] + high[1]) / 2
    ground_z = low[2]
    layout[item] = {
        "export": ITEMS[item] + ".glb",
        "placementRobloxXYZStuds": [round(center_x, 4), 0, round(-center_y, 4)],
        "sourceGroundOffsetBlenderZ": round(ground_z, 4),
    }
    for part in parts:
        for vertex in part.data.vertices:
            vertex.co.x -= center_x
            vertex.co.y -= center_y
            vertex.co.z -= ground_z
        part.data.update()
    bpy.ops.object.select_all(action="DESELECT")
    for part in parts:
        part.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.export_scene.gltf(filepath=str(PKG / "exports" / (ITEMS[item] + ".glb")),
                              export_format="GLB", export_image_format="AUTO",
                              use_selection=True, export_apply=True)
    print("EXPORTED", item, [(p.name, len(p.data.loop_triangles)) for p in parts], flush=True)
(PKG / "source/assembly-layout.json").write_text(json.dumps(layout, indent=2) + "\n",
                                                  encoding="utf-8")
