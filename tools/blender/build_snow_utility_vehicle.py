"""Preserve the textured vehicle scan at 25% detail, split into Roblox-size meshes."""

from pathlib import Path
import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/snow-utility-vehicle"
SOURCE = PKG / "source/trellis-original.glb"
BLEND = PKG / "source/SnowUtilityVehicle.blend"
EXPORT = PKG / "exports/SnowUtilityVehicle.glb"
TEXTURES = PKG / "textures"
TEXTURES.mkdir(parents=True, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
source_objects = [ob for ob in bpy.context.scene.objects if ob.type == "MESH"]
assert len(source_objects) == 1
source = source_objects[0]

# Blender's collapse decimator keeps the silhouette at this tested ratio. The
# rejected alternative is a single 10k mesh, which would discard 96% of faces.
bpy.context.view_layer.objects.active = source
modifier = source.modifiers.new("25 percent tested source retention", "DECIMATE")
modifier.ratio = .25
modifier.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier=modifier.name)
mesh = source.data
assert 68_000 < len(mesh.polygons) < 72_000, len(mesh.polygons)

# The source is a normalized scan. Fit its actual height to seven studs and
# place all tires at z=0, preserving relative width and length.
world = [source.matrix_world @ vert.co for vert in mesh.vertices]
low = Vector(tuple(min(co[i] for co in world) for i in range(3)))
high = Vector(tuple(max(co[i] for co in world) for i in range(3)))
scale = 7.0 / (high.z - low.z)
mid_x, mid_y = (low.x + high.x)/2, (low.y + high.y)/2
points = [((co.x-mid_x)*scale, (co.y-mid_y)*scale, (co.z-low.z)*scale) for co in world]

# Convert both WebP source maps to durable Roblox-compatible 1024 PNG files.
images = {image.name: image for image in bpy.data.images if image.size[0] > 0}
assert len(images) == 2, list(images)
for key, filename in (("Image_0", "Vehicle_Color.png"),
                      ("Image_1", "Vehicle_MetalRough.png")):
    image = images[key]
    image.scale(1024, 1024)
    image.filepath_raw = str(TEXTURES / filename)
    image.file_format = "PNG"
    image.save()

original_uv = mesh.uv_layers.active
assert original_uv is not None
material = source.data.materials[0]
limit = 8500
parts = []
polygons = list(mesh.polygons)
for start in range(0, len(polygons), limit):
    batch = polygons[start:start+limit]
    verts, faces, uv_faces, smooth = [], [], [], []
    index = {}
    for poly in batch:
        face, coords = [], []
        for loop_index in poly.loop_indices:
            original_index = mesh.loops[loop_index].vertex_index
            uv = original_uv.data[loop_index].uv
            key = (original_index, round(uv.x, 6), round(uv.y, 6))
            if key not in index:
                index[key] = len(verts)
                verts.append(points[original_index])
            face.append(index[key])
            coords.append((uv.x, uv.y))
        faces.append(face)
        uv_faces.append(coords)
        smooth.append(poly.use_smooth)
    part_mesh = bpy.data.meshes.new(f"Vehicle segment {len(parts)+1:02}")
    part_mesh.from_pydata(verts, [], faces)
    part_mesh.update()
    part_mesh.materials.append(material)
    uv_layer = part_mesh.uv_layers.new(name="UVMap")
    for face_index, (poly, coords) in enumerate(zip(part_mesh.polygons, uv_faces)):
        poly.use_smooth = smooth[face_index]
        for loop_index, coord in zip(poly.loop_indices, coords):
            uv_layer.data[loop_index].uv = coord
    part = bpy.data.objects.new(f"SnowUtilityVehicle_Segment_{len(parts)+1:02}", part_mesh)
    bpy.context.scene.collection.objects.link(part)
    parts.append(part)

bpy.data.objects.remove(source, do_unlink=True)
for image in images.values():
    image.pack()
bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))

bpy.ops.object.select_all(action="DESELECT")
for part in parts:
    part.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.export_scene.gltf(filepath=str(EXPORT), export_format="GLB",
                          export_image_format="AUTO", use_selection=True,
                          export_yup=True)
print("EXPORTED", EXPORT, len(parts), "meshes", len(polygons), "triangles",
      "dimensions", tuple(round((high[i]-low[i])*scale, 3) for i in range(3)))
