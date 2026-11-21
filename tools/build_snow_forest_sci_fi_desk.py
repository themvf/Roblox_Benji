"""Rebuild, render, and validate the command desk without publishing.

python tools/build_snow_forest_sci_fi_desk.py
python tools/build_snow_forest_sci_fi_desk.py --check-only
"""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

import gltf_post

ROOT = Path(__file__).resolve().parents[1]
PACKAGE = ROOT / "assets/models/snow-forest-sci-fi-desk"
VIEWS = {"front": "0,6,14", "side": "14,6,0",
         "rear": "0,6,-14", "quarter": "9,6,12"}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate():
    path = PACKAGE / "exports/SnowForestSciFiDesk.glb"
    doc, blob = gltf_post.read_glb(path)
    if len(doc.get("meshes", [])) != 1 or len(doc.get("materials", [])) != 1:
        raise RuntimeError("Expected one mesh and shared atlas material")
    primitive = doc["meshes"][0]["primitives"][0]
    if len(doc["meshes"][0]["primitives"]) != 1 or primitive.get("mode", 4) != 4:
        raise RuntimeError("Expected one triangle primitive")
    triangles = doc["accessors"][primitive["indices"]]["count"] // 3
    if not 0 < triangles < 10000:
        raise RuntimeError("Roblox per-mesh triangle cap exceeded")
    if "TEXCOORD_0" not in primitive["attributes"]:
        raise RuntimeError("Missing atlas UVs")
    accessor = doc["accessors"][primitive["attributes"]["POSITION"]]
    lo, hi = accessor["min"], accessor["max"]
    expected_lo, expected_hi = [-4.05, 0, -2.05], [4.05, 6.545, 2.334]
    if any(abs(lo[i] - expected_lo[i]) > 0.005 or abs(hi[i] - expected_hi[i]) > 0.005
           for i in range(3)):
        raise RuntimeError("Unexpected bounds, pivot, or orientation")
    for node in doc["nodes"]:
        if any(key in node for key in ("matrix", "translation", "rotation", "scale")):
            raise RuntimeError("Unexpected GLB transform")
    images = doc.get("images", [])
    if len(images) != 2 or any(item.get("mimeType") != "image/png" for item in images):
        raise RuntimeError("Expected two embedded PNG images")
    if gltf_post.foreign_textures(doc):
        raise RuntimeError("Unsupported texture format")
    if any(size != (1024, 1024) for _, size in gltf_post.texture_info(doc, blob)):
        raise RuntimeError("Expected 1024-pixel texture maps")
    appraisal = json.loads((PACKAGE / "appraisal.json").read_text(encoding="utf-8"))
    if appraisal["sourceSha256"] != sha(PACKAGE / "source/trellis-original.glb"):
        raise RuntimeError("Source differs from recorded appraisal")
    if not appraisal.get("decision"):
        raise RuntimeError("Appraisal decision is empty")
    required = ["source/reference-0.png", "source/reference-2.png",
                "source/trellis-original.glb", "source/SnowForestSciFiDesk.blend",
                "exports/SnowForestSciFiDesk.glb", "textures/Desk_Color.png",
                "textures/Desk_Roughness.png", "textures/Desk_Metalness.png",
                "appraisal.json", "views.png", "SetupDecoration.luau"]
    required += ["review/final-%s.png" % view for view in VIEWS]
    hashes = {name: sha(PACKAGE / name) for name in required}
    return hashes, {"triangles": triangles, "boundsGlbYUp": {"min": lo, "max": hi},
                    "embeddedTextureFormats": [item["mimeType"] for item in images],
                    "exportBytes": path.stat().st_size}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument("--blender", type=Path)
    args = parser.parse_args()
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    report = {"checkedAtUtc": stamp, "mode": "check" if args.check_only else "rebuild",
              "status": "running", "visualApproval": "pending", "studioImport": "unverified"}
    output = PACKAGE / "validation.json"
    try:
        if not args.check_only:
            blender = args.blender or shutil.which("blender")
            if not blender and os.name == "nt":
                candidate = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Blender Foundation/Blender 4.3/blender.exe"
                if candidate.exists():
                    blender = candidate
            if not blender:
                raise RuntimeError("Blender 4.3 missing; pass --blender PATH")
            backup = ROOT / ".mapbuild/snow-forest-sci-fi-desk" / stamp
            backup.mkdir(parents=True)
            for name in ("source/SnowForestSciFiDesk.blend",
                         "exports/SnowForestSciFiDesk.glb", "textures/Desk_Color.png",
                         "textures/Desk_Roughness.png", "textures/Desk_Metalness.png"):
                existing = PACKAGE / name
                if existing.exists():
                    target = backup / name
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(existing, target)
            for view in VIEWS:
                existing = PACKAGE / ("review/final-%s.png" % view)
                if existing.exists():
                    target = backup / "review" / existing.name
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(existing, target)
            report["backup"] = str(backup.relative_to(ROOT))

            def run(label, script, *arguments):
                command = [str(blender), "--factory-startup", "-b", "--python-exit-code", "1",
                           "--python", script]
                if arguments:
                    command += ["--", *arguments]
                with (backup / (label + ".log")).open("w", encoding="utf-8") as log:
                    subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                   check=True, timeout=600)

            run("author", "tools/blender/build_snow_forest_sci_fi_desk.py")
            for view, eye in VIEWS.items():
                run("render-" + view, "tools/blender/preview_scene.py",
                    "--glb", "assets/models/snow-forest-sci-fi-desk/exports/SnowForestSciFiDesk.glb",
                    "--materials", "original", "--no-arena", "--eye=" + eye,
                    "--look", "0,3,0", "--lens", "55", "--resolution", "900,900",
                    "--samples", "24", "--out", str(PACKAGE / ("review/final-%s.png" % view)))
        report["filesSha256"], report["measured"] = validate()
        report["status"] = "passed"
        report["limitations"] = [
            "Local checks and renders do not establish user visual approval or Studio import.",
            "Eight-stud width and decoration role are provisional.",
            "Check-only verifies saved files; it does not regenerate renders.",
        ]
    except Exception as exc:
        report["status"] = "failed"
        report["error"] = str(exc)
        raise
    finally:
        output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("PASS: sci-fi command desk local package; visual approval and Studio import pending.")


if __name__ == "__main__":
    main()
