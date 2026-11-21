"""Author the Penthouse hedge section. Run with Blender --factory-startup -b.

Clean build, not a scan. Image-to-3D turned the reference hedge into thousands of loose
one-sided leaf cards (77,000 triangles, 23% back faces: see-through in game from every
side). A clipped hedge is a box with a lumpy surface, so it is modelled as one: a stone
planter and a leaf mass whose sides and top are pushed in and out by smooth noise.

One section fills a block 8 long x 4 deep x 8 tall. Its two ends are flat and square, so
sections butt together along a wall. Blender axes: X = length, Y = depth, Z = up.
The map places it 31 times, so it is kept under 2,000 triangles with one 512 px texture.
"""
from pathlib import Path
import json

import bmesh
import bpy
import numpy as np
from mathutils import Vector, noise

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/penthouse-hedge"
LENGTH, DEPTH, HEIGHT = 8.0, 4.0, 8.0
PLANTER = 2.0  # planter height
LEAF_DEPTH = 3.7  # the leaf mass sits just inside the planter's faces
bpy.ops.wm.read_factory_settings(use_empty=True)
for sub in ("textures", "exports", "review"):
    (OUT / sub).mkdir(parents=True, exist_ok=True)

# ---- texture: leaves on the left three quarters, limestone on the right ----
N = 512
SPLIT = 384
rng = np.random.default_rng(7)


def blotches(cells, passes):
    """Smooth random field in 0..1: coarse random cells, blurred."""
    field = np.kron(rng.random((cells, cells)), np.ones((N // cells, N // cells)))
    for _ in range(passes):
        field = (field + np.roll(field, 3, 0) + np.roll(field, -3, 0) + np.roll(field, 3, 1) + np.roll(field, -3, 1)) / 5
    return field


color = np.ones((N, N, 4), dtype=np.float32)
shade = 0.55 * blotches(16, 6) + 0.30 * blotches(64, 2) + 0.15 * rng.random((N, N))
dark, light = np.array((0.07, 0.19, 0.07)), np.array((0.27, 0.46, 0.17))
color[:, :, :3] = dark + (light - dark) * shade[:, :, None]
speck = rng.random((N, N)) > 0.965  # single bright leaves catching the light
color[speck, :3] = (0.42, 0.60, 0.26)
stone = 0.76 + 0.06 * blotches(32, 4) + 0.03 * rng.random((N, N))
color[:, SPLIT:, 0] = stone[:, SPLIT:] * 1.00
color[:, SPLIT:, 1] = stone[:, SPLIT:] * 0.97
color[:, SPLIT:, 2] = stone[:, SPLIT:] * 0.90

image = bpy.data.images.new("PenthouseHedge_Color", width=N, height=N, alpha=True)
image.pixels.foreach_set(np.clip(color, 0, 1).ravel())
image.filepath_raw = str(OUT / "textures" / "PenthouseHedge_Color.png")
image.file_format = "PNG"
image.save()

mat = bpy.data.materials.new("PenthouseHedge")
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get("Principled BSDF")
bsdf.inputs["Roughness"].default_value = 0.9
tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
tex.image = image
mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])

# ---- geometry ----
bm = bmesh.new()


def grid(origin, u, v, nu, nv):
    """A nu x nv quad grid spanning origin + s*u + t*v. Returns nothing; shares no verts."""
    rows = [[bm.verts.new(origin + u * (i / nu) + v * (j / nv)) for i in range(nu + 1)] for j in range(nv + 1)]
    for j in range(nv):
        for i in range(nu):
            bm.faces.new((rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]))


hx, hy = LENGTH / 2, LEAF_DEPTH / 2
z0, z1 = PLANTER - 0.1, HEIGHT - 0.2  # the noise can add up to 0.2 on top
NX, NY, NZ = 20, 8, 14
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
grid(Vector((-hx, -hy, z1)), X * LENGTH, Y * LEAF_DEPTH, NX, NY)  # top
grid(Vector((-hx, -hy, z0)), X * LENGTH, Z * (z1 - z0), NX, NZ)  # front
grid(Vector((hx, hy, z0)), -X * LENGTH, Z * (z1 - z0), NX, NZ)  # back
grid(Vector((-hx, hy, z0)), -Y * LEAF_DEPTH, Z * (z1 - z0), NY, NZ)  # left end
grid(Vector((hx, -hy, z0)), Y * LEAF_DEPTH, Z * (z1 - z0), NY, NZ)  # right end
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
bm.normal_update()
leaf_faces = set(bm.faces)
for vert in bm.verts:
    # Push each vertex in or out across the hedge, never along it: the ends stay flat at
    # x = +-4 so two sections meet without a gap. Nothing moves at the planter's lip.
    direction = Vector((0.0, vert.normal.y, vert.normal.z))
    if direction.length < 1e-6 or vert.co.z <= z0 + 1e-4:
        continue
    p = vert.co
    # the pattern repeats every 8 studs along x, so neighbouring sections line up at the joint
    wrapped = Vector((0.0, p.y, p.z))
    bump = 0.0
    for scale, weight in ((0.9, 0.16), (2.1, 0.06)):
        a = noise.noise(Vector((np.cos(p.x * np.pi / 4), np.sin(p.x * np.pi / 4), 0)) * scale + wrapped * scale)
        bump += a * weight
    vert.co = p + direction.normalized() * bump

