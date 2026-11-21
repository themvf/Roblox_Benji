"""Build the sci-fi chair from its saved TRELLIS source; Blender 4.3.2.

The 8.6k single-mesh trial visibly broke the back panel. A 26.7k textured
trial preserved the shape, so this keeps that decimation and separates faces
into three <=10k-triangle meshes without moving or cutting any triangles.
"""
from pathlib import Path
import bpy
import bmesh

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/models/sci-fi-chair"
HEIGHT = 5.0  # provisional stud size for visual review
RATIO = 0.09
PART_TRI_LIMIT = 9500

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.import_scene.gltf(filepath=str(OUT / "source/trellis-original.glb"))
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
assert len(meshes) == 1, "Source topology changed; reappraise before building"
source = meshes[0]
bpy.ops.object.select_all(action="DESELECT")
source.select_set(True)
bpy.context.view_layer.objects.active = source
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
assert len(source.data.polygons) == 297023, "Source triangle count changed"

# Keep the original editable mesh in the .blend but exclude it from the export.
source.name = "SOURCE_Trellis_Original"
source.hide_render = True
source.hide_set(True)

for folder in ("source", "exports", "textures", "review"):
    (OUT / folder).mkdir(exist_ok=True)

# The input packs WebP images. Convert the existing mapped images, preserving
# their pixels and UV assignments. The exporter embeds PNG in the final GLB.
for image in list(bpy.data.images):
    if image.source != "FILE":
        continue
    _ = image.pixels[0]  # load glTF's packed WebP before saving a converted file
    lower = image.name.lower()
    label = "Color" if "0" in lower else "MetallicRoughness"
    path = OUT / "textures" / ("Chair_" + label + ".png")
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    converted = bpy.data.images.load(str(path), check_existing=False)
    converted.colorspace_settings.name = image.colorspace_settings.name
    for material in bpy.data.materials:
        if material.use_nodes:
            for node in material.node_tree.nodes:
                if node.type == "TEX_IMAGE" and node.image == image:
                    node.image = converted
    bpy.data.images.remove(image)

body = source.copy()
body.data = source.data.copy()
bpy.context.scene.collection.objects.link(body)
body.name = "WORK_Decimated"
source.hide_set(False)
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
bpy.context.view_layer.objects.active = body
mod = body.modifiers.new("ShapePreservingTrial_0.09", "DECIMATE")
mod.ratio = RATIO
bpy.ops.object.modifier_apply(modifier=mod.name)
assert len(body.data.polygons) < 3 * PART_TRI_LIMIT

lo = [min(v.co[i] for v in body.data.vertices) for i in range(3)]
hi = [max(v.co[i] for v in body.data.vertices) for i in range(3)]
mid_x = (lo[0] + hi[0]) / 2
mid_y = (lo[1] + hi[1]) / 2
scale = HEIGHT / (hi[2] - lo[2])
for v in body.data.vertices:
    v.co.x = (v.co.x - mid_x) * scale
    v.co.y = (v.co.y - mid_y) * scale
    v.co.z = (v.co.z - lo[2]) * scale
body.data.update()

# Sort triangles by height, then allocate balanced, spatially coherent groups.
# Deleting nonmember faces from copies leaves all retained vertex positions and
# UVs untouched. It does not introduce geometric cuts through triangles.
faces = list(body.data.polygons)
ordered = sorted(faces, key=lambda f: sum(body.data.vertices[i].co.z for i in f.vertices) / len(f.vertices))
groups = [set(f.index for f in ordered[i::3]) for i in range(3)]
# Interleaving above balances exactly, but use contiguous bands for cleaner seams.
n = len(ordered)
groups = [set(f.index for f in ordered[n*k//3:n*(k+1)//3]) for k in range(3)]
parts = []
for number, keep in enumerate(groups, 1):
    part = body.copy()
    part.data = body.data.copy()
    bpy.context.scene.collection.objects.link(part)
    part.name = "Chair_%02d" % number
    bm = bmesh.new()
    bm.from_mesh(part.data)
    bm.faces.ensure_lookup_table()
    remove = [f for f in bm.faces if f.index not in keep]
    bmesh.ops.delete(bm, geom=remove, context="FACES")
    bm.to_mesh(part.data)
    bm.free()
    part.data.update()
    assert 0 < len(part.data.polygons) <= PART_TRI_LIMIT
    parts.append(part)
body.hide_render = True
body.hide_set(True)

export_collection = bpy.data.collections.new("EXPORT")
bpy.context.scene.collection.children.link(export_collection)
for part in parts:
    for collection in list(part.users_collection):
        collection.objects.unlink(part)
    export_collection.objects.link(part)

bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "source/Chair.blend"))
bpy.ops.object.select_all(action="DESELECT")
for part in parts:
    part.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.export_scene.gltf(
    filepath=str(OUT / "exports/SciFiChair.glb"),
    export_format="GLB",
    export_image_format="AUTO",
    use_selection=True,
    export_apply=True,
)
print("chair triangles by mesh:", [len(p.data.polygons) for p in parts])
print("wrote", OUT / "exports/SciFiChair.glb")
