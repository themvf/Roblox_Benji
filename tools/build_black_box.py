"""Build, render and locally verify the glossy black cargo box; no Studio actions.

python tools/build_black_box.py
python tools/build_black_box.py --check-only
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
PKG = ROOT / "assets/models/black-box"
EXPORT = PKG / "exports/GlossyBlackBox.glb"
SOURCE_SHA = "6dd90da72429503086027a7817d69cf3bf09c75741c67a6ab41caf12bf47c271"
VIEWS = {"front-quarter": "8,7,9", "doors": "0,5,11",
         "service": "11,5,0", "rear": "-8,7,-9"}
DECISION = (
    "A closed cubic sci-fi cargo box for provisional non-colliding decoration, "
    "viewed at player height from all sides. The supplied BlackBox.png is the "
    "design reference and the user-selected TRELLIS GLB is 3D reference. "
    "A 9,000-triangle reduction shredded the panels, so the delivery is a "
    "clean hard-surface rebuild with paired doors, service latch, armored "
    "corners, silver trim and corner reflectors. The user requested a shiny "
    "finish: dark graphite metal with low roughness and polished chrome trim "
    "is authored in the color and metallic-roughness atlases. Approximate "
    "4.45-stud height and decoration role await visual approval."
)

def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()

def validate():
    doc, blob = gltf_post.read_glb(EXPORT)
    meshes, mats = doc.get("meshes", []), doc.get("materials", [])
    if len(meshes) != 1 or len(mats) != 1:
        raise RuntimeError("Expected one mesh and one material")
    prims = meshes[0]["primitives"]
    if len(prims) != 1 or prims[0].get("mode", 4) != 4:
        raise RuntimeError("Expected one triangle primitive")
    prim = prims[0]
    if "TEXCOORD_0" not in prim["attributes"]:
        raise RuntimeError("UVs missing")
    count = doc["accessors"][prim["indices"]]["count"] // 3
    if not 0 < count < 10000:
        raise RuntimeError("Roblox per-mesh triangle cap exceeded")
    pos = doc["accessors"][prim["attributes"]["POSITION"]]
    lo, hi = pos["min"], pos["max"]
    if abs(lo[1]) > .005 or not 4.3 < hi[1] < 4.6:
        raise RuntimeError("Expected bottom pivot and about 4.45-stud height")
    if abs(lo[0]+hi[0]) > .005 or abs(lo[2]+hi[2]) > .005:
        raise RuntimeError("Expected centered horizontal footprint")
    if any(key in node for node in doc["nodes"]
           for key in ("matrix", "translation", "rotation", "scale")):
        raise RuntimeError("Unexpected node transform")
    if gltf_post.foreign_textures(doc):
        raise RuntimeError("Unsupported embedded texture")
    textures = gltf_post.texture_info(doc, blob)
    if len(textures) != 2 or any(t != ("image/png", (1024,1024)) for t in textures):
        raise RuntimeError("Expected color and packed metallic-roughness PNGs")
    pbr = mats[0].get("pbrMetallicRoughness", {})
    if "baseColorTexture" not in pbr or "metallicRoughnessTexture" not in pbr:
        raise RuntimeError("Glossy PBR maps are not wired")
    if sha(PKG / "source/trellis-original.glb") != SOURCE_SHA:
        raise RuntimeError("Original TRELLIS source changed")
    appraisal = json.loads((PKG / "appraisal.json").read_text(encoding="utf-8"))
    if appraisal.get("sourceSha256") != SOURCE_SHA or appraisal.get("decision") != DECISION:
        raise RuntimeError("Source appraisal decision is stale")
    required = [
        "appraisal.json", "views.png", "source/design-reference.png",
        "source/trellis-original.glb", "source/GlossyBlackBox.blend",
        "exports/GlossyBlackBox.glb", "textures/BlackBox_Color.png",
        "textures/BlackBox_Roughness.png", "textures/BlackBox_Metalness.png",
        "trials/decimate-manifest.json", "trials/decimated-9000.glb",
        "trials/decimated-9000-quarter.png", "SetupDecoration.luau",
        "review/gloss-study.png",
    ] + ["review/%s.png" % name for name in VIEWS]
    hashes = {name: sha(PKG/name) for name in required}
    return hashes, {"triangles": count, "meshes": len(meshes),
                    "materials": len(mats), "boundsMin": lo, "boundsMax": hi,
                    "embeddedTextures": textures, "exportBytes": EXPORT.stat().st_size}

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
            backup = ROOT / ".mapbuild/black-box" / stamp
            backup.mkdir(parents=True)
            for name in ("source/GlossyBlackBox.blend", "exports/GlossyBlackBox.glb",
                         "appraisal.json", "views.png", "review/gloss-study.png") + tuple(
                             "review/%s.png" % name for name in VIEWS):
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
                with (backup / (label+".log")).open("w", encoding="utf-8") as log:
                    subprocess.run(command, cwd=ROOT, stdout=log,
                                   stderr=subprocess.STDOUT, check=True, timeout=1800)

            run("author", "tools/blender/build_black_box.py")
            run("appraise", "tools/blender/appraise_asset.py", "--source",
                str(PKG / "source/trellis-original.glb"), "--record",
                str(PKG / "appraisal.json"))
            appraisal = json.loads((PKG / "appraisal.json").read_text(encoding="utf-8"))
            appraisal["decision"] = DECISION
            (PKG / "appraisal.json").write_text(json.dumps(appraisal, indent=2)+"\n",
                                                 encoding="utf-8")
            for view, eye in VIEWS.items():
                run("render-"+view, "tools/blender/preview_scene.py", "--glb",
                    str(EXPORT), "--materials", "original", "--no-arena",
                    "--eye="+eye, "--look", "0,2,0", "--lens", "42",
                    "--resolution", "960,640", "--samples", "24",
                    "--ground", "60", "--ground-y=-0.05",
                    "--out", str(PKG / ("review/"+view+".png")))
            run("render-gloss", "tools/blender/render_black_box_gloss.py")
        report["filesSha256"], report["measured"] = validate()
        report["status"] = "passed"
        report["limitations"] = [
            "Blender renders establish local appearance, not Studio visual approval.",
            "Roblox texture loading and actual Studio highlights are unverified.",
            "Size and non-colliding decoration role are provisional.",
            "Studio import and map integration are unverified.",
            "Check-only hashes previews but does not regenerate them.",
        ]
    except Exception as exc:
        report["status"] = "failed"
        report["error"] = str(exc)
        raise
    finally:
        (PKG / "validation.json").write_text(json.dumps(report, indent=2)+"\n",
                                               encoding="utf-8")
    print("PASS: glossy black-box local package; visual approval next.")

if __name__ == "__main__":
    main()