# planter: a plain box, top open (the leaf mass covers it)
px, py = LENGTH / 2, DEPTH / 2
corners = [Vector((sx * px, sy * py, z)) for z in (0.0, PLANTER) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
pv = [bm.verts.new(c) for c in corners]
planter_faces = [
    bm.faces.new((pv[0], pv[1], pv[5], pv[4])),
    bm.faces.new((pv[1], pv[2], pv[6], pv[5])),
    bm.faces.new((pv[2], pv[3], pv[7], pv[6])),
    bm.faces.new((pv[3], pv[0], pv[4], pv[7])),
    bm.faces.new((pv[4], pv[5], pv[6], pv[7])),
    bm.faces.new((pv[3], pv[2], pv[1], pv[0])),
]
bm.normal_update()

# ---- UVs: project each face along its dominant axis into its region of the texture ----
uv = bm.loops.layers.uv.new("UVMap")
u_leaf, u_stone = (0.01, SPLIT / N - 0.01), (SPLIT / N + 0.01, 0.99)
for face in bm.faces:
    n = face.normal
    axis = max(range(3), key=lambda i: abs(n[i]))
    a, b = [i for i in range(3) if i != axis]
    spans = (LENGTH, DEPTH, HEIGHT)
    lows = (-LENGTH / 2, -DEPTH / 2, 0.0)
    region = u_leaf if face in leaf_faces else u_stone
    for loop in face.loops:
        s = min(max((loop.vert.co[a] - lows[a]) / spans[a], 0.0), 1.0)
        t = min(max((loop.vert.co[b] - lows[b]) / spans[b], 0.0), 1.0)
        loop[uv].uv = (region[0] + (region[1] - region[0]) * s, 0.01 + 0.98 * t)
    face.smooth = face in leaf_faces

bmesh.ops.triangulate(bm, faces=bm.faces)
mesh = bpy.data.meshes.new("PenthouseHedge")
bm.to_mesh(mesh)
bm.free()
mesh.materials.append(mat)
hedge = bpy.data.objects.new("PenthouseHedge", mesh)
bpy.context.scene.collection.objects.link(hedge)
hedge["CanCollide"] = False
hedge["Anchored"] = True
bpy.context.view_layer.update()

triangles = len(mesh.polygons)
dims = [round(d, 3) for d in hedge.dimensions]
assert triangles < 2500, triangles
assert abs(hedge.dimensions.x - LENGTH) < 1e-4, dims
assert hedge.dimensions.y <= DEPTH + 0.01 and hedge.dimensions.z <= HEIGHT + 0.01, dims
bpy.ops.object.select_all(action="DESELECT")
hedge.select_set(True)
bpy.context.view_layer.objects.active = hedge
bpy.ops.export_scene.gltf(
    filepath=str(OUT / "exports" / "PenthouseHedgeClean.glb"),
    export_format="GLB",
    use_selection=True,
    export_yup=True,
    export_apply=True,
    export_extras=True,
    export_materials="EXPORT",
    export_image_format="AUTO",
)
(OUT / "source" / "build-metrics.json").write_text(
    json.dumps(
        {
            "triangles": triangles,
            "blenderDimensions": dims,
            "lengthAxis": "x",
            "materialCount": 1,
            "surfaceDetail": "procedural leaf and limestone texture, 512 px; noise-displaced leaf mass",
            "tileable": "ends flat at x = +-4; surface pattern repeats every 8 studs along x",
        },
        indent=2,
    )
    + "\n"
)
print("HEDGE BUILD:", triangles, "triangles;", dims, "Blender dimensions")
