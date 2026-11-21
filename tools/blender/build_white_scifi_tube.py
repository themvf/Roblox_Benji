"""Model a white sci-fi canister from the supplied front-view reference."""

import argparse
import math
from pathlib import Path
import sys

import bpy


HEIGHT = 12.0
groups = {}


def material(name, color, texture_path, roughness=0.65, metallic=0.0):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*color, 1)
    result.use_nodes = True
    shader = result.node_tree.nodes["Principled BSDF"]
    shader.inputs["Base Color"].default_value = (1, 1, 1, 1)
    shader.inputs["Roughness"].default_value = roughness
    shader.inputs["Metallic"].default_value = metallic
    image = bpy.data.images.load(str(texture_path), check_existing=False)
    image.pack()
    texture = result.node_tree.nodes.new("ShaderNodeTexImage")
    texture.image = image
    result.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    return result


def finish(obj, group, mat, bevel=0):
    bpy.context.view_layer.objects.active = obj
    if bevel:
        modifier = obj.modifiers.new("Edge softness", "BEVEL")
        modifier.width = bevel
        modifier.segments = 2
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.data.materials.append(mat)
    groups.setdefault(group, []).append(obj)
    return obj


def cylinder(name, radius, bottom, top, group, mat, vertices=48, bevel=0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=top - bottom, location=(0, 0, (bottom + top) / 2))
    obj = bpy.context.object
    obj.name = name
    return finish(obj, group, mat, bevel)


def box(name, center, size, group, mat, bevel=0, angle=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center, rotation=(0, 0, angle))
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, group, mat, bevel)


def torus(name, radius, minor, height, group, mat):
    bpy.ops.mesh.primitive_torus_add(major_segments=48, minor_segments=6, location=(0, 0, height), major_radius=radius, minor_radius=minor)
    obj = bpy.context.object
    obj.name = name
    return finish(obj, group, mat)


def build(out, texture_dir):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    texture_dir = Path(texture_dir)
    white = material("Warm white ceramic", (0.65, 0.69, 0.72), texture_dir / "WhiteHousing.png", 0.76)
    highlight = material("Pale panel edges", (0.82, 0.84, 0.83), texture_dir / "PalePanels.png", 0.65)
    dark = material("Graphite recesses", (0.035, 0.052, 0.056), texture_dir / "DarkRecesses.png", 0.60, 0.40)
    graphite = material("Gunmetal trim", (0.14, 0.18, 0.19), texture_dir / "GunmetalDetails.png", 0.55, 0.48)
    amber = material("Amber indicator", (0.78, 0.19, 0.018), texture_dir / "AmberLights.png", 0.40)

    # One cylindrical body with substantial top and base collars.
    cylinder("Main vertical housing", 1.79, 2.25, 9.45, "WhiteHousing", white)
    cylinder("Lower base", 2.03, 0.0, 1.25, "WhiteHousing", white, bevel=0.10)
    cylinder("Upper cap", 2.03, 10.56, 11.88, "WhiteHousing", white, bevel=0.10)
    cylinder("Lower shoulder", 1.92, 1.28, 1.57, "WhiteHousing", highlight, bevel=0.04)
    cylinder("Upper shoulder", 1.92, 9.42, 9.70, "WhiteHousing", highlight, bevel=0.04)
    cylinder("Upper crown", 1.83, 11.86, HEIGHT, "GunmetalDetails", graphite)

    cylinder("Lower dark collar", 1.87, 1.54, 2.28, "DarkRecesses", dark)
    cylinder("Upper dark collar", 1.87, 9.67, 10.59, "DarkRecesses", dark)
    for height in (1.64, 1.84, 2.04, 10.07, 10.48):
        torus("Collar groove", 1.89, 0.025, height, "GunmetalDetails", graphite)
    for height in (0.26, 0.93, 11.03, 11.65):
        torus("Fine cap seam", 2.038, 0.018, height, "GunmetalDetails", graphite)

    # Segmented upper machinery, visible around the whole circumference.
    for index in range(12):
        angle = 2 * math.pi * index / 12
        x = 1.89 * math.sin(angle)
        y = -1.89 * math.cos(angle)
        box("Upper radial strut", (x, y, 10.13), (0.13, 0.15, 0.70), "GunmetalDetails", graphite, bevel=0.015, angle=-angle)

    # The broad asymmetric front service door is inspired by the reference's
    # white faceted panel. Front faces Blender -Y, hence Roblox +Z.
    box("Door dark gasket", (0.04, -1.82, 5.81), (2.42, 0.12, 6.96), "DarkRecesses", dark, bevel=0.08)
    box("Door white plate", (-0.01, -1.91, 5.81), (2.22, 0.12, 6.76), "WhiteHousing", white, bevel=0.08)
    box("Door center raised facet", (-0.39, -1.99, 5.80), (1.03, 0.035, 5.98), "PalePanels", highlight, bevel=0.03)
    box("Door left channel", (-1.01, -2.01, 5.82), (0.025, 0.025, 5.94), "GunmetalDetails", graphite)
    box("Door right seam", (1.03, -2.01, 5.82), (0.022, 0.025, 5.90), "GunmetalDetails", graphite)

    # Narrow control niche and warm indicator on the right side.
    box("Control rim", (1.31, -1.63, 5.87), (0.68, 0.18, 2.42), "GunmetalDetails", graphite, bevel=0.04)
    box("Control recess", (1.31, -1.74, 5.87), (0.51, 0.055, 2.19), "DarkRecesses", dark, bevel=0.02)
    box("Amber vertical status", (1.31, -1.78, 6.04), (0.095, 0.025, 0.56), "AmberLights", amber, bevel=0.012)
    box("Amber top status", (0.15, -1.91, 10.12), (0.075, 0.03, 0.23), "AmberLights", amber)

    # Small radial divisions keep the end caps from reading as plain tubes.
    for index in range(12):
        angle = 2 * math.pi * index / 12
        x = 2.04 * math.sin(angle)
        y = -2.04 * math.cos(angle)
        for height in (0.39, 11.44):
            box("Cap segment seam", (x, y, height), (0.018, 0.025, 0.27), "GunmetalDetails", graphite, angle=-angle)

    # Join each material group into one MeshPart for predictable Studio import.
    bpy.ops.object.select_all(action="DESELECT")
    for name, objects in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        if len(objects) > 1:
            bpy.ops.object.join()
        joined = bpy.context.object
        joined.name = "Tube_" + name
        joined.data.name = joined.name

    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_image_format="AUTO", use_selection=True)
    print("exported white sci-fi tube", out)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True)
    parser.add_argument("--texture-dir", required=True)
    parsed = parser.parse_args(args)
    build(parsed.out, parsed.texture_dir)
