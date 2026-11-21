"""Author a clean sci-fi command desk from reference-2.png.

The TRELLIS source and a 25k-triangle reduction are retained as references in
the package, but the reduction fractures broad panels and screen edges.
Blender: X across, -Y front, Z up. glTF export: +Y up, +Z front.
"""
from pathlib import Path
import math

import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/snow-forest-sci-fi-desk"
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


material = bpy.data.materials.new("CommandDesk_Atlas")
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


# Wide ground shoes and armored side legs; the center cabinet leaves leg room
# visually, while collision is handled later in Studio.
for side, xpos in (("L", -3.12), ("R", 3.12)):
    box(side + "_Foot", (xpos, -0.05, 0.18), (1.45, 3.95, 0.36), "shadow", 0.10)
    box(side + "_FootCap", (xpos, -0.05, 0.29), (1.36, 3.78, 0.20), "light", 0.06)
    wedge(side + "_Housing", xpos, 1.32,
          [(-1.65, 0.34), (1.66, 0.34), (1.65, 2.75),
           (0.90, 2.98), (-0.95, 2.92), (-1.72, 1.55)], "shell")
    wedge(side + "_FrontBrace", xpos, 0.34,
          [(-1.78, 0.35), (-1.36, 0.35), (-0.96, 2.91), (-1.30, 2.91)], "light")
    box(side + "_Inset", (xpos + (0.67 if side == "R" else -0.67), 0.15, 1.48),
        (0.045, 1.95, 1.65), "shadow", 0.025)
    box(side + "_Panel", (xpos + (0.70 if side == "R" else -0.70), 0.18, 1.52),
        (0.035, 1.70, 1.40), "light", 0.015)
    for height in (0.50, 0.65, 0.80):
        box(side + "_Vent_" + str(height), (xpos, -1.76, height),
            (0.82, 0.025, 0.035), "seam", 0)

box("CenterCabinet", (0, 1.0, 1.30), (4.65, 1.25, 2.45), "shadow", 0.06)
box("CenterFront", (0, 0.345, 1.30), (4.48, 0.10, 2.23), "shell", 0.025)
for x in (-1.33, 0, 1.33):
    box("CabinetDoor", (x, 0.275, 1.35), (1.18, 0.035, 1.88), "light", 0.025)
    box("DoorSeam", (x, 0.245, 0.45), (0.85, 0.018, 0.026), "seam", 0)

# Cantilevered desktop and its readable front edge.
box("TableCore", (0, -0.10, 3.00), (8.10, 4.30, 0.39), "shell", 0.13)
box("TableTop", (0, -0.10, 3.22), (7.83, 4.04, 0.12), "light", 0.055)
box("FrontTrim", (0, -2.29, 2.93), (7.65, 0.055, 0.075), "shadow", 0.01)
for x in (-2.55, 2.55):
    box("FrontAmber", (x, -2.324, 2.87), (0.16, 0.02, 0.045), "amber", 0)

# Sloping back console, broad enough to frame the central touch display.
wedge("ConsoleBody", 0, 7.70,
      [(-0.25, 3.23), (2.04, 3.23), (2.04, 4.02), (1.20, 4.08)], "shell")
for x in (-3.25, 3.25):
    box("SideControlBank", (x, 0.50, 3.72), (1.18, 1.20, 0.09),
        "light", 0.035, (math.radians(30), 0, 0))
    for offset in (-0.30, 0, 0.30):
        box("SideKey", (x + offset, 0.43, 3.79), (0.20, 0.20, 0.035),
            "shadow", 0.012, (math.radians(30), 0, 0))

box("CenterDisplayBezel", (0, 0.50, 3.72), (2.62, 1.20, 0.10),
    "seam", 0.035, (math.radians(30), 0, 0))
box("CenterBlueDisplay", (0, 0.47, 3.78), (2.42, 1.02, 0.025),
    "display", 0.006, (math.radians(30), 0, 0))
for x in (-1.0, -0.48, 0.15, 0.72):
    box("DisplayReadout", (x, 0.25, 3.68), (0.32, 0.012, 0.018),
        "glow", 0, (math.radians(30), 0, 0))

# Left tablet, keyboard, right control puck, and small raised angled display.
box("LeftTabletBezel", (-2.85, -1.05, 3.33), (1.42, 1.03, 0.075), "seam", 0.025)
box("LeftTablet", (-2.85, -1.05, 3.377), (1.24, 0.84, 0.02), "display", 0.006)
box("KeyboardBase", (0, -1.17, 3.34), (1.95, 0.77, 0.13), "shadow", 0.045)
for row in range(3):
    for column in range(9):
        box("Key_%02d_%02d" % (row, column),
            (-0.78 + column * 0.195, -1.41 + row * 0.205, 3.42),
            (0.135, 0.14, 0.045), "seam", 0.008)
box("ControlBase", (2.75, -1.35, 3.34), (1.03, 0.82, 0.16), "light", 0.035)
box("ControlPuck", (2.75, -1.35, 3.46), (0.34, 0.34, 0.12), "shadow", 0.065)
box("RaisedTabletFrame", (2.15, 0.55, 4.07), (0.85, 0.18, 0.67),
    "shell", 0.06, (math.radians(-18), 0, 0))
box("RaisedTabletScreen", (2.15, 0.43, 4.07), (0.69, 0.025, 0.49),
    "display", 0.01, (math.radians(-18), 0, 0))

# Large upper monitor. Keep its front dark as in the matched reference.
box("MonitorStem", (0, 1.53, 4.29), (2.05, 0.52, 0.63), "shadow", 0.07)
box("MonitorShell", (0, 1.57, 5.22), (3.28, 0.52, 2.48),
    "light", 0.14, (math.radians(-7), 0, 0))
box("MonitorBezel", (0, 1.282, 5.22), (2.89, 0.08, 2.02),
    "seam", 0.045, (math.radians(-7), 0, 0))
box("MonitorGlass", (0, 1.225, 5.22), (2.69, 0.02, 1.82),
    "screen", 0.006, (math.radians(-7), 0, 0))
box("MonitorTopLedge", (0, 1.52, 6.45), (3.42, 0.56, 0.10), "shell", 0.04)
for x in (-1.20, 1.20):
    box("MonitorLatch", (x, 1.22, 6.46), (0.17, 0.18, 0.17), "shadow", 0.015)

# Keep named edit parts, plus a joined delivery mesh with a ground pivot.
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
final.name = "SnowForestSciFiDesk"
assert len(final.data.polygons) < 10000, len(final.data.polygons)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "source/SnowForestSciFiDesk.blend"))
bpy.ops.object.select_all(action="DESELECT")
final.select_set(True)
bpy.context.view_layer.objects.active = final
bpy.ops.export_scene.gltf(
    filepath=str(OUT / "exports/SnowForestSciFiDesk.glb"),
    export_format="GLB", export_image_format="AUTO",
    use_selection=True, export_apply=True,
)
print("triangles", len(final.data.polygons))
print("wrote", OUT / "exports/SnowForestSciFiDesk.glb")
