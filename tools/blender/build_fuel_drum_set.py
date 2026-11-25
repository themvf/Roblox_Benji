"""Build three complete weathered drums and a separate three-drum arrangement."""
from pathlib import Path
import json
import math
import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/fuel-drum-set"
TEXTURES = PKG / "textures"
EXPORTS = PKG / "exports"
BLEND = PKG / "source/FuelDrumSet.blend"
MANIFEST = PKG / "source/drum-manifest.json"
SIDES = 64
HEIGHT = 3.52
PROFILE = [
    (0.00, 0.98), (0.035, 1.06), (0.08, 1.105), (0.135, 1.12),
    (0.19, 1.075), (0.24, 1.045), (1.09, 1.045),
    (1.135, 1.09), (1.19, 1.09), (1.235, 1.045),
    (2.27, 1.045), (2.315, 1.09), (2.37, 1.09), (2.415, 1.045),
    (3.30, 1.045), (3.36, 1.08), (3.415, 1.12),
    (3.475, 1.105), (3.52, 1.02),
]
VARIANTS = [
    {"name": "FuelDrum_A", "seed": 210013, "base": (0.38, 0.50, 0.55), "rust": 0.85},
    {"name": "FuelDrum_B", "seed": 210014, "base": (0.33, 0.46, 0.52), "rust": 1.08},
    {"name": "FuelDrum_C", "seed": 210015, "base": (0.42, 0.51, 0.54), "rust": 1.20},
]


def write_image(name, data):
    image = bpy.data.images.new(name, width=data.shape[1], height=data.shape[0], alpha=True)
    image.pixels.foreach_set(data.astype(np.float32).ravel())
    image.filepath_raw = str(TEXTURES / (name + ".png"))
    image.file_format = "PNG"
    image.save()
    return image


def material_for(variant):
    size = 1024
    yy, xx = np.mgrid[:size, :size]
    u, v = xx / size, yy / size
    rng = np.random.default_rng(variant["seed"])
    grain = rng.normal(0, 0.018, (size, size))
    streaks = (0.55 * np.sin(23 * u + 2 * np.sin(8 * v))
               + 0.32 * np.sin(61 * u + 5 * v) + 0.19 * np.sin(113 * u - 3 * v))
    broad = 0.045 * np.sin(8 * u + 10 * v) + 0.03 * np.sin(19 * u - 13 * v)
    body = np.array(variant["base"], dtype=np.float32)
    light = grain + broad + 0.03 * streaks
    color = np.empty((size, size, 4), dtype=np.float32)
    color[:, :, :3] = body[None, None, :] + light[:, :, None]
    color[:, :, 3] = 1
    rim = (0.82 * np.exp(-((v - 0.045) / 0.033) ** 2)
           + 0.38 * np.exp(-((v - 0.69) / 0.029) ** 2)
           + 0.25 * np.exp(-((v - 0.26) / 0.012) ** 2)
           + 0.22 * np.exp(-((v - 0.50) / 0.012) ** 2))
    spots = np.clip(0.40 + 0.40 * np.sin(37 * u + 17 * v) * np.sin(26 * u - 31 * v)
                    + 0.22 * grain / 0.018, 0, 1)
    rust = np.clip(variant["rust"] * rim * spots * 1.45, 0, 0.84)
    patch = np.clip((np.sin(19 * u + 11 * v) * np.sin(27 * u - 16 * v) - 0.12) * 0.27, 0, 0.22)
    rust += variant["rust"] * patch * (0.3 + 0.7 * np.abs(v - 0.37) / 0.37)
    drips = np.zeros((size, size), dtype=np.float32)
    for _ in range(19):
        center = rng.uniform(0, 1)
        width = rng.uniform(0.004, 0.018)
        distance = np.abs((u - center + 0.5) % 1 - 0.5)
        start = rng.uniform(0.22, 0.52)
        direction = rng.choice((-1, 1))
        run = np.clip((v - start) / 0.18, 0, 1) if direction > 0 else np.clip((start - v) / 0.18, 0, 1)
        drips += rng.uniform(0.12, 0.35) * np.exp(-(distance / width) ** 2) * run
    rust += variant["rust"] * drips
    rust = np.clip(rust, 0, 0.85)
    color[:, :, :3] = color[:, :, :3] * (1 - rust[:, :, None]) + np.array(
        [0.36, 0.15, 0.065], dtype=np.float32)[None, None, :] * rust[:, :, None]
    chips = (rng.random((size, size)) > 0.995) & (v < 0.74)
    color[:, :, :3][chips] *= 0.65
    # Lid occupies the upper-right atlas; dark bung-cap patch is upper-left.
    lid = v > 0.74
    color[:, :, :3][lid] = (body + 0.045 + (grain + broad)[lid, None])
    cx, cy = 0.57, 0.87
    radius = np.sqrt((u - cx) ** 2 + (v - cy) ** 2)
    lid_rust = np.clip(np.exp(-((radius - 0.115) / 0.012) ** 2) * 0.50 * spots, 0, 0.5)
    color[:, :, :3][lid] = (color[:, :, :3][lid] * (1 - lid_rust[lid, None])
                            + np.array([0.28, 0.15, 0.08])[None, :] * lid_rust[lid, None])
    cap_patch = (u < 0.16) & (v > 0.76)
    color[:, :, :3][cap_patch] = [0.20, 0.24, 0.25]
    color[:, :, :3] = np.clip(color[:, :, :3], 0, 1)
    rough = np.clip(0.38 + 0.34 * rust + 0.06 * grain / 0.018, 0.25, 0.86)
    rough[cap_patch] = 0.50
    rough_rgba = np.stack([rough, rough, rough, np.ones_like(rough)], axis=-1)
    albedo = write_image(variant["name"] + "_Color", color)
    rough_image = write_image(variant["name"] + "_Roughness", rough_rgba)
    rough_image.colorspace_settings.name = "Non-Color"
    mat = bpy.data.materials.new(variant["name"] + "_WeatheredMetal")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Metallic"].default_value = 0.58
    bsdf.inputs["Roughness"].default_value = 0.42
    color_node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    color_node.image = albedo
    mat.node_tree.links.new(color_node.outputs["Color"], bsdf.inputs["Base Color"])
    rough_node = mat.node_tree.nodes.new("ShaderNodeTexImage")
    rough_node.image = rough_image
    mat.node_tree.links.new(rough_node.outputs["Color"], bsdf.inputs["Roughness"])
    return mat


