"""Does a reduced model still have the outline of the model it was made from?

    python tools/outline_check.py <source.glb> <export.glb> [--min 0.9] [--sheet out.png]

Every other asset check asks whether Roblox will accept the file. None asks whether
the result still looks like the source, and that is how a wave runner cut from 291,000
triangles to 9,000 passed every gate while full of holes. This draws both models as
flat silhouettes from the front, side and top and scores how much they overlap
(intersection over union: 1.0 is identical, holes and torn edges pull it down).

Outlines alone turned out too forgiving: a hole in a hull is filled in by the far
side, and the wave runner's worst build still scored 0.947. So it also compares
nearest-surface depth from six sides and reports surface error, the share of the
source's visible surface the export gets wrong. That separates them: the build that
looked right scores 0.040, the crumpled one 0.231, the one full of holes 0.347.

Exit status is 1 when the worst outline is under --min or, with --max-error, when
the worst surface error is over it, so it works as a gate. tools/asset_generate.py
build applies it with a 0.15 ceiling.

What it cannot see: a surface that keeps its shape but looks lumpy up close, and
anything Roblox does to the mesh after import. Those still need eyes.

No Blender. Reads the GLB with the standard library plus numpy and Pillow, and draws
both models at the same scale relative to their own bounding box, so a source in
generator units and an export in studs compare directly.
"""

import argparse
import json
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw

SIZE = 256  # canvas edge in pixels; outlines are compared at this resolution
COMPONENT = {5120: "i1", 5121: "u1", 5122: "<i2", 5123: "<u2", 5125: "<u4", 5126: "<f4"}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}
# Each view: the two axes drawn across and up the canvas. glTF is Y-up.
VIEWS = {"front": (0, 1), "side": (2, 1), "top": (0, 2)}


def read_glb(path):
    with open(path, "rb") as handle:
        magic, _, _ = struct.unpack("<4sII", handle.read(12))
        if magic != b"glTF":
            raise ValueError(f"{path} is not a binary glTF file")
        length, _ = struct.unpack("<II", handle.read(8))
        doc = json.loads(handle.read(length))
        length, _ = struct.unpack("<II", handle.read(8))
        blob = handle.read(length)
    return doc, blob


def accessor(doc, blob, index):
    acc = doc["accessors"][index]
    view = doc["bufferViews"][acc["bufferView"]]
    dtype = np.dtype(COMPONENT[acc["componentType"]])
    width = WIDTH[acc["type"]]
    start = view.get("byteOffset", 0) + acc.get("byteOffset", 0)
    stride = view.get("byteStride") or dtype.itemsize * width
    raw = np.frombuffer(blob, dtype=np.uint8, count=stride * (acc["count"] - 1) + dtype.itemsize * width, offset=start)
    rows = np.lib.stride_tricks.as_strided(raw, shape=(acc["count"], dtype.itemsize * width), strides=(stride, 1))
    return np.ascontiguousarray(rows).view(dtype).reshape(acc["count"], width)


def node_matrix(node):
    if "matrix" in node:
        return np.array(node["matrix"], dtype=np.float64).reshape(4, 4).T
    matrix = np.eye(4)
    sx, sy, sz = node.get("scale", (1, 1, 1))
    x, y, z, w = node.get("rotation", (0, 0, 0, 1))
    rotation = np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ])
    matrix[:3, :3] = rotation * np.array([sx, sy, sz])
    matrix[:3, 3] = node.get("translation", (0, 0, 0))
    return matrix


