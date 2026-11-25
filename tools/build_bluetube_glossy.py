"""Rebuild and validate the clean glossy blue containment tube.

    python tools/build_bluetube_glossy.py
    python tools/build_bluetube_glossy.py --check-only
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PKG = ROOT / "assets/models/bluetube-glossy"
OUTPUT = PKG / "exports/BlueTube_Glossy.glb"
BLEND = PKG / "source/GlossyBlueTube.blend"
VALIDATION = PKG / "validation.json"
PREVIEWS = [PKG / "review" / f"{name}.png" for name in ("front", "side", "rear", "quarter", "top")]
AUTHOR = ROOT / "tools/blender/build_bluetube_clean_geometry.py"
RENDERER = ROOT / "tools/blender/render_bluetube_glossy.py"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_glb(path: Path):
    data = path.read_bytes()
    assert data[:4] == b"glTF" and struct.unpack_from("<I", data, 4)[0] == 2
    assert struct.unpack_from("<I", data, 8)[0] == len(data)
    pos = 12
    chunks = {}
    while pos < len(data):
        length, kind = struct.unpack_from("<II", data, pos)
        chunks[kind] = data[pos + 8:pos + 8 + length]
        pos += 8 + length
    assert pos == len(data)
    return json.loads(chunks[0x4E4F534A])


def blender() -> Path:
    return Path(os.environ.get("BLENDER", r"C:\Program Files\Blender Foundation\Blender 4.3\blender.exe"))


def backup_generated():
    previous = [p for p in (OUTPUT, BLEND, VALIDATION, *PREVIEWS) if p.exists()]
    if not previous:
        return
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    target = ROOT / ".mapbuild/bluetube-glossy" / stamp
    target.mkdir(parents=True, exist_ok=True)
    for path in previous:
        dest = target / path.relative_to(PKG)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dest)


def run(label: str, script: Path, *args: str):
    log = PKG / "review" / f"{label}.log"
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("w", encoding="utf-8") as out:
        subprocess.run([str(blender()), "-b", "-noaudio", "--python", str(script), *args],
                       cwd=ROOT, stdout=out, stderr=subprocess.STDOUT, check=True)


def validate(mode: str):
    doc = read_glb(OUTPUT)
    assert OUTPUT.stat().st_size > 100_000
    assert BLEND.stat().st_size > 100_000
    assert len(doc.get("images", [])) == 0  # this rebuild uses named PBR material factors
    assert not doc.get("extensionsRequired", [])
    assert len(doc["meshes"]) >= 8
    tris = {}
    bounds = {"min": [float("inf")] * 3, "max": [float("-inf")] * 3}
    for mesh in doc["meshes"]:
        count = 0
        for primitive in mesh["primitives"]:
            count += doc["accessors"][primitive["indices"]]["count"] // 3
            position = doc["accessors"][primitive["attributes"]["POSITION"]]
            for axis in range(3):
                bounds["min"][axis] = min(bounds["min"][axis], position["min"][axis])
                bounds["max"][axis] = max(bounds["max"][axis], position["max"][axis])
        assert 0 < count <= 10_000, mesh["name"]
        tris[mesh["name"]] = count
    assert abs(bounds["min"][1]) < .05 and abs(bounds["max"][1] - 12.1) < .05, bounds
    assert 8 < bounds["max"][0] - bounds["min"][0] < 11
    assert any(m.get("alphaMode") == "BLEND" and "glass" in m.get("name", "").lower()
               for m in doc["materials"])
    for preview in PREVIEWS:
        assert preview.is_file() and preview.stat().st_size > 10_000, preview
    files = [PKG / "source/bluetube_clean.glb", PKG / "source/BlueTube_OptimizedBaseline.glb",
             PKG / "source/design-reference.png", BLEND, PKG / "appraisal.json", PKG / "views.png",
             OUTPUT, AUTHOR, RENDERER, *PREVIEWS]
    result = {
        "checkedAtUtc": datetime.now(timezone.utc).isoformat(),
        "status": "passed", "mode": mode,
        "meshCount": len(doc["meshes"]), "trianglesPerMesh": tris,
        "totalTriangles": sum(tris.values()), "embeddedTextureCount": 0,
        "boundsGlbYUp": bounds,
        "exportBytes": OUTPUT.stat().st_size,
        "sha256": {str(p.relative_to(ROOT)).replace("\\", "/"): sha(p) for p in files},
        "visualApproval": "pending", "studioImport": "unverified", "mapIntegration": "unverified",
        "limitations": [
            "The clean geometry recreates major surface details; it is not a texture transfer from the damaged source.",
            "Transparent cyan glass and glossy response require Studio lighting/material verification.",
            "The sci-fi chamber remains a static visual prop; no particles, lights, or gameplay are included."
        ],
    }
    VALIDATION.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: clean glossy blue tube; {len(doc['meshes'])} meshes, {sum(tris.values())} total triangles")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--check-only", action="store_true")
    args = parser.parse_args()
    if not args.check_only:
        backup_generated()
        run("build", AUTHOR)
        run("render", RENDERER, "--", str(OUTPUT))
    validate("check" if args.check_only else "build")
