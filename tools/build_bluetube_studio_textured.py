"""Bake tube-family factor-only materials into importable PBR maps.

Keeps each original candidate untouched. Small solid maps carry its color and
finish data through Studio's texture import path.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
from io import BytesIO
from pathlib import Path
import hashlib
import json
import re
import struct

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PKG = ROOT / "assets/models/bluetube-glossy"
VARIANTS = {
    "blue": "BlueTube_Glossy",
    "green": "BlueTube_GreenCore",
    "yellow": "BlueTube_NeonYellowCore",
    "cracked": "BlueTube_CrackedOozing",
    "bluecracked": "BlueTube_BlueCrackedOozing",
    "occupant": "BlueTube_FaintOccupant",
}
JSON = 0x4E4F534A
BIN = 0x004E4942


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_glb(data: bytes) -> tuple[dict, bytearray]:
    assert data[:4] == b"glTF" and struct.unpack_from("<I", data, 4)[0] == 2
    assert struct.unpack_from("<I", data, 8)[0] == len(data)
    pos = 12
    chunks = {}
    while pos < len(data):
        size, kind = struct.unpack_from("<II", data, pos)
        chunks[kind] = data[pos + 8 : pos + 8 + size]
        pos += 8 + size
    assert set(chunks) == {JSON, BIN}
    return json.loads(chunks[JSON]), bytearray(chunks[BIN])


def srgb_byte(linear: float) -> int:
    v = max(0.0, min(1.0, linear))
    if v <= 0.0031308:
        v *= 12.92
    else:
        v = 1.055 * v ** (1 / 2.4) - 0.055
    return round(v * 255)


def image_bytes(color: tuple[int, ...], mode: str) -> bytes:
    image = Image.new(mode, (64, 64), color)
    output = BytesIO()
    image.save(output, format="PNG", optimize=True)
    return output.getvalue()


def write_glb(doc: dict, binary: bytearray) -> bytes:
    doc["buffers"][0]["byteLength"] = len(binary)
    js = json.dumps(doc, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    js += b" " * ((-len(js)) % 4)
    binary.extend(b"\0" * ((-len(binary)) % 4))
    total = 12 + 8 + len(js) + 8 + len(binary)
    return (struct.pack("<4sII", b"glTF", 2, total)
            + struct.pack("<II", len(js), JSON) + js
            + struct.pack("<II", len(binary), BIN) + binary)


def build_variant(variant: str) -> None:
    stem = VARIANTS[variant]
    source = PKG / "exports" / f"{stem}.glb"
    output = PKG / "exports" / f"{stem}_StudioTextured.glb"
    textures = PKG / "textures/studio-textured"
    validation = PKG / "validation-studio-textured.json"
    if variant != "blue":
        textures = textures / variant
        validation = PKG / f"validation-studio-textured-{variant}.json"
    source_bytes = source.read_bytes()
    doc, binary = load_glb(source_bytes)
    assert not doc.get("images") and not doc.get("textures")
    original_binary = bytes(binary)
    textures.mkdir(parents=True, exist_ok=True)
    doc["images"] = []
    doc["textures"] = []
    doc["samplers"] = [{"magFilter": 9729, "minFilter": 9729, "wrapS": 10497, "wrapT": 10497}]
    written = {}

    def embed_image(filename: str, contents: bytes) -> int:
        (textures / filename).write_bytes(contents)
        written[filename] = sha(contents)
        binary.extend(b"\0" * ((-len(binary)) % 4))
        offset = len(binary)
        binary.extend(contents)
        view = len(doc["bufferViews"])
        doc["bufferViews"].append({"buffer": 0, "byteOffset": offset, "byteLength": len(contents)})
        image = len(doc["images"])
        doc["images"].append({"name": filename, "bufferView": view, "mimeType": "image/png"})
        texture = len(doc["textures"])
        doc["textures"].append({"name": filename, "sampler": 0, "source": image})
        return texture

    for mat in doc["materials"]:
        name = re.sub(r"[^A-Za-z0-9]+", "_", mat["name"]).strip("_")
        pbr = mat.setdefault("pbrMetallicRoughness", {})
        rgba = pbr.get("baseColorFactor", [1, 1, 1, 1])
        color = tuple(srgb_byte(v) for v in rgba[:3]) + (round(rgba[3] * 255),)
        pbr["baseColorTexture"] = {"index": embed_image(f"{name}_Color.png", image_bytes(color, "RGBA"))}
        pbr["baseColorFactor"] = [1, 1, 1, 1]

        roughness = round(pbr.get("roughnessFactor", 1.0) * 255)
        metallic = round(pbr.get("metallicFactor", 1.0) * 255)
        packed = (255, roughness, metallic)
        pbr["metallicRoughnessTexture"] = {"index": embed_image(
            f"{name}_MetallicRoughness.png", image_bytes(packed, "RGB"))}
        pbr["roughnessFactor"] = 1.0
        pbr["metallicFactor"] = 1.0

        if "emissiveFactor" in mat:
            glow = tuple(srgb_byte(v) for v in mat["emissiveFactor"])
            mat["emissiveTexture"] = {"index": embed_image(
                f"{name}_Emissive.png", image_bytes(glow, "RGB"))}
            mat["emissiveFactor"] = [1, 1, 1]

    # The glass was factor-only and had no UVs. A constant image only needs a
    # valid coordinate, so assign the center texel to every vertex.
    uv_additions = 0
    for mesh in doc["meshes"]:
        for primitive in mesh["primitives"]:
            if "TEXCOORD_0" in primitive["attributes"]:
                continue
            count = doc["accessors"][primitive["attributes"]["POSITION"]]["count"]
            binary.extend(b"\0" * ((-len(binary)) % 4))
            offset = len(binary)
            binary.extend(struct.pack("<ff", 0.5, 0.5) * count)
            view = len(doc["bufferViews"])
            doc["bufferViews"].append({"buffer": 0, "byteOffset": offset,
                                        "byteLength": 8 * count, "target": 34962})
            accessor = len(doc["accessors"])
            doc["accessors"].append({"bufferView": view, "componentType": 5126,
                                     "count": count, "type": "VEC2"})
            primitive["attributes"]["TEXCOORD_0"] = accessor
            uv_additions += 1

    assert bytes(binary[:len(original_binary)]) == original_binary
    output_bytes = write_glb(doc, binary)
    output.write_bytes(output_bytes)
    verified, _ = load_glb(output.read_bytes())
    assert len(verified["images"]) == len(written)
    assert all("baseColorTexture" in mat["pbrMetallicRoughness"] for mat in verified["materials"])
    assert all("TEXCOORD_0" in primitive["attributes"]
               for mesh in verified["meshes"] for primitive in mesh["primitives"])
    validation.write_text(json.dumps({
        "checkedAtUtc": datetime.now(timezone.utc).isoformat(),
        "status": "local structural pass; Studio preview not yet verified",
        "variant": variant,
        "sourceFile": str(source.relative_to(ROOT)),
        "exportFile": str(output.relative_to(ROOT)),
        "sourceSha256": sha(source_bytes),
        "exportSha256": sha(output_bytes),
        "meshCount": len(verified["meshes"]),
        "materialCount": len(verified["materials"]),
        "embeddedImages": len(verified["images"]),
        "addedUvPrimitives": uv_additions,
        "originalGeometryBytesPreserved": True,
        "textureSha256": written,
        "limitations": ["Studio importer preview and in-game rendering remain unverified",
                        "Roblox glass alpha and emissive response require Studio review"],
    }, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: {output}, {len(verified['images'])} embedded PBR images")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("variants", nargs="*", choices=VARIANTS.keys(),
                        help="Variants to build; default is all available variants")
    args = parser.parse_args()
    for variant in args.variants or VARIANTS:
        build_variant(variant)


if __name__ == "__main__":
    main()
