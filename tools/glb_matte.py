"""Take the shine off a GLB: rewrite every metallic-roughness texture to rough and non-metal.

    python tools/glb_matte.py <in.glb> <out.glb> [roughness 0-1, default 0.85]

Generators (Tripo especially) export armour and car paint as near-mirror metal: the red SUV
came in at roughness 0.19 / metal 0.48, the armored vehicle 0.08 / 0.78, the knight helmet
0.11 / 0.79. Under Roblox lighting that reads as plastic chrome. glTF keeps roughness in
the green channel and metalness in the blue; the colour and bump textures are left alone,
so the model keeps its painted detail and loses only the shine. A little of the original
roughness variation is kept so different materials still differ.

The input must already be decoded (no meshopt/draco); `asset_generate.py import` and
`kit_look.py intake` decode first.
"""
import io
import base64
import json
import struct
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import outline_check  # noqa: E402  (read_glb)

KEEP_VARIATION = 0.15


def matte(src, out, rough=0.85):
    """Returns (mean roughness, mean metal) of the texture before the change, or None."""
    doc, blob = outline_check.read_glb(src)
    targets, before = set(), None
    for material in doc.get("materials", []):
        pbr = material.setdefault("pbrMetallicRoughness", {})
        pbr["roughnessFactor"], pbr["metallicFactor"] = 1.0, 1.0
        if "metallicRoughnessTexture" in pbr:
            targets.add(doc["textures"][pbr["metallicRoughnessTexture"]["index"]]["source"])
        else:
            pbr["roughnessFactor"], pbr["metallicFactor"] = rough, 0.0
    replaced = {}
    for index in targets:
        image = doc["images"][index]
        if "bufferView" in image:
            view = doc["bufferViews"][image["bufferView"]]
            start = view.get("byteOffset", 0)
            data = blob[start:start + view["byteLength"]]
            kind = {"image/png": "PNG", "image/jpeg": "JPEG", "image/webp": "WEBP"}[image["mimeType"]]
        else:
            uri = image.get("uri", "")
            if not uri.startswith("data:") or ";base64," not in uri:
                raise ValueError("GLB image must be embedded in a buffer view or base64 data URI")
            data = base64.b64decode(uri.split(",", 1)[1], validate=True)
            kind = Image.open(io.BytesIO(data)).format
            if kind not in ("PNG", "JPEG", "WEBP"):
                raise ValueError(f"Unsupported embedded image format: {kind}")
        pixels = np.asarray(Image.open(io.BytesIO(data)).convert("RGB")).copy()
        before = (pixels[..., 1].mean() / 255, pixels[..., 2].mean() / 255)
        green = pixels[..., 1].astype(float)
        pixels[..., 1] = np.clip(rough * 255 + (green - green.mean()) * KEEP_VARIATION, 0, 255).astype(np.uint8)
        pixels[..., 2] = 0
        buffer = io.BytesIO()
        Image.fromarray(pixels).save(buffer, format=kind, quality=92)
        if "bufferView" in image:
            replaced[image["bufferView"]] = buffer.getvalue()
        else:
            mime = {"PNG": "image/png", "JPEG": "image/jpeg", "WEBP": "image/webp"}[kind]
            image["uri"] = f"data:{mime};base64," + base64.b64encode(buffer.getvalue()).decode("ascii")
    chunks, offset = [], 0
    for number, view in enumerate(doc["bufferViews"]):
        start = view.get("byteOffset", 0)
        data = replaced.get(number, blob[start:start + view["byteLength"]])
        pad = (-offset) % 4
        chunks.append(b"\x00" * pad)
        offset += pad
        view["byteOffset"], view["byteLength"] = offset, len(data)
        chunks.append(data)
        offset += len(data)
    binary = b"".join(chunks)
    binary += b"\x00" * ((-len(binary)) % 4)
    doc["buffers"][0]["byteLength"] = len(binary)
    text = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    text += b" " * ((-len(text)) % 4)
    with open(out, "wb") as handle:
        handle.write(struct.pack("<4sII", b"glTF", 2, 28 + len(text) + len(binary)))
        handle.write(struct.pack("<II", len(text), 0x4E4F534A) + text)
        handle.write(struct.pack("<II", len(binary), 0x004E4942) + binary)
    return before


def shrink_textures(src, out, limit=1024, quality=88):
    """Resize every embedded texture to at most `limit` pixels a side. Roblox caps textures at
    1024, and Tripo ships 4096 (the knight's look came to 26 MB). Returns (before, after) bytes."""
    doc, blob = outline_check.read_glb(src)
    replaced = {}
    for image in doc.get("images", []):
        view = doc["bufferViews"][image["bufferView"]]
        start = view.get("byteOffset", 0)
        data = blob[start:start + view["byteLength"]]
        picture = Image.open(io.BytesIO(data))
        if max(picture.size) <= limit:
            continue
        picture.thumbnail((limit, limit), Image.LANCZOS)
        buffer = io.BytesIO()
        if image["mimeType"] == "image/png":
            picture.save(buffer, format="PNG", optimize=True)
        else:
            picture.convert("RGB").save(buffer, format="JPEG", quality=quality)
            image["mimeType"] = "image/jpeg"
        replaced[image["bufferView"]] = buffer.getvalue()
    _write(doc, blob, replaced, out)
    return len(blob), sum(len(v) for v in replaced.values())


