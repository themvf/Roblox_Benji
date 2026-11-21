"""Model a clean glossy containment tube from the supplied concept and source views.

    blender -b -noaudio --python tools/blender/build_bluetube_clean_geometry.py

Blender Z is up. Exported glTF uses Y up for Roblox. The original generated mesh
remains in source/ and is not silently mixed into the clean geometry.
"""
import math
from pathlib import Path

import bpy

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/bluetube-glossy"
bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, roughness, metallic=0.0, emission=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1)
        bsdf.inputs["Emission Strength"].default_value = 0.75
    return mat


shell = material("Glossy cobalt blue enamel", (.115, .31, .42), .19, .72)
shell_light = material("Worn light blue panels", (.25, .48, .58), .27, .55)
edge = material("Polished steel edge", (.34, .49, .54), .16, .84)
dark = material("Recessed graphite", (.035, .075, .09), .38, .35)
rubber = material("Dark rubber gasket", (.025, .035, .045), .65, .02)
cyan = material("Cyan energy core", (.08, .75, .93), .48, .03, (.07, .6, .82))
glass = material("Cyan glass shell", (.06, .53, .69), .13, .08)
glass.node_tree.nodes["Principled BSDF"].inputs["Alpha"].default_value = .32
glass.blend_method = "BLEND"
screen = material("Diagnostic screen", (.018, .13, .18), .25, .08, (.04, .45, .7))
accent = material("Indicator bright cyan", (.08, .72, .85), .23, .10, (.02, .42, .6))
warn = material("Warm status light", (.95, .42, .11), .33, .18, (.8, .2, .01))


def finish(ob, name, mat, smooth=False):
    ob.name = name
    ob.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if smooth:
        for face in ob.data.polygons:
            face.use_smooth = True
    return ob


def box(name, xyz, size, mat, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    ob = bpy.context.object
    ob.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = ob.modifiers.new("Manufactured edge radius", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.modifier_apply(modifier=mod.name)
        normals = ob.modifiers.new("Weighted face normals", "WEIGHTED_NORMAL")
        bpy.ops.object.modifier_apply(modifier=normals.name)
    return finish(ob, name, mat)


def cylinder(name, xyz, radius, depth, mat, vertices=64):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=xyz)
    return finish(bpy.context.object, name, mat, smooth=True)


def ring(name, cx, cy, z0, z1, outer, inner, mat, vertices=64):
    verts = []
    for z, r in ((z0, outer), (z1, outer), (z1, inner), (z0, inner)):
        verts.extend((cx + math.cos(2 * math.pi * i / vertices) * r,
                      cy + math.sin(2 * math.pi * i / vertices) * r, z)
                     for i in range(vertices))
    faces = []
    for band in range(4):
        nxt = (band + 1) % 4
        for i in range(vertices):
            j = (i + 1) % vertices
            faces.append((band * vertices + i, band * vertices + j,
                          nxt * vertices + j, nxt * vertices + i))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat)
    for face in mesh.polygons:
        face.use_smooth = True
    return ob


def radial_box(name, radius, angle, z, length, width, height, mat):
    a = math.radians(angle)
    x, y = TUBE_X + math.cos(a) * radius, TUBE_Y + math.sin(a) * radius
    ob = box(name, (0, 0, 0), (length, width, height), mat, .045)
    ob.rotation_euler.z = a
    ob.location = (x, y, z)
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=False)
    return ob


TUBE_X, TUBE_Y = 1.25, .15

# Stable base and stepped, fully connected collar. No source shards or holes.
cylinder("Foundation puck", (TUBE_X, TUBE_Y, .24), 2.73, .48, dark)
cylinder("Ground foot", (TUBE_X, TUBE_Y, .09), 2.91, .18, rubber)
ring("Lower chrome lip", TUBE_X, TUBE_Y, .41, .53, 2.78, 2.37, edge)
ring("Lower blue retaining band", TUBE_X, TUBE_Y, .53, .86, 2.68, 2.27, shell)
ring("Lower seal", TUBE_X, TUBE_Y, .86, .98, 2.54, 2.33, rubber)
ring("Lit floor collar", TUBE_X, TUBE_Y, .98, 1.06, 2.43, 2.21, accent)

# The opaque, softly lit core is enclosed by a glossy blue shell. The pair
# avoids fragile transparent geometry and survives glTF/Studio import.
cylinder("Continuous blue chamber", (TUBE_X, TUBE_Y, 5.34), 2.26, 8.64, cyan)
ring("Glossy glass wall", TUBE_X, TUBE_Y, 1.02, 9.68, 2.39, 2.31, glass)
for angle in (-58, 42, 137, 222):
    a = math.radians(angle)
    x, y = TUBE_X + 2.42 * math.cos(a), TUBE_Y + 2.42 * math.sin(a)
    cylinder("Chamber upright", (x, y, 5.33), .065, 8.58, edge, 16)

ring("Upper seal", TUBE_X, TUBE_Y, 9.61, 9.79, 2.55, 2.30, rubber)
ring("Upper internal light", TUBE_X, TUBE_Y, 9.79, 9.86, 2.48, 2.23, accent)
ring("Top lower shoulder", TUBE_X, TUBE_Y, 9.84, 10.16, 2.76, 2.30, shell)
ring("Top machine ring", TUBE_X, TUBE_Y, 10.15, 10.95, 3.02, 2.23, shell_light)
ring("Top roof rim", TUBE_X, TUBE_Y, 10.94, 11.21, 2.94, 2.26, shell)
cylinder("Closed roof", (TUBE_X, TUBE_Y, 11.15), 2.46, .20, shell)
ring("Top thin chrome seam", TUBE_X, TUBE_Y, 10.11, 10.18, 3.04, 2.81, edge)
ring("Top roof seam", TUBE_X, TUBE_Y, 11.20, 11.26, 2.84, 2.46, dark)
for angle in range(0, 360, 30):
    radial_box("Cap armor rib", 2.91, angle, 10.55, .38, .22, .76, shell)
    a = math.radians(angle)
    x, y = TUBE_X + 2.90 * math.cos(a), TUBE_Y + 2.90 * math.sin(a)
    cylinder("Cap fastener", (x, y, 11.05), .085, .08, edge, 12)
