"""Add the glowing barrel strip to the Halcyon's Meshy mesh before the scan build. Blender 4.3, headless.

    blender -b -noaudio --python tools/blender/fix_halcyon_rifle.py

Input:  assets/models/halcyon-rifle/meshy-2k/model.glb, Meshy's image-to-3d result with 2k geometry
        and PBR maps (4,000-triangle remesh, 2026-11-23). The first, standard-geometry run (meshy/)
        looked melted up close. Meshy painted the concept's cyan-to-magenta strip as a dark slot.
Output: assets/models/halcyon-rifle/source/HalcyonRifle.glb, which `asset_generate.py build` then
        turns, scales, centres, repairs and splits.

What it changes: two thin bars are laid in the slot, through the gun's width so both flanks show
them, cyan in front and magenta behind as in the concept. Each is UV-mapped to its own swatch
painted into an unused corner of the atlas. The brief's `scene.split` list cuts each colour into
its own mesh ("GlowCyan", "GlowMagenta"), so Studio can make each one Neon. The cyan window also
takes Meshy's cyan lens, which should glow too.

Frame: Meshy's glTF is X-long, Y-up; after import Blender has X along the gun (muzzle at -X),
Z up, and the width on Y. Numbers below are in Meshy units (the gun is 1.9 long, 0.364 tall),
measured on surface samples of Meshy's texture: the slot runs at z 0.045-0.075 from x -0.89 to
-0.02, off-centre in width: its dark inner tube spans y -0.027..0.048 inside a white shell.
"""

from pathlib import Path

import bmesh
import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/halcyon-rifle"
SOURCE = PKG / "meshy-2k/model.glb"
OUT = PKG / "source/HalcyonRifle.glb"
TEXTURE_OUT = PKG / "source/HalcyonRifle_texture.png"

STRIP_Z, STRIP_HALF_Z = 0.06, 0.004
STRIP_Y0, STRIP_Y1 = -0.031, 0.052  # proud of the inner tube on both flanks, inside the shell
# (name, x from, x to, sRGB): the concept's strip runs cyan from 17% to 45% of the length from the
# muzzle, then magenta to 50%. Colours are matched by scene.split in brief.json.
BARS = [
    ("cyan", -0.627, -0.12, (90, 225, 255)),  # hue 192, sat 0.65
    ("magenta", -0.12, -0.03, (240, 70, 220)),  # hue 307, sat 0.71
]
# The cyan lens at the front of the dark tube, in Blender's frame (x long, y width, z up). The
# tube's front face is at x -0.89 spanning y -0.025..0.051, z 0.02..0.09; the disc sits just proud.
LENS_X0, LENS_X1 = -0.897, -0.888
LENS_Y, LENS_Z, LENS_R, LENS_SIDES = 0.013, 0.055, 0.027, 10
# Finish (2026-11-23 "looks bad up close"): Meshy's roughness map averages 0.23, so the concept's
# matte black parts came out glossy; remap it into a satin-to-matte range and drop most metal.
ROUGH_FLOOR, ROUGH_SCALE, METAL_SCALE = 0.55, 0.4, 0.3
# Cream panels carry Meshy's blotchy baked noise. Pixels that read as cream (bright, low saturation)
# are blended toward a blur of cream-only pixels, so dark panel lines and orange trim stay sharp.
CREAM_VAL, CREAM_SAT, CREAM_SIGMA, CREAM_BLEND = 0.62, 0.22, 6.0, 0.8
SWATCH = 12  # pixels
MAX_TRIS = 4000  # the held-role budget


