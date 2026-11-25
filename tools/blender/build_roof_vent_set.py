"""Separate the nine textured source vents into independent Roblox GLBs."""
from pathlib import Path
import json
import math
import bpy
import mathutils

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/roof-vent-set"
SOURCE = PKG / "source/trellis-original.glb"
BLEND = PKG / "source/RoofVentSet.blend"
EXPORTS = PKG / "exports"
TEXTURES = PKG / "textures"
MANIFEST = PKG / "source/vent-manifest.json"

# Source is a three-row product sheet. These cuts lie in measured empty gaps.
X_CUTS = (-0.16, 0.19)
Z_CUTS = ((-0.01, 0.26), (-0.10, 0.25), (-0.20, 0.16))
NAMES = {
    (2, 0): "SlantedLouverHood",
    (2, 1): "CurvedRoofOutlet",
    (2, 2): "RectangularIntakeBox",
    (1, 0): "WideRoofLouver",
    (1, 1): "TallVentStack",
    (1, 2): "RoundRoofExtractor",
    (0, 0): "PitchedRoofVent",
    (0, 1): "RaisedCurvedDuct",
    (0, 2): "TwinDuctIntake",
}
KEEP_RATIO = 0.60
PART_TRIANGLE_BUDGET = 8500
FOOTPRINT_STUDS = 4.0


def classify(x, z):
    col = 0 if x < X_CUTS[0] else 1 if x < X_CUTS[1] else 2
    low, high = Z_CUTS[col]
    row = 0 if z < low else 1 if z < high else 2
    return row, col


def triangles(mesh):
    return sum(len(poly.vertices) - 2 for poly in mesh.polygons)


def make_mesh(name, source_mesh, face_indices, transform):
    used = {}
    verts = []
    faces = []
    uv_faces = []
    smooth = []
    uv_data = source_mesh.uv_layers.active.data
    for face_index in face_indices:
        face = source_mesh.polygons[face_index]
        mapped = []
        for vertex_index in face.vertices:
            index = int(vertex_index)
            if index not in used:
                used[index] = len(verts)
                verts.append(transform(source_mesh.vertices[index].co))
            mapped.append(used[index])
        faces.append(mapped)
        uv_faces.append([tuple(uv_data[li].uv) for li in face.loop_indices])
        smooth.append(face.use_smooth)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for polygon, values, use_smooth in zip(mesh.polygons, uv_faces, smooth):
        polygon.use_smooth = use_smooth
        for loop_index, uv in zip(polygon.loop_indices, values):
            uv_layer.data[loop_index].uv = uv
    for mat in source_mesh.materials:
        mesh.materials.append(mat)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def split_budget(name, source_obj):
    mesh = source_obj.data
    axis = max(range(3), key=lambda i: max(v.co[i] for v in mesh.vertices) - min(v.co[i] for v in mesh.vertices))
    ordered = sorted(range(len(mesh.polygons)),
                     key=lambda i: sum(mesh.vertices[v].co[axis] for v in mesh.polygons[i].vertices)
                     / len(mesh.polygons[i].vertices))
    chunks = []
    current = []
    count = 0
    for face_index in ordered:
        tris = len(mesh.polygons[face_index].vertices) - 2
        if current and count + tris > PART_TRIANGLE_BUDGET:
            chunks.append(current)
            current, count = [], 0
        current.append(face_index)
        count += tris
    if current:
        chunks.append(current)
    parts = [make_mesh(f"{name}_Part{index:02d}", mesh, chunk, lambda co: tuple(co))
             for index, chunk in enumerate(chunks, 1)]
    bpy.data.objects.remove(source_obj, do_unlink=True)
    assert all(0 < triangles(part.data) < 10000 for part in parts)
    return parts


def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    original = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH")
    bpy.ops.object.select_all(action="DESELECT")
    original.select_set(True)
    bpy.context.view_layer.objects.active = original
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    mesh = original.data
    assert len(mesh.materials) == 1 and mesh.uv_layers.active

    for image_id, filename in (("Image_0", "RoofVents_Color.png"),
                               ("Image_1", "RoofVents_ORM.png")):
        image = bpy.data.images[image_id]
        image.filepath_raw = str(TEXTURES / filename)
        image.file_format = "PNG"
        image.save()

    groups = {key: [] for key in NAMES}
    for face in mesh.polygons:
        point = sum((mesh.vertices[v].co for v in face.vertices), mathutils.Vector((0, 0, 0))) / len(face.vertices)
        key = classify(point.x, point.z)
        if any(classify(mesh.vertices[v].co.x, mesh.vertices[v].co.z) != key for v in face.vertices):
            raise RuntimeError(f"A source face crosses a prop boundary: {face.index}")
        groups[key].append(face.index)
    assert sum(map(len, groups.values())) == len(mesh.polygons)

    manifest = {"source": "trellis-original.glb", "sourceFaces": len(mesh.polygons),
                "retainedRatio": KEEP_RATIO, "partTriangleBudget": PART_TRIANGLE_BUDGET,
                "footprintStuds": FOOTPRINT_STUDS, "assets": []}
    for key, name in NAMES.items():
        face_indices = groups[key]
        used = {v for index in face_indices for v in mesh.polygons[index].vertices}
        mins = [min(mesh.vertices[v].co[a] for v in used) for a in range(3)]
        maxs = [max(mesh.vertices[v].co[a] for v in used) for a in range(3)]
        factor = FOOTPRINT_STUDS / max(maxs[0] - mins[0], maxs[1] - mins[1])
        cx, cy = (mins[0] + maxs[0]) / 2, (mins[1] + maxs[1]) / 2
        ground = mins[2]
        def recenter(co):
            return ((co.x - cx) * factor, (co.y - cy) * factor, (co.z - ground) * factor)
        base = make_mesh(name + "_Base", mesh, face_indices, recenter)
        before = triangles(base.data)
        bpy.ops.object.select_all(action="DESELECT")
        base.select_set(True)
        bpy.context.view_layer.objects.active = base
        mod = base.modifiers.new("Shape-preserving reduction", "DECIMATE")
        mod.ratio = KEEP_RATIO
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
        after = triangles(base.data)
        parts = split_budget(name, base)
        bpy.ops.object.select_all(action="DESELECT")
        for part in parts:
            part.select_set(True)
        bpy.context.view_layer.objects.active = parts[0]
        path = EXPORTS / (name + ".glb")
        bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True)
        manifest["assets"].append({"name": name, "gridRowBottomFirst": key[0],
                                   "gridColumnLeftFirst": key[1], "sourceTriangles": before,
                                   "exportTriangles": after,
                                   "partTriangles": [triangles(part.data) for part in parts],
                                   "dimensionsStuds": [round((maxs[a] - mins[a]) * factor, 3) for a in range(3)],
                                   "export": str(path.relative_to(PKG))})
        for part in parts:
            part.location = ((key[1] - 1) * 7, (key[0] - 1) * 7, 0)
        print(name, before, "->", after, "tris", len(parts), "parts")

    bpy.data.objects.remove(original, do_unlink=True)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("wrote", len(manifest["assets"]), "assets")


if __name__ == "__main__":
    main()
