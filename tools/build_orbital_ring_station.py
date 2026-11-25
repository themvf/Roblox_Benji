"""Build and validate the orbital station art package for Roblox Studio."""

import argparse
from datetime import datetime, timezone
import hashlib
import io
import json
import math
from pathlib import Path
import struct
import subprocess

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "assets" / "models" / "orbital-ring-station"
SOURCE = PACKAGE / "source" / "original.glb"
EXPORT = PACKAGE / "exports" / "OrbitalRingStation.glb"
SCRIPT = ROOT / "tools" / "blender" / "build_orbital_ring_station.py"
DEFAULT_BLENDER = Path(r"C:\Program Files\Blender Foundation\Blender 4.3\blender.exe")


def read_glb(path):
    blob = path.read_bytes()
    magic, version, length = struct.unpack_from("<4sII", blob)
    if (magic, version, length) != (b"glTF", 2, len(blob)):
        raise ValueError("invalid GLB header: " + str(path))
    json_size, json_type = struct.unpack_from("<I4s", blob, 12)
    if json_type != b"JSON":
        raise ValueError("GLB has no JSON chunk")
    model = json.loads(blob[20 : 20 + json_size])
    binary_start = 20 + json_size
    bin_size, bin_type = struct.unpack_from("<I4s", blob, binary_start)
    if bin_type != b"BIN\0":
        raise ValueError("GLB has no binary chunk")
    return model, blob[binary_start + 8 : binary_start + 8 + bin_size]


def extract_textures():
    model, binary = read_glb(SOURCE)
    if len(model.get("images", [])) < 2:
        raise ValueError("expected embedded base-color and metallic-roughness maps")
    outputs = []
    for index, name in enumerate(("BaseColor.png", "MetallicRoughness.png")):
        image = model["images"][index]
        view = model["bufferViews"][image["bufferView"]]
        start = view.get("byteOffset", 0)
        output = PACKAGE / "textures" / name
        output.parent.mkdir(parents=True, exist_ok=True)
        with Image.open(io.BytesIO(binary[start : start + view["byteLength"]])) as original:
            original.convert("RGBA" if index == 0 else "RGB").resize(
                (1024, 1024), Image.Resampling.LANCZOS
            ).save(output, format="PNG", optimize=True)
        outputs.append(output)
    return outputs


def validate():
    model, _ = read_glb(EXPORT)
    counts = [
        model["accessors"][primitive["indices"]]["count"] // 3
        for mesh in model.get("meshes", [])
        for primitive in mesh["primitives"]
    ]
    position_accessors = [
        model["accessors"][primitive["attributes"]["POSITION"]]
        for mesh in model.get("meshes", [])
        for primitive in mesh["primitives"]
    ]
    minimum = [min(item["min"][axis] for item in position_accessors) for axis in range(3)]
    maximum = [max(item["max"][axis] for item in position_accessors) for axis in range(3)]
    checks = {
        "meshTriangleLimit": bool(counts) and max(counts) <= 10000,
        "height80Studs": math.isclose(maximum[1] - minimum[1], 80, abs_tol=0.1),
        "embeddedPngTextures": len(model.get("images", [])) >= 2
        and all(item.get("mimeType") == "image/png" for item in model["images"]),
        "sectorNames": all(mesh.get("name", "").startswith("Station_S") for mesh in model["meshes"]),
    }
    record = {
        "checkedAtUtc": datetime.now(timezone.utc).isoformat(),
        "sourceSha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "exportSha256": hashlib.sha256(EXPORT.read_bytes()).hexdigest(),
        "textureSha256": {
            name: hashlib.sha256((PACKAGE / "textures" / name).read_bytes()).hexdigest()
            for name in ("BaseColor.png", "MetallicRoughness.png")
        },
        "meshNames": [mesh.get("name", "") for mesh in model["meshes"]],
        "trianglesPerMesh": counts,
        "totalTriangles": sum(counts),
        "meshCount": len(counts),
        "boundsGlbYUp": {"min": minimum, "max": maximum},
        "imageFormats": [image.get("mimeType") for image in model.get("images", [])],
        "checks": checks,
        "studioImport": "unverified",
        "mapPlacement": "unverified",
    }
    (PACKAGE / "validation.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(record, indent=2))
    if not all(checks.values()):
        raise SystemExit("export validation failed")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--blender", type=Path, default=DEFAULT_BLENDER)
    args = parser.parse_args()
    if not args.blender.is_file() or not SOURCE.is_file():
        raise SystemExit("Blender or source GLB is missing")
    color, metal = extract_textures()
    EXPORT.parent.mkdir(parents=True, exist_ok=True)
    command = [
        str(args.blender), "-b", "-t", "4", "--factory-startup", "-noaudio",
        "--python-exit-code", "1", "--python", str(SCRIPT), "--",
        "--source", str(SOURCE), "--color", str(color),
        "--metallic-roughness", str(metal), "--out", str(EXPORT),
    ]
    subprocess.run(command, check=True, cwd=ROOT)
    validate()


if __name__ == "__main__":
    main()
