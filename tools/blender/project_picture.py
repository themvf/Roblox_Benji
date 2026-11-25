"""Paint the T-pose picture back onto the front of a TRELLIS model, before prepare_avatar_setup.py bakes it.

    blender -b -noaudio --python tools/blender/project_picture.py -- <model.glb> <picture.png> <out.glb>
        [--front -y] [--texture 2048] [--report <report.json>]

Why: TRELLIS rebuilds the shape well but repaints it. DarkArmourAuto's picture has galaxy panels,
cyan edge lines and a chest swirl; TRELLIS's own texture has none of them, so no bake setting after it
could bring them back (assets/kit-looks/trials/DarkArmourAuto/skinned/detail-loss/compare.png).

How: the picture is a straight-on view of the same character, so an orthographic projection along the
front axis, fitted to the silhouette's bounding box, lands each picture pixel on the surface it shows.
A corner takes the picture's colour by how squarely it faces the camera (fully past FACE_FULL, not at
all below FACE_NONE) and only if nothing of the model sits in front of it; the sides and back keep
TRELLIS's paint. The blend is baked into a new texture on the model's own UVs and written as a GLB
that prepare_avatar_setup.py takes as its `source`.

The report gives the fit (picture box, model box) and the share of the surface that took picture paint.
"""
import json
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

FACE_NONE, FACE_FULL = 0.25, 0.65

argv = sys.argv[sys.argv.index("--") + 1:]
model, picture, out = (str(Path(a).resolve()) for a in argv[:3])
out = Path(out)
opts = dict(zip(argv[3::2], argv[4::2]))
front_axis = opts.get("--front", "-y")
tex_size = int(opts.get("--texture", 2048))
sign = -1.0 if front_axis.startswith("-") else 1.0
FRONT = Vector((0, sign, 0)) if front_axis.endswith("y") else Vector((sign, 0, 0))
if not front_axis.endswith("y"):
    raise SystemExit("only a front along y is supported")

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=model)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
for o in list(bpy.data.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o)
if len(meshes) != 1:
    raise SystemExit(f"expected one mesh, found {len(meshes)}")
obj = meshes[0]
obj.data.transform(obj.matrix_world)
obj.matrix_world.identity()
me = obj.data

