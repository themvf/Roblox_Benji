"""Prepare the supplied textured rifle as eight sub-10k triangle mesh sections.

Run with Blender 4.3: blender --factory-startup -b --python-exit-code 1
    --python tools/blender/build_white_sniper.py
"""
from pathlib import Path
import bpy
import mathutils

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/white-sniper"
SOURCE = PKG / "source/White Sniper.glb"
EXPORT = PKG / "exports/WhiteSniper.glb"
BLEND = PKG / "source/WhiteSniper.blend"
MAX_TRIANGLES = 9500
TARGET_TRIANGLES = 72000

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
assert len(meshes) == 1, f"Expected one source mesh, got {len(meshes)}"
src = meshes[0]
bpy.context.view_layer.objects.active = src
src.select_set(True)
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# TRELLIS packed WebP images are not a dependable Studio import format.
# Convert them to named PNGs and point the material at the PNG files.
for index, image in enumerate(list(bpy.data.images)):
    if image.type != "IMAGE":
        continue
    texture = PKG / "textures" / f"WhiteSniper_Texture_{index}.png"
    image.save_render(filepath=str(texture))
    image.filepath = str(texture)
    image.reload()

# The source is one metre long on Blender Y. A 5.5-stud rifle fits the game avatar.
for vertex in src.data.vertices:
    vertex.co *= 5.5
src.data.update()
modifier = src.modifiers.new("Game detail reduction", "DECIMATE")
modifier.ratio = min(1, TARGET_TRIANGLES / 292816)
bpy.ops.object.modifier_apply(modifier=modifier.name)
mesh = src.data
assert all(len(p.vertices) == 3 for p in mesh.polygons)
uv = mesh.uv_layers.active
assert uv, "The source UV texture was lost"

# Divide by face order along the barrel. Faces are never clipped or removed here;
# every source triangle belongs to exactly one mesh. Shared cut vertices coincide.
ordered = sorted(mesh.polygons, key=lambda p: p.center.y)
sections = []
for start in range(0, len(ordered), MAX_TRIANGLES):
    faces = ordered[start : start + MAX_TRIANGLES]
    vertices = []
    face_indices = []
    loop_uvs = []
    index = {}
    for polygon in faces:
        corners = []
        corner_uvs = []
        for loop_index in polygon.loop_indices:
            original = mesh.loops[loop_index].vertex_index
            if original not in index:
                index[original] = len(vertices)
                vertices.append(tuple(mesh.vertices[original].co))
            corners.append(index[original])
            corner_uvs.append(tuple(uv.data[loop_index].uv))
        face_indices.append(corners)
        loop_uvs.append(corner_uvs)
    piece = bpy.data.meshes.new(f"RifleSection_{len(sections) + 1:02}")
    piece.from_pydata(vertices, [], face_indices)
    piece.update()
    piece_uv = piece.uv_layers.new(name="UVMap")
    for polygon, corners in zip(piece.polygons, loop_uvs):
        for loop_index, coords in zip(polygon.loop_indices, corners):
            piece_uv.data[loop_index].uv = coords
        polygon.use_smooth = True
    for material in mesh.materials:
        piece.materials.append(material)
    obj = bpy.data.objects.new(piece.name, piece)
    bpy.context.collection.objects.link(obj)
    sections.append(obj)

bpy.data.objects.remove(src, do_unlink=True)
for obj in sections:
    assert len(obj.data.polygons) <= MAX_TRIANGLES
    obj.select_set(True)
bpy.context.view_layer.objects.active = obj

# Save editable source plus a portable textured GLB. The eight mesh parts preserve
# substantially more surface detail than forcing the scan into one Roblox mesh.
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
bpy.ops.export_scene.gltf(
    filepath=str(EXPORT),
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    export_image_format="AUTO",
)
print(f"WHITE_SNIPER sections={len(sections)} triangles={sum(len(o.data.polygons) for o in sections)} export={EXPORT}")
