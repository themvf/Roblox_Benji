"""Make a clean, closed R15 proportion study for the Sci-Fi Sentry.

This is an authoring trial, not a Marketplace avatar. The separate body regions
can be posed without cutting fragments from the original scan. Armor is kept as
separate objects so it can later be rebuilt as compliant accessories.
"""
from pathlib import Path
import json
import math
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/ninja-soldier-skins"
TRIAL = PKG / "trials" / "SciFiSentryCleanBody"
TRIAL.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color, metallic=0, roughness=.45, emission=0):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1)
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    if emission:
        shader.inputs["Emission Color"].default_value = (*color, 1)
        shader.inputs["Emission Strength"].default_value = emission
    return mat


undersuit = material("01 Carbon black undersuit", (.014, .021, .025), .15, .73)
armor = material("02 Graphite ceramic armor", (.031, .049, .057), .48, .31)
edge = material("03 Edge alloy", (.066, .083, .087), .74, .24)
rubber = material("04 Joint rubber", (.022, .029, .030), .05, .88)
bronze = material("05 Worn bronze fittings", (.31, .18, .064), .7, .32)
cyan = material("06 Cyan light", (.012, .6, .75), .12, .24, 2.8)
visor = material("07 Dark smoked visor", (.006, .017, .023), .65, .14)


def tapered(name, x, y, z0, z1, bottom, top, mat, sides=12):
    """One closed, clean body region, with two elliptical rings and end caps."""
    verts = []
    for z, radius in ((z0, bottom), (z1, top)):
        for i in range(sides):
            a = 2 * math.pi * i / sides
            verts.append((x + radius[0] * math.cos(a), y + radius[1] * math.sin(a), z))
    faces = []
    faces.append(tuple(reversed(range(sides))))
    faces.append(tuple(range(sides, sides * 2)))
    for i in range(sides):
        j = (i + 1) % sides
        faces.append((i, j, sides + j, sides + i))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new("Soft machined edges", "BEVEL")
    bevel.width = .035
    bevel.segments = 2
    obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    return obj


