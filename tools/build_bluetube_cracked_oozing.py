"""Build and validate the separate cracked, oozing neon-yellow tube."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import shutil
import subprocess

from build_bluetube_green_core import read_glb, sha

ROOT = Path(__file__).resolve().parents[1]
PKG = ROOT / "assets/models/bluetube-glossy"
BASE = PKG / "exports/BlueTube_NeonYellowCore.glb"
BLUE = PKG / "exports/BlueTube_Glossy.glb"
GREEN = PKG / "exports/BlueTube_GreenCore.glb"
OUTPUT = PKG / "exports/BlueTube_CrackedOozing.glb"
BLEND = PKG / "source/CrackedOozingTube.blend"
VALIDATION = PKG / "validation-cracked-oozing.json"
PREVIEWS = [PKG / "review" / f"leaking-{name}.png"
            for name in ("front", "side", "rear", "quarter", "top", "damage", "night")]
AUTHOR = ROOT / "tools/blender/build_bluetube_cracked_oozing.py"
RENDERER = ROOT / "tools/blender/render_bluetube_glossy.py"
BASE_SHA = "b229a998309dace3fd3d8aca7b58f3ceea829df14f75917b1a8429262d1a07fd"
BLUE_SHA = "e9f08426a558e02bff92aa3b6bbc1ca682a2c6e43ae41f91743543c7fd0dc3ce"
GREEN_SHA = "4846123480dac45e03e1184988ffeddf7a786ef4f81a4bb64bc08998d6385d93"


def backup():
    previous = [p for p in (OUTPUT, BLEND, VALIDATION, *PREVIEWS) if p.exists()]
    if not previous:
        return
    folder = ROOT / ".mapbuild/bluetube-cracked-oozing" / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    for path in previous:
        dest = folder / path.relative_to(PKG)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dest)


def blender_run(label: str, script: Path, *args: str):
    exe = Path(os.environ.get("BLENDER", r"C:\Program Files\Blender Foundation\Blender 4.3\blender.exe"))
    log = PKG / "review" / f"leaking-{label}.log"
    with log.open("w", encoding="utf-8") as out:
        subprocess.run([str(exe), "-b", "-noaudio", "--python", str(script), *args],
                       cwd=ROOT, stdout=out, stderr=subprocess.STDOUT, check=True)


def build():
    assert sha(BASE) == BASE_SHA and sha(BLUE) == BLUE_SHA and sha(GREEN) == GREEN_SHA
    backup()
    blender_run("build", AUTHOR)
    blender_run("render", RENDERER, "--", str(OUTPUT), "leaking-")
    blender_run("damage", RENDERER, "--", str(OUTPUT), "leaking-", "--damage-only")
    blender_run("night", RENDERER, "--", str(OUTPUT), "leaking-", "--night-only")


def validate(mode: str):
    assert sha(BASE) == BASE_SHA and sha(BLUE) == BLUE_SHA and sha(GREEN) == GREEN_SHA
    doc, _ = read_glb(OUTPUT)
    assert BLEND.is_file() and BLEND.stat().st_size > 100_000
    assert len(doc.get("images", [])) == 0
    names = {m["name"] for m in doc["meshes"]}
    for name in ("Tube_Cracked_yellow_glass_shell", "Tube_Glass_fractures",
                 "Tube_Retained_glass_shards", "Tube_Fluorescent_ooze", "Tube_Thick_residue"):
        assert name in names, name
    counts = {}
    bounds = {"min": [float("inf")] * 3, "max": [float("-inf")] * 3}
    for mesh in doc["meshes"]:
        count = 0
        for primitive in mesh["primitives"]:
            count += doc["accessors"][primitive["indices"]]["count"] // 3
            pos = doc["accessors"][primitive["attributes"]["POSITION"]]
            for axis in range(3):
                bounds["min"][axis] = min(bounds["min"][axis], pos["min"][axis])
                bounds["max"][axis] = max(bounds["max"][axis], pos["max"][axis])
        assert 0 < count <= 10_000, mesh["name"]
        counts[mesh["name"]] = count
    assert 12 <= len(doc["meshes"]) <= 18
    assert abs(bounds["max"][1] - 12.1) < .1 and -.1 < bounds["min"][1] < .1, bounds
    assert any("viscous leak" in m.get("name", "") for m in doc["materials"])
    for preview in PREVIEWS:
        assert preview.is_file() and preview.stat().st_size > 10_000, preview
    files = [BASE, BLUE, GREEN, OUTPUT, BLEND, AUTHOR, RENDERER, *PREVIEWS]
    result = {
        "checkedAtUtc": datetime.now(timezone.utc).isoformat(), "status": "passed", "mode": mode,
        "baseYellowSha256": BASE_SHA, "blueSha256": BLUE_SHA, "greenSha256": GREEN_SHA,
        "exportSha256": sha(OUTPUT), "meshCount": len(doc["meshes"]),
        "trianglesPerMesh": counts, "totalTriangles": sum(counts.values()),
        "boundsGlbYUp": bounds, "exportBytes": OUTPUT.stat().st_size,
        "sha256": {p.relative_to(ROOT).as_posix(): sha(p) for p in files},
        "visualApproval": "pending", "studioImport": "unverified", "mapIntegration": "unverified",
        "limitations": [
            "The leak, droplets and pool are static geometry; no simulation, particle effect or gameplay is included.",
            "The cracked shell is intentionally open; its alpha and emissive appearance require Studio inspection.",
            "The neon material helper has not been run on this variant in Studio."
        ],
    }
    VALIDATION.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: cracked/oozing tube; {len(doc['meshes'])} meshes, {sum(counts.values())} triangles")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--check-only", action="store_true")
    args = parser.parse_args()
    if not args.check_only:
        build()
    validate("check" if args.check_only else "build")
