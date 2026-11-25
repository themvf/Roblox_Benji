"""Author a clean simple sci-fi desk from reference-0.png.

The TRELLIS source and 27k-triangle reduction are retained as references, but
the reduction fractures the tabletop and four-screen display surround.
Blender: X across, -Y front, Z up. glTF export: +Y up, +Z front.
"""
from pathlib import Path
import math

import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/simple-sci-fi-desk"
N = 1024

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
for folder in ("source", "textures", "exports", "review"):
    (OUT / folder).mkdir(parents=True, exist_ok=True)

# An atlas keeps the whole prop on one material. Swatches occupy the bottom
# strip; broad screens are actual inset meshes, not accidental TRELLIS noise.
swatches = {
    "shell": ((0.79, 0.84, 0.89), 0.42, 0.08),
    "light": ((0.89, 0.92, 0.95), 0.36, 0.04),
    "shadow": ((0.48, 0.55, 0.61), 0.55, 0.15),
    "seam": ((0.18, 0.24, 0.29), 0.7, 0.05),
    "screen": ((0.018, 0.030, 0.038), 0.12, 0.0),
    "display": ((0.14, 0.29, 0.38), 0.22, 0.0),
    "glow": ((0.38, 0.65, 0.73), 0.24, 0.0),
    "amber": ((0.93, 0.43, 0.11), 0.32, 0.0),
}
color = np.ones((N, N, 4), dtype=np.float32)
rough = np.ones((N, N, 4), dtype=np.float32)
metal = np.ones((N, N, 4), dtype=np.float32)
color[:, :, :3] = (0.79, 0.84, 0.89)
rough[:, :, :3] = 0.45
metal[:, :, :3] = 0.05
uv_slot = {}
for index, (name, (rgb, r, m)) in enumerate(swatches.items()):
    start = index * 128
    color[:128, start:start + 128, :3] = rgb
    rough[:128, start:start + 128, :3] = r
    metal[:128, start:start + 128, :3] = m
    uv_slot[name] = ((start + 64) / N, 64 / N)


def save_image(name, pixels, noncolor=False):
    image = bpy.data.images.new(name, width=N, height=N, alpha=True)
    if noncolor:
        image.colorspace_settings.name = "Non-Color"
    image.pixels.foreach_set(pixels.ravel())
    image.filepath_raw = str(OUT / "textures" / (name + ".png"))
    image.file_format = "PNG"
    image.save()
    return image


material = bpy.data.materials.new("SimpleDesk_Atlas")
material.use_nodes = True
bsdf = material.node_tree.nodes.get("Principled BSDF")
for name, pixels, socket, noncolor in (
    ("Desk_Color", color, "Base Color", False),
    ("Desk_Roughness", rough, "Roughness", True),
    ("Desk_Metalness", metal, "Metallic", True),
):
    node = material.node_tree.nodes.new("ShaderNodeTexImage")
    node.image = save_image(name, pixels, noncolor)
    material.node_tree.links.new(node.outputs["Color"], bsdf.inputs[socket])

source_collection = bpy.data.collections.new("SOURCE")
bpy.context.scene.collection.children.link(source_collection)
parts = []


def finish(obj, name, surface):
    obj.name = name
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    source_collection.objects.link(obj)
    obj.data.materials.clear()
    obj.data.materials.append(material)
    uv = obj.data.uv_layers.active or obj.data.uv_layers.new(name="UVMap")
    for loop in uv.data:
        loop.uv = uv_slot[surface]
    parts.append(obj)
    return obj


def box(name, center, dimensions, surface="shell", bevel=0.02, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1)
    obj = bpy.context.object
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("SoftEdges", "BEVEL")
        mod.width = min(bevel, min(dimensions) / 3)
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
        normal = obj.modifiers.new("WeightedNormals", "WEIGHTED_NORMAL")
        bpy.ops.object.modifier_apply(modifier=normal.name)
    obj.location = center
    if rotation:
        obj.rotation_euler = rotation
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return finish(obj, name, surface)


def wedge(name, x_center, x_width, profile, surface):
    """Extrude a Y/Z side outline along X."""
    left, right = x_center - x_width / 2, x_center + x_width / 2
    vertices = [(left, y, z) for y, z in profile] + [(right, y, z) for y, z in profile]
    count = len(profile)
    faces = [tuple(reversed(tuple(range(count)))), tuple(range(count, count * 2))]
    for i in range(count):
        j = (i + 1) % count
        faces.append((i, j, count + j, count + i))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return finish(obj, name, surface)


# Two separated pedestal legs keep the open underside seen in reference-0.
for side, xpos in (("L", -3.60), ("R", 3.60)):
    box(side + "_FootBase", (xpos, 0, 0.18), (1.32, 4.10, 0.36), "shadow", 0.09)
    box(side + "_FootCap", (xpos, 0, 0.29), (1.22, 3.98, 0.19), "light", 0.05)
    wedge(side + "_Pedestal", xpos, 1.16,
          [(-1.45, 0.35), (1.58, 0.35), (1.72, 3.02),
           (0.72, 3.28), (-0.44, 3.13), (-1.30, 1.50)], "shell")
    wedge(side + "_AngledFront", xpos, 0.34,
          [(-1.55, 0.42), (-1.17, 0.42), (-0.34, 3.12), (-0.66, 3.12)], "light")
    outer = xpos + (0.60 if side == "R" else -0.60)
    box(side + "_SideInset", (outer, 0.40, 1.71),
        (0.035, 1.85, 1.57), "shadow", 0.015)
    box(side + "_SidePanel", (outer + (0.027 if side == "R" else -0.027), 0.40, 1.73),
        (0.028, 1.65, 1.38), "light", 0.014)
    for row, height in enumerate((0.57, 0.72, 0.87)):
        box(side + "_FrontVent_" + str(row), (xpos, -1.53, height),
            (0.72, 0.025, 0.038), "seam", 0)

