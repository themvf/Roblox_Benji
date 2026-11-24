"""Prepare the Lightning Carbine's Meshy mesh for the scan build. Blender 4.3, headless.

    blender -b -noaudio --python tools/blender/fix_lightning_carbine.py

Input:  assets/models/lightning-carbine/meshy/model.glb, Meshy's image-to-3d result remeshed by
        Meshy to 4,000 triangles with the texture baked onto that exact mesh.
        Tried and dropped (2026-11-22): the same task remeshed at 30,000 and collapsed here to
        3,700. Blender's collapse melted the hard edges into blobs, raised spikes on the muzzle
        and smeared the paint across Meshy's UV charts. Meshy's own low remesh is the base.
Output: assets/models/lightning-carbine/source/LightningCarbine.glb, which `asset_generate.py
        build` then turns, scales, centres and splits. It stays under the brief's decimate
        target, so the build never decimates it (and never crumples the bolt).

What it changes, in order:
  1. Texture: the copper rails are brightened toward the concept's copper, and the olive-brown
     dirt streaks inside the yellow paint are filled from the clean yellow around them. Near-black
     panel lines, vents and screws are left alone (they are darker and greyer than the dirt).
  2. Mesh: the crumpled silver sheet Meshy made of the concept's lightning is cut out of the coil
     gap (every face whose centre is inside the gap, clear of the two tubes' facing surfaces).
  3. Lightning: a jagged bolt with three forks is added in the open gap between the rails, from
     the receiver face to the muzzle housing, UV-mapped to an electric-blue swatch painted into
     an unused corner of the atlas. The brief's `scene.split` cuts every face of that colour into
     its own "Arc" mesh, so Studio can make it Neon (and game code can flicker it).

Frame: Meshy's glTF is X-long, Y-up; after import Blender has X along the gun (muzzle at -X),
Z up, and the gun's width on Y. Numbers below are in Meshy units (the gun is 1.9 long).
"""

import math
import random
from pathlib import Path

import bmesh
import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/lightning-carbine"
SOURCE = PKG / "meshy/model.glb"
OUT = PKG / "source/LightningCarbine.glb"
TEXTURE_OUT = PKG / "source/LightningCarbine_texture.png"

MAX_TRIS = 3880  # the brief's scene.decimate: stay at or under it so the build leaves the mesh alone
# The open gap between the two coil tubes, measured on Meshy face centres.
GAP_REAR_X, GAP_FRONT_X = -0.318, -0.842  # receiver face, muzzle housing face
GAP_LOW_Z, GAP_HIGH_Z = 0.030, 0.126
# The foil sheet: faces centred in the gap's middle band, away from both tube surfaces.
SHEET_X = (-0.835, -0.325)
SHEET_Z = (0.040, 0.116)
SHEET_HALF_Y = 0.07
# Past the box, the sheet's leftover faces are told apart by their grey-white paint.
FOIL_X = (-0.86, -0.18)
FOIL_MIN_VAL, FOIL_MAX_CHROMA = 0.45, 0.08
PLATE_INSET, PLATE_HALF_Y = 0.004, 0.045
ARC_RGB = (140, 215, 255)  # hue 201, sat 0.45, val 1.0: matched by scene.split in brief.json
SWATCH = 12  # pixels


def rgb_to_hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    mx, mn = rgb.max(-1), rgb.min(-1)
    d = mx - mn
    h = np.zeros_like(mx)
    nz = d > 1e-6
    rm = nz & (mx == r)
    gm = nz & (mx == g) & ~rm
    bm_ = nz & ~rm & ~gm
    h[rm] = ((g - b)[rm] / d[rm]) % 6
    h[gm] = (b - r)[gm] / d[gm] + 2
    h[bm_] = (r - g)[bm_] / d[bm_] + 4
    h *= 60
    s = np.where(mx > 1e-6, d / np.maximum(mx, 1e-6), 0)
    return h, s, mx


