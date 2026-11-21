"""Author the intact black/orange cargo case. Blender X long, Y deep, Z up.

One Blender unit is one stud. The original TRELLIS mesh is a reference only:
its 286k triangles shred into jagged panels at Roblox's per-mesh budget.
"""
from pathlib import Path
import math
import random
import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/black-orange-box"
N = 1024
rng = np.random.default_rng(71)
random.seed(71)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
for folder in ("source", "exports", "textures", "review", "trials"):
    (OUT / folder).mkdir(parents=True, exist_ok=True)

# Compact 4x4 material atlas: one swatch per modeled part, with subtle paint grain.
swatches = {
    "shell": ((.105, .112, .124), .55, .40),
    "lid": ((.075, .081, .092), .43, .52),
    "frame": ((.145, .152, .166), .56, .56),
    "inset": ((.071, .078, .088), .66, .31),
    "orange": ((.90, .295, .065), .45, .42),
    "amber": ((1.0, .47, .09), .48, .32),
    "steel": ((.57, .61, .64), .32, .88),
    "rubber": ((.034, .038, .043), .91, .02),
    "screen": ((.028, .037, .048), .24, .13),
    "recess": ((.044, .049, .056), .76, .25),
    "base": ((.061, .065, .073), .78, .31),
    "label": ((.25, .25, .24), .68, .10),
}
color = np.ones((N, N, 4), dtype=np.float32)
rough = np.ones_like(color)
metal = np.ones_like(color)
slots = {}
for index, (name, (rgb, r, m)) in enumerate(swatches.items()):
    x, y = (index % 4) * 256, (index // 4) * 256
    noise = rng.normal(0, .008, (256, 256))
    broad = rng.normal(0, .014, (16, 16)).repeat(16, 0).repeat(16, 1)
    if name in ("screen", "rubber", "recess"):
        noise *= .35
        broad *= .35
    color[y:y+256, x:x+256, :3] = np.clip(
        np.asarray(rgb)[None, None, :] + noise[:, :, None] + broad[:, :, None], 0, 1)
    rough[y:y+256, x:x+256, :3] = np.clip(r + broad[:, :, None] * .8, 0, 1)
    metal[y:y+256, x:x+256, :3] = m
    slots[name] = (x, y)

def save_image(name, data, noncolor=False):
    img = bpy.data.images.new(name, width=N, height=N, alpha=True)
    if noncolor:
        img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(data.ravel())
    img.filepath_raw = str(OUT / "textures" / (name + ".png"))
    img.file_format = "PNG"
    img.save()
    img.pack()
    return img

mat = bpy.data.materials.new("BlackOrangeCase_Atlas")
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get("Principled BSDF")
for name, image, socket, noncolor in (
    ("BlackOrange_Color", color, "Base Color", False),
    ("BlackOrange_Roughness", rough, "Roughness", True),
    ("BlackOrange_Metalness", metal, "Metallic", True),
):
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = save_image(name, image, noncolor)
    mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs[socket])

parts = []
def finish(obj, name, surface):
    obj.name = name
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    uv = obj.data.uv_layers.active or obj.data.uv_layers.new(name="UVMap")
    x, y = slots[surface]
    corners = ((x+12, y+12), (x+244, y+12), (x+244, y+244), (x+12, y+244))
    for polygon in obj.data.polygons:
        for i, loop in enumerate(polygon.loop_indices):
            px, py = corners[i % 4]
            uv.data[loop].uv = (px/N, py/N)
    parts.append(obj)
    return obj

def box(name, loc, size, surface="shell", bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1)
    obj = bpy.context.object
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("Edge chamfer", "BEVEL")
        mod.width = min(bevel, min(size) / 3)
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod = obj.modifiers.new("Corner normals", "WEIGHTED_NORMAL")
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.location = loc
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return finish(obj, name, surface)

