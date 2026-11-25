"""Create a separate neon-yellow-core variant of the repaired glossy tube.

    python tools/build_bluetube_neon_yellow_core.py
    python tools/build_bluetube_neon_yellow_core.py --check-only
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import struct
import subprocess

from build_bluetube_green_core import read_glb, sha

ROOT = Path(__file__).resolve().parents[1]
PKG = ROOT / "assets/models/bluetube-glossy"
BASE = PKG / "exports/BlueTube_Glossy.glb"
GREEN = PKG / "exports/BlueTube_GreenCore.glb"
OUTPUT = PKG / "exports/BlueTube_NeonYellowCore.glb"
VALIDATION = PKG / "validation-neon-yellow.json"
PREVIEWS = [PKG / "review" / f"yellow-{name}.png"
            for name in ("front", "side", "rear", "quarter", "top", "night")]
BLUE_SHA = "e9f08426a558e02bff92aa3b6bbc1ca682a2c6e43ae41f91743543c7fd0dc3ce"
GREEN_SHA = "4846123480dac45e03e1184988ffeddf7a786ef4f81a4bb64bc08998d6385d93"

CHANGES = {
    "Cyan energy core": ("Neon yellow energy core", [.80, 1.00, .005, 1], [.73, .95, .002]),
    "Cyan glass shell": ("Yellow glass shell", [.71, .93, .008, .30], None),
    "Indicator bright cyan": ("Indicator neon yellow", [.83, 1.00, .005, 1], [.59, .74, .002]),
}
MESH_NAMES = {
    "Tube_Cyan_energy_core": "Tube_Neon_yellow_energy_core",
    "Tube_Cyan_glass_shell": "Tube_Yellow_glass_shell",
    "Tube_Indicator_bright_cyan": "Tube_Indicator_neon_yellow",
}


def backup():
    old = [p for p in (OUTPUT, VALIDATION, *PREVIEWS) if p.exists()]
    if not old:
        return
    folder = ROOT / ".mapbuild/bluetube-neon-yellow" / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    for path in old:
        dest = folder / path.relative_to(PKG)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dest)


def build():
    assert sha(BASE) == BLUE_SHA and sha(GREEN) == GREEN_SHA, "Earlier variants changed; inspect before deriving"
    doc, blob = read_glb(BASE)
    seen = set()
    for mat in doc["materials"]:
        if mat["name"] not in CHANGES:
            continue
        old = mat["name"]
        name, color, emission = CHANGES[old]
        mat["name"] = name
        mat["pbrMetallicRoughness"]["baseColorFactor"] = color
        if emission is not None:
            mat["emissiveFactor"] = emission
        seen.add(old)
    assert seen == set(CHANGES)
    for mesh in doc["meshes"]:
        mesh["name"] = MESH_NAMES.get(mesh["name"], mesh["name"])
    for node in doc["nodes"]:
        node["name"] = MESH_NAMES.get(node.get("name"), node.get("name"))
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
    with (PKG / "review/yellow-render.log").open("w", encoding="utf-8") as out:
        subprocess.run([str(exe), "-b", "-noaudio", "--python", str(script),
                        "--", str(OUTPUT), "yellow-"], cwd=ROOT,
                       stdout=out, stderr=subprocess.STDOUT, check=True)
        subprocess.run([str(exe), "-b", "-noaudio", "--python", str(script),
                        "--", str(OUTPUT), "yellow-", "--night-only"], cwd=ROOT,
                       stdout=out, stderr=subprocess.STDOUT, check=True)


def validate(mode: str):
    assert sha(BASE) == BLUE_SHA and sha(GREEN) == GREEN_SHA
    blue_doc, blue_blob = read_glb(BASE)
    doc, blob = read_glb(OUTPUT)
    assert blob == blue_blob
    for field in ("accessors", "bufferViews", "scenes", "buffers"):
        assert doc[field] == blue_doc[field], field
    for mesh, original in zip(doc["meshes"], blue_doc["meshes"]):
        assert mesh["primitives"] == original["primitives"]
        assert mesh["name"] == MESH_NAMES.get(original["name"], original["name"])
    for node, original in zip(doc["nodes"], blue_doc["nodes"]):
        assert {k: v for k, v in node.items() if k != "name"} == {k: v for k, v in original.items() if k != "name"}
    materials = {m["name"]: m for m in doc["materials"]}
    for name in ("Neon yellow energy core", "Yellow glass shell", "Indicator neon yellow"):
        assert name in materials
        color = materials[name]["pbrMetallicRoughness"]["baseColorFactor"]
        assert color[0] > .7 and color[1] > .7 and color[2] < .1
    assert materials["Yellow glass shell"].get("alphaMode") == "BLEND"
    assert materials["Neon yellow energy core"]["emissiveFactor"][0] > .7
    assert materials["Neon yellow energy core"]["emissiveFactor"][1] > .9
    assert any(n.get("name") == "Tube_Neon_yellow_energy_core" for n in doc["nodes"])
    assert len(doc["meshes"]) == 10 and not doc.get("images")
    tris = [sum(doc["accessors"][p["indices"]]["count"] // 3 for p in m["primitives"])
            for m in doc["meshes"]]
    assert sum(tris) == 14628 and max(tris) < 10000
    for preview in PREVIEWS:
        assert preview.is_file() and preview.stat().st_size > 10000
    result = {
        "checkedAtUtc": datetime.now(timezone.utc).isoformat(), "status": "passed", "mode": mode,
        "blueExportSha256": BLUE_SHA, "greenExportSha256": GREEN_SHA,
        "yellowExportSha256": sha(OUTPUT), "geometryBinIdenticalToBlue": True,
        "meshCount": len(doc["meshes"]), "totalTriangles": sum(tris), "trianglesPerMesh": tris,
        "sha256": {p.relative_to(ROOT).as_posix(): sha(p) for p in (BASE, GREEN, OUTPUT, *PREVIEWS)},
        "visualApproval": "pending", "studioImport": "unverified", "mapIntegration": "unverified",
        "limitations": ["Emissive yellow PBR factors do not establish an actual Roblox Neon material or Light instance.",
                        "Studio glow, alpha and lighting must be inspected after import."],
    }
    VALIDATION.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("PASS: independent neon-yellow-core GLB; blue and green exports preserved")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--check-only", action="store_true")
    args = parser.parse_args()
    if not args.check_only:
        backup()
        build()
        render()
    validate("check" if args.check_only else "build")
