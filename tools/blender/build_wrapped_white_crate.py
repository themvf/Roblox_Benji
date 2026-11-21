"""Build a Roblox-ready two-crate pallet fully covered in white plastic."""

from pathlib import Path
import math
import bmesh
import bpy
import mathutils
import numpy as np


ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/wrapped-white-crate"
SOURCE = PKG / "source/trellis-original.glb"
EXPORT = PKG / "exports/WrappedWhiteCrate.glb"
BLEND = PKG / "source/WrappedWhiteCrate.blend"
TEXTURES = PKG / "textures"
TARGET_WOOD_TRIS = 17800
LENGTH = 8.0


def triangles(obj):
    return sum(len(poly.vertices) - 2 for poly in obj.data.polygons)


def save_image(image, name):
    path = TEXTURES / name
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    return path


def plastic_map(name, roughness=False):
    size = 1024
    yy, xx = np.mgrid[0:size, 0:size]
    rng = np.random.default_rng(151601)
    grain = rng.normal(0.0, 0.004 if roughness else 0.003, (size, size))
    striation = 0.006 * np.sin(xx * 0.055 + 0.7 * np.sin(yy * 0.015))
    folds = 0.007 * np.sin(yy * 0.105 + 0.4 * np.sin(xx * 0.021))
    value = np.clip((0.36 if roughness else 0.89) + grain + striation + folds, 0, 1)
    if roughness:
        rgba = np.stack([value, value, value, np.ones_like(value)], axis=-1)
    else:
        rgba = np.stack([value, value * 0.997, value * 0.985, np.ones_like(value)], axis=-1)
    image = bpy.data.images.new(name, width=size, height=size, alpha=True)
    image.pixels.foreach_set(rgba.astype(np.float32).ravel())
    save_image(image, name + ".png")
    return image