# A broad but thin worktop with rounded perimeter and visible inset panels.
box("TableStructure", (0, -0.05, 3.20), (9.20, 4.50, 0.40), "shell", 0.14)
box("TopSurface", (0, -0.06, 3.42), (8.94, 4.24, 0.10), "light", 0.055)
box("FrontBezel", (0, -2.33, 3.12), (8.66, 0.06, 0.10), "shadow", 0.015)
box("AmberFrontLine", (0, -2.38, 3.13), (8.35, 0.018, 0.025), "amber", 0)
for index, x in enumerate((-2.42, 0, 2.42)):
    box("TopInsetFrame_" + str(index), (x, -0.96, 3.49),
        (2.07, 1.57, 0.018), "shadow", 0.009)
    box("TopInsetPanel_" + str(index), (x, -0.96, 3.505),
        (1.91, 1.40, 0.017), "shell", 0.006)
    box("TopInsetAccent_" + str(index), (x, -1.55, 3.522),
        (0.48, 0.027, 0.01), "light", 0)

# The rear display bank is the distinctive feature of this variant: four small
# dark monitors under a continuous roof, not the large single black monitor of
# the other desk package.
wedge("RearConsoleCore", 0, 8.10,
      [(0.47, 3.46), (2.02, 3.46), (2.02, 5.30),
       (1.44, 5.30), (0.91, 4.24)], "shell")
box("DisplayBacking", (0, 1.205, 4.73), (6.50, 0.29, 1.17),
    "shadow", 0.055, (math.radians(-8), 0, 0))
for index, x in enumerate((-2.37, -0.79, 0.79, 2.37)):
    box("MonitorFrame_" + str(index), (x, 1.042, 4.75),
        (1.53, 0.09, 0.92), "seam", 0.035,
        (math.radians(-8), 0, 0))
    box("MonitorGlass_" + str(index), (x, 0.984, 4.75),
        (1.38, 0.02, 0.77), "screen", 0.007,
        (math.radians(-8), 0, 0))
    box("MonitorReadout_" + str(index), (x - 0.30, 0.966, 4.53),
        (0.43, 0.012, 0.02), "display", 0)
box("DisplayRoof", (0, 1.55, 5.33), (8.85, 0.82, 0.19), "light", 0.055)
box("DisplayRoofShadow", (0, 1.10, 5.21), (7.80, 0.05, 0.05), "shadow", 0.015)
for side, x in (("L", -4.06), ("R", 4.06)):
    box(side + "_DisplayTower", (x, 1.49, 4.56),
        (0.75, 1.03, 1.66), "light", 0.085)
    box(side + "_TowerInset", (x, 0.955, 4.69),
        (0.44, 0.03, 0.79), "shadow", 0.014)
    for height in (4.58, 4.69, 4.80):
        box(side + "_TowerKey", (x, 0.925, height),
            (0.22, 0.015, 0.035), "display", 0)

# Sloped lower console, panel doors and a few small interface marks.
box("LowerControlPlate", (0, 0.37, 3.91), (7.45, 1.06, 0.13),
    "light", 0.04, (math.radians(29), 0, 0))
for index, x in enumerate((-2.32, 0, 2.32)):
    box("LowerPanel_" + str(index), (x, 0.28, 3.99),
        (1.75, 0.67, 0.025), "shell", 0.012,
        (math.radians(29), 0, 0))
    box("LowerSlot_" + str(index), (x, 0.055, 3.90),
        (0.95, 0.018, 0.018), "shadow", 0)
for x in (-3.13, 3.13):
    box("ControlAmber", (x, -0.04, 3.91), (0.08, 0.018, 0.06), "amber", 0)

# Named editable pieces live in SOURCE; only the joined mesh is exported.
source_collection.hide_render = True
export_collection = bpy.data.collections.new("EXPORT")
bpy.context.scene.collection.children.link(export_collection)
copies = []
for obj in parts:
    duplicate = obj.copy()
    duplicate.data = obj.data.copy()
    export_collection.objects.link(duplicate)
    copies.append(duplicate)
bpy.ops.object.select_all(action="DESELECT")
for obj in copies:
    obj.select_set(True)
bpy.context.view_layer.objects.active = copies[0]
bpy.ops.object.join()
final = bpy.context.object
final.name = "SimpleSciFiDesk"
assert len(final.data.polygons) < 10000, len(final.data.polygons)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "source/SimpleSciFiDesk.blend"))
bpy.ops.object.select_all(action="DESELECT")
final.select_set(True)
bpy.context.view_layer.objects.active = final
bpy.ops.export_scene.gltf(
    filepath=str(OUT / "exports/SimpleSciFiDesk.glb"),
    export_format="GLB", export_image_format="AUTO",
    use_selection=True, export_apply=True,
)
print("source polygons", len(final.data.polygons))
print("wrote", OUT / "exports/SimpleSciFiDesk.glb")
