"""Make a separate green-chamber variant from the verified clean blue tube.

    python tools/build_bluetube_green_core.py
    python tools/build_bluetube_green_core.py --check-only
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
BASE = PKG / "exports/BlueTube_Glossy.glb"
OUTPUT = PKG / "exports/BlueTube_GreenCore.glb"
VALIDATION = PKG / "validation-green.json"
PREVIEWS = [PKG / "review" / f"green-{name}.png"
            for name in ("front", "side", "rear", "quarter", "top")]
BLUE_SHA = "e9f08426a558e02bff92aa3b6bbc1ca682a2c6e43ae41f91743543c7fd0dc3ce"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_glb(path: Path):
    data = path.read_bytes()
    assert data[:4] == b"glTF" and struct.unpack_from("<I", data, 8)[0] == len(data)
    pos = 12
    chunks = {}
    while pos < len(data):
        length, kind = struct.unpack_from("<II", data, pos)
        chunks[kind] = data[pos + 8:pos + 8 + length]
        pos += 8 + length
    assert pos == len(data)
    return json.loads(chunks[0x4E4F534A]), chunks[0x004E4942]


def backup():
    current = [p for p in (OUTPUT, VALIDATION, *PREVIEWS) if p.exists()]
    if current:
        folder = ROOT / ".mapbuild/bluetube-green-core" / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        for path in current:
            dest = folder / path.relative_to(PKG)
            dest.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(path, dest)


def build():
    assert sha(BASE) == BLUE_SHA, "Blue source changed; inspect before deriving variant"
    doc, blob = read_glb(BASE)
    changes = {
        "Cyan energy core": ("Green energy core", [.10, .84, .18, 1], [.035, .56, .055]),
        "Cyan glass shell": ("Green glass shell", [.075, .52, .13, .32], None),
        "Indicator bright cyan": ("Indicator bright green", [.12, .84, .20, 1], [.04, .45, .045]),
    }
    seen = set()
    for mat in doc["materials"]:
        old = mat["name"]
        if old not in changes:
            continue
        name, color, emission = changes[old]
        mat["name"] = name
        mat["pbrMetallicRoughness"]["baseColorFactor"] = color
        if emission is not None:
            mat["emissiveFactor"] = emission
        seen.add(old)
    assert seen == changes.keys(), seen
    encoded = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    encoded += b" " * ((-len(encoded)) % 4)
    payload = struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(encoded) + 8 + len(blob))
    payload += struct.pack("<II", len(encoded), 0x4E4F534A) + encoded
    payload += struct.pack("<II", len(blob), 0x004E4942) + blob
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_bytes(payload)


def render():
    exe = Path(os.environ.get("BLENDER", r"C:\Program Files\Blender Foundation\Blender 4.3\blender.exe"))
    script = ROOT / "tools/blender/render_bluetube_glossy.py"
    log = PKG / "review/green-render.log"
    with log.open("w", encoding="utf-8") as out:
        subprocess.run([str(exe), "-b", "-noaudio", "--python", str(script),
                        "--", str(OUTPUT), "green-"], cwd=ROOT,
                       stdout=out, stderr=subprocess.STDOUT, check=True)


def validate(mode: str):
    assert sha(BASE) == BLUE_SHA
    blue_doc, blue_blob = read_glb(BASE)
    doc, blob = read_glb(OUTPUT)
    assert blob == blue_blob  # exact meshes, indices, UVs and transforms
    for field in ("meshes", "accessors", "bufferViews", "nodes", "scenes", "buffers"):
        assert doc[field] == blue_doc[field], field
    by_name = {m["name"]: m for m in doc["materials"]}
    for name in ("Green energy core", "Green glass shell", "Indicator bright green"):
        assert name in by_name
        color = by_name[name]["pbrMetallicRoughness"]["baseColorFactor"]
        assert color[1] > color[0] * 3 and color[1] > color[2] * 2
    assert by_name["Green glass shell"].get("alphaMode") == "BLEND"
    blue_names = {"Cyan energy core", "Cyan glass shell", "Indicator bright cyan"}
    assert not blue_names.intersection(by_name)
    assert len(doc.get("images", [])) == 0 and len(doc["meshes"]) == 10
    tris = [sum(doc["accessors"][p["indices"]]["count"] // 3 for p in m["primitives"])
            for m in doc["meshes"]]
    assert sum(tris) == 14628 and max(tris) <= 10000
    for preview in PREVIEWS:
        assert preview.is_file() and preview.stat().st_size > 10000
    result = {
        "checkedAtUtc": datetime.now(timezone.utc).isoformat(), "status": "passed", "mode": mode,
        "baseExportSha256": BLUE_SHA, "greenExportSha256": sha(OUTPUT),
        "geometryBinIdentical": True, "meshCount": len(doc["meshes"]),
        "trianglesPerMesh": tris, "totalTriangles": sum(tris),
        "sha256": {p.relative_to(ROOT).as_posix(): sha(p) for p in (BASE, OUTPUT, *PREVIEWS)},
        "visualApproval": "pending", "studioImport": "unverified", "mapIntegration": "unverified",
        "limitations": ["Green core and glass are static material changes; no new light or particle effect.",
                        "Studio alpha and emission appearance remain unverified."],
    }
    VALIDATION.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("PASS: independent green-core GLB; blue geometry and export preserved")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--check-only", action="store_true")
    args = parser.parse_args()
    if not args.check_only:
        backup()
        build()
        render()
    validate("check" if args.check_only else "build")