def retint(src, out, hue=215.0, grain_from=None, grain=0.9, sheen=1.35, dark_mask=None, seams=None):
    """Turn a piece's warm flat patches (copper, pink: a concept's rim light baked in as colour)
    into the armour's steel hue, keeping their light and shade. `grain_from` borrows scratch
    detail from another piece's texture, so flat painted panels stop reading as wood (the
    knight's helmet beside its steel chest). Every piece is exported matte, so steel reads as
    steel only through painted scratches and bright worn edges: the grain goes over the whole
    texture, and `sheen` stretches the highlights to the other plates' range (the helmet's
    95th-percentile brightness was 161 against the shoulder plate's 202).
    `dark_mask` (a UV-space PNG from tools/blender/uv_mask.py) marks paint that a glow plate
    covers, such as the eyes: it goes dark so the plate has a clean edge. `seams` (a hex colour)
    paints the thin dark gaps between plates in the look's glow, as the other pieces have.
    Returns the fraction of pixels retinted."""
    from PIL import ImageFilter

    doc, blob = outline_check.read_glb(src)
    mat = doc["materials"][0]["pbrMetallicRoughness"]
    image = doc["images"][doc["textures"][mat["baseColorTexture"]["index"]]["source"]]
    view = doc["bufferViews"][image["bufferView"]]
    start = view.get("byteOffset", 0)
    picture = Image.open(io.BytesIO(blob[start:start + view["byteLength"]])).convert("RGB")
    raw = np.asarray(picture).astype(float)
    hsv = np.asarray(picture.convert("HSV")).astype(float)
    h, sat = hsv[..., 0] * 360 / 255, hsv[..., 1] / 255
    # warm: copper and pink, and the faint pink left on the knight's crown (red above blue)
    warm = (((h < 50) | (h > 290)) & (sat > 0.06)) | (raw[..., 0] - raw[..., 2] > 6)
    hsv[..., 0] = np.where(warm, hue * 255 / 360, hsv[..., 0])
    hsv[..., 1] = np.where(warm, np.clip(sat * 0.8 + 0.12, 0, 0.6) * 255, hsv[..., 1])
    rgb = np.asarray(Image.fromarray(hsv.astype(np.uint8), "HSV").convert("RGB")).astype(float)
    if grain_from:
        gdoc, gblob = outline_check.read_glb(grain_from)
        gmat = gdoc["materials"][0]["pbrMetallicRoughness"]
        gimage = gdoc["images"][gdoc["textures"][gmat["baseColorTexture"]["index"]]["source"]]
        gview = gdoc["bufferViews"][gimage["bufferView"]]
        gstart = gview.get("byteOffset", 0)
        other = Image.open(io.BytesIO(gblob[gstart:gstart + gview["byteLength"]])).convert("L")
        other = other.resize(picture.size, Image.LANCZOS)
        detail = np.asarray(other).astype(float)
        # high-pass: the scratches and edges, not the other piece's layout
        blurred = np.asarray(other.filter(ImageFilter.GaussianBlur(12))).astype(float)
        rgb = rgb + ((detail - blurred) * grain)[..., None]
    # Lift the light half of the range: dark recesses stay, lit plates get the bright worn look.
    lum = rgb.mean(axis=2, keepdims=True)
    mid = np.percentile(lum, 50)
    rgb = np.where(lum > mid, mid + (rgb - mid) * sheen, rgb)
    # Last pass: anything still off the steel hue (pink and magenta that red-above-blue misses,
    # the knight's crown) is turned to it. Grey and near-white stay as they are.
    final = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8))
    fhsv = np.asarray(final.convert("HSV")).astype(float)
    fh, fs = fhsv[..., 0] * 360 / 255, fhsv[..., 1] / 255
    off = ((fh < hue - 35) | (fh > hue + 35)) & (fs > 0.04)
    fhsv[..., 0] = np.where(off, hue * 255 / 360, fhsv[..., 0])
    rgb = np.where(off[..., None], np.asarray(Image.fromarray(fhsv.astype(np.uint8), "HSV").convert("RGB")).astype(float), rgb)
    warm = warm | off
    covered = np.zeros(picture.size[::-1], dtype=bool)
    if dark_mask:
        covered = np.asarray(Image.open(dark_mask).convert("L").resize(picture.size, Image.NEAREST)) > 127
        bright = raw.mean(axis=2) > 70  # the paint, not the visor's own dark bar
        rgb = np.where((covered & bright)[..., None], np.array([20, 22, 28], dtype=float), rgb)
    if seams:
        glow = np.array([int(seams[i:i + 2], 16) for i in (1, 3, 5)], dtype=float)
        # the piece's own gaps between plates, found before borrowed scratches add false ones
        grey = Image.fromarray(np.clip(raw.mean(axis=2), 0, 255).astype(np.uint8))
        closed = grey.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.MinFilter(9))
        gap = np.asarray(closed).astype(float) - np.asarray(grey).astype(float)  # black-hat: thin dark lines
        # a thin dark line between lit plates; not on near-white, where orange turns pink
        line = (gap > 14) & ~covered & (np.asarray(closed) < 165)
        line = np.asarray(Image.fromarray((line * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.5))) / 255
        rgb = rgb * (1 - line[..., None] * 0.85) + glow * line[..., None] * 0.85
    data = io.BytesIO()
    Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).save(data, format="PNG")
    image["mimeType"] = "image/png"
    _write(doc, blob, {image["bufferView"]: data.getvalue()}, out)
    return float(warm.mean())


