"""Clean the TRELLIS blue tube and put blue smoke in its glass chamber.

    blender -b -noaudio --python tools/blender/prepare_bluetube.py -- \
        --source SciFiTubes/bluetubelarge.glb --out SciFiTubes/bluetube_clean.glb

The generator produced the chamber's glass as an opaque pale wall, a cable tangle on the
floor, a flat plate, a bottle and loose wires, all as ~25,000 disconnected shards. This:

  1. deletes the floor clutter, stray wires and the opaque glass/bottle volume,
  2. adds a cylinder of "smoke" where the glass was, and
  3. paints one patch of the base-colour atlas bright cyan, in texture space the deleted
     glass freed up, and points the cylinder's UVs at it.

One mesh, one material, because scene_kit joins everything and Roblox needs it that way.
Coordinates are Blender's after glTF import (Z up), source proportions (the body is about
one unit tall). Tuned by looking at orthographic renders, so the numbers are measurements
of THIS file, not general rules.
"""
import argparse
import math
import sys

import bmesh
import bpy
import numpy as np

# Glass chamber, measured from the front and top orthographic renders.
GLASS_CX, GLASS_CY = -0.065, 0.04
GLASS_R = 0.25
FRAME_X = 0.125  # the machine frame starts here; nothing right of it is touched
GLASS_Z0, GLASS_Z1 = -0.355, 0.325
SMOKE_R = 0.215
BODY_CX, BODY_CY = -0.065, 0.04
BODY_R = 0.39  # the rings are about 0.36; anything further out is a dangling wire or debris
FLOOR_Z = -0.465  # everything flat on the floor: plate, cables, the dark strip
SMOKE_RGB = (0.20, 0.85, 1.00)


def argv():
    tail = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", required=True)
    ap.add_argument("--out", required=True)
    return ap.parse_args(tail)


def islands(bm):
    seen, island_of, info = set(), {}, []
    for v in bm.verts:
        if v.index in seen:
            continue
        stack, comp = [v], []
        seen.add(v.index)
        while stack:
            x = stack.pop()
            comp.append(x)
            for e in x.link_edges:
                o = e.other_vert(x)
                if o.index not in seen:
                    seen.add(o.index)
                    stack.append(o)
        for c in comp:
            island_of[c.index] = len(info)
        xs = [c.co.x for c in comp]
        ys = [c.co.y for c in comp]
        zs = [c.co.z for c in comp]
        info.append((min(xs), max(xs), min(ys), max(ys), min(zs), max(zs)))
    return island_of, info


def free_square(bm, uv, kill, grid=512, margin=3):
    """Largest empty square of the UV atlas, ignoring faces about to be deleted.

    Rasterises every surviving UV triangle onto a coarse grid, dilates it by `margin`
    cells, then finds the biggest all-empty square. Returns its centre and side in UV units."""
    occ = np.zeros((grid, grid), dtype=bool)
    for f in bm.faces:
        if f.index in kill:
            continue
        pts = np.array([tuple(l[uv].uv) for l in f.loops]) * grid
        lo = np.floor(pts.min(0)).astype(int).clip(0, grid - 1)
        hi = np.ceil(pts.max(0)).astype(int).clip(0, grid - 1)
        occ[lo[1]:hi[1] + 1, lo[0]:hi[0] + 1] = True  # bounding box: conservative, so safe
    for _ in range(margin):
        occ = occ | np.roll(occ, 1, 0) | np.roll(occ, -1, 0) | np.roll(occ, 1, 1) | np.roll(occ, -1, 1)
    best = (0, 0, 0)
    dp = np.zeros((grid, grid), dtype=np.int32)
    for y in range(grid):
        for x in range(grid):
            if occ[y, x]:
                dp[y, x] = 0
            elif y == 0 or x == 0:
                dp[y, x] = 1
            else:
                dp[y, x] = 1 + min(dp[y - 1, x], dp[y, x - 1], dp[y - 1, x - 1])
            if dp[y, x] > best[0]:
                best = (int(dp[y, x]), x, y)
    side, x, y = best
    return ((x - side / 2) / grid, (y - side / 2) / grid), side / grid


def main():
    args = argv()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=args.source)
    ob = [o for o in bpy.data.objects if o.type == "MESH"][0]
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    uv = bm.loops.layers.uv.active
    island_of, info = islands(bm)

    kill, why = set(), {}

    def mark(f, reason):
        kill.add(f.index)
        why[reason] = why.get(reason, 0) + 1

    for f in bm.faces:
        c = f.calc_center_median()
        rad = math.hypot(c.x - BODY_CX, c.y - BODY_CY)
        x0, x1, y0, y1, z0, z1 = info[island_of[f.verts[0].index]]
        if c.z < FLOOR_Z:
            mark(f, "floor clutter")
        elif rad > BODY_R and c.x < 0.30:
            mark(f, "outlier")
        elif c.x < FRAME_X and GLASS_Z0 - 0.02 < c.z < GLASS_Z1 - 0.01:
            # Between the two rings and left of the machine frame there is nothing worth
            # keeping: the opaque glass, a wire, a bottle and a second canister live here.
            mark(f, "chamber band")
        elif -0.27 < c.x < -0.07 and -0.42 < c.y < -0.18 and -0.48 < c.z < GLASS_Z0 + 0.01:
            mark(f, "bottle")

    print("REMOVED", why, "of", len(bm.faces))
    centre_uv, side_uv = free_square(bm, uv, kill)
    print("free atlas square: centre %.3f,%.3f side %.3f of the atlas" % (centre_uv[0], centre_uv[1], side_uv))

    bmesh.ops.delete(bm, geom=[bm.faces[i] for i in kill], context="FACES_ONLY")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")

    # Smoke cylinder, capped, with every UV on the patch centre.
    cx, cy = centre_uv
    seg = 48
    geom = bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=SMOKE_R, radius2=SMOKE_R,
                                 depth=GLASS_Z1 - GLASS_Z0 + 0.06)["verts"]
    bmesh.ops.translate(bm, verts=geom, vec=(GLASS_CX, GLASS_CY, (GLASS_Z0 + GLASS_Z1) / 2 + 0.005))
    for f in bm.faces:
        if all(v in geom for v in f.verts):
            for l in f.loops:
                l[uv].uv = (cx, cy)
    bm.to_mesh(ob.data)
    bm.free()

    # Paint the free square (inset, so filtering at the edge never reaches used texels).
    mat = ob.data.materials[0]
    img = next(n.image for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image and n.image.size[0] > 0)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    half = int(side_uv * w / 2 * 0.6)
    x0, y0 = int(cx * w) - half, int(cy * h) - half
    px[y0:y0 + 2 * half, x0:x0 + 2 * half] = (*SMOKE_RGB, 1.0)
    img.pixels = px.reshape(-1).tolist()
    print("painted a %dx%d px patch at (%d, %d) of %dx%d" % (2 * half, 2 * half, x0, y0, w, h))
    img.pack()

    bpy.ops.export_scene.gltf(filepath=args.out, export_format="GLB")


if __name__ == "__main__":
    main()
