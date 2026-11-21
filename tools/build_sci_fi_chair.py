"""Rebuild and verify the sci-fi chair without uploading or changing Studio.

python tools/build_sci_fi_chair.py
python tools/build_sci_fi_chair.py --check-only
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
PACKAGE = ROOT / "assets/models/sci-fi-chair"
VIEWS = {
    "front": "12,4,0",
    "side": "0,4,12",
    "rear": "-12,4,0",
    "quarter": "8,5,8",
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate():
    export = PACKAGE / "exports/SciFiChair.glb"
    doc, blob = gltf_post.read_glb(export)
    if len(doc.get("meshes", [])) != 3 or len(doc.get("materials", [])) != 1:
        raise RuntimeError("Expected three meshes and one shared material")
    triangles = []
    bounds = []
    for mesh in doc["meshes"]:
        if len(mesh["primitives"]) != 1:
            raise RuntimeError("Expected one primitive per mesh")
        primitive = mesh["primitives"][0]
        count = doc["accessors"][primitive["indices"]]["count"] // 3
        if not 0 < count < 10000:
            raise RuntimeError("Roblox per-mesh triangle budget exceeded")
        if "TEXCOORD_0" not in primitive["attributes"]:
            raise RuntimeError("Missing texture coordinates")
        triangles.append(count)
        accessor = doc["accessors"][primitive["attributes"]["POSITION"]]
        bounds.append((accessor["min"], accessor["max"]))
    for node in doc["nodes"]:
        if any(key in node for key in ("matrix", "translation", "rotation", "scale")):
            raise RuntimeError("Unexpected transform in production GLB")
    low = [min(box[0][i] for box in bounds) for i in range(3)]
    high = [max(box[1][i] for box in bounds) for i in range(3)]
    if abs(low[1]) > 0.005 or abs(high[1] - 5) > 0.005:
        raise RuntimeError("Expected five-stud height and ground pivot")
    if max(abs(low[0] + high[0]), abs(low[2] + high[2])) > 0.05:
        raise RuntimeError("Expected centered horizontal bounds")
    images = doc.get("images", [])
    if len(images) != 2 or any(image.get("mimeType") != "image/png" for image in images):
        raise RuntimeError("Expected two embedded PNG textures")
    if gltf_post.foreign_textures(doc):
        raise RuntimeError("Unsupported embedded texture format")
    if any(size != (2048, 2048) for _, size in gltf_post.texture_info(doc, blob)):
        raise RuntimeError("Expected two 2048-pixel texture maps")
    appraisal = json.loads((PACKAGE / "appraisal.json").read_text(encoding="utf-8"))
    if appraisal["sourceSha256"] != digest(PACKAGE / "source/trellis-original.glb"):
        raise RuntimeError("Original source differs from the appraisal")
    if not appraisal.get("decision"):
        raise RuntimeError("Appraisal decision is empty")
    required = [
        "source/design-reference.png", "source/trellis-original.glb", "source/Chair.blend",
        "exports/SciFiChair.glb", "textures/Chair_Color.png",
        "textures/Chair_MetallicRoughness.png", "appraisal.json", "views.png",
        "SetupDecoration.luau", "approval.json",
    ] + ["review/final-%s.png" % view for view in VIEWS]
    hashes = {name: digest(PACKAGE / name) for name in required}
    return hashes, {
        "meshCount": 3, "trianglesPerMesh": triangles,
        "boundsGlbYUp": {"min": low, "max": high},
        "embeddedTextureFormats": [image["mimeType"] for image in images],
        "exportBytes": export.stat().st_size,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument("--blender", type=Path)
    args = parser.parse_args()
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    report = {
        "checkedAtUtc": stamp, "mode": "check" if args.check_only else "rebuild",
        "status": "running", "visualApproval": "pending", "studioImport": "unverified",
    }
    report_path = PACKAGE / "validation.json"
    try:
        if not args.check_only:
            blender = args.blender or shutil.which("blender")
            if not blender and os.name == "nt":
                candidate = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Blender Foundation/Blender 4.3/blender.exe"
                if candidate.exists():
                    blender = candidate
            if not blender:
                raise RuntimeError("Blender 4.3 missing; pass --blender PATH")
            backup = ROOT / ".mapbuild/sci-fi-chair" / stamp
            backup.mkdir(parents=True)
            for name in ("source/Chair.blend", "exports/SciFiChair.glb",
                         "textures/Chair_Color.png", "textures/Chair_MetallicRoughness.png"):
                path = PACKAGE / name
                if path.exists():
                    target = backup / name
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(path, target)
            for view in VIEWS:
                path = PACKAGE / ("review/final-%s.png" % view)
                if path.exists():
                    target = backup / "review" / path.name
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(path, target)
            report["backup"] = str(backup.relative_to(ROOT))

            def run(label, script, *arguments):
                command = [str(blender), "--factory-startup", "-b", "--python-exit-code", "1",
                           "--python", script]
                if arguments:
                    command += ["--", *arguments]
                with (backup / (label + ".log")).open("w", encoding="utf-8") as log:
                    subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                   check=True, timeout=600)

            run("author", "tools/blender/build_sci_fi_chair.py")
            for view, eye in VIEWS.items():
                run("render-" + view, "tools/blender/preview_scene.py",
                    "--glb", "assets/models/sci-fi-chair/exports/SciFiChair.glb",
                    "--materials", "original", "--no-arena", "--eye=" + eye,
                    "--look", "0,2.5,0", "--lens", "55", "--resolution", "900,900",
                    "--samples", "32", "--out", str(PACKAGE / ("review/final-%s.png" % view)))
        report["filesSha256"], report["measured"] = validate()
        approval = json.loads((PACKAGE / "approval.json").read_text(encoding="utf-8"))
        if approval.get("exportSha256") == report["filesSha256"]["exports/SciFiChair.glb"]:
            report["visualApproval"] = "approved 2026-10-10 for this exact export"
        report["status"] = "passed"
        report["limitations"] = [
            "User approval applies only to the recorded export hash; Studio import remains unverified.",
            "The chair has no interactive Seat.",
            "Check-only verifies saved hashes and structure; it does not regenerate renders.",
        ]
    except Exception as exc:
        report["status"] = "failed"
        report["error"] = str(exc)
        raise
    finally:
        report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("PASS: sci-fi chair local package. Visual approval:", report["visualApproval"], "; Studio import unverified.")


if __name__ == "__main__":
    main()
