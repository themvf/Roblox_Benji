"""Build a cracked, leaking yellow-core tube from the clean neon-yellow variant.

The base tube's chamber wall is replaced by a cut shell. Crack lines, a few
retained glass shards, and raised viscous flows are new geometry. The base
intact exports are never modified.
"""
import math
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/bluetube-glossy"
SOURCE = PKG / "exports/BlueTube_NeonYellowCore.glb"
OUT = PKG / "exports/BlueTube_CrackedOozing.glb"
BLEND = PKG / "source/CrackedOozingTube.blend"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
scene = bpy.context.scene

shell_obj = next(o for o in scene.objects if o.type == "MESH" and "Yellow_glass_shell" in o.name)
shell_mat = shell_obj.data.materials[0]
bpy.data.objects.remove(shell_obj, do_unlink=True)


def mat(name, rgb, roughness, metallic=0, emission=None, alpha=1):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    bsdf = material.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, alpha)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Alpha"].default_value = alpha
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1)
        bsdf.inputs["Emission Strength"].default_value = .75
    if alpha < 1:
        material.blend_method = "BLEND"
    return material


ooze = mat("Fluorescent yellow-green viscous leak", (.56, .84, .012), .19, .02, (.24, .42, .003))
ooze_dark = mat("Thick yellow-green residue", (.30, .47, .008), .28, .03, (.10, .17, 0))
fracture = mat("Dark fracture lines", (.018, .035, .039), .5, .1)
fracture_edge = mat("Sharp glass fracture edges", (.43, .73, .73), .18, .22, alpha=.64)

CX, CY = 1.3376073, .1605129
R = 2.557506
BOTTOM, TOP = 1.091488, 10.358435
ANGLE = math.radians(-82)
HOLE_Z = 6.62


def polar(angle, radius, z):
    return Vector((CX + math.cos(angle) * radius, CY + math.sin(angle) * radius, z))


def half_width(z):
    dz = abs((z - HOLE_Z) / 1.26)
    if dz >= 1:
        return 0
    return .34 * (1 - .34 * dz) + .025 * math.sin(z * 7.2)


def in_opening(angle, z):
    diff = math.atan2(math.sin(angle - ANGLE), math.cos(angle - ANGLE))
    return abs(diff) < half_width(z)


# A single, purposefully cut translucent wall. Its hole is limited to a few
# lower-middle rows and leaves the structural upper/lower seals intact.
segments, rows = 72, 37
verts, faces = [], []
for row in range(rows + 1):
    z = BOTTOM + (TOP - BOTTOM) * row / rows
    for side in range(segments):
        angle = 2 * math.pi * side / segments
        verts.append(tuple(polar(angle, R, z)))
for row in range(rows):
    z = BOTTOM + (TOP - BOTTOM) * (row + .5) / rows
    for side in range(segments):
        angle = 2 * math.pi * (side + .5) / segments
        if in_opening(angle, z):
            continue
        nxt = (side + 1) % segments
        a, b = row * segments + side, row * segments + nxt
        c, d = (row + 1) * segments + nxt, (row + 1) * segments + side
        faces.append((a, b, c, d))
mesh = bpy.data.meshes.new("Cracked chamber glass geometry")
mesh.from_pydata(verts, [], faces)
mesh.update()
shell = bpy.data.objects.new("Tube_Cracked_yellow_glass_shell", mesh)
scene.collection.objects.link(shell)
shell.data.name = shell.name
shell.data.materials.append(shell_mat)
shell_mat.use_backface_culling = False
for face in mesh.polygons:
    face.use_smooth = True


def bead(name, points, radii, material, sides=10):
    """Swept closed tube with per-point thickness for viscous trails."""
    points = [Vector(p) for p in points]
    vertices, polygons = [], []
    for i, (point, radius) in enumerate(zip(points, radii)):
        tangent = (points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]).normalized()
        u = tangent.cross(Vector((0, 0, 1)))
        if u.length < .01:
            u = tangent.cross(Vector((1, 0, 0)))
        u.normalize()
        v = tangent.cross(u).normalized()
        for j in range(sides):
            a = 2 * math.pi * j / sides
            vertices.append(tuple(point + radius * (math.cos(a) * u + math.sin(a) * v)))
    polygons.append(tuple(range(sides - 1, -1, -1)))
    for i in range(len(points) - 1):
        for j in range(sides):
            k = (j + 1) % sides
            polygons.append((i * sides + j, i * sides + k, (i + 1) * sides + k, (i + 1) * sides + j))
    polygons.append(tuple((len(points) - 1) * sides + j for j in range(sides)))
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], polygons)
    data.update()
    ob = bpy.data.objects.new(name, data)
    scene.collection.objects.link(ob)
    ob.data.materials.append(material)
    for face in data.polygons:
        face.use_smooth = True
    return ob


def line(name, polar_points, material=fracture, radius=.033):
    points = [polar(a, R + .035, z) for a, z in polar_points]
    return bead(name, points, [radius] * len(points), material, 7)


# Dark open edges and branching cracks read as fractured glass, while the
# disconnected, outward-leaning shards clearly show where the wall broke.
levels = [5.39, 5.60, 5.95, 6.27, 6.62, 6.96, 7.29, 7.57, 7.85]
for side, sign in (("left", -1), ("right", 1)):
    points = [(ANGLE + sign * (half_width(z) + .03), z) for z in levels]
    line("Fracture opening " + side, points, fracture, .055)
    for start, rise, drift in ((5.9, -1.16, .24), (7.25, 1.20, .23)):
        a0 = ANGLE + sign * (half_width(start) + .03)
        line("Branching glass crack", [(a0, start), (a0 + sign * drift * .48, start + rise * .48),
                                        (a0 + sign * drift, start + rise)], fracture, .025)