def barrel_mesh(name, material, offset=(0, 0, 0)):
    verts, uv, faces, smooth = [], [], [], []
    ox, oy, oz = offset
    def vertex(x, y, z, tex_u, tex_v):
        verts.append((x + ox, y + oy, z + oz))
        uv.append((tex_u, tex_v))
        return len(verts) - 1
    for z, radius in PROFILE:
        for i in range(SIDES + 1):
            angle = 2 * math.pi * i / SIDES
            vertex(radius * math.cos(angle), radius * math.sin(angle), z,
                   i / SIDES, 0.04 + 0.66 * z / HEIGHT)
    for level in range(len(PROFILE) - 1):
        for i in range(SIDES):
            a = level * (SIDES + 1) + i
            b = (level + 1) * (SIDES + 1) + i
            faces.append((a, a + 1, b + 1, b))
            smooth.append(True)

    # Recessed circular lid with subtle concentric stamped rings.
    top_levels = ((1.02, 3.465), (0.96, 3.455), (0.82, 3.461), (0.0, 3.458))
    top_start = len(verts)
    for radius, z in top_levels[:-1]:
        for i in range(SIDES + 1):
            angle = 2 * math.pi * i / SIDES
            vertex(radius * math.cos(angle), radius * math.sin(angle), z,
                   0.57 + radius * 0.115 * math.cos(angle),
                   0.87 + radius * 0.115 * math.sin(angle))
    center = vertex(0, 0, top_levels[-1][1], 0.57, 0.87)
    for level in range(len(top_levels) - 2):
        for i in range(SIDES):
            a = top_start + level * (SIDES + 1) + i
            b = top_start + (level + 1) * (SIDES + 1) + i
            faces.append((a, b, b + 1, a + 1))
            smooth.append(False)
    last = top_start + (len(top_levels) - 2) * (SIDES + 1)
    for i in range(SIDES):
        faces.append((last + i, center, last + i + 1))
        smooth.append(False)

    bottom_center = vertex(0, 0, 0, 0.57, 0.87)
    for i in range(SIDES):
        faces.append((i + 1, bottom_center, i))
        smooth.append(False)

    def cap(cx, cy, radius, height, sides=12):
        lower, upper = [], []
        for i in range(sides):
            angle = 2 * math.pi * i / sides
            x, y = cx + radius * math.cos(angle), cy + radius * math.sin(angle)
            lower.append(vertex(x, y, 3.462, 0.07, 0.85))
            upper.append(vertex(x, y, 3.462 + height, 0.07, 0.85))
        top = vertex(cx, cy, 3.462 + height, 0.07, 0.85)
        for i in range(sides):
            j = (i + 1) % sides
            faces.append((lower[i], lower[j], upper[j], upper[i]))
            smooth.append(False)
            faces.append((upper[i], upper[j], top))
            smooth.append(False)
    cap(-0.70, 0.36, 0.125, 0.075, 12)
    cap(0.67, -0.38, 0.075, 0.035, 10)

    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    layer = mesh.uv_layers.new(name="UVMap")
    for polygon, use_smooth in zip(mesh.polygons, smooth):
        polygon.use_smooth = use_smooth
        for loop_index in polygon.loop_indices:
            layer.data[loop_index].uv = uv[mesh.loops[loop_index].vertex_index]
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def export(name, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(filepath=str(EXPORTS / (name + ".glb")),
                              export_format="GLB", use_selection=True)


def main():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    mats = [material_for(variant) for variant in VARIANTS]
    singles = []
    for variant, mat in zip(VARIANTS, mats):
        obj = barrel_mesh(variant["name"], mat)
        export(variant["name"], [obj])
        singles.append(obj)
    arrangement = ((-1.17, 0.73, 0), (1.17, 0.73, 0), (0, -1.12, 0))
    group = [barrel_mesh("FuelDrum_ThreePack_" + str(i + 1), mat, offset)
             for i, (mat, offset) in enumerate(zip(mats, arrangement))]
    export("FuelDrum_ThreePack", group)
    for index, obj in enumerate(singles):
        obj.location = ((index - 1) * 5, 5, 0)
    for obj in group:
        obj.location = (0, -5, 0)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND))
    manifest = {"individuals": [v["name"] for v in VARIANTS], "group": "FuelDrum_ThreePack",
                "drumHeightStuds": HEIGHT, "drumDiameterStuds": 2.24,
                "construction": "complete modeled cylinders with rolled ribs, recessed lid and two cap details",
                "sourcePurpose": "3D and weathering reference; no source mesh triangles in exports"}
    MANIFEST.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("wrote four exports")


if __name__ == "__main__":
    main()