# ---------------------------------------------------------------- the picture's silhouette box
img = bpy.data.images.load(picture)
w, h = img.size
px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]  # row 0 = top
rgb = px[:, :, :3]
corner = np.concatenate([rgb[:8, :8].reshape(-1, 3), rgb[:8, -8:].reshape(-1, 3)]).mean(0)
fg = np.abs(rgb - corner).max(2) > 0.08
rows, cols = np.where(fg)
v0, v1, u0, u1 = rows.min(), rows.max(), cols.min(), cols.max()
# The background must never land on the model: at the silhouette the projection grazes side-facing
# surface, which picked up white streaks on DarkArmourAuto's shoulders and thighs. The picture gets an
# alpha of its silhouette shrunk by ERODE pixels, and the blend is multiplied by it.
ERODE = max(2, w // 200)
inside = fg.copy()
for _ in range(ERODE):
    inside[1:, :] &= inside[:-1, :].copy()
    inside[:-1, :] &= inside[1:, :].copy()
    inside[:, 1:] &= inside[:, :-1].copy()
    inside[:, :-1] &= inside[:, 1:].copy()
px[:, :, 3] = inside.astype(np.float32)


def box_blur(a, r):
    """Mean over a (2r+1)^2 window, edges clamped."""
    p = np.pad(a, r, mode="edge")
    c = np.cumsum(np.cumsum(p, 0), 1)
    c = np.pad(c, ((1, 0), (1, 0)))
    k = 2 * r + 1
    return (c[k:, k:] - c[:-k, k:] - c[k:, :-k] + c[:-k, :-k]) / (k * k)


# The picture is lit: black armour carries grey-white gloss. Painted on as colour it read as white
# speckle at 1024 px and drew a dark outline where it met TRELLIS's flat black on the sides. Grey,
# bright texels are pulled down towards GLOSS_FLOOR unless they sit in colour (skin, purple glow round
# the eyes, cyan lines), judged by the saturation of their neighbourhood.
GLOSS_FLOOR, GLOSS_KEEP = 0.16, 0.2
hi_c, lo_c = rgb.max(2), rgb.min(2)
# Colourfulness as max minus min channel, not saturation: near-black armour with a faint purple tint
# has a high saturation ratio, which hid the gloss on it from the first version of this test.
chroma = hi_c - lo_c
coloured = box_blur(chroma, max(4, w // 64)) > 0.12  # wide enough to keep the eyes' white-hot centres
gloss = inside & ~coloured & (chroma < 0.1) & (hi_c > GLOSS_FLOOR)
scale_down = (GLOSS_FLOOR + (hi_c - GLOSS_FLOOR) * GLOSS_KEEP) / np.maximum(hi_c, 1e-4)
rgb[gloss] *= scale_down[gloss][:, None]
px[:, :, :3] = rgb
gloss_share = float(gloss.sum() / max(inside.sum(), 1))
img.pixels[:] = px[::-1].ravel()
img.alpha_mode = "STRAIGHT"
toned = bpy.data.images.new("PictureToned", w, h, alpha=True)  # kept beside the report for review
toned.pixels.foreach_set(np.ascontiguousarray(px[::-1]).ravel())
toned.update()
toned.filepath_raw = str(out.with_name(out.stem + "-picture.png"))
toned.file_format = "PNG"
toned.save()
# Cycles bakes from the file on disk, not from pixels edited in memory: project the saved, toned copy.
img = bpy.data.images.load(toned.filepath_raw, check_existing=False)
img.alpha_mode = "STRAIGHT"

# ---------------------------------------------------------------- the model's front box
co = np.array([v.co[:] for v in me.vertices])
x0, x1 = co[:, 0].min(), co[:, 0].max()
z0, z1 = co[:, 2].min(), co[:, 2].max()
# Looking along -FRONT, screen right is +x when the front is -y and -x when it is +y.
right = 1.0 if sign < 0 else -1.0


def to_picture_uv(p):
    """Model point -> picture UV (0..1, v up), through the fitted boxes."""
    sx = (p[0] - x0) / (x1 - x0)
    if right < 0:
        sx = 1 - sx
    sz = (p[2] - z0) / (z1 - z0)
    u = (u0 + sx * (u1 - u0)) / w
    v = 1 - (v0 + (1 - sz) * (v1 - v0)) / h
    return u, v


# ---------------------------------------------------------------- per-vertex weight: facing and visible
bvh = BVHTree.FromObject(obj, bpy.context.evaluated_depsgraph_get())
depth = (co[:, 1].max() - co[:, 1].min()) * 4 + 1
eps = 1e-4 * (z1 - z0)
weight = np.zeros(len(me.vertices), dtype=np.float32)
for v in me.vertices:
    facing = v.normal.dot(FRONT)
    if facing <= FACE_NONE:
        continue
    start = v.co + FRONT * eps
    hit = bvh.ray_cast(start, FRONT, depth)
    if hit[0] is not None:  # something of the model is in front of this point
        continue
    t = (facing - FACE_NONE) / (FACE_FULL - FACE_NONE)
    weight[v.index] = min(1.0, t) ** 1.5

attr = me.color_attributes.new("projWeight", "FLOAT_COLOR", "POINT")
for i, wv in enumerate(weight):
    attr.data[i].color = (wv, wv, wv, 1.0)
proj = me.uv_layers.new(name="pictureUV")
src_uv = me.uv_layers[0].name
for loop in me.loops:
    proj.data[loop.index].uv = to_picture_uv(me.vertices[loop.vertex_index].co)
me.uv_layers.active = me.uv_layers[src_uv]

# ---------------------------------------------------------------- blend and bake onto the model's own UVs
mat = me.materials[0]
tree = mat.node_tree
old = next(n for n in tree.nodes if n.type == "TEX_IMAGE" and n.image)
own_uv = tree.nodes.new("ShaderNodeUVMap")
own_uv.uv_map = src_uv
tree.links.new(own_uv.outputs["UV"], old.inputs["Vector"])
pic_uv = tree.nodes.new("ShaderNodeUVMap")
pic_uv.uv_map = "pictureUV"
pic = tree.nodes.new("ShaderNodeTexImage")
pic.image = img
pic.extension = "EXTEND"
tree.links.new(pic_uv.outputs["UV"], pic.inputs["Vector"])
wnode = tree.nodes.new("ShaderNodeAttribute")
wnode.attribute_name = "projWeight"
gate = tree.nodes.new("ShaderNodeMath")
gate.operation = "MULTIPLY"
tree.links.new(wnode.outputs["Fac"], gate.inputs[0])
tree.links.new(pic.outputs["Alpha"], gate.inputs[1])
mix = tree.nodes.new("ShaderNodeMix")
mix.data_type = "RGBA"
tree.links.new(gate.outputs["Value"], mix.inputs["Factor"])
tree.links.new(old.outputs["Color"], mix.inputs[6])
tree.links.new(pic.outputs["Color"], mix.inputs[7])
emit = tree.nodes.new("ShaderNodeEmission")
tree.links.new(mix.outputs[2], emit.inputs["Color"])
sink = next(n for n in tree.nodes if n.type == "OUTPUT_MATERIAL")
tree.links.new(emit.outputs["Emission"], sink.inputs["Surface"])

baked = bpy.data.images.new("Projected", tex_size, tex_size, alpha=False)
target = tree.nodes.new("ShaderNodeTexImage")
target.image = baked
tree.links.new(own_uv.outputs["UV"], target.inputs["Vector"])
tree.nodes.active = target
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 4
scene.render.bake.margin = 8
for o in bpy.data.objects:
    o.select_set(o is obj)
bpy.context.view_layer.objects.active = obj
bpy.ops.object.bake(type="EMIT", use_clear=True)

# ---------------------------------------------------------------- swap the paint and write the GLB
for n in list(tree.nodes):
    if n not in (target, own_uv, sink):
        tree.nodes.remove(n)
bsdf = tree.nodes.new("ShaderNodeBsdfPrincipled")
tree.links.new(target.outputs["Color"], bsdf.inputs["Base Color"])
tree.links.new(bsdf.outputs["BSDF"], sink.inputs["Surface"])
baked.filepath_raw = str(out.with_name(out.stem + "-color.png"))
baked.file_format = "PNG"
baked.save()
baked.pack()
me.uv_layers.remove(me.uv_layers["pictureUV"])
me.color_attributes.remove(me.color_attributes["projWeight"])
bpy.ops.export_scene.gltf(filepath=str(out), export_format="GLB", use_selection=True)

area = np.array([p.area for p in me.polygons])
poly_w = np.array([weight[list(p.vertices)].mean() for p in me.polygons])
report = {
    "picture": picture,
    "pictureBox": [int(u0), int(v0), int(u1), int(v1)],
    "modelBox": [round(float(x0), 4), round(float(z0), 4), round(float(x1), 4), round(float(z1), 4)],
    "front": front_axis,
    "paintedShare": round(float((area * poly_w).sum() / area.sum()), 3),
    "glossToned": round(gloss_share, 3),
    "texture": tex_size,
}
if "--report" in opts:
    Path(opts["--report"]).write_text(json.dumps(report, indent=1))
print("PROJECT", json.dumps(report))
