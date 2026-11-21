"""Build, render, and validate the shipping container; or check saved files.

Run from repository root: python tools/build_shipping_container.py [--check-only]
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
PKG = ROOT / "assets/models/shipping-container"
VIEWS = {"quarter": "37,21,28", "doors": "38,12,0",
         "side": "0,13,40", "rear": "-37,12,0"}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def validate():
    path = PKG / "exports/ShippingContainer.glb"
    doc, blob = gltf_post.read_glb(path)
    if len(doc.get("meshes", [])) != 1 or len(doc.get("materials", [])) != 1:
        raise RuntimeError("Expected one mesh and one atlas material")
    mesh = doc["meshes"][0]
    if len(mesh["primitives"]) != 1:
        raise RuntimeError("Expected one triangle primitive")
    primitive = mesh["primitives"][0]
    triangles = doc["accessors"][primitive["indices"]]["count"] // 3
    if not 0 < triangles < 10000:
        raise RuntimeError("Exceeded Roblox per-mesh triangle limit")
    if "TEXCOORD_0" not in primitive["attributes"]:
        raise RuntimeError("Missing UVs")
    pos = doc["accessors"][primitive["attributes"]["POSITION"]]
    lo, hi = pos["min"], pos["max"]
    if abs(lo[1]) > .005 or abs(hi[1]-10.78) > .005:
        raise RuntimeError("Unexpected height or bottom pivot")
    if not (22.3 < hi[0]-lo[0] < 22.5 and 8 < hi[2]-lo[2] < 8.2):
        raise RuntimeError("Unexpected footprint")
    if any(k in node for node in doc["nodes"]
           for k in ("matrix", "translation", "rotation", "scale")):
        raise RuntimeError("Unexpected node transform")
    if len(doc.get("images", [])) != 2 or any(i.get("mimeType") != "image/png" for i in doc["images"]):
        raise RuntimeError("Expected embedded PNG colour and packed metal/roughness")
    if gltf_post.foreign_textures(doc):
        raise RuntimeError("Unsupported texture extension")
    if any(size != (1024, 1024) for _, size in gltf_post.texture_info(doc, blob)):
        raise RuntimeError("Expected 1024 maps")
    appraisal = json.loads((PKG / "appraisal.json").read_text(encoding="utf-8"))
    if appraisal["sourceSha256"] != sha(PKG / "source/trellis-original.glb"):
        raise RuntimeError("Appraisal source hash mismatch")
    if not appraisal.get("decision"):
        raise RuntimeError("Missing appraisal decision")
    files = ["source/design-reference.png", "source/trellis-original.glb",
             "source/ShippingContainer.blend", "exports/ShippingContainer.glb",
             "textures/Container_Color.png", "textures/Container_Roughness.png",
             "textures/Container_Metalness.png", "appraisal.json", "views.png",
             "SetupDecoration.luau"]
    files += [f"review/final-{name}.png" for name in VIEWS]
    hashes = {name: sha(PKG / name) for name in files}
    return hashes, {"triangles": triangles, "boundsGlbYUp": {"min": lo, "max": hi},
                    "embeddedTextureFormats": [i["mimeType"] for i in doc["images"]],
                    "exportBytes": path.stat().st_size}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument("--blender", type=Path)
    args = parser.parse_args()
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    report = {"checkedAtUtc": stamp, "mode": "check" if args.check_only else "rebuild",
              "status": "running", "visualApproval": "pending", "studioImport": "unverified"}
    output = PKG / "validation.json"
    try:
        if not args.check_only:
            blender = args.blender or shutil.which("blender")
            if not blender and os.name == "nt":
                candidate = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Blender Foundation/Blender 4.3/blender.exe"
                if candidate.exists(): blender = candidate
            if not blender: raise RuntimeError("Blender missing; pass --blender PATH")
            backup = ROOT / ".mapbuild/shipping-container" / stamp
            backup.mkdir(parents=True)
            for name in ("source/ShippingContainer.blend", "exports/ShippingContainer.glb",
                         "textures/Container_Color.png", "textures/Container_Roughness.png",
                         "textures/Container_Metalness.png") + tuple(f"review/final-{v}.png" for v in VIEWS):
                path = PKG / name
                if path.exists():
                    target = backup / name
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(path, target)
            report["backup"] = str(backup.relative_to(ROOT))
            def run(label, script, *arguments):
                command = [str(blender), "--factory-startup", "-b", "--python-exit-code", "1", "--python", script]
                if arguments: command += ["--", *arguments]
                with (backup / (label + ".log")).open("w", encoding="utf-8") as log:
                    subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                   check=True, timeout=600)
            run("author", "tools/blender/build_shipping_container.py")
            for view, eye in VIEWS.items():
                run("render-" + view, "tools/blender/preview_scene.py",
                    "--glb", "assets/models/shipping-container/exports/ShippingContainer.glb",
                    "--materials", "original", "--no-arena", "--eye=" + eye,
                    "--look", "0,5.4,0", "--lens", "50", "--resolution", "850,850",
                    "--samples", "16", "--out", str(PKG / f"review/final-{view}.png"))
        report["filesSha256"], report["measured"] = validate()
        report["status"] = "passed"
        report["limitations"] = [
            "Local checks and Blender renders do not establish visual approval or Studio import.",
            "The 22-stud nominal length and decoration role are provisional.",
            "Check-only verifies saved files and hashes; it does not regenerate views.",
        ]
    except Exception as exc:
        report["status"] = "failed"; report["error"] = str(exc)
        raise
    finally:
        output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("PASS: shipping container local package; visual approval and Studio import pending")

if __name__ == "__main__": main()