line("Fracture upper split", [(ANGLE - .28, 7.68), (ANGLE, 8.05), (ANGLE + .24, 7.74)], fracture, .027)
line("Fracture lower split", [(ANGLE - .23, 5.54), (ANGLE, 5.04), (ANGLE + .26, 5.55)], fracture, .03)


def shard(name, angle, z, size, tilt):
    center = polar(angle, R + .13, z)
    tangent = Vector((-math.sin(angle), math.cos(angle), 0))
    radial = Vector((math.cos(angle), math.sin(angle), 0))
    tip = center + radial * tilt + Vector((0, 0, size * .65))
    verts = [center - tangent * size * .44 - Vector((0, 0, size * .52)),
             center + tangent * size * .48 - Vector((0, 0, size * .41)),
             tip]
    data = bpy.data.meshes.new(name)
    data.from_pydata([tuple(p) for p in verts], [], [(0, 1, 2)])
    data.update()
    ob = bpy.data.objects.new(name, data)
    scene.collection.objects.link(ob)
    data.materials.append(fracture_edge)
    return ob


for angle, z, size, tilt in ((ANGLE - .34, 7.62, .55, .22),
                             (ANGLE + .36, 7.32, .68, .32),
                             (ANGLE - .30, 5.85, .49, .28),
                             (ANGLE + .29, 5.49, .58, .24)):
    shard("Retained broken glass shard", angle, z, size, tilt)


def p(angle, radius, z, dx=0):
    value = polar(angle, radius, z)
    value.x += dx
    return value


# A thick rope leaves the opening, follows the curved wall, crosses the lower
# collar and terminates in a shallow irregular floor pool. Smaller strands and
# hanging drops make the escape direction obvious from front and quarter views.
bead("Ooze main vertical spill", [
    p(ANGLE, 2.22, 7.06), p(ANGLE, 2.72, 6.94), p(ANGLE + .01, 2.83, 6.55),
    p(ANGLE + .035, 2.85, 5.93), p(ANGLE + .05, 2.84, 5.03),
    p(ANGLE + .02, 2.85, 4.07), p(ANGLE - .01, 2.88, 3.15),
    p(ANGLE + .025, 2.88, 2.20), p(ANGLE + .05, 2.91, 1.24),
    p(ANGLE + .07, 3.16, .54), p(ANGLE + .08, 3.50, .18),
], [.22, .37, .31, .26, .21, .28, .25, .29, .33, .42, .38], ooze, 12)
bead("Ooze secondary strand", [
    p(ANGLE - .16, 2.65, 6.66), p(ANGLE - .15, 2.77, 6.24),
    p(ANGLE - .17, 2.76, 5.46), p(ANGLE - .15, 2.77, 4.65),
    p(ANGLE - .17, 2.79, 3.93),
], [.19, .17, .12, .11, .16], ooze_dark, 10)
bead("Ooze hanging droplet", [
    p(ANGLE + .18, 2.69, 6.62), p(ANGLE + .20, 2.75, 6.10),
    p(ANGLE + .22, 2.76, 5.63), p(ANGLE + .21, 2.77, 5.20),
], [.17, .14, .11, .24], ooze, 10)


def pool_blob(name, xyz, scale, material):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=xyz)
    ob = bpy.context.object
    ob.name = name
    ob.scale = scale
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    ob.data.materials.append(material)
    for face in ob.data.polygons:
        face.use_smooth = True


pool_center = p(ANGLE + .09, 3.55, .08)
pool_blob("Ooze floor pool main", pool_center, (1.55, .91, .095), ooze)
pool_blob("Ooze floor pool lobe", pool_center + Vector((.72, -.34, -.005)), (.82, .54, .087), ooze)
pool_blob("Ooze viscous dark edge", pool_center + Vector((-.32, .18, -.018)), (.62, .39, .035), ooze_dark)
for i, (dx, dy) in enumerate(((-1.02, -.12), (1.10, -.13), (.67, -.72))):
    pool_blob("Ooze splash bead %d" % i, pool_center + Vector((dx, dy, -.01)),
              (.18, .14, .045), ooze)
bead("Ooze thin ground rivulet", [pool_center + Vector((.61, -.17, .01)),
                                  pool_center + Vector((1.17, -.35, .01)),
                                  pool_center + Vector((1.67, -.43, -.015))],
     [.14, .12, .055], ooze, 8)


BLEND.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))

# Preserve editable individual features in the .blend, but group each new
# material for export so the Roblox import has a manageable part count.
for material, name in ((fracture, "Tube_Glass_fractures"),
                       (fracture_edge, "Tube_Retained_glass_shards"),
                       (ooze, "Tube_Fluorescent_ooze"),
                       (ooze_dark, "Tube_Thick_residue")):
    group = [ob for ob in scene.objects if ob.type == "MESH" and ob.data.materials
             and ob.data.materials[0] == material]
    if not group:
        continue
    bpy.ops.object.select_all(action="DESELECT")
    for ob in group:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = group[0]
    if len(group) > 1:
        bpy.ops.object.join()
    group[0].name = name
    group[0].data.name = name

bpy.ops.object.select_all(action="DESELECT")
for ob in scene.objects:
    if ob.type == "MESH":
        ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", use_selection=True,
                          export_yup=True, export_apply=True)
print("EXPORTED", OUT)