# Main shell and inset lid. All modeled detail remains attached to the body.
box("Lower skid", (0, 0, .18), (7.16, 4.20, .36), "base", .10)
box("Lower silver reveal", (0, 0, .36), (7.07, 4.15, .045), "steel", .014)
box("Cargo body", (0, 0, 1.62), (7.03, 4.05, 2.56), "shell", .20)
box("Waist gasket", (0, 0, 2.95), (7.12, 4.13, .085), "rubber", .02)
box("Orange waist band", (0, 0, 3.01), (7.17, 4.19, .075), "orange", .02)
box("Silver lid seam", (0, 0, 3.07), (7.17, 4.19, .035), "steel", .01)
box("Armored lid", (0, 0, 3.33), (7.23, 4.25, .54), "lid", .20)
box("Lid top well", (0, 0, 3.605), (4.55, 2.55, .028), "recess", .02)
box("Lid top inset", (0, 0, 3.624), (3.86, 1.84, .025), "frame", .015)
for side in (-1, 1):
    box("Lid rail %s" % side, (0, side*1.39, 3.62),
        (5.4, .065, .048), "steel", .016)
    box("Top orange rail %s" % side, (0, side*1.76, 3.59),
        (4.35, .055, .033), "orange", .012)
    box("Long side armor %s" % side, (0, side*2.043, 1.53),
        (6.57, .09, 2.17), "frame", .09)
    box("Long side recess %s" % side, (0, side*2.095, 1.53),
        (4.54, .028, 1.41), "recess", .015)
    box("Long side panel %s" % side, (0, side*2.117, 1.53),
        (3.77, .025, 1.00), "shell", .04)
    for x in (-3.09, 3.09):
        box("Side grip rim %s %s" % (side, x), (x, side*2.104, 1.51),
            (.42, .045, 1.36), "steel", .05)
        box("Side grip void %s %s" % (side, x), (x, side*2.135, 1.51),
            (.29, .025, 1.16), "recess", .035)
    for x in (-2.0, 2.0):
        box("Orange latch %s %s" % (side, x), (x, side*2.12, 2.74),
            (.38, .05, .10), "amber", .018)
    for x in (-3.36, 3.36):
        box("Corner guard %s %s" % (side, x), (x, side*1.96, 1.49),
            (.31, .19, 2.71), "lid", .055)

for end in (-1, 1):
    box("End armor %s" % end, (end*3.535, 0, 1.54),
        (.08, 3.52, 2.32), "frame", .07)
    box("End hatch rim %s" % end, (end*3.59, 0, 1.53),
        (.035, 1.62, 1.74), "orange", .024)
    box("End hatch %s" % end, (end*3.615, 0, 1.53),
        (.035, 1.49, 1.60), "lid", .025)
    box("Latch surround %s" % end, (end*3.647, 0, 1.62),
        (.035, .63, .72), "recess", .02)
    box("Latch bridge %s" % end, (end*3.675, 0, 1.62),
        (.045, .46, .12), "steel", .025)
    box("Latch button %s" % end, (end*3.704, 0, 1.36),
        (.035, .26, .16), "screen", .018)
    for y in (-1.70, 1.70):
        box("End bumper %s %s" % (end, y), (end*3.56, y, 1.42),
            (.18, .27, 2.55), "lid", .06)
    box("End top badge %s" % end, (end*3.57, 0, 3.44),
        (.05, 1.3, .10), "orange", .025)

# Recessed skid vents and small lid fasteners help the case read at game scale.
for side in (-1, 1):
    for x in (-2.4, -1.65, 1.65, 2.4):
        box("Skid vent %s %s" % (side, x), (x, side*2.116, .18),
            (.43, .018, .065), "rubber", .012)
    for x in (-2.78, -1.83, 1.83, 2.78):
        box("Lid bolt %s %s" % (side, x), (x, side*1.63, 3.622),
            (.10, .10, .025), "steel", .012)

bpy.ops.object.select_all(action="DESELECT")
for obj in parts:
    obj.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
export = bpy.context.object
export.name = "BlackOrangeCargoCase"
export["Role"] = "Decoration candidate; visual approval pending"
export["Anchored"] = True
export.data.calc_loop_triangles()
count = len(export.data.loop_triangles)
assert 0 < count < 10000, count
assert min(v.co.z for v in export.data.vertices) >= -.0001
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "source/BlackOrangeCase.blend"))
bpy.ops.export_scene.gltf(
    filepath=str(OUT / "exports/BlackOrangeCase.glb"),
    export_format="GLB", use_selection=True, export_yup=True,
    export_apply=True, export_extras=True, export_materials="EXPORT",
    export_image_format="AUTO")
print("BLACK ORANGE CASE:", count, "triangles", flush=True)