def material(name, color, roughness=0.42, color_image=None, rough_image=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = 0
    if color_image:
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = color_image
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if rough_image:
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = rough_image
        tex.image.colorspace_settings.name = "Non-Color"
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Roughness"])
    return mat


def mesh_grid(name, columns, rows, sample, mat, uv_span=(1, 1)):
    verts = []
    for j in range(rows + 1):
        v = j / rows
        for i in range(columns + 1):
            u = i / columns
            verts.append(sample(u, v))
    faces = []
    for j in range(rows):
        for i in range(columns):
            a = j * (columns + 1) + i
            faces.append((a, a + 1, a + columns + 2, a + columns + 1))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for polygon in mesh.polygons:
        for loop_index in polygon.loop_indices:
            vertex_index = mesh.loops[loop_index].vertex_index
            u = (vertex_index % (columns + 1)) / columns
            v = (vertex_index // (columns + 1)) / rows
            uv_layer.data[loop_index].uv = (u * uv_span[0], v * uv_span[1])
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    solidify = obj.modifiers.new("Thin wrapped film", "SOLIDIFY")
    solidify.thickness = 0.025
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=solidify.name)
    return obj


def cube(name, location, scale, mat, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("Soft edge", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.materials.append(mat)
    return obj


def split_wood(obj):
    base = bmesh.new()
    base.from_mesh(obj.data)
    result = []
    for side, clear_inner, clear_outer in (
        ("Left", True, False),
        ("Right", False, True),
    ):
        bm = base.copy()
        bmesh.ops.bisect_plane(
            bm,
            geom=list(bm.verts) + list(bm.edges) + list(bm.faces),
            dist=0.00001,
            plane_co=(0, 0, 0),
            plane_no=(1, 0, 0),
            clear_inner=clear_inner,
            clear_outer=clear_outer,
        )
        mesh = bpy.data.meshes.new("CrateWood_" + side)
        bm.to_mesh(mesh)
        bm.free()
        for source_mat in obj.data.materials:
            mesh.materials.append(source_mat)
        part = bpy.data.objects.new("CrateWood_" + side, mesh)
        bpy.context.collection.objects.link(part)
        count = triangles(part)
        if count >= 10000:
            bpy.ops.object.select_all(action="DESELECT")
            part.select_set(True)
            bpy.context.view_layer.objects.active = part
            mod = part.modifiers.new("Roblox per-mesh budget", "DECIMATE")
            mod.ratio = 9500 / count
            bpy.ops.object.modifier_apply(modifier=mod.name)
        print(part.name, triangles(part), "triangles")
        assert 0 < triangles(part) < 10000
        result.append(part)
    base.free()
    bpy.data.objects.remove(obj, do_unlink=True)
    return result


def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    assert len(meshes) == 1
    wood = meshes[0]
    bpy.ops.object.select_all(action="DESELECT")
    wood.select_set(True)
    bpy.context.view_layer.objects.active = wood
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    original_triangles = triangles(wood)
    mod = wood.modifiers.new("Retain textured crate shape", "DECIMATE")
    mod.ratio = TARGET_WOOD_TRIS / original_triangles
    mod.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=mod.name)

    for image_id, filename in (("Image_0", "Wood_Color.png"), ("Image_1", "Wood_ORM.png")):
        save_image(bpy.data.images[image_id], filename)

    bounds = wood.bound_box
    source_low = min(v[2] for v in bounds)
    source_long = max(v[1] for v in bounds) - min(v[1] for v in bounds)
    factor = LENGTH / source_long
    for vertex in wood.data.vertices:
        x, y, z = vertex.co
        vertex.co = (y * factor, -x * factor, (z - source_low) * factor)
    wood.data.update()
    split_wood(wood)

    plastic_color = plastic_map("Plastic_Color")
    plastic_rough = plastic_map("Plastic_Roughness", roughness=True)
    film = material("White shrink film", (0.9, 0.9, 0.88), 0.36, plastic_color, plastic_rough)
    fold = material("Film fold and overlap", (0.75, 0.78, 0.78), 0.45)
    height = 3.82
    half_depth = 1.91
    start, end = -4.04, 4.04

    def edge_x(v):
        return end + 0.018 * math.sin(v * 17.2) + 0.009 * math.sin(v * 46.0)

    def wrinkle(u, v):
        return 0.035 * math.sin(12.5 * u + 18 * v) + 0.018 * math.sin(34 * u - 9 * v)

    for side, direction in (("Front", -1), ("Back", 1)):
        def side_point(u, v, sign=direction):
            x = start + (edge_x(v) - start) * u
            z = 0.55 + (height - 0.49) * v + 0.05 * math.sin(11 * u) * (1 - v)
            y = sign * (half_depth + 0.07 + wrinkle(u, v))
            return (x, y, z)

        mesh_grid("WhiteWrap_" + side, 48, 18, side_point, film, (2.5, 1.4))
        for index, level in enumerate((1.14, 2.66)):
            cube(
                f"FilmOverlap_{side}_{index}",
                (0, direction * (half_depth + 0.115), level),
                (8.05, 0.025, 0.055),
                fold,
                0.01,
            )

    mesh_grid(
        "WhiteWrap_Top",
        48,
        22,
        lambda u, v: (
            start + (edge_x(v) - start) * u,
            (v * 2 - 1) * (half_depth + 0.145),
            height + 0.065 + wrinkle(u, v),
        ),
        film,
        (2.5, 1.4),
    )
    mesh_grid(
        "WhiteWrap_LeftEnd",
        22,
        18,
        lambda u, v: (
            start - 0.025 - wrinkle(u, v),
            (u * 2 - 1) * (half_depth + 0.06),
            0.55 + (height - 0.49) * v,
        ),
        film,
        (1.4, 1.4),
    )
    mesh_grid(
        "WhiteWrap_RightEnd",
        22,
        18,
        lambda u, v: (
            end + 0.04 + wrinkle(u, v),
            (u * 2 - 1) * (half_depth + 0.08),
            0.55 + (height - 0.49) * v,
        ),
        film,
        (1.4, 1.4),
    )

    # Folded seams and shallow diagonal creases make the plastic read as film.
    for side, direction in (("Front", -1), ("Back", 1)):
        for index, level in enumerate((0.95, 1.75, 2.55)):
            cube(
                f"Wrinkle_{side}_{index}",
                (-2.7 + index * 2.7, direction * (half_depth + 0.122), level),
                (1.55, 0.018, 0.035),
                fold,
                0.008,
            ).rotation_euler[1] = math.radians((-1 if side == "Front" else 1) * (10 + index * 4))
        cube(
            "FoldedEndSeam_" + side,
            (end, direction * (half_depth + 0.115), 2.2),
            (0.085, 0.03, 2.95),
            fold,
            0.015,
        )
        cube(
            "RolledTopEdge_" + side,
            (0, direction * (half_depth + 0.08), height + 0.025),
            (8.12, 0.09, 0.075),
            film,
            0.025,
        )
        cube(
            "RolledEndCorner_" + side,
            (start - 0.018, direction * (half_depth + 0.065), 2.18),
            (0.085, 0.13, 3.28),
            film,
            0.018,
        )
        cube(
            "RolledRightCorner_" + side,
            (end + 0.035, direction * (half_depth + 0.065), 2.18),
            (0.085, 0.13, 3.28),
            film,
            0.018,
        )
    for side, x in (("Left", start), ("Right", end)):
        cube(
            "RolledTopEnd_" + side,
            (x + (0.01 if side == "Right" else -0.01), 0, height + 0.012),
            (0.19, 4.12, 0.14),
            film,
            0.025,
        )

    # All small folds share one material and one Roblox MeshPart.
    detail = [
        obj for obj in bpy.context.scene.objects
        if obj.type == "MESH" and (obj.name.startswith("FilmOverlap_") or obj.name.startswith("Wrinkle_")
                                  or obj.name.startswith("FoldedEndSeam_") or obj.name.startswith("RolledTopEdge_")
                                  or obj.name.startswith("RolledEndCorner_") or obj.name.startswith("RolledRightCorner_")
                                  or obj.name.startswith("RolledTopEnd_"))
    ]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in detail:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = detail[0]
    bpy.ops.object.join()
    bpy.context.object.name = "PlasticFoldDetails"
    bpy.context.object.data.name = "PlasticFoldDetails"

    # Source importer leaves empty hierarchy nodes; export only actual meshes.
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            obj.select_set(True)
    bpy.context.view_layer.objects.active = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    bpy.ops.export_scene.gltf(filepath=str(EXPORT), export_format="GLB", use_selection=True)
    print("wrote", EXPORT)


if __name__ == "__main__":
    main()
