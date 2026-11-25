"""Clean glossy rebuild of the supplied black sci-fi cargo box.

Blender X/Y are the footprint, Z is up, and one Blender unit is one stud.
The dense TRELLIS mesh is a visual reference, not production geometry.
"""
from pathlib import Path
import math
import random
import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/black-box"
N = 1024
rng = np.random.default_rng(83)
random.seed(83)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
for sub in ("source", "exports", "textures", "review", "trials"):
    (OUT/sub).mkdir(parents=True, exist_ok=True)

# Color, perceptual roughness and metallic value. The shell is dark graphite,
# rather than absolute black, so specular reflections stay visible.
swatches = {
    "shell": ((.108, .116, .125), .18, .82),
    "face": ((.072, .078, .087), .23, .68),
    "frame": ((.055, .062, .073), .19, .81),
    "recess": ((.021, .025, .031), .48, .25),
    "chrome": ((.78, .82, .86), .105, .96),
    "silver": ((.49, .54, .58), .16, .90),
    "white": ((.89, .94, .96), .19, .58),
    "rubber": ((.025, .029, .035), .82, .03),
    "latch": ((.18, .20, .22), .25, .78),
    "interior": ((.039, .045, .053), .39, .45),
}
color = np.ones((N, N, 4), dtype=np.float32)
rough = np.ones_like(color)
metal = np.ones_like(color)
slots = {}
for i, (name, (rgb, r, m)) in enumerate(swatches.items()):
    x, y = (i % 4) * 256, (i // 4) * 256
    fine = rng.normal(0, .002, (256, 256))
    broad = rng.normal(0, .004, (16, 16)).repeat(16, 0).repeat(16, 1)
    color[y:y+256, x:x+256, :3] = np.clip(
        np.asarray(rgb)[None, None, :] + (fine+broad)[:, :, None], 0, 1)
    rough[y:y+256, x:x+256, :3] = np.clip(r+broad[:, :, None]*.7, 0, 1)
    metal[y:y+256, x:x+256, :3] = m
    slots[name] = (x, y)

def image(name, data, noncolor=False):
    img = bpy.data.images.new(name, width=N, height=N, alpha=True)
    if noncolor:
        img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(data.ravel())
    img.filepath_raw = str(OUT / "textures" / (name + ".png"))
    img.file_format = "PNG"
    img.save()
    img.pack()
    return img

mat = bpy.data.materials.new("BlackBox_Glossy_Atlas")
mat.use_nodes = True
p = mat.node_tree.nodes.get("Principled BSDF")
for name, data, socket, noncolor in (
    ("BlackBox_Color", color, "Base Color", False),
    ("BlackBox_Roughness", rough, "Roughness", True),
    ("BlackBox_Metalness", metal, "Metallic", True),
):
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = image(name, data, noncolor)
    mat.node_tree.links.new(tex.outputs["Color"], p.inputs[socket])

parts = []
def finish(ob, name, surface):
    ob.name = name
    ob.data.materials.clear()
    ob.data.materials.append(mat)
    uv = ob.data.uv_layers.active or ob.data.uv_layers.new(name="UVMap")
    x, y = slots[surface]
    corners = ((x+12,y+12),(x+244,y+12),(x+244,y+244),(x+12,y+244))
    for poly in ob.data.polygons:
        for j, loop in enumerate(poly.loop_indices):
            px, py = corners[j % 4]
            uv.data[loop].uv = (px/N, py/N)
    parts.append(ob)
    return ob

def box(name, loc, size, surface="shell", bevel=0, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1)
    ob = bpy.context.object
    ob.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = ob.modifiers.new("Controlled bevel", "BEVEL")
        mod.width = min(bevel, min(size)/3)
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod = ob.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
        bpy.ops.object.modifier_apply(modifier=mod.name)
    ob.location = loc
    if rotation:
        ob.rotation_euler = rotation
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return finish(ob, name, surface)

box("Structural shell", (0,0,2.17), (4.22,4.22,3.85), "shell", .20)
box("Base bumper", (0,0,.20), (4.38,4.38,.40), "rubber", .12)
box("Base bright reveal", (0,0,.42), (4.31,4.31,.055), "silver", .017)
box("Roof armor", (0,0,4.17), (4.40,4.40,.44), "frame", .17)
box("Roof steel seam", (0,0,3.91), (4.29,4.29,.046), "chrome", .015)
box("Roof recess", (0,0,4.402), (2.80,2.80,.018), "recess", .012)
box("Roof center plate", (0,0,4.418), (2.16,2.16,.014), "face", .012)
for sign in (-1,1):
    box("Roof long rail X %s" % sign, (0,sign*1.52,4.42),
        (3.25,.075,.055), "chrome", .018)
    box("Roof long rail Y %s" % sign, (sign*1.52,0,4.42),
        (.075,3.25,.055), "chrome", .018)
    box("Roof recess strip X %s" % sign, (0,sign*1.11,4.43),
        (1.4,.052,.020), "silver", .01)

# +Y and -Y: split cargo doors with a center seam and bright perimeter.
for side in (-1,1):
    y = side*2.125
    box("Door perimeter %s" % side, (0,y,2.16),
        (3.74,.055,3.38), "chrome", .065)
    box("Door recess %s" % side, (0,side*2.160,2.16),
        (3.57,.045,3.20), "recess", .048)
    for leaf in (-1,1):
        x = leaf*.865
        box("Door leaf %s %s" % (side,leaf),
            (x,side*2.194,2.16), (1.67,.052,3.03), "face", .048)
        box("Leaf center relief %s %s" % (side,leaf),
            (x,side*2.226,2.16), (.84,.023,2.28), "shell", .020)
        for z in (.80,3.53):
            box("Door corner reflector %s %s %s" % (side,leaf,z),
                (leaf*1.37,side*2.247,z), (.37,.035,.075),
                "white", .013, (0,math.radians(52*leaf),0))
    box("Door seam %s" % side, (0,side*2.235,2.16),
        (.038,.035,3.0), "rubber", .010)
    for x in (-1.83,1.83):
        box("Door side rail %s %s" % (side,x),
            (x,side*2.206,2.16), (.095,.060,3.05), "silver", .02)
    box("Upper grab %s" % side, (0,side*2.241,3.57),
        (1.0,.06,.14), "latch", .035)
    box("Lower grab %s" % side, (0,side*2.241,.74),
        (1.0,.06,.13), "latch", .035)

# +/- X: equipment service door and central lock, like the second face in the
# image. Silver trim and white corner markers make the glossy black readable.
for side in (-1,1):
    x = side*2.126
    box("Service perimeter %s" % side, (x,0,2.16),
        (.055,3.73,3.38), "chrome", .06)
    box("Service recess %s" % side, (side*2.161,0,2.16),
        (.045,3.57,3.20), "recess", .045)
    box("Service door %s" % side, (side*2.197,0,2.16),
        (.055,3.41,3.03), "face", .045)
    box("Service central panel %s" % side, (side*2.232,0,2.16),
        (.022,1.00,2.25), "shell", .025)
    box("Lock cavity %s" % side, (side*2.251,0,2.12),
        (.022,.74,.71), "recess", .018)
    box("Lock body %s" % side, (side*2.273,0,2.12),
        (.038,.48,.49), "latch", .023)
    box("Lock chrome bridge %s" % side, (side*2.30,0,1.99),
        (.030,.38,.09), "chrome", .016)
    for y in (-1.44,1.44):
        for z in (.79,3.52):
            box("Service reflector %s %s %s" % (side,y,z),
                (side*2.237,y,z), (.035,.36,.074), "white", .012,
                (math.radians(-52 if y>0 else 52),0,0))
    for z in (.62,3.70):
        box("Service horizontal vent %s %s" % (side,z),
            (side*2.238,0,z), (.030,1.05,.10), "recess", .015)

# Main corner guards are larger than the source scan's noisy triangles; their
# controlled bevels carry the shiny highlights without fragmenting the shape.
for sx in (-1,1):
    for sy in (-1,1):
        box("Corner armor %s %s" % (sx,sy),
            (sx*2.02,sy*2.02,2.17), (.35,.35,3.89), "frame", .09)
        box("Corner vertical steel %s %s" % (sx,sy),
            (sx*2.211,sy*2.211,2.18), (.045,.045,2.66), "chrome", .012)
        for z in (.57,3.85):
            box("Corner bolt %s %s %s" % (sx,sy,z),
                (sx*2.21,sy*2.21,z), (.10,.10,.09), "silver", .018)

bpy.ops.object.select_all(action="DESELECT")
for part in parts:
    part.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
ob = bpy.context.object
ob.name = "GlossyBlackCargoBox"
ob["Role"] = "Decoration candidate; appearance pending visual approval"
ob["Anchored"] = True
ob.data.calc_loop_triangles()
count = len(ob.data.loop_triangles)
assert 0 < count < 10000, count
assert min(v.co.z for v in ob.data.vertices) >= -.0001
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "source/GlossyBlackBox.blend"))
bpy.ops.export_scene.gltf(filepath=str(OUT / "exports/GlossyBlackBox.glb"),
    export_format="GLB", use_selection=True, export_yup=True,
    export_apply=True, export_extras=True, export_materials="EXPORT",
    export_image_format="AUTO")
print("GLOSSY BLACK BOX:", count, "triangles", flush=True)