def hsv_to_rgb(h, s, v):
    c = v * s
    hp = (h % 360) / 60
    x = c * (1 - np.abs(hp % 2 - 1))
    z = np.zeros_like(h)
    sector = np.floor(hp).astype(int)
    out = np.stack(
        [np.select([sector == k for k in range(6)], vals) for vals in (
            [c, x, z, z, x, c],
            [x, c, c, x, z, z],
            [z, z, x, c, c, x],
        )],
        -1,
    )
    return out + (v - c)[..., None]


def box(a, r, op):
    """Separable box max (op=np.maximum) or sum (op=np.add) of radius r. Edges wrap, which is
    harmless here: no paint chart touches the atlas border."""
    out = a
    for axis in (0, 1):
        res = out.copy()
        for k in range(1, r + 1):
            res = op(res, np.roll(out, k, axis))
            res = op(res, np.roll(out, -k, axis))
        out = res
    return out


def clean_texture(image):
    w, h = image.size
    px = np.empty(w * h * 4, dtype=np.float32)
    image.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    rgb = px[..., :3].astype(np.float64)
    hue, sat, val = rgb_to_hsv(rgb)

    # 1. Dirt in the yellow paint: fill from the clean yellow within a few pixels.
    clean = (hue >= 40) & (hue <= 56) & (sat > 0.6) & (val > 0.75)
    near = box(clean.astype(np.float32), 6, np.maximum) > 0
    dirty = near & ~clean & (hue >= 28) & (hue <= 62) & (sat > 0.25) & (val > 0.3)
    weight = box(clean.astype(np.float64), 8, np.add)
    fill = np.stack([box(rgb[..., i] * clean, 8, np.add) for i in range(3)], -1) / np.maximum(weight, 1)[..., None]
    fixable = dirty & (weight > 4)
    rgb[fixable] = fill[fixable]
    print("texture: %d dirty yellow pixels filled" % int(fixable.sum()))

    # 2. Copper: brighter and a little more saturated, pulled toward the concept's hue.
    hue, sat, val = rgb_to_hsv(rgb)
    copper = (hue >= 10) & (hue <= 35) & (sat >= 0.3) & (sat <= 0.9) & (val >= 0.18) & (val <= 0.75)
    nh = hue * 0.6 + 22 * 0.4
    ns = np.minimum(1.0, sat * 1.12)
    nv = np.minimum(0.95, val * 1.55 + 0.04)
    rgb[copper] = hsv_to_rgb(nh, ns, nv)[copper]
    print("texture: %d copper pixels brightened" % int(copper.sum()))

    px[..., :3] = np.clip(rgb, 0, 1)
    return px, w, h


