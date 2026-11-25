"""Two defects the outline and hole checks cannot see, measured from the written GLB.

    python tools/surface_checks.py <export.glb>

  ground patch   Image-to-3D copies whatever the subject stands on: a slab of dirt, grass
                 or floor under the model. Measured as how much more of the footprint the
                 bottom slice of the model fills than the slice just above it. A crate
                 fills both equally; a tower on four legs standing on a copied patch of
                 ground fills the bottom and almost nothing above.

  texture bleed  Each texture is an atlas: islands of used pixels with unused background
                 between them. At a distance the game draws a shrunken copy of the atlas,
                 and every shrunken pixel near an island edge is a blend of surface and
                 background. If the background is a different brightness, the model
                 sparkles. Measured as the share of used pixels, in a copy shrunk eight
                 times, whose brightness moves by more than BLEED_STEP.

Neither needs Blender. Both return numbers; tools/asset_generate.py decides what they mean.
"""

import io
import json
import sys

import numpy as np
from PIL import Image, ImageDraw

import outline_check

SAMPLES = 200000
GRID = 48  # footprint cells per side
BOTTOM_SLICE = 0.04  # of the height
ABOVE_SLICE = (0.08, 0.25)
SHRINK = 8
BLEED_STEP = 0.12  # brightness change, 0-1, that reads as a speck


def surface_points(tris, count=SAMPLES, seed=7):
    """Random points spread evenly over the surface, so a big flat triangle counts by its area."""
    edge_a, edge_b = tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0]
    area = 0.5 * np.linalg.norm(np.cross(edge_a, edge_b), axis=1)
    total = float(area.sum())
    if total <= 0:
        return np.zeros((0, 3))
    rng = np.random.default_rng(seed)
    pick = rng.choice(len(tris), size=count, p=area / total)
    u, v = rng.random(count), rng.random(count)
    flip = u + v > 1
    u[flip], v[flip] = 1 - u[flip], 1 - v[flip]
    return tris[pick, 0] + edge_a[pick] * u[:, None] + edge_b[pick] * v[:, None]


def ground_patch(export):
    """How much of the footprint the bottom slice fills, against the slice above it. glTF is Y-up."""
    points = surface_points(outline_check.triangles(export))
    lo, hi = points.min(axis=0), points.max(axis=0)
    span = np.maximum(hi - lo, 1e-9)
    height = (points[:, 1] - lo[1]) / span[1]

    def filled(mask):
        chosen = points[mask]
        if not len(chosen):
            return 0.0
        cx = np.minimum(((chosen[:, 0] - lo[0]) / span[0] * GRID).astype(int), GRID - 1)
        cz = np.minimum(((chosen[:, 2] - lo[2]) / span[2] * GRID).astype(int), GRID - 1)
        cells = np.zeros((GRID, GRID), dtype=bool)
        cells[cx, cz] = True
        return float(cells.mean())

    bottom = filled(height <= BOTTOM_SLICE)
    above = filled((height >= ABOVE_SLICE[0]) & (height <= ABOVE_SLICE[1]))
    return {
        "bottomFill": round(bottom, 3),
        "aboveFill": round(above, 3),
        "ratio": round(bottom / max(above, 1e-3), 2),
        "footprintStuds": [round(float(span[0]), 2), round(float(span[2]), 2)],
    }


def _images(doc, blob):
    out = {}
    for index, image in enumerate(doc.get("images", [])):
        if "bufferView" not in image:
            continue
        view = doc["bufferViews"][image["bufferView"]]
        start = view.get("byteOffset", 0)
        try:
            out[index] = Image.open(io.BytesIO(blob[start : start + view["byteLength"]])).convert("RGB")
        except OSError:
            continue
    return out


def _box(values, factor):
    h, w = values.shape[0] // factor * factor, values.shape[1] // factor * factor
    return values[:h, :w].reshape(h // factor, factor, w // factor, factor).mean(axis=(1, 3))


def texture_bleed(export):
    """Worst atlas of the file: share of used pixels that change brightness when shrunk."""
    doc, blob = outline_check.read_glb(export)
    images = _images(doc, blob)
    masks = {}
    for mesh in doc.get("meshes", []):
        for prim in mesh["primitives"]:
            material = doc.get("materials", [{}])[prim["material"]] if "material" in prim else {}
            texture = material.get("pbrMetallicRoughness", {}).get("baseColorTexture")
            if texture is None or "TEXCOORD_0" not in prim["attributes"]:
                continue
            source = doc["textures"][texture["index"]].get("source")
            if source not in images:
                continue
            width, height = images[source].size
            if source not in masks:
                masks[source] = Image.new("L", (width, height), 0)
            uv = outline_check.accessor(doc, blob, prim["attributes"]["TEXCOORD_0"]).astype(np.float64)
            if "indices" in prim:
                order = outline_check.accessor(doc, blob, prim["indices"]).reshape(-1).astype(np.int64)
            else:
                order = np.arange(len(uv))
            corners = uv[order[: len(order) // 3 * 3]].reshape(-1, 3, 2) * (width, height)
            draw = ImageDraw.Draw(masks[source])
            for corner in corners:
                draw.polygon([tuple(p) for p in corner], fill=255, outline=255)
    worst = None
    for source, mask in masks.items():
        used = np.asarray(mask, dtype=np.float64) / 255.0
        pixels = np.asarray(images[source], dtype=np.float64) / 255.0
        brightness = pixels @ np.array([0.2126, 0.7152, 0.0722])
        share = _box(used, SHRINK)
        blended = _box(brightness, SHRINK)
        surface = _box(brightness * used, SHRINK) / np.maximum(share, 1e-6)
        counted = share > 0.25  # a shrunken pixel that is mostly background is rarely drawn
        if not counted.any():
            continue
        drift = np.abs(blended - surface)[counted]
        unused = used < 0.5
        result = {
            "image": source,
            "size": list(images[source].size),
            "usedShare": round(float(used.mean()), 3),
            "backgroundBrightness": round(float(brightness[unused].mean()), 3) if unused.any() else None,
            "surfaceBrightness": round(float(brightness[~unused].mean()), 3) if (~unused).any() else None,
            "bleedPercent": round(100.0 * float((drift > BLEED_STEP).mean()), 2),
        }
        if worst is None or result["bleedPercent"] > worst["bleedPercent"]:
            worst = result
    return worst or {"bleedPercent": 0.0, "image": None}


def main():
    for path in sys.argv[1:]:
        print(path)
        print("  ground  " + json.dumps(ground_patch(path)))
        print("  bleed   " + json.dumps(texture_bleed(path)))


if __name__ == "__main__":
    main()