def box(name, xyz, dims, mat, bevel=.035, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=xyz)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dims
    if rotation:
        obj.rotation_euler = rotation
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("Machined radius", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    return obj


def orb(name, xyz, dims, mat, segments=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=8, location=xyz)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def tube(name, points, radius, mat, sides=8):
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 1
    spline = curve.splines.new("POLY")
    spline.points.add(len(points) - 1)
    for point, xyz in zip(spline.points, points):
        point.co = (*xyz, 1)
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


# Fifteen named R15 regions. These are anatomical guides for retopology and
# source-detail transfer; Avatar Setup and dynamic-head validation remain ahead.
body = {}
body["Head"] = orb("Head", (0, 0, 4.78), (.89, .76, .89), undersuit)
body["UpperTorso"] = tapered("UpperTorso", 0, 0, 3.20, 4.25, (.75, .40), (.87, .43), undersuit)
body["LowerTorso"] = tapered("LowerTorso", 0, 0, 2.57, 3.22, (.65, .36), (.76, .40), undersuit)
for side, sign in (("Left", -1), ("Right", 1)):
    x = sign * 1.13
    body[f"{side}UpperArm"] = tapered(f"{side}UpperArm", x, 0, 3.22, 4.14,
                                        (.29, .28), (.35, .33), undersuit)
    body[f"{side}LowerArm"] = tapered(f"{side}LowerArm", x, 0, 2.35, 3.19,
                                        (.22, .21), (.28, .27), undersuit)
    body[f"{side}Hand"] = tapered(f"{side}Hand", x, 0, 1.98, 2.35,
                                    (.20, .13), (.23, .18), undersuit)
    x = sign * .43
    body[f"{side}UpperLeg"] = tapered(f"{side}UpperLeg", x, 0, 1.48, 2.59,
                                        (.35, .36), (.41, .39), undersuit)
    body[f"{side}LowerLeg"] = tapered(f"{side}LowerLeg", x, 0, .47, 1.45,
                                        (.25, .28), (.34, .34), undersuit)
    body[f"{side}Foot"] = orb(f"{side}Foot", (x, -.18, .27), (.72, 1.02, .42), undersuit)
assert len(body) == 15

# The neck and black joints retain overlap when limbs bend.
tapered("Neck guide", 0, 0, 4.17, 4.45, (.24, .24), (.25, .25), rubber)
for side, sign in (("Left", -1), ("Right", 1)):
    for name, z, x, size in (("Shoulder", 4.10, 1.12, .43),
                             ("Elbow", 3.20, 1.13, .31),
                             ("Hip", 2.55, .43, .38),
                             ("Knee", 1.46, .43, .32)):
        orb(f"{side} {name} articulation", (sign*x, 0, z), (size, size, size), rubber)

# High level armor forms echo the actual source without inheriting scan shards.
box("UpperTorso__segmented chest carrier", (0, -.44, 3.78), (1.47, .22, .76), armor, .09)
box("UpperTorso__central vent", (0, -.575, 3.76), (.38, .055, .52), edge, .035)
for sign in (-1, 1):
    box(f"UpperTorso__breast plate {sign}", (sign*.49, -.58, 3.83), (.42, .11, .56), armor, .055,
        (0, 0, sign*.13))
    box(f"UpperTorso__bronze mount {sign}", (sign*.68, -.58, 4.20), (.08, .10, .11), bronze, .015)
    box(f"UpperTorso__cyan status {sign}", (sign*.67, -.66, 3.80), (.05, .03, .17), cyan, .008)
box("LowerTorso__abdominal plate", (0, -.4, 2.92), (.94, .18, .48), armor, .07)
for z in (2.79, 2.95, 3.11):
    box(f"LowerTorso__rib {z}", (0, -.51, z), (.67, .08, .045), edge, .008)
box("UpperTorso__backpack core", (0, .53, 3.74), (.85, .36, .94), armor, .08)
box("UpperTorso__backpack spine", (0, .78, 3.72), (.16, .10, .78), edge, .025)
for sign in (-1, 1):
    box(f"UpperTorso__strap {sign}", (sign*.53, .0, 3.75), (.13, 1.05, .75), rubber, .03)
    tube(f"UpperTorso__breathing hose {sign}", [(sign*.36, -.38, 4.43),
         (sign*.6, -.46, 4.30), (sign*.65, -.56, 3.97), (sign*.44, -.61, 3.58)], .055, rubber)

for side, sign in (("Left", -1), ("Right", 1)):
    armx = sign*1.13
    legx = sign*.43
    box(f"{side}UpperArm__shoulder cap", (sign*1.18, -.06, 3.98), (.68, .66, .42), armor, .13)
    box(f"{side}UpperArm__outer plate", (sign*1.39, -.08, 3.58), (.22, .46, .57), armor, .07)
    box(f"{side}UpperArm__joint ring", (armx, 0, 3.26), (.61, .62, .12), edge, .025)
    box(f"{side}LowerArm__forearm shield", (armx, -.26, 2.77), (.46, .18, .61), armor, .07)
    box(f"{side}LowerArm__highlight", (armx, -.365, 2.81), (.12, .02, .31), edge, .007)
    box(f"{side}Hand__gauntlet", (armx, -.16, 2.20), (.43, .30, .29), armor, .05)
    box(f"{side}UpperLeg__thigh shield", (legx, -.29, 2.00), (.65, .20, .83), armor, .10)
    box(f"{side}UpperLeg__inset", (legx, -.41, 2.00), (.32, .025, .52), edge, .025)
    box(f"{side}LowerLeg__shin shield", (legx, -.28, .91), (.55, .21, .78), armor, .08)
    for z in (.70, .87, 1.04):
        box(f"{side}LowerLeg__shin rib {z}", (legx, -.405, z), (.40, .03, .055), edge, .008)
    box(f"{side}Foot__toe armor", (legx, -.47, .24), (.67, .48, .25), armor, .07)
    box(f"{side}Foot__heel armor", (legx, .19, .27), (.58, .24, .28), armor, .055)

# Head shell/antenna are kept distinct from the body. A functional head and
# accessory segmentation must be verified in Studio; these are visual guides.
orb("Head__helmet shell", (0, .035, 4.88), (1.08, .97, .90), armor)
box("Head__brow", (0, -.49, 4.96), (.83, .19, .23), edge, .055)
box("Head__visor", (0, -.52, 4.81), (.79, .10, .23), visor, .06)
box("Head__cyan visor slit", (0, -.579, 4.78), (.60, .017, .026), cyan, .006)
box("Head__respirator", (0, -.55, 4.48), (.49, .33, .31), armor, .08)
for sign in (-1, 1):
    orb(f"Head__filter {sign}", (sign*.41, -.43, 4.47), (.30, .30, .30), edge)
    box(f"Head__temple port {sign}", (sign*.53, -.15, 4.69), (.12, .24, .17), bronze, .025)
tube("UpperTorso__antenna", [(-.34, .75, 4.16), (-.33, .82, 4.56),
                           (-.30, .84, 4.94), (-.22, .86, 5.28)], .018, edge)

scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.samples = 24
scene.render.resolution_x = 700
scene.render.resolution_y = 700
scene.render.resolution_percentage = 100
scene.view_settings.view_transform = "AgX"
world = bpy.data.worlds.new("Neutral review")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (.29, .35, .39, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = .65

def light(name, pos, energy, size):
    data = bpy.data.lights.new(name, "AREA")
    data.energy = energy
    data.shape = "DISK"
    data.size = size
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.location = pos
    obj.rotation_euler = (Vector((0, 0, 2.7)) - obj.location).to_track_quat("-Z", "Y").to_euler()

light("Key", (-4, -5, 8), 850, 5)
light("Rim", (3, 4, 6), 1100, 4)
light("Fill", (4, -4, 4), 450, 5)

def render_view(label, camera_at):
    bpy.ops.object.camera_add(location=camera_at)
    camera = bpy.context.object
    camera.name = "Review camera"
    direction = Vector((0, 0, 2.7)) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 6.7
    scene.camera = camera
    scene.render.filepath = str(TRIAL / f"{label}.png")
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera, do_unlink=True)

# Save editable geometry without render lights/camera in delivery exports later.
bpy.ops.wm.save_as_mainfile(filepath=str(TRIAL / "SciFiSentryCleanBody.blend"))
render_view("front", (7, -11, 6))
render_view("side", (12, 0, 5))
render_view("rear", (7, 11, 6))

record = {
    "status": "proportion and surface-layout trial only; not Roblox/Marketplace ready",
    "bodyRegions": sorted(body),
    "sourceReference": "source/SciFiSentrySource.glb",
    "knownGaps": ["no source texture transfer", "no dynamic head", "no skinning or cages",
                   "armor accessories not yet consolidated or validated", "no pose verification"],
}
(TRIAL / "manifest.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
print("SAVED", TRIAL)