def free_swatch(ob, w, h):
    """A SWATCH-pixel square that no face's UVs reach, scanned from the top-right corner."""
    me = ob.data
    uv = me.uv_layers.active.data
    taken = np.zeros((h // SWATCH + 1, w // SWATCH + 1), dtype=bool)
    for poly in me.polygons:
        us = [uv[i].uv.x * w for i in poly.loop_indices]
        vs = [uv[i].uv.y * h for i in poly.loop_indices]
        x0, x1 = int(min(us)) // SWATCH, int(max(us)) // SWATCH
        y0, y1 = int(min(vs)) // SWATCH, int(max(vs)) // SWATCH
        taken[max(0, y0) : y1 + 1, max(0, x0) : x1 + 1] = True
    for gy in range(taken.shape[0] - 2, -1, -1):
        for gx in range(taken.shape[1] - 2, -1, -1):
            if not taken[gy, gx]:
                return gx * SWATCH, gy * SWATCH
    raise SystemExit("no free swatch in the atlas")


def bolt_paths(rng):
    """Main bolt from the receiver face to the muzzle housing, plus three forks."""
    mid = (GAP_LOW_Z + GAP_HIGH_Z) / 2
    amp = (GAP_HIGH_Z - GAP_LOW_Z) / 2 - 0.016
    n = 14
    main = []
    for i in range(n):
        t = i / (n - 1)
        x = GAP_REAR_X + (GAP_FRONT_X - GAP_REAR_X) * t
        # Ends sit on the gap's centre line, where the arc meets each electrode face.
        swing = 0.0 if i in (0, n - 1) else rng.uniform(-amp, amp) * (0.55 if i in (1, n - 2) else 1.0)
        main.append((x + (rng.uniform(-0.008, 0.008) if 0 < i < n - 1 else 0), rng.uniform(-0.01, 0.01), mid + swing))
    forks = []
    for start in (3, 7, 10):
        x, y, z = main[start]
        up = 1 if z < mid else -1
        pts = [(x, y, z)]
        for k in range(1, 4):
            x -= rng.uniform(0.025, 0.04)
            z += up * rng.uniform(0.008, 0.016) * (1 if k != 2 else -0.6)
            z = min(max(z, GAP_LOW_Z + 0.01), GAP_HIGH_Z - 0.01)
            pts.append((x, y + rng.uniform(-0.008, 0.008), z))
        forks.append(pts)
    return main, forks


def add_tube(bm, uv_layer, points, half_z, half_y, uv):
    """A closed diamond-section tube through points, every corner on the arc swatch."""
    rings = []
    for i, (x, y, z) in enumerate(points):
        taper = 1.0 if 0 < i < len(points) - 1 else 0.55
        hz, hy = half_z * taper, half_y * taper
        rings.append([bm.verts.new(p) for p in ((x, y, z - hz), (x, y + hy, z), (x, y, z + hz), (x, y - hy, z))])
    faces = []
    for r0, r1 in zip(rings, rings[1:]):
        for k in range(4):
            j = (k + 1) % 4
            faces.append(bm.faces.new((r0[k], r0[j], r1[j], r1[k])))
    faces.append(bm.faces.new(rings[0]))
    faces.append(bm.faces.new(list(reversed(rings[-1]))))
    bmesh.ops.recalc_face_normals(bm, faces=faces)
    for face in faces:
        face.material_index = 0
        for loop in face.loops:
            loop[uv_layer].uv = uv
    return faces


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
    print("source: %d triangles, x %.3f..%.3f, z %.3f..%.3f" % (len(ob.data.polygons), min(xs), max(xs), min(zs), max(zs)))

    image = next(n.image for n in ob.material_slots[0].material.node_tree.nodes if n.type == "TEX_IMAGE" and n.image)
    px, w, h = clean_texture(image)

    # Cut Meshy's foil sheet out of the coil gap.
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    uv_layer = bm.loops.layers.uv.active
    sheet = []
    for face in bm.faces:
        c = face.calc_center_median()
        if SHEET_X[0] < c.x < SHEET_X[1] and SHEET_Z[0] < c.z < SHEET_Z[1] and abs(c.y) < SHEET_HALF_Y:
            sheet.append(face)
        elif FOIL_X[0] < c.x < FOIL_X[1] and GAP_LOW_Z - 0.01 < c.z < GAP_HIGH_Z + 0.01 and abs(c.y) < SHEET_HALF_Y:
            # The sheet's ends: a sliver at the muzzle housing and a strip that runs on into the
            # receiver. Cut by colour, so the dark housing and copper rails beside them stay.
            u = sum(lp[uv_layer].uv.x for lp in face.loops) / len(face.loops)
            v = sum(lp[uv_layer].uv.y for lp in face.loops) / len(face.loops)
            r, g, b = px[min(int(v * h), h - 1), min(int(u * w), w - 1), :3]
            if max(r, g, b) > FOIL_MIN_VAL and max(r, g, b) - min(r, g, b) < FOIL_MAX_CHROMA:
                sheet.append(face)
    bmesh.ops.delete(bm, geom=sheet, context="FACES")
    # The sheet plugged a window in the muzzle housing's back face and the receiver's front face.
    # Close both with a plate just inside the face, painted with the housing's own dark grey.
    dark_uv = None
    for face in bm.faces:
        c = face.calc_center_median()
        if -0.87 < c.x < -0.84 and abs(c.y) < 0.04 and face.is_valid:
            u = sum(lp[uv_layer].uv.x for lp in face.loops) / len(face.loops)
            v = sum(lp[uv_layer].uv.y for lp in face.loops) / len(face.loops)
            if max(px[min(int(v * h), h - 1), min(int(u * w), w - 1), :3]) < 0.12:
                dark_uv = (u, v)
                break
    assert dark_uv, "no dark housing face found to paint the plates"
    # Each plate is two faces back to back, since the hollow muzzle housing shows its far side.
    plates = []
    for x, facing in ((GAP_FRONT_X - PLATE_INSET, 1), (GAP_REAR_X + PLATE_INSET, -1)):
        plates += [(x, facing), (x - 0.003 * facing, -facing)]
    for x, facing in plates:
        lo, hi = GAP_LOW_Z + 0.005, GAP_HIGH_Z - 0.005
        corners = [(x, -PLATE_HALF_Y, lo), (x, PLATE_HALF_Y, lo), (x, PLATE_HALF_Y, hi), (x, -PLATE_HALF_Y, hi)]
        if facing < 0:
            corners.reverse()
        plate = bm.faces.new([bm.verts.new(p) for p in corners])
        plate.normal_update()
        assert plate.normal.x * facing > 0.9, "plate faces the wrong way"
        for loop in plate.loops:
            loop[uv_layer].uv = dark_uv
    bm.to_mesh(ob.data)
    bm.free()
    body_tris = len(ob.data.polygons)
    print("mesh: cut %d foil faces from the coil gap; closed both ends" % len(sheet))

    # Paint the arc swatch where no face samples, then add the bolt mapped onto it.
    sx, sy = free_swatch(ob, w, h)
    px[sy : sy + SWATCH, sx : sx + SWATCH, :3] = [c / 255 for c in ARC_RGB]
    image.pixels.foreach_set(px.ravel())
    TEXTURE_OUT.parent.mkdir(parents=True, exist_ok=True)
    image.filepath_raw = str(TEXTURE_OUT)
    image.file_format = "PNG"
    image.save()
    # The glTF importer packs the original image, and the exporter writes that packed copy, not
    # the edited pixels. Point the material at the saved PNG instead.
    edited = bpy.data.images.load(str(TEXTURE_OUT), check_existing=False)
    for node in ob.material_slots[0].material.node_tree.nodes:
        if node.type == "TEX_IMAGE" and node.image == image:
            node.image = edited
    uv =((sx + SWATCH / 2) / w, (sy + SWATCH / 2) / h)

    bm = bmesh.new()
    bm.from_mesh(ob.data)
    uv_layer = bm.loops.layers.uv.active
    main_path, forks = bolt_paths(random.Random(7))
    add_tube(bm, uv_layer, main_path, 0.0135, 0.012, uv)
    for fork in forks:
        add_tube(bm, uv_layer, fork, 0.008, 0.0075, uv)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 3])
    bm.to_mesh(ob.data)
    bm.free()
    total = len(ob.data.polygons)
    print("mesh: body %d + arc %d = %d triangles; arc swatch at pixel %d,%d" % (body_tris, total - body_tris, total, sx, sy))
    assert total <= MAX_TRIS, "over the build's decimate target; the build would decimate the bolt"

    OUT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(OUT), export_format="GLB", use_selection=True, export_yup=True, export_apply=True,
        export_materials="EXPORT", export_image_format="AUTO",
    )
    print("wrote %s (%.2f MB)" % (OUT, OUT.stat().st_size / 1e6))


main()
