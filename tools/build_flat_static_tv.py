"""Build and validate the standless flat static television."""

from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import subprocess

from PIL import Image

from build_satellite_dish import read_glb


ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "assets" / "models" / "flat-static-tv"
SOURCE = PACKAGE / "source" / "original.glb"
REFERENCE = PACKAGE / "source" / "static-reference.png"
SCREEN = PACKAGE / "textures" / "StaticScreen.png"
EXPORT = PACKAGE / "exports" / "FlatStaticTV.glb"
BLENDER = Path(r"C:\Program Files\Blender Foundation\Blender 4.3\blender.exe")
SCRIPT = ROOT / "tools" / "blender" / "build_flat_static_tv.py"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    SCREEN.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(REFERENCE) as image:
        image.convert("RGB").crop((85, 199, 940, 797)).resize(
            (1024, 576), Image.Resampling.LANCZOS
        ).save(SCREEN, format="PNG", optimize=True)
    EXPORT.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [
            str(BLENDER), "-b", "-t", "4", "--factory-startup", "-noaudio",
            "--python-exit-code", "1", "--python", str(SCRIPT), "--",
            "--static", str(SCREEN), "--out", str(EXPORT),
        ],
        check=True,
        cwd=ROOT,
    )

    model, _ = read_glb(EXPORT)
    meshes = model["meshes"]
    counts = [
        model["accessors"][primitive["indices"]]["count"] // 3
        for mesh in meshes for primitive in mesh["primitives"]
    ]
    positions = [
        model["accessors"][primitive["attributes"]["POSITION"]]
        for mesh in meshes for primitive in mesh["primitives"]
    ]
    low = [min(accessor["min"][axis] for accessor in positions) for axis in range(3)]
    high = [max(accessor["max"][axis] for accessor in positions) for axis in range(3)]
    names = [mesh.get("name", "") for mesh in meshes]
    checks = {
        "twoMeshes": len(meshes) == 2,
        "noStandMesh": not any("stand" in name.lower() for name in names),
        "meshTriangleLimit": bool(counts) and max(counts) <= 10000,
        "width8Studs": math.isclose(high[0] - low[0], 8.0, abs_tol=0.05),
        "height4p6Studs": math.isclose(high[1] - low[1], 4.6, abs_tol=0.05),
        "depthUnderHalfStud": high[2] - low[2] < 0.5,
        "bottomAtZero": math.isclose(low[1], 0.0, abs_tol=0.05),
        "embeddedScreenPng": len(model.get("images", [])) >= 1
        and all(image.get("mimeType") == "image/png" for image in model["images"]),
    }
    record = {
        "checkedAtUtc": datetime.now(timezone.utc).isoformat(),
        "sourceSha256": sha(SOURCE),
        "referenceSha256": sha(REFERENCE),
        "exportSha256": sha(EXPORT),
        "screenTextureSha256": sha(SCREEN),
        "meshNames": names,
        "trianglesPerMesh": counts,
        "boundsGlbYUp": {"min": low, "max": high},
        "checks": checks,
        "studioImport": "unverified; user will upload",
    }
    (PACKAGE / "validation.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    if not all(checks.values()):
        raise RuntimeError("validation failed: " + json.dumps(checks))
    print(json.dumps(record, indent=2))


if __name__ == "__main__":
    main()