def free_swatches(ob, w, h, count):
    """`count` SWATCH-pixel squares no face's UVs reach, scanned from the top-right corner."""
    me = ob.data
    uv = me.uv_layers.active.data
    taken = np.zeros((h // SWATCH + 1, w // SWATCH + 1), dtype=bool)
    for poly in me.polygons:
        us = [uv[i].uv.x * w for i in poly.loop_indices]
        vs = [uv[i].uv.y * h for i in poly.loop_indices]
        x0, x1 = int(min(us)) // SWATCH, int(max(us)) // SWATCH
        y0, y1 = int(min(vs)) // SWATCH, int(max(vs)) // SWATCH
        taken[max(0, y0) : y1 + 1, max(0, x0) : x1 + 1] = True
    found = []
    for gy in range(taken.shape[0] - 2, -1, -1):
        for gx in range(taken.shape[1] - 2, -1, -1):
            if not taken[gy, gx]:
                found.append((gx * SWATCH, gy * SWATCH))
                if len(found) == count:
                    return found
    raise SystemExit("not enough free swatches in the atlas")


def add_bar(bm, uv_layer, x0, x1, uv):
    """A closed box along the slot, every corner on one swatch."""
    z0, z1 = STRIP_Z - STRIP_HALF_Z, STRIP_Z + STRIP_HALF_Z
    ya, yb = STRIP_Y0, STRIP_Y1
    v = [bm.verts.new(p) for p in (
        (x0, ya, z0), (x1, ya, z0), (x1, yb, z0), (x0, yb, z0),
        (x0, ya, z1), (x1, ya, z1), (x1, yb, z1), (x0, yb, z1),
    )]
    quads = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
    faces = [bm.faces.new([v[i] for i in q]) for q in quads]
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    for face in faces:
        face.material_index = 0
        for loop in face.loops:
            loop[uv_layer].uv = uv


def add_lens(bm, uv_layer, uv):
    """A short disc facing the muzzle, on the cyan swatch so it splits into GlowCyan."""
    import math

    rings = []
    for x in (LENS_X0, LENS_X1):
        ring = []
        for i in range(LENS_SIDES):
            a = 2 * math.pi * i / LENS_SIDES
            ring.append(bm.verts.new((x, LENS_Y + LENS_R * math.cos(a), LENS_Z + LENS_R * math.sin(a))))
        rings.append(ring)
    faces = [bm.faces.new(rings[0]), bm.faces.new(list(reversed(rings[1])))]
    for i in range(LENS_SIDES):
        j = (i + 1) % LENS_SIDES
        faces.append(bm.faces.new((rings[0][i], rings[0][j], rings[1][j], rings[1][i])))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    for face in faces:
        face.material_index = 0
        for loop in face.loops:
            loop[uv_layer].uv = uv


def blur(a, sigma):
    """Separable Gaussian blur of an (h, w) or (h, w, c) array, edges clamped."""
    r = int(3 * sigma)
    k = np.exp(-0.5 * (np.arange(-r, r + 1) / sigma) ** 2)
    k /= k.sum()
    for axis in (0, 1):
        pad = [(0, 0)] * a.ndim
        pad[axis] = (r, r)
        p = np.pad(a, pad, mode="edge")
        out = np.zeros_like(a)
        for i, kv in enumerate(k):
            sl = [slice(None)] * a.ndim
            sl[axis] = slice(i, i + a.shape[axis])
            out += kv * p[tuple(sl)]
        a = out
    return a


def smooth_cream(px):
    rgb = px[..., :3]
    mx, mn = rgb.max(-1), rgb.min(-1)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    mask = ((mx > CREAM_VAL) & (sat < CREAM_SAT)).astype(np.float32)
    num = blur(rgb * mask[..., None], CREAM_SIGMA)
    den = blur(mask, CREAM_SIGMA)[..., None]
    smooth = num / np.maximum(den, 1e-4)
    m = (mask * CREAM_BLEND)[..., None]
    px[..., :3] = rgb * (1 - m) + smooth * m
    print("finish: smoothed %.0f%% of the atlas as cream panels" % (100 * mask.mean()))


def save_edited(ob, image, px, path):
    """Write pixels to a PNG and point the material at it. The glTF importer packs the original
    image, and the exporter writes that packed copy, not the edited pixels."""
    image.pixels.foreach_set(px.ravel())
    path.parent.mkdir(parents=True, exist_ok=True)
    image.filepath_raw = str(path)
    image.file_format = "PNG"
    image.save()
    edited = bpy.data.images.load(str(path), check_existing=False)
    edited.colorspace_settings.name = image.colorspace_settings.name
    for node in ob.material_slots[0].material.node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.image == image:
            node.image = edited


def read_pixels(image):
    w, h = image.size
    px = np.empty(w * h * 4, dtype=np.float32)
    image.pixels.foreach_get(px)
    return px.reshape(h, w, 4)


def matte_finish(ob):
    """Remap the glTF metallic-roughness image (G roughness, B metal)."""
    tree = ob.material_slots[0].material.node_tree
    bsdf = next(n for n in tree.nodes if n.type == "BSDF_PRINCIPLED")
    mr = None
    node = bsdf.inputs["Roughness"].links[0].from_node if bsdf.inputs["Roughness"].links else None
    while node is not None and mr is None:  # walk back through the Separate Color node
        if node.type == "TEX_IMAGE":
            mr = node.image
        else:
            linked = [s for s in node.inputs if s.links]
            node = linked[0].links[0].from_node if linked else None
    if mr is None:
        print("finish: no metallic-roughness image; skipped")
        return
    px = read_pixels(mr)
    print("finish: roughness mean %.2f -> " % px[..., 1].mean(), end="")
    px[..., 1] = ROUGH_FLOOR + ROUGH_SCALE * px[..., 1]
    px[..., 2] *= METAL_SCALE
    print("%.2f, metal mean %.2f" % (px[..., 1].mean(), px[..., 2].mean()))
    save_edited(ob, mr, px, PKG / "source/HalcyonRifle_metalrough.png")


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    assert len(meshes) == 1, "expected one Meshy mesh, got %d" % len(meshes)
    ob = meshes[0]
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    xs = [v.co.x for v in ob.data.vertices]
    zs = [v.co.z for v in ob.data.vertices]
    body_tris = len(ob.data.polygons)
    print("source: %d triangles, x %.3f..%.3f, z %.3f..%.3f" % (body_tris, min(xs), max(xs), min(zs), max(zs)))

    # With PBR there are several image nodes; paint the one feeding Base Color.
    tree = ob.material_slots[0].material.node_tree
    bsdf = next(n for n in tree.nodes if n.type == "BSDF_PRINCIPLED")
    image = bsdf.inputs["Base Color"].links[0].from_node.image
    w, h = image.size
    px = read_pixels(image)
    smooth_cream(px)
    spots = free_swatches(ob, w, h, len(BARS))
    for (sx, sy), (_, _, _, rgb) in zip(spots, BARS):
        px[sy : sy + SWATCH, sx : sx + SWATCH, :3] = [c / 255 for c in rgb]
    save_edited(ob, image, px, TEXTURE_OUT)
    matte_finish(ob)

    bm = bmesh.new()
    bm.from_mesh(ob.data)
    uv_layer = bm.loops.layers.uv.active
    for (sx, sy), (name, x0, x1, _) in zip(spots, BARS):
        add_bar(bm, uv_layer, x0, x1, ((sx + SWATCH / 2) / w, (sy + SWATCH / 2) / h))
        print("strip: %s bar x %.3f..%.3f on swatch at pixel %d,%d" % (name, x0, x1, sx, sy))
    sx, sy = spots[0]  # cyan
    add_lens(bm, uv_layer, ((sx + SWATCH / 2) / w, (sy + SWATCH / 2) / h))
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
    bm.to_mesh(ob.data)
    bm.free()
    total = len(ob.data.polygons)
    print("mesh: body %d + strip %d = %d triangles" % (body_tris, total - body_tris, total))
    assert total <= MAX_TRIS, "over the held-role triangle budget"

    OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUT), export_format="GLB", use_selection=True, export_yup=True, export_apply=True,
        export_materials="EXPORT", export_image_format="AUTO",
    )
    print("wrote %s (%.2f MB)" % (OUT, OUT.stat().st_size / 1e6))


main()
