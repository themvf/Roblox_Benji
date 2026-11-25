"""Derive a blue-core, blue-spill cracked tube from the saved cracked geometry.

The original yellow cracked export is never modified. Its opening, hanging
strands and floor pool are retained exactly; only material factors and names
change. A Studio-textured copy is generated from this candidate.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import struct
import subprocess

from build_bluetube_studio_textured import build_variant, load_glb

ROOT = Path(__file__).resolve().parents[1]
PKG = ROOT / "assets/models/bluetube-glossy"
BASE = PKG / "exports/BlueTube_CrackedOozing.glb"
OUTPUT = PKG / "exports/BlueTube_BlueCrackedOozing.glb"
TEXTURED = PKG / "exports/BlueTube_BlueCrackedOozing_StudioTextured.glb"
VALIDATION = PKG / "validation-blue-cracked-oozing.json"
PREVIEW = PKG / "review"
BASE_SHA = "b91152dc8ff9551b2f50d778c9877197a688e51027abc02e75c19216eaee40ee"
VIEWS = ("front", "side", "rear", "quarter", "top", "damage")

MATERIALS = {
    "Indicator neon yellow": ("Indicator bright cyan", [.08, .80, 1, 1], [.04, .45, .65]),
    "Neon yellow energy core": ("Cyan energy core", [.08, .75, .93, 1], [.0525, .45, .615]),
    "Yellow glass shell": ("Cracked cyan glass shell", [.06, .53, .69, .30], None),
    "Fluorescent yellow-green viscous leak":
        ("Electric blue viscous leak", [.015, .23, .88, 1], [.004, .11, .43]),
    "Thick yellow-green residue":
        ("Deep blue pooled residue", [.012, .065, .29, 1], [.002, .026, .12]),
}
OBJECTS = {
    "Tube_Indicator_neon_yellow": "Tube_Indicator_bright_cyan",
    "Tube_Neon_yellow_energy_core": "Tube_Cyan_energy_core",
    "Tube_Cracked_yellow_glass_shell": "Tube_Cracked_cyan_glass_shell",
    "Tube_Fluorescent_ooze": "Tube_Electric_blue_ooze",
    "Tube_Thick_residue": "Tube_Deep_blue_residue",
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def encode_glb(doc: dict, binary: bytes) -> bytes:
    chunk = json.dumps(doc, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    chunk += b" " * ((-len(chunk)) % 4)
    total = 12 + 8 + len(chunk) + 8 + len(binary)
    return (struct.pack("<4sII", b"glTF", 2, total)
            + struct.pack("<II", len(chunk), 0x4E4F534A) + chunk
            + struct.pack("<II", len(binary), 0x004E4942) + binary)


def build() -> None:
    assert sha(BASE) == BASE_SHA, "Cracked source changed; inspect before deriving"
    doc, binary = load_glb(BASE.read_bytes())
    seen = set()
    for material in doc["materials"]:
        old = material["name"]
        if old not in MATERIALS:
            continue
        name, color, emissive = MATERIALS[old]
        material["name"] = name
        material["pbrMetallicRoughness"]["baseColorFactor"] = color
        if emissive is not None:
            material["emissiveFactor"] = emissive
        seen.add(old)
    assert seen == MATERIALS.keys(), seen
    for category in ("meshes", "nodes"):
        for item in doc[category]:
            item["name"] = OBJECTS.get(item.get("name"), item.get("name"))
    OUTPUT.write_bytes(encode_glb(doc, binary))
    build_variant("bluecracked")
    blender = Path(r"C:\Program Files\Blender Foundation\Blender 4.3\blender.exe")
    renderer = ROOT / "tools/blender/render_bluetube_glossy.py"
    for flag in ("", "--damage-only"):
        cmd = [str(blender), "-b", "-noaudio", "--python", str(renderer),
               "--", str(TEXTURED), "blue-cracked-"]
        if flag:
            cmd.append(flag)
        with (PREVIEW / f"blue-cracked-render{('-damage' if flag else '')}.log").open("w", encoding="utf-8") as log:
            subprocess.run(cmd, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True)


def validate() -> None:
    assert sha(BASE) == BASE_SHA
    source_doc, source_binary = load_glb(BASE.read_bytes())
    doc, binary = load_glb(OUTPUT.read_bytes())
    textured_doc, textured_binary = load_glb(TEXTURED.read_bytes())
    assert binary == source_binary
    for field in ("accessors", "bufferViews", "buffers", "scenes"):
        assert doc[field] == source_doc[field], field
    assert len(doc["meshes"]) == 14
    assert len(textured_doc["images"]) == 34
    assert textured_binary.startswith(binary)
    by_name = {m["name"]: m for m in doc["materials"]}
    assert all(new_name in by_name for new_name, _, _ in MATERIALS.values())
    assert by_name["Cracked cyan glass shell"]["alphaMode"] == "BLEND"
    assert by_name["Electric blue viscous leak"]["pbrMetallicRoughness"]["baseColorFactor"][2] > .8
    assert {m["name"] for m in doc["meshes"]}.issuperset(OBJECTS.values())
    views = [PREVIEW / f"blue-cracked-{view}.png" for view in VIEWS]
    assert all(p.is_file() and p.stat().st_size > 10_000 for p in views)
    counts = {mesh["name"]: sum(doc["accessors"][p["indices"]]["count"] // 3
                                 for p in mesh["primitives"]) for mesh in doc["meshes"]}
    assert max(counts.values()) <= 10_000
    VALIDATION.write_text(json.dumps({
        "checkedAtUtc": datetime.now(timezone.utc).isoformat(),
        "status": "local pass; visual approval and Studio import pending",
        "baseSha256": BASE_SHA,
        "exportSha256": sha(OUTPUT),
        "studioTexturedSha256": sha(TEXTURED),
        "geometryBinaryIdenticalToCrackedYellow": True,
        "meshCount": len(doc["meshes"]),
        "totalTriangles": sum(counts.values()),
        "trianglesPerMesh": counts,
        "reviewSha256": {p.name: sha(p) for p in views},
        "limitations": ["The spill is static geometry, not a fluid simulation.",
                        "Glass alpha and blue emissive appearance require Studio inspection."],
    }, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: blue cracked tube, {len(doc['meshes'])} meshes, {sum(counts.values())} triangles")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--check-only", action="store_true")
    args = parser.parse_args()
    if not args.check_only:
        build()
    validate()