for angle in range(15, 360, 45):
    radial_box("Roof inset panel", 1.66, angle, 11.28, 1.11, .38, .055, shell_light)

# Tall control cabinet to one side. Layered panels provide crisp manufactured
# detail without retaining the raw generator's interpenetrating triangles.
box("Cabinet footing", (-2.94, .25, .34), (2.94, 3.36, .68), dark, .12)
box("Cabinet spine", (-2.93, .35, 5.23), (2.79, 2.92, 9.78), shell, .20)
box("Cabinet roof", (-2.93, .33, 10.18), (3.08, 3.13, .64), shell_light, .15)
box("Cabinet roof trim", (-2.93, .33, 10.52), (2.86, 2.95, .12), edge, .055)
box("Front dark recess", (-2.99, -1.145, 4.67), (2.19, .095, 7.40), dark, .11)
box("Door glossy face", (-3.05, -1.216, 4.55), (1.87, .080, 6.96), shell_light, .12)
box("Door inset", (-3.12, -1.275, 4.38), (1.48, .035, 5.85), shell, .07)
box("Door inset seam", (-3.12, -1.299, 4.38), (1.25, .021, 5.62), dark, .02)
box("Door inner panel", (-3.12, -1.324, 4.38), (1.12, .025, 5.48), shell_light, .055)
for z in (1.18, 7.78):
    box("Door cross rail", (-3.05, -1.366, z), (1.66, .06, .14), edge, .025)
for x in (-4.22, -1.67):
    box("Front vertical guard", (x, -1.44, 4.65), (.16, .23, 8.55), shell, .06)
    for z in (1.26, 4.85, 8.52):
        cylinder("Guard stud", (x, -1.57, z), .07, .06, edge, 10)

# Functional-looking screen, keyed panel, vent bank and side conduits.
box("Screen frame", (-1.69, -1.469, 6.10), (.92, .16, 1.79), dark, .07)
box("Cyan display", (-1.69, -1.568, 6.12), (.73, .035, 1.53), screen, .035)
for z in (5.61, 5.93, 6.29, 6.58):
    box("Display trace", (-1.67, -1.592, z), (.43, .022, .025), accent, .006)
box("Keypad frame", (-1.71, -1.470, 4.70), (.85, .10, .76), dark, .04)
for row in range(2):
    for col in range(3):
        box("Control key", (-1.98 + col * .25, -1.536, 4.51 + row * .26),
            (.13, .04, .11), edge, .017)
box("Cabinet side service panel", (-4.347, .34, 5.53), (.07, 1.83, 4.58), shell_light, .08)
box("Cabinet side seam", (-4.399, .34, 5.53), (.03, 1.56, 4.22), dark, .03)
for z in (3.84, 4.02, 4.20, 4.38, 4.56):
    box("Side cooling vent", (-4.425, .34, z), (.029, 1.24, .070), dark, .01)
for z in (3.4, 6.9):
    box("Tube to cabinet bracket", (-1.28, .53, z), (1.1, 1.10, .40), edge, .07)
    box("Bracket inset", (-1.28, .53, z + .24), (.84, .86, .08), shell, .035)
for z in (.78, 9.35):
    box("Cabinet lateral stabilizer", (-2.13, 1.46, z), (1.36, .33, .40), dark, .05)
for x, z in ((-1.75, 2.1), (-1.75, 8.2)):
    cylinder("Amber service indicator", (x, -1.54, z), .095, .065, warn, 16)

# Match the established approximately 12.1-stud height and ground pivot.
all_meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
low = min(v.co.z for o in all_meshes for v in o.data.vertices)
high = max(v.co.z for o in all_meshes for v in o.data.vertices)
factor = 12.1 / (high - low)
for ob in all_meshes:
    for vert in ob.data.vertices:
        vert.co.x *= factor
        vert.co.y *= factor
        vert.co.z = (vert.co.z - low) * factor
    ob.data.update()
print("FIT_HEIGHT", high - low, "to", 12.1, "factor", factor)

# Keep the source Blender scene editable before packaging the exported meshes.
PKG.joinpath("source").mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(PKG / "source/GlossyBlueTube.blend"))

# Each material becomes one mesh on export. All original generated geometry is
# excluded; each clean mesh remains well below Roblox's 10k triangle limit.
for mat in list(bpy.data.materials):
    group = [o for o in bpy.context.scene.objects
             if o.type == "MESH" and o.data.materials and o.data.materials[0] == mat]
    if not group:
        continue
    bpy.ops.object.select_all(action="DESELECT")
    for ob in group:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = group[0]
    if len(group) > 1:
        bpy.ops.object.join()
    group[0].name = "Tube_" + mat.name.replace(" ", "_")
    group[0].data.name = group[0].name

bpy.ops.object.select_all(action="DESELECT")
for ob in bpy.context.scene.objects:
    if ob.type == "MESH":
        ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(PKG / "exports/BlueTube_Glossy.glb"),
                          export_format="GLB", use_selection=True,
                          export_yup=True, export_apply=True)
print("EXPORTED", PKG / "exports/BlueTube_Glossy.glb")