def triangles(path):
    """Every triangle in the file, in world space, as an (n, 3, 3) array."""
    doc, blob = read_glb(path)
    nodes = doc.get("nodes", [])
    scene = doc.get("scenes", [{}])[doc.get("scene", 0)]
    out = []

    def walk(index, parent):
        node = nodes[index]
        world = parent @ node_matrix(node)
        if "mesh" in node:
            for prim in doc["meshes"][node["mesh"]]["primitives"]:
                if prim.get("mode", 4) != 4:
                    continue
                points = accessor(doc, blob, prim["attributes"]["POSITION"]).astype(np.float64)
                points = points @ world[:3, :3].T + world[:3, 3]
                if "indices" in prim:
                    order = accessor(doc, blob, prim["indices"]).reshape(-1).astype(np.int64)
                else:
                    order = np.arange(len(points))
                out.append(points[order[: len(order) // 3 * 3]].reshape(-1, 3, 3))
        for child in node.get("children", []):
            walk(child, world)

    for root in scene.get("nodes", range(len(nodes))):
        walk(root, np.eye(4))
    if not out:
        raise ValueError(f"{path} holds no triangles")
    return np.concatenate(out)


def silhouettes(tris):
    """One filled mask per view, drawn to fit the model's own bounding box."""
    flat = tris.reshape(-1, 3)
    low, high = flat.min(0), flat.max(0)
    span = float((high - low).max()) or 1.0
    scale = (SIZE - 8) / span
    masks = {}
    for name, (across, up) in VIEWS.items():
        image = Image.new("1", (SIZE, SIZE), 0)
        draw = ImageDraw.Draw(image)
        xs = (tris[:, :, across] - (low[across] + high[across]) / 2) * scale + SIZE / 2
        ys = SIZE / 2 - (tris[:, :, up] - (low[up] + high[up]) / 2) * scale
        for (x0, x1, x2), (y0, y1, y2) in zip(xs.tolist(), ys.tolist()):
            draw.polygon(((x0, y0), (x1, y1), (x2, y2)), fill=1)
        masks[name] = np.asarray(image, dtype=bool)
    return masks


def compare(source, export):
    """{view: overlap score} for two GLB paths, plus the masks for a sheet."""
    a, b = silhouettes(triangles(source)), silhouettes(triangles(export))
    scores = {}
    for name in VIEWS:
        union = np.logical_or(a[name], b[name]).sum()
        scores[name] = float(np.logical_and(a[name], b[name]).sum() / union) if union else 1.0
    return scores, a, b


# Surface points per model. 600,000 was too few: on a model with much hidden or layered
# surface, a pixel often got no point from its nearest face and read through to the one
# behind. A sculpture scored 0.272 against its export and 0.265 against ITSELF, and three
# sound builds were waived past the gate. Measured 2026-11-16 at 4,000,000: self-noise
# 0.000-0.006 on six models; sculpture 0.016, cabinet wall 0.036 (was 0.388), sofa 0.012,
# wave runner 0.029, Black Hawk 0.035, and the torn radio tower still 0.109.
SAMPLES = 4_000_000
DEPTH_TOLERANCE = 0.015  # of the model's longest side: closer than this counts as the same surface
# Each depth view: across axis, up axis, depth axis, and which way the camera looks along it.
DEPTH_VIEWS = {
    "front": (0, 1, 2, 1), "back": (0, 1, 2, -1),
    "right": (2, 1, 0, 1), "left": (2, 1, 0, -1),
    "top": (0, 2, 1, 1), "bottom": (0, 2, 1, -1),
}


NOISE_SEED = 11  # a second scattering of the source, to check the measure against itself


def depth_maps(tris, seed=7):
    """Nearest-surface depth from six sides, by scattering points over the surface.

    A silhouette cannot see a hole in a hull, because the far side fills it in. Depth
    can: through a hole the nearest surface is suddenly the far wall. Depths are in
    units of the model's longest side, so two scales compare directly.
    """
    rng = np.random.default_rng(seed)  # fixed seed: the same file always scores the same
    edge1, edge2 = tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0]
    area = np.linalg.norm(np.cross(edge1, edge2), axis=1)
    pick = rng.choice(len(tris), size=SAMPLES, p=area / area.sum())
    u, v = rng.random(SAMPLES), rng.random(SAMPLES)
    flip = u + v > 1
    u[flip], v[flip] = 1 - u[flip], 1 - v[flip]
    points = tris[pick, 0] + edge1[pick] * u[:, None] + edge2[pick] * v[:, None]

    flat = tris.reshape(-1, 3)
    low, high = flat.min(0), flat.max(0)
    span = float((high - low).max()) or 1.0
    unit = (points - (low + high) / 2) / span  # every axis now within -0.5 .. 0.5
    maps = {}
    for name, (across, up, deep, sign) in DEPTH_VIEWS.items():
        col = np.clip(((unit[:, across] + 0.5) * (SIZE - 1)).astype(int), 0, SIZE - 1)
        row = np.clip(((0.5 - unit[:, up]) * (SIZE - 1)).astype(int), 0, SIZE - 1)
        nearest = np.full(SIZE * SIZE, -np.inf)
        np.maximum.at(nearest, row * SIZE + col, unit[:, deep] * sign)
        maps[name] = nearest.reshape(SIZE, SIZE)
    return maps


def surface_measure(source, export):
    """{view: {"error", "noise"}} for an export against its source.

    error: share of the source's visible surface the export gets wrong (missing, or nearer
    or farther than DEPTH_TOLERANCE). 0.0 is a perfect copy; holes, torn faces and
    collapsed detail all raise it.

    noise: the same score for the source against a second scattering of itself. It should
    be near zero. If it is not, the measure is short of points for this model and the
    error cannot be trusted; raise SAMPLES.
    """
    source_tris = triangles(source)
    a, again, b = depth_maps(source_tris), depth_maps(source_tris, NOISE_SEED), depth_maps(triangles(export))
    out = {}
    for name in DEPTH_VIEWS:
        seen = np.isfinite(a[name])
        total = max(seen.sum(), 1)
        with np.errstate(invalid="ignore"):
            out[name] = {
                "error": float((seen & ~(np.abs(a[name] - b[name]) <= DEPTH_TOLERANCE)).sum() / total),
                "noise": float((seen & ~(np.abs(a[name] - again[name]) <= DEPTH_TOLERANCE)).sum() / total),
            }
    return out


def surface_error(source, export):
    """{view: error} from surface_measure, for callers that only want the score."""
    return {name: found["error"] for name, found in surface_measure(source, export).items()}


def sheet(path, a, b):
    """Source outline, export outline and their difference, one row per view.

    In the difference, red is source the export lost and blue is export the source
    never had (spikes, torn faces).
    """
    out = Image.new("RGB", (SIZE * 3, SIZE * len(VIEWS)), "white")
    for row, name in enumerate(VIEWS):
        for col, mask in enumerate((a[name], b[name])):
            out.paste(Image.fromarray(np.where(mask, 60, 255).astype(np.uint8)).convert("RGB"), (col * SIZE, row * SIZE))
        diff = np.full((SIZE, SIZE, 3), 255, dtype=np.uint8)
        diff[a[name] & b[name]] = (200, 200, 200)
        diff[a[name] & ~b[name]] = (210, 50, 40)
        diff[~a[name] & b[name]] = (40, 90, 210)
        out.paste(Image.fromarray(diff), (2 * SIZE, row * SIZE))
    out.save(path)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("source")
    ap.add_argument("export")
    ap.add_argument("--min", type=float, default=0.9, help="lowest acceptable overlap in any view (default 0.9)")
    ap.add_argument("--max-error", type=float, default=None, help="highest acceptable surface error in any view")
    ap.add_argument("--sheet", help="write a source / export / difference image here")
    args = ap.parse_args()
    scores, a, b = compare(args.source, args.export)
    for name, score in scores.items():
        print(f"  outline  {name:<6} {score:.3f}")
    if args.sheet:
        sheet(args.sheet, a, b)
    errors = surface_error(args.source, args.export)
    print("  surface  " + "  ".join(f"{name} {value:.3f}" for name, value in errors.items()))
    print(f"  surface error: worst {max(errors.values()):.3f}, mean {sum(errors.values()) / len(errors):.3f}")
    if args.max_error is not None and max(errors.values()) > args.max_error:
        print(f"  FAIL surface error {max(errors.values()):.3f} is over {args.max_error}: detail was lost")
        sys.exit(1)
    worst = min(scores.values())
    if worst < args.min:
        print(f"  FAIL outline overlap {worst:.3f} is under {args.min}: the reduction changed the shape")
        sys.exit(1)
    print(f"  outline ok (worst view {worst:.3f}, floor {args.min})")


if __name__ == "__main__":
    main()
