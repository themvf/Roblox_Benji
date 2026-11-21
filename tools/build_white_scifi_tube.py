"""Build and validate the image-derived white sci-fi tube prop."""

from datetime import datetime, timezone
import hashlib
import json
import math
from pathlib import Path
import random
import subprocess

from build_satellite_dish import read_glb
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "assets" / "models" / "white-scifi-tube"
REFERENCE = PACKAGE / "source" / "reference.png"
EXPORT = PACKAGE / "exports" / "WhiteSciFiTube.glb"
BLENDER = Path(r"C:\Program Files\Blender Foundation\Blender 4.3\blender.exe")
SCRIPT = ROOT / "tools" / "blender" / "build_white_scifi_tube.py"
TEXTURES = PACKAGE / "textures"
PALETTE = {
    "WhiteHousing.png": ((158, 172, 180), 5),
    "PalePanels.png": ((206, 213, 211), 4),
    "DarkRecesses.png": ((34, 47, 52), 4),
    "GunmetalDetails.png": ((68, 82, 89), 5),
    "AmberLights.png": ((234, 95, 23), 3),
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def make_textures():
    TEXTURES.mkdir(parents=True, exist_ok=True)
    for name, (color, variation) in PALETTE.items():
        rng = random.Random(name)
        pixels = []
        for _ in range(128 * 128):
            shift = rng.randint(-variation, variation)
            pixels.append(tuple(max(0, min(255, channel + shift)) for channel in color))
        image = Image.new("RGB", (128, 128))
        image.putdata(pixels)
        image.save(TEXTURES / name, format="PNG", optimize=True)


def main():
    make_textures()
    EXPORT.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        [str(BLENDER), "-b", "-t", "4", "--factory-startup", "-noaudio",
         "--python-exit-code", "1", "--python", str(SCRIPT), "--", "--out", str(EXPORT),
         "--texture-dir", str(TEXTURES)],
        cwd=ROOT,
        check=True,
    )
    model, _ = read_glb(EXPORT)
    meshes = model["meshes"]
    counts = [sum(model["accessors"][primitive["indices"]]["count"] // 3 for primitive in mesh["primitives"])
              for mesh in meshes]
    positions = [model["accessors"][primitive["attributes"]["POSITION"]]
                 for mesh in meshes for primitive in mesh["primitives"]]
    low = [min(item["min"][axis] for item in positions) for axis in range(3)]
    high = [max(item["max"][axis] for item in positions) for axis in range(3)]
    checks = {
        "meshTriangleLimit": bool(counts) and max(counts) <= 10000,
        "height12Studs": math.isclose(high[1] - low[1], 12, abs_tol=0.05),
        "baseAtZero": math.isclose(low[1], 0, abs_tol=0.05),
        "uprightCylinder": 3.8 < high[0] - low[0] < 4.6 and 3.8 < high[2] - low[2] < 4.6,
        "fiveMaterialGroups": len(meshes) == 5 and len(model.get("materials", [])) == 5,
        "referenceColorsPresent": any("Amber" in material.get("name", "") for material in model["materials"]),
        "embeddedPngColorMaps": len(model.get("images", [])) == 5
        and all(image.get("mimeType") == "image/png" for image in model["images"])
        and all(material.get("pbrMetallicRoughness", {}).get("baseColorTexture") for material in model["materials"]),
    }
    record = {
        "checkedAtUtc": datetime.now(timezone.utc).isoformat(),
        "referenceSha256": sha(REFERENCE),
        "exportSha256": sha(EXPORT),
        "exportBytes": EXPORT.stat().st_size,
        "meshNames": [mesh.get("name") for mesh in meshes],
        "trianglesPerMesh": counts,
        "boundsGlbYUp": {"min": low, "max": high},
        "materialNames": [material.get("name") for material in model["materials"]],
        "textureSha256": {name: sha(TEXTURES / name) for name in PALETTE},
        "checks": checks,
        "studioImport": "unverified; user will upload",
        "mapPlacement": "unverified",
    }
    (PACKAGE / "validation.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    if not all(checks.values()):
        raise RuntimeError("validation failed: " + json.dumps(checks))
    print(json.dumps(record, indent=2))


if __name__ == "__main__":
    main()
