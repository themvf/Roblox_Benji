"""Rebuild and locally check the black/orange case package; no Studio actions.

python tools/build_black_orange_box.py
python tools/build_black_orange_box.py --check-only
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
PKG = ROOT / "assets/models/black-orange-box"
EXPORT = PKG / "exports/BlackOrangeCase.glb"
SOURCE_SHA = "cb33c82718f215be6547d054f3fdacaa66bf30ddc46349721abbbc002f63308d"
VIEWS = {"front-quarter": "11,7,13", "side": "0,5,13",
         "end": "13,5,0", "rear": "-11,7,-13"}
DECISION = (
    "An intact black-and-orange sci-fi cargo case for provisional non-colliding "
    "decoration, viewed at player height from all sides. The Midjourney image "
    "is the design reference and the user-selected TRELLIS GLB is shape/color "
    "reference. A 9,000-triangle reduction produced jagged panel artifacts, so "
    "the delivery is clean authored geometry with a dark armored shell, "
    "orange lid band, recessed side panels, end latches and top well. "
    "Approximate height 3.64 studs is provisional. The user requested a later "
    "fix; its specific changes and visual approval are pending."
)

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def validate():
    doc, blob = gltf_post.read_glb(EXPORT)
    meshes = doc.get("meshes", [])
    materials = doc.get("materials", [])
    if len(meshes) != 1 or len(materials) != 1:
        raise RuntimeError("Expected one mesh/material")
    prims = meshes[0]["primitives"]
    if len(prims) != 1 or prims[0].get("mode", 4) != 4:
        raise RuntimeError("Expected one triangle primitive")
    prim = prims[0]
    if "TEXCOORD_0" not in prim["attributes"]:
        raise RuntimeError("Missing UVs")
    count = doc["accessors"][prim["indices"]]["count"] // 3
    if not 0 < count < 10000:
        raise RuntimeError("Roblox triangle cap exceeded")
    pos = doc["accessors"][prim["attributes"]["POSITION"]]
    lo, hi = pos["min"], pos["max"]
    if abs(lo[1]) > .005 or not 3.5 < hi[1] < 3.8:
        raise RuntimeError("Expected bottom pivot and about 3.64-stud height")
    if abs(lo[0] + hi[0]) > .005 or abs(lo[2] + hi[2]) > .005:
        raise RuntimeError("Expected centered horizontal footprint")
    if any(key in node for node in doc["nodes"]
           for key in ("matrix", "translation", "rotation", "scale")):
        raise RuntimeError("Unexpected node transform")
    if gltf_post.foreign_textures(doc):
        raise RuntimeError("Unsupported texture encoding")
    textures = gltf_post.texture_info(doc, blob)
    if len(textures) != 2 or any(t != ("image/png", (1024, 1024)) for t in textures):
        raise RuntimeError("Expected two embedded 1024 PNGs")
    if sha(PKG / "source/trellis-original.glb") != SOURCE_SHA:
        raise RuntimeError("Source GLB changed")
    appraisal = json.loads((PKG / "appraisal.json").read_text(encoding="utf-8"))
    if appraisal.get("sourceSha256") != SOURCE_SHA or appraisal.get("decision") != DECISION:
        raise RuntimeError("Source appraisal or decision is stale")
    required = [
        "appraisal.json", "views.png", "source/design-reference.png",
        "source/trellis-original.glb", "source/BlackOrangeCase.blend",
        "exports/BlackOrangeCase.glb", "textures/BlackOrange_Color.png",
        "textures/BlackOrange_Roughness.png", "textures/BlackOrange_Metalness.png",
        "trials/decimate-manifest.json", "trials/decimated-9000.glb",
        "trials/decimated-9000-quarter.png", "SetupDecoration.luau",
    ] + ["review/%s.png" % name for name in VIEWS]
    hashes = {name: sha(PKG / name) for name in required}
    return hashes, {"triangles": count, "meshes": len(meshes),
                    "materials": len(materials), "boundsMin": lo,
                    "boundsMax": hi, "embeddedTextures": textures,
                    "exportBytes": EXPORT.stat().st_size}

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--check-only", action="store_true")
    ap.add_argument("--blender", type=Path)
    args = ap.parse_args()
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    report = {"checkedAtUtc": stamp, "mode": "check" if args.check_only else "rebuild",
              "status": "running", "visualApproval": "pending",
              "studioImport": "unverified", "mapIntegration": "unverified"}
    try:
        if not args.check_only:
            blender = args.blender or shutil.which("blender")
            if not blender and os.name == "nt":
                candidate = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / \
                    "Blender Foundation/Blender 4.3/blender.exe"
                if candidate.exists():
                    blender = candidate
            if not blender:
                raise RuntimeError("Blender 4.3 missing; pass --blender PATH")
            backup = ROOT / ".mapbuild/black-orange-box" / stamp
            backup.mkdir(parents=True)
            for name in ("source/BlackOrangeCase.blend", "exports/BlackOrangeCase.glb",
                         "appraisal.json", "views.png") + tuple(
                             "review/%s.png" % view for view in VIEWS):
                src = PKG / name
                if src.exists():
                    dst = backup / name
                    dst.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(src, dst)
            report["backup"] = str(backup.relative_to(ROOT))

            def run(label, script, *arguments):
                command = [str(blender), "--factory-startup", "-b",
                           "--python-exit-code", "1", "--python", script]
                if arguments:
                    command += ["--", *arguments]
                print(label, flush=True)
                with (backup / (label + ".log")).open("w", encoding="utf-8") as log:
                    subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                   check=True, timeout=1800)

            run("author", "tools/blender/build_black_orange_box.py")
            run("appraise", "tools/blender/appraise_asset.py", "--source",
                str(PKG / "source/trellis-original.glb"), "--record",
                str(PKG / "appraisal.json"))
            appraisal = json.loads((PKG / "appraisal.json").read_text(encoding="utf-8"))
            appraisal["decision"] = DECISION
            (PKG / "appraisal.json").write_text(json.dumps(appraisal, indent=2) + "\n",
                                                 encoding="utf-8")
            for view, eye in VIEWS.items():
                run("render-" + view, "tools/blender/preview_scene.py", "--glb",
                    str(EXPORT), "--materials", "original", "--no-arena",
                    "--eye=" + eye, "--look", "0,1.8,0", "--lens", "42",
                    "--resolution", "960,640", "--samples", "24", "--ground", "60",
                    "--ground-y=-0.05", "--out", str(PKG / ("review/" + view + ".png")))
        report["filesSha256"], report["measured"] = validate()
        report["status"] = "passed"
        report["limitations"] = [
            "Local file checks and Blender previews do not establish user visual approval.",
            "Studio import, texture loading, physics and map integration are unverified.",
            "Size and non-colliding decoration role are provisional.",
            "Check-only hashes saved previews but does not regenerate them.",
        ]
    except Exception as exc:
        report["status"] = "failed"
        report["error"] = str(exc)
        raise
    finally:
        (PKG / "validation.json").write_text(json.dumps(report, indent=2) + "\n",
                                               encoding="utf-8")
    print("PASS: black/orange case local package; visual approval next.")

if __name__ == "__main__":
    main()
