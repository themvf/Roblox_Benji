"""Create a thin, standless static television for Roblox import."""

import argparse
import math
import sys

import bpy


WIDTH = 8.0
HEIGHT = 4.6
DEPTH = 0.28


def material(name, color, roughness=0.7, metallic=0.0):
    value = bpy.data.materials.new(name)
    value.diffuse_color = (*color, 1.0)
    value.use_nodes = True
    shader = value.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = (*color, 1.0)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    return value


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--static", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args(argv)

    bpy.ops.wm.read_factory_settings(use_empty=True)

    # The back is Z=0 in the exported Y-up GLB. Blender's negative Y faces
    # forward, so the imported screen faces positive Roblox Z.
    bpy.ops.mesh.primitive_cube_add(size=1, location=(0, -DEPTH / 2, HEIGHT / 2))
    body = bpy.context.object
    body.name = "TV_SlimFrame"
    body.data.name = "TV_SlimFrame"
    body.dimensions = (WIDTH, DEPTH, HEIGHT)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel = body.modifiers.new("Soft cabinet edges", "BEVEL")
    bevel.width = 0.035
    bevel.segments = 2
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    normal = body.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    bpy.ops.object.modifier_apply(modifier=normal.name)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    body.data.materials.append(material("Graphite cabinet", (0.018, 0.023, 0.031), 0.73, 0.18))

    # A separate screen lets Studio preserve the static image as a ColorMap.
    bpy.ops.mesh.primitive_plane_add(
        size=1,
        location=(0, -DEPTH - 0.005, HEIGHT / 2),
        rotation=(math.pi / 2, 0, 0),
    )
    screen = bpy.context.object
    screen.name = "TV_StaticScreen"
    screen.data.name = "TV_StaticScreen"
    screen.scale = (7.68, 4.28, 1)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    screen_mat = material("Blue static screen", (1, 1, 1), 0.92, 0.0)
    image = bpy.data.images.load(args.static, check_existing=False)
    image.pack()
    nodes = screen_mat.node_tree.nodes
    texture = nodes.new("ShaderNodeTexImage")
    texture.image = image
    screen_mat.node_tree.links.new(texture.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])
    screen.data.materials.append(screen_mat)

    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    screen.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=args.out,
        export_format="GLB",
        export_image_format="AUTO",
        use_selection=True,
    )
    print("exported standless TV", args.out)


if __name__ == "__main__":
    main()
