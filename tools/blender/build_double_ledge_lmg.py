"""Convert the supplied dense scan into separate Roblox-size turret mesh chunks.

Run through tools/build_double_ledge_lmg.py so textures and validation are recorded.
The source is kept intact. This is a visual prototype, not a collision mesh.
"""

import argparse
import sys

import bpy


MAX_FACES = 9000
HEIGHT_STUDS = 8.0
HEAD_START = 4.55


def imported_mesh(source):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=source)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    if not meshes:
        raise RuntimeError("source contains no mesh")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def build():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--color", required=True)
    parser.add_argument("--metallic-roughness", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args(argv)

    obj = imported_mesh(args.source)
    for name, path in (("Image_0", args.color), ("Image_1", args.metallic_roughness)):
        img = bpy.data.images.get(name)
        if img is None:
            raise RuntimeError("missing imported material image " + name)
        img.filepath = path
        img.source = "FILE"
        img.reload()

    source_faces = len(obj.data.polygons)
    modifier = obj.modifiers.new("Reduce scan for Roblox", "DECIMATE")
    modifier.ratio = 0.25
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    reduced_faces = len(obj.data.polygons)

    coords = [vertex.co for vertex in obj.data.vertices]
    mins = [min(p[axis] for p in coords) for axis in range(3)]
    maxs = [max(p[axis] for p in coords) for axis in range(3)]
    scale = HEIGHT_STUDS / (maxs[2] - mins[2])
    center_x = (mins[0] + maxs[0]) / 2
    center_y = (mins[1] + maxs[1]) / 2
    for vertex in obj.data.vertices:
        vertex.co.x = (vertex.co.x - center_x) * scale
        vertex.co.y = (vertex.co.y - center_y) * scale
        vertex.co.z = (vertex.co.z - mins[2]) * scale
    obj.data.update()

    source_uv = obj.data.uv_layers.active
    if source_uv is None:
        raise RuntimeError("source has no UV layer")
    parts = {"Base": [], "Head": []}
    for poly in obj.data.polygons:
        average_height = sum(obj.data.vertices[index].co.z for index in poly.vertices) / len(poly.vertices)
        parts["Head" if average_height >= HEAD_START else "Base"].append(poly)

    for part_name, faces in parts.items():
        for start in range(0, len(faces), MAX_FACES):
            subset = faces[start : start + MAX_FACES]
            vertex_map = {}
            vertices = []
            triangles = []
            uv_values = []
            for poly in subset:
                local = []
                for loop_index in poly.loop_indices:
                    source_index = obj.data.loops[loop_index].vertex_index
                    if source_index not in vertex_map:
                        vertex_map[source_index] = len(vertices)
                        vertices.append(tuple(obj.data.vertices[source_index].co))
                    local.append(vertex_map[source_index])
                    uv_values.append(tuple(source_uv.data[loop_index].uv))
                triangles.append(local)
            mesh = bpy.data.meshes.new("%s_%02d" % (part_name, start // MAX_FACES + 1))
            mesh.from_pydata(vertices, [], triangles)
            mesh.update()
            mesh.materials.append(obj.data.materials[0])
            uv_layer = mesh.uv_layers.new(name="UVMap")
            for index, uv in enumerate(uv_values):
                uv_layer.data[index].uv = uv
            for poly in mesh.polygons:
                poly.use_smooth = True
            chunk = bpy.data.objects.new(mesh.name, mesh)
            bpy.context.collection.objects.link(chunk)
            print(mesh.name, "triangles", len(mesh.polygons))

    bpy.data.objects.remove(obj, do_unlink=True)
    bpy.ops.object.select_all(action="DESELECT")
    for part_name in ("Base", "Head"):
        for chunk in bpy.data.objects:
            if chunk.type == "MESH" and chunk.name.startswith(part_name + "_"):
                chunk.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=args.out,
        export_format="GLB",
        export_image_format="AUTO",
        use_selection=True,
    )
    print("source", source_faces, "reduced", reduced_faces, "export", args.out)


if __name__ == "__main__":
    build()
