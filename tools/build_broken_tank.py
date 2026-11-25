"""Build the supplied broken-tank scan for local Roblox Studio import."""

from datetime import datetime, timezone
import hashlib
import io
import json
import math
from pathlib import Path
import subprocess

from PIL import Image

from build_satellite_dish import read_glb


ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "assets" / "models" / "broken-tank"
SOURCE = PACKAGE / "source" / "original.glb"
EXPORT = PACKAGE / "exports" / "BrokenTank.glb"
BLENDER = Path(r"C:\Program Files\Blender Foundation\Blender 4.3\blender.exe")
BLENDER_SCRIPT = ROOT / "tools" / "blender" / "build_orbital_ring_station.py"
HEIGHT_STUDS = 6.0


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def extract_textures():
    model, binary = read_glb(SOURCE)
    if len(model.get("images", [])) != 2:
        raise ValueError("expected two embedded material images")
    paths = []
    for index, name in enumerate(("BaseColor.png", "MetallicRoughness.png")):
        image = model["images"][index]
        view = model["bufferViews"][image["bufferView"]]
        start = view.get("byteOffset", 0)
        path = PACKAGE / "textures" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        with Image.open(io.BytesIO(binary[start : start + view["byteLength"]])) as original:
            original.convert("RGBA" if index == 0 else "RGB").resize(
                (1024, 1024), Image.Resampling.LANCZOS
            ).save(path, format="PNG", optimize=True)
        paths.append(path)
    return paths


def validate():
    model, _ = read_glb(EXPORT)
    counts = [
        model["accessors"][primitive["indices"]]["count"] // 3
        for mesh in model["meshes"]
        for primitive in mesh["primitives"]
    ]
    position_accessors = [
        model["accessors"][primitive["attributes"]["POSITION"]]
        for mesh in model["meshes"]
        for primitive in mesh["primitives"]
    ]
    low = [min(item["min"][axis] for item in position_accessors) for axis in range(3)]
    high = [max(item["max"][axis] for item in position_accessors) for axis in range(3)]
    checks = {
        "meshTriangleLimit": bool(counts) and max(counts) <= 10000,
        "height6Studs": math.isclose(high[1] - low[1], HEIGHT_STUDS, abs_tol=0.05),
        "bottomAtZero": math.isclose(low[1], 0, abs_tol=0.05),
        "embeddedPngTextures": len(model.get("images", [])) == 2
        and all(image.get("mimeType") == "image/png" for image in model["images"]),
        "tankPartNames": all(mesh.get("name", "").startswith("Tank_S") for mesh in model["meshes"]),
    }
    record = {
        "checkedAtUtc": datetime.now(timezone.utc).isoformat(),
        "sourceSha256": digest(SOURCE),
        "exportSha256": digest(EXPORT),
        "textureSha256": {name: digest(PACKAGE / "textures" / name) for name in ("BaseColor.png", "MetallicRoughness.png")},
        "meshNames": [mesh.get("name", "") for mesh in model["meshes"]],
        "trianglesPerMesh": counts,
        "totalTriangles": sum(counts),
        "meshCount": len(counts),
        "boundsGlbYUp": {"min": low, "max": high},
        "checks": checks,
        "studioImport": "unverified; user will upload",
        "mapPlacement": "unverified",
    }
    (PACKAGE / "validation.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    if not all(checks.values()):
        raise RuntimeError("export validation failed: " + json.dumps(checks))
    print(json.dumps(record, indent=2))


def main():
    if not SOURCE.is_file() or not BLENDER.is_file():
        raise FileNotFoundError("source GLB or Blender is missing")
    color, material = extract_textures()
    EXPORT.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            str(BLENDER), "-b", "-t", "4", "--factory-startup", "-noaudio",
            "--python-exit-code", "1", "--python", str(BLENDER_SCRIPT), "--",
            "--source", str(SOURCE), "--color", str(color),
            "--metallic-roughness", str(material), "--out", str(EXPORT),
            "--height", str(HEIGHT_STUDS), "--name-prefix", "Tank",
        ],
        check=True,
        cwd=ROOT,
    )
    validate()


if __name__ == "__main__":
    main()
