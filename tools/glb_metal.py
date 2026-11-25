"""Give a generated GLB's metal parts their shine back: gold (or any hue band) becomes metal.

    python tools/glb_metal.py <in.glb> <out.glb> [--hue 20,65] [--warm 42] [--saturate 1.8]
        [--metal-rough 0.3] [--paint-rough 0.4] [--preview mask.png]

Image-to-3D services (Meshy without PBR) return one baked base-colour texture with metal 0 and
roughness 0.8, so polished gold comes out as matte cream (the Gilded Derringer). This finds the
metal in the colour texture by hue, saturation and brightness, nudges its colour toward the
metal's own hue (a metal's base colour is its reflection tint, and pale cream at metal 1 reads
as silver), and adds a glTF metallicRoughness texture: metal 1 at `--metal-rough` there, metal 0
at `--paint-rough` everywhere else (lacquer, wood, grips). Run it on the package's source GLB
before `asset_generate.py build`, so a rebuild keeps it; the Roblox importer turns the maps
into a SurfaceAppearance.

The input must already be decoded (no meshopt/draco) with an embedded base-colour image.
"""

import argparse
import io
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parent))
import outline_check  # noqa: E402  (read_glb)
from glb_matte import _write  # noqa: E402


def rgb_to_hsv(rgb):
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    top, low = rgb.max(-1), rgb.min(-1)
    span = top - low
    safe = np.where(span == 0, 1, span)
    hue = np.where(
        top == r, ((g - b) / safe) % 6, np.where(top == g, (b - r) / safe + 2, (r - g) / safe + 4)
    )
    hue = np.where(span == 0, 0, hue) * 60.0
    sat = np.where(top == 0, 0, span / np.where(top == 0, 1, top))
    return hue, sat, top


def hsv_to_rgb(hue, sat, val):
    c = val * sat
    h = (hue / 60.0) % 6
    x = c * (1 - np.abs(h % 2 - 1))
    zero = np.zeros_like(c)
    sector = np.floor(h).astype(int)
    table = [(c, x, zero), (x, c, zero), (zero, c, x), (zero, x, c), (x, zero, c), (c, zero, x)]
    out = np.zeros(hue.shape + (3,))
    for i, (r, g, b) in enumerate(table):
        pick = sector == i
        out[pick] = np.stack([r[pick], g[pick], b[pick]], -1)
    return out + (val - c)[..., None]


def image_bytes(doc, blob, index):
    view = doc["bufferViews"][doc["images"][index]["bufferView"]]
    start = view.get("byteOffset", 0)
    return blob[start : start + view["byteLength"]]


def gild(src, out, hue_band=(20, 65), warm=42.0, saturate=1.8, metal_rough=0.3, paint_rough=0.4, preview=None):
    """Returns the fraction of texels made metal."""
    doc, blob = outline_check.read_glb(src)
    if len(doc.get("materials", [])) != 1:
        raise SystemExit("expected one material; this tool reads one base-colour texture")
    pbr = doc["materials"][0].setdefault("pbrMetallicRoughness", {})
    if "baseColorTexture" not in pbr:
        raise SystemExit("no base-colour texture to read the metal from")
    colour_index = doc["textures"][pbr["baseColorTexture"]["index"]]["source"]
    colour_image = doc["images"][colour_index]
    picture = Image.open(io.BytesIO(image_bytes(doc, blob, colour_index))).convert("RGB")
    rgb = np.asarray(picture).astype(float) / 255.0
    hue, sat, val = rgb_to_hsv(rgb)

    metal = (hue >= hue_band[0]) & (hue <= hue_band[1]) & (sat > 0.12) & (val > 0.35)
    # soften the edge a texel or two so the mask does not alias along UV seams
    soft = Image.fromarray((metal * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2))
    weight = np.asarray(soft).astype(float) / 255.0

    gold_sat = np.clip(sat * saturate, 0, 0.62)
    gold = hsv_to_rgb(np.full_like(hue, warm), gold_sat, np.clip(val * 0.97, 0, 1))
    new_rgb = rgb * (1 - weight[..., None]) + gold * weight[..., None]
    colour = Image.fromarray((np.clip(new_rgb, 0, 1) * 255).astype(np.uint8))

    mr = np.zeros(rgb.shape, dtype=np.uint8)
    mr[..., 0] = 255  # occlusion unused
    mr[..., 1] = np.round((paint_rough + (metal_rough - paint_rough) * weight) * 255).astype(np.uint8)
    mr[..., 2] = np.round(weight * 255).astype(np.uint8)

    replaced = {}
    buffer = io.BytesIO()
    if colour_image.get("mimeType") == "image/png":
        colour.save(buffer, format="PNG", optimize=True)
    else:
        colour.save(buffer, format="JPEG", quality=92)
        colour_image["mimeType"] = "image/jpeg"
    replaced[colour_image["bufferView"]] = buffer.getvalue()

    buffer = io.BytesIO()
    Image.fromarray(mr).save(buffer, format="PNG", optimize=True)
    doc["bufferViews"].append({"buffer": 0, "byteOffset": 0, "byteLength": 0})
    replaced[len(doc["bufferViews"]) - 1] = buffer.getvalue()
    doc["images"].append({"bufferView": len(doc["bufferViews"]) - 1, "mimeType": "image/png", "name": "metal_rough"})
    texture = {"source": len(doc["images"]) - 1}
    sampler = doc["textures"][pbr["baseColorTexture"]["index"]].get("sampler")
    if sampler is not None:
        texture["sampler"] = sampler
    doc["textures"].append(texture)
    pbr["metallicRoughnessTexture"] = {"index": len(doc["textures"]) - 1}
    pbr["metallicFactor"], pbr["roughnessFactor"] = 1.0, 1.0

    _write(doc, blob, replaced, out)
    if preview:
        Image.fromarray(mr[..., 2]).save(preview)
    return float(weight.mean())


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--hue", default="20,65", help="hue band in degrees that is metal")
    ap.add_argument("--warm", type=float, default=42.0, help="hue the metal is tinted to")
    ap.add_argument("--saturate", type=float, default=1.8, help="saturation multiplier on the metal")
    ap.add_argument("--metal-rough", type=float, default=0.3)
    ap.add_argument("--paint-rough", type=float, default=0.4)
    ap.add_argument("--preview", help="write the metal mask as a PNG")
    a = ap.parse_args()
    low, high = (float(v) for v in a.hue.split(","))
    share = gild(a.src, a.out, (low, high), a.warm, a.saturate, a.metal_rough, a.paint_rough, a.preview)
    print(f"metal on {share:.0%} of the texture; wrote {a.out}")


if __name__ == "__main__":
    main()
