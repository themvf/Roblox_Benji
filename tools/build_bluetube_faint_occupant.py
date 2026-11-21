"""Build and validate a separate blue tube with a faint occupant shadow."""
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
BLUE = PKG / "exports/BlueTube_Glossy.glb"
GREEN = PKG / "exports/BlueTube_GreenCore.glb"
YELLOW = PKG / "exports/BlueTube_NeonYellowCore.glb"
CRACKED = PKG / "exports/BlueTube_CrackedOozing.glb"
OUTPUT = PKG / "exports/BlueTube_FaintOccupant.glb"
BLEND = PKG / "source/FaintOccupantTube.blend"
VALIDATION = PKG / "validation-faint-occupant.json"
PREVIEWS = [PKG / "review" / f"occupant-{name}.png"
            for name in ("front", "side", "rear", "quarter", "top", "night")]
AUTHOR = ROOT / "tools/blender/build_bluetube_faint_occupant.py"
RENDERER = ROOT / "tools/blender/render_bluetube_glossy.py"
BASE_HASHES = {
    BLUE: "e9f08426a558e02bff92aa3b6bbc1ca682a2c6e43ae41f91743543c7fd0dc3ce",
    GREEN: "4846123480dac45e03e1184988ffeddf7a786ef4f81a4bb64bc08998d6385d93",
    YELLOW: "b229a998309dace3fd3d8aca7b58f3ceea829df14f75917b1a8429262d1a07fd",
    CRACKED: "b91152dc8ff9551b2f50d778c9877197a688e51027abc02e75c19216eaee40ee",
}


def verify_bases():
    for path, expected in BASE_HASHES.items():
        assert sha(path) == expected, f"Previously delivered variant changed: {path}"


def backup():
    previous = [p for p in (OUTPUT, BLEND, VALIDATION, *PREVIEWS) if p.exists()]
    if not previous:
        return
    folder = ROOT / ".mapbuild/bluetube-faint-occupant" / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    for path in previous:
        dest = folder / path.relative_to(PKG)
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dest)


def blender_run(label: str, script: Path, *args: str):
    exe = Path(os.environ.get("BLENDER", r"C:\Program Files\Blender Foundation\Blender 4.3\blender.exe"))
    log = PKG / "review" / f"occupant-{label}.log"
    with log.open("w", encoding="utf-8") as out:
        subprocess.run([str(exe), "-b", "-noaudio", "--python", str(script), *args],
                       cwd=ROOT, stdout=out, stderr=subprocess.STDOUT, check=True)


def build():
    verify_bases()
    backup()
    blender_run("build", AUTHOR)
    assert OUTPUT.is_file(), "Blender did not write the GLB; inspect occupant-build.log"
    blender_run("render", RENDERER, "--", str(OUTPUT), "occupant-")
    blender_run("night", RENDERER, "--", str(OUTPUT), "occupant-", "--night-only")


def validate(mode: str):
    verify_bases()
    doc, _ = read_glb(OUTPUT)
    assert BLEND.is_file() and BLEND.stat().st_size > 100_000
    assert len(doc.get("images", [])) == 0
    counts = {}
    bounds = {"min": [float("inf")] * 3, "max": [float("-inf")] * 3}
    for mesh in doc["meshes"]:
        count = 0
        for prim in mesh["primitives"]:
            count += doc["accessors"][prim["indices"]]["count"] // 3
            pos = doc["accessors"][prim["attributes"]["POSITION"]]
            for axis in range(3):
                bounds["min"][axis] = min(bounds["min"][axis], pos["min"][axis])
                bounds["max"][axis] = max(bounds["max"][axis], pos["max"][axis])
        assert 0 < count <= 10_000, mesh["name"]
        counts[mesh["name"]] = count
    assert len(doc["meshes"]) == 11
    assert "Tube_Faint_human_shadow" in counts
    assert abs(bounds["min"][1]) < .05 and abs(bounds["max"][1] - 12.1) < .05
    shadow_mat = next(m for m in doc["materials"] if m["name"] == "Faint submerged human shadow")
    assert shadow_mat["alphaMode"] == "BLEND"
    assert shadow_mat["pbrMetallicRoughness"]["baseColorFactor"][3] <= .25
    for preview in PREVIEWS:
        assert preview.is_file() and preview.stat().st_size > 10_000, preview
    files = [*BASE_HASHES, OUTPUT, BLEND, AUTHOR, RENDERER, *PREVIEWS]
    result = {
        "checkedAtUtc": datetime.now(timezone.utc).isoformat(), "status": "passed", "mode": mode,
        "baseBlueSha256": BASE_HASHES[BLUE], "exportSha256": sha(OUTPUT),
        "meshCount": len(doc["meshes"]), "trianglesPerMesh": counts,
        "totalTriangles": sum(counts.values()), "boundsGlbYUp": bounds,
        "exportBytes": OUTPUT.stat().st_size,
        "sha256": {p.relative_to(ROOT).as_posix(): sha(p) for p in files},
        "visualApproval": "pending", "studioImport": "unverified", "mapIntegration": "unverified",
        "limitations": [
            "The occupant is a faint, static silhouette; no character or animation is inside the chamber.",
            "The transparent shadow and glass appearance require Studio verification under intended lighting.",
        ],
    }
    VALIDATION.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"PASS: faint-occupant tube; {len(doc['meshes'])} meshes, {sum(counts.values())} triangles")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--check-only", action="store_true")
    args = parser.parse_args()
    if not args.check_only:
        build()
    validate("check" if args.check_only else "build")
