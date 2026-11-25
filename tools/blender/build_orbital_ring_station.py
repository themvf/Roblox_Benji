"""Reduce and sector-split a one-mesh textured scan for Roblox import."""

import argparse
import math
import sys

import bpy


MAX_FACES = 9000
DEFAULT_HEIGHT_STUDS = 80.0


def build():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--color", required=True)
    parser.add_argument("--metallic-roughness", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--height", type=float, default=DEFAULT_HEIGHT_STUDS)
    parser.add_argument("--name-prefix", default="Station")
    args = parser.parse_args(argv)
    if args.height <= 0 or not args.name_prefix.isidentifier():
        raise ValueError("height must be positive and name-prefix must be an identifier")

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=args.source)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if len(meshes) != 1:
        raise RuntimeError("expected one mesh in source, found %d" % len(meshes))
    obj = meshes[0]
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    source_faces = len(obj.data.polygons)

    for name, path in (("Image_0", args.color), ("Image_1", args.metallic_roughness)):
        image = bpy.data.images.get(name)
        if image is None:
            raise RuntimeError("missing material image " + name)
        image.filepath = path
        image.source = "FILE"
        image.reload()

    modifier = obj.modifiers.new("Visual reduction", "DECIMATE")
    modifier.ratio = 0.25
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    reduced_faces = len(obj.data.polygons)

    # Decimate can leave loose extreme vertices; glTF discards them on export.
    # Scale from vertices used by faces so the written GLB has the target height.
    used = {index for polygon in obj.data.polygons for index in polygon.vertices}
    coordinates = [obj.data.vertices[index].co for index in used]
    low = [min(point[axis] for point in coordinates) for axis in range(3)]
    high = [max(point[axis] for point in coordinates) for axis in range(3)]
    scale = args.height / (high[2] - low[2])
    center_x = (low[0] + high[0]) / 2
    center_y = (low[1] + high[1]) / 2
    for vertex in obj.data.vertices:
        vertex.co.x = (vertex.co.x - center_x) * scale
        vertex.co.y = (vertex.co.y - center_y) * scale
        vertex.co.z = (vertex.co.z - low[2]) * scale
    obj.data.update()

    uv = obj.data.uv_layers.active
    if uv is None:
        raise RuntimeError("the scan has no UVs")
    sectors = [[] for _ in range(8)]
    for polygon in obj.data.polygons:
        x = sum(obj.data.vertices[index].co.x for index in polygon.vertices) / len(polygon.vertices)
        y = sum(obj.data.vertices[index].co.y for index in polygon.vertices) / len(polygon.vertices)
        angle = (math.atan2(y, x) + math.pi) / (2 * math.pi)
        sectors[min(7, int(angle * 8))].append(polygon)

    created = []
    for sector, faces in enumerate(sectors):
        for start in range(0, len(faces), MAX_FACES):
            name = "%s_S%02d_%02d" % (args.name_prefix, sector + 1, start // MAX_FACES + 1)
            vertex_map = {}
            vertices = []
            triangles = []
            uv_values = []
            for polygon in faces[start : start + MAX_FACES]:
                local = []
                for loop_index in polygon.loop_indices:
                    original_index = obj.data.loops[loop_index].vertex_index
                    if original_index not in vertex_map:
                        vertex_map[original_index] = len(vertices)
                        vertices.append(tuple(obj.data.vertices[original_index].co))
                    local.append(vertex_map[original_index])
                    uv_values.append(tuple(uv.data[loop_index].uv))
                triangles.append(local)
            mesh = bpy.data.meshes.new(name)
            mesh.from_pydata(vertices, [], triangles)
            mesh.update()
            mesh.materials.append(obj.data.materials[0])
            new_uv = mesh.uv_layers.new(name="UVMap")
            for index, values in enumerate(uv_values):
                new_uv.data[index].uv = values
            for polygon in mesh.polygons:
                polygon.use_smooth = True
            part = bpy.data.objects.new(name, mesh)
            bpy.context.collection.objects.link(part)
            created.append(part)
            print(name, len(triangles), "triangles")

    bpy.data.objects.remove(obj, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for part in created:
        part.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=args.out,
        export_format="GLB",
        export_image_format="AUTO",
        use_selection=True,
    )
    print("source", source_faces, "reduced", reduced_faces, "export", args.out)


if __name__ == "__main__":
    build()
