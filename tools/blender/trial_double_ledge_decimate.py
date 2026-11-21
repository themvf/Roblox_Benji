"""Measure how well the supplied turret scan survives Blender decimation."""

import argparse
import sys

import bpy


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--ratio", type=float, required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args(argv)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=args.source)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    print("source faces", len(obj.data.polygons))
    modifier = obj.modifiers.new("TrialDecimate", "DECIMATE")
    modifier.ratio = args.ratio
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    print("decimated faces", len(obj.data.polygons))
    low = min(v.co.z for v in obj.data.vertices)
    high = max(v.co.z for v in obj.data.vertices)
    factor = 8 / (high - low)
    mid_x = (min(v.co.x for v in obj.data.vertices) + max(v.co.x for v in obj.data.vertices)) / 2
    mid_y = (min(v.co.y for v in obj.data.vertices) + max(v.co.y for v in obj.data.vertices)) / 2
    for vertex in obj.data.vertices:
        vertex.co.x = (vertex.co.x - mid_x) * factor
        vertex.co.y = (vertex.co.y - mid_y) * factor
        vertex.co.z = (vertex.co.z - low) * factor
    obj.data.update()
    bpy.ops.export_scene.gltf(
        filepath=args.out,
        export_format="GLB",
        export_image_format="AUTO",
        use_selection=True,
    )
    print("wrote", args.out)


if __name__ == "__main__":
    main()