def _texture(path):
    doc, blob = outline_check.read_glb(path)
    mat = doc["materials"][0]["pbrMetallicRoughness"]
    image = doc["images"][doc["textures"][mat["baseColorTexture"]["index"]]["source"]]
    if "bufferView" not in image:
        uri = image.get("uri", "")
        if not uri.startswith("data:") or ";base64," not in uri:
            raise ValueError("GLB texture must be embedded in a buffer view or base64 data URI")
        return Image.open(io.BytesIO(base64.b64decode(uri.split(",", 1)[1], validate=True)))
    view = doc["bufferViews"][image["bufferView"]]
    start = view.get("byteOffset", 0)
    return Image.open(io.BytesIO(blob[start:start + view["byteLength"]]))


def replace_texture(src, out, picture_path, dark_mask=None, grain_from=None, grain=0.9):
    """Put a new base-colour picture into a piece (a texture baked by
    tools/blender/finish_piece.py), keeping its mesh and UVs. `dark_mask` darkens the paint
    under the look's glow plates, as retint does. `grain_from` lays another piece's painted
    scratches over the steel (the user, 2026-11-18: the baked helmet was too smooth beside the
    shoulder plates) but not over the baked glow, which stays clean."""
    from PIL import ImageFilter

    doc, blob = outline_check.read_glb(src)
    mat = doc["materials"][0]["pbrMetallicRoughness"]
    image = doc["images"][doc["textures"][mat["baseColorTexture"]["index"]]["source"]]
    picture = Image.open(picture_path).convert("RGB")
    rgb = np.asarray(picture).astype(float)
    if grain_from:
        other = _texture(grain_from).convert("L").resize(picture.size, Image.LANCZOS)
        detail = np.asarray(other).astype(float)
        blurred = np.asarray(other.filter(ImageFilter.GaussianBlur(12))).astype(float)
        steel = (rgb[..., 2] >= rgb[..., 0]).astype(float)  # not the orange glow
        rgb = rgb + ((detail - blurred) * grain * steel)[..., None]
    if dark_mask:
        covered = np.asarray(Image.open(dark_mask).convert("L").resize(picture.size, Image.NEAREST)) > 127
        bright = rgb.mean(axis=2) > 70
        rgb = np.where((covered & bright)[..., None], np.array([20, 22, 28], dtype=float), rgb)
    data = io.BytesIO()
    Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).save(data, format="PNG")
    image["mimeType"] = "image/png"
    _write(doc, blob, {image["bufferView"]: data.getvalue()}, out)


def _write(doc, blob, replaced, out):
    chunks, offset = [], 0
    for number, view in enumerate(doc["bufferViews"]):
        start = view.get("byteOffset", 0)
        data = replaced.get(number, blob[start:start + view["byteLength"]])
        pad = (-offset) % 4
        chunks.append(b"\x00" * pad)
        offset += pad
        view["byteOffset"], view["byteLength"] = offset, len(data)
        chunks.append(data)
        offset += len(data)
    binary = b"".join(chunks)
    binary += b"\x00" * ((-len(binary)) % 4)
    doc["buffers"][0]["byteLength"] = len(binary)
    text = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    text += b" " * ((-len(text)) % 4)
    with open(out, "wb") as handle:
        handle.write(struct.pack("<4sII", b"glTF", 2, 28 + len(text) + len(binary)))
        handle.write(struct.pack("<II", len(text), 0x4E4F534A) + text)
        handle.write(struct.pack("<II", len(binary), 0x004E4942) + binary)


if __name__ == "__main__":
    was = matte(sys.argv[1], sys.argv[2], float(sys.argv[3]) if len(sys.argv) > 3 else 0.85)
    if was:
        print("was roughness %.2f, metal %.2f; now matte" % was)
    print("wrote", sys.argv[2])
