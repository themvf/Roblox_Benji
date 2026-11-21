"""Build and inspect the Double Ledge mounted-turret visual for Roblox Studio."""

import argparse
import hashlib
import io
import json
import math
from pathlib import Path
import struct
import subprocess

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "assets" / "models" / "double-ledge-lmg"
SOURCE = PACKAGE / "source" / "original.glb"
EXPORT = PACKAGE / "exports" / "DoubleLedgeTurret.glb"
BLENDER_SCRIPT = ROOT / "tools" / "blender" / "build_double_ledge_lmg.py"
DEFAULT_BLENDER = Path(r"C:\Program Files\Blender Foundation\Blender 4.3\blender.exe")


def glb(path):
    blob = path.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", blob)
    if (magic, version, length) != (b"glTF", 2, len(blob)):
        raise ValueError("invalid GLB header: " + str(path))
    json_len, json_type = struct.unpack_from("<I4s", blob, 12)
    if json_type != b"JSON":
        raise ValueError("GLB has no JSON chunk")
    model = json.loads(blob[20 : 20 + json_len])
    offset = 20 + json_len
    bin_len, bin_type = struct.unpack_from("<I4s", blob, offset)
    if bin_type != b"BIN\0":
        raise ValueError("GLB has no binary chunk")
    return model, blob[offset + 8 : offset + 8 + bin_len]


def extract_textures():
    model, binary = glb(SOURCE)
    if len(model.get("images", [])) < 2:
        raise ValueError("expected base color and metallic-roughness textures")
    paths = []
    for index, name in enumerate(("BaseColor.png", "MetallicRoughness.png")):
        image = model["images"][index]
        view = model["bufferViews"][image["bufferView"]]
        start = view.get("byteOffset", 0)
        raw = binary[start : start + view["byteLength"]]
        output = PACKAGE / "textures" / name
        output.parent.mkdir(parents=True, exist_ok=True)
        with Image.open(io.BytesIO(raw)) as original:
            original.convert("RGBA" if index == 0 else "RGB").resize(
                (1024, 1024), Image.Resampling.LANCZOS
            ).save(output, format="PNG", optimize=True)
        paths.append(output)
    return paths


def validate():
    model, _ = glb(EXPORT)
    mesh_counts = [model["accessors"][primitive["indices"]]["count"] // 3
                   for mesh in model.get("meshes", []) for primitive in mesh["primitives"]]
    names = [mesh.get("name", "") for mesh in model.get("meshes", [])]
    position_accessors = [model["accessors"][primitive["attributes"]["POSITION"]]
                          for mesh in model.get("meshes", []) for primitive in mesh["primitives"]]
    mins = [min(accessor["min"][axis] for accessor in position_accessors) for axis in range(3)]
    maxs = [max(accessor["max"][axis] for accessor in position_accessors) for axis in range(3)]
    record = {
        "sourceSha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "exportSha256": hashlib.sha256(EXPORT.read_bytes()).hexdigest(),
        "meshCount": len(mesh_counts),
        "meshNames": names,
        "trianglesPerMesh": mesh_counts,
        "totalTriangles": sum(mesh_counts),
        "boundsGlbYUp": {"min": mins, "max": maxs},
        "imageFormats": [image.get("mimeType") for image in model.get("images", [])],
        "limits": {"maxTrianglesPerMesh": 10000, "targetHeightStuds": 8},
        "checks": {
            "meshTriangleLimit": bool(mesh_counts) and max(mesh_counts) <= 10000,
            "baseAndHeadNamed": any(name.startswith("Base_") for name in names)
                                 and any(name.startswith("Head_") for name in names),
            "height": math.isclose(maxs[1] - mins[1], 8, abs_tol=0.05),
            "pngTextures": len(model.get("images", [])) >= 2
                           and all(image.get("mimeType") == "image/png" for image in model["images"]),
        },
        "studioImport": "unverified",
        "studioTextures": "unverified",
        "gameplay": "unverified",
    }
    path = PACKAGE / "validation.json"
    path.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(record, indent=2))
    if not all(record["checks"].values()):
        raise SystemExit("export validation failed")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--blender", type=Path, default=DEFAULT_BLENDER)
    args = parser.parse_args()
    if not args.blender.is_file():
        raise SystemExit("Blender executable not found: " + str(args.blender))
    if not SOURCE.is_file():
        raise SystemExit("source GLB not found: " + str(SOURCE))
    color, metal = extract_textures()
    EXPORT.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run([
        str(args.blender), "-b", "-t", "4", "--factory-startup", "-noaudio",
        "--python", str(BLENDER_SCRIPT), "--",
        "--source", str(SOURCE), "--color", str(color),
        "--metallic-roughness", str(metal), "--out", str(EXPORT),
    ], check=True, cwd=ROOT)
    validate()


if __name__ == "__main__":
    main()
