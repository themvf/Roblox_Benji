"""Rebuild or locally check wrapped and plain Roblox-ready crate variants."""
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
PKG = ROOT / "assets/models/wrapped-white-crate"
EXPORT = PKG / "exports/WrappedWhiteCrate.glb"
PLAIN_EXPORT = PKG / "exports/PlainWoodenCrates.glb"
SOURCE_SHA = "7f79db77ea652eb29f6493ca43d82418329918a3d573658f2e6c6add3ad0da9a"
VIEWS = {"front-quarter": "8,6,9", "rear-quarter": "-8,6,-9",
         "right-end": "14,6,0", "top": "1,17,1"}
PLAIN_VIEWS = {"plain-front-quarter": "8,6,9", "plain-rear-quarter": "-8,6,-9",
               "plain-top": "1,17,1"}
DECISION = (
    "Two pale wooden shipping crates on one pallet, supplied as a 296,178-triangle TRELLIS GLB. "
    "The 9,000-triangle trial damaged slats and top detail. A 17,800-triangle reduction "
    "retains the silhouette and readable wood, split into two pieces under Roblox's "
    "10,000-triangle per-mesh limit. A newly modeled off-white plastic film covers "
    "the full length of both boxes, including top, sides, and both ends; "
    "only the pallet feet remain exposed. Provisional 8-stud-long, static "
    "decoration. Visual approval, Studio import, and map placement are separate pending stages."
)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def validate():
    doc, blob = gltf_post.read_glb(EXPORT)
    meshes = gltf_post.mesh_triangles(doc)
    if len(meshes) != 8 or any(not 0 < tris < 10000 for _, tris in meshes):
        raise RuntimeError("Unexpected mesh count or Roblox per-mesh triangle cap exceeded")
    if "WhiteWrap_RightEnd" not in dict(meshes):
        raise RuntimeError("Right-end plastic panel missing")
    if any("TEXCOORD_0" not in p["attributes"] for m in doc["meshes"] for p in m["primitives"]):
        raise RuntimeError("UVs missing")
    positions = [doc["accessors"][p["attributes"]["POSITION"]]
                 for m in doc["meshes"] for p in m["primitives"]]
    low = [min(a["min"][axis] for a in positions) for axis in range(3)]
    high = [max(a["max"][axis] for a in positions) for axis in range(3)]
    if abs(low[1]) > 0.005 or not 8.0 < high[0] - low[0] < 8.3 or not 3.8 < high[1] < 4.1:
        raise RuntimeError("Unexpected bottom pivot or stud dimensions")
    if any(key in node for node in doc["nodes"] for key in ("matrix", "translation", "rotation", "scale")):
        raise RuntimeError("Unexpected node transform")
    if gltf_post.foreign_textures(doc):
        raise RuntimeError("Unsupported texture format")
    textures = gltf_post.texture_info(doc, blob)
    if len(textures) != 4 or any(mime != "image/png" for mime, _ in textures):
        raise RuntimeError("Expected four embedded PNG textures")
    plain_doc, plain_blob = gltf_post.read_glb(PLAIN_EXPORT)
    plain_meshes = gltf_post.mesh_triangles(plain_doc)
    wood_meshes = {name: tris for name, tris in meshes if name.startswith("CrateWood_")}
    if dict(plain_meshes) != wood_meshes or len(plain_meshes) != 2:
        raise RuntimeError("Plain variant must contain exactly the same two wood meshes")
    if any("TEXCOORD_0" not in p["attributes"] for m in plain_doc["meshes"] for p in m["primitives"]):
        raise RuntimeError("Plain variant UVs missing")
    if any(key in node for node in plain_doc["nodes"] for key in ("matrix", "translation", "rotation", "scale")):
        raise RuntimeError("Unexpected plain variant node transform")
    if gltf_post.foreign_textures(plain_doc):
        raise RuntimeError("Plain variant uses unsupported textures")
    plain_textures = gltf_post.texture_info(plain_doc, plain_blob)
    if len(plain_textures) != 2 or any(mime != "image/png" for mime, _ in plain_textures):
        raise RuntimeError("Plain variant must embed two wood PNG textures")
    plain_positions = [plain_doc["accessors"][p["attributes"]["POSITION"]]
                       for m in plain_doc["meshes"] for p in m["primitives"]]
    plain_low = [min(a["min"][axis] for a in plain_positions) for axis in range(3)]
    plain_high = [max(a["max"][axis] for a in plain_positions) for axis in range(3)]
    if abs(plain_low[1]) > 0.005 or not 7.8 < plain_high[0] - plain_low[0] < 8.1:
        raise RuntimeError("Plain variant bottom pivot or length changed")
    if sha(PKG / "source/trellis-original.glb") != SOURCE_SHA:
        raise RuntimeError("Supplied source changed")
    appraisal = json.loads((PKG / "appraisal.json").read_text(encoding="utf-8"))
    if appraisal.get("sourceSha256") != SOURCE_SHA or appraisal.get("decision") != DECISION:
        raise RuntimeError("Appraisal decision missing or stale")
    required = [
        "source/trellis-original.glb", "source/WrappedWhiteCrate.blend", "appraisal.json",
        "views.png", "exports/WrappedWhiteCrate.glb", "textures/Wood_Color.png",
        "textures/Wood_ORM.png", "textures/Plastic_Color.png",
        "textures/Plastic_Roughness.png", "review/source-quarter.png",
        "trials/decimate-9000.glb", "trials/decimate-9000-quarter.png",
        "source/PlainWoodenCrates.blend", "exports/PlainWoodenCrates.glb",
        "SetupDecoration.luau", "SetupPlainDecoration.luau",
    ] + ["review/" + view + ".png" for view in VIEWS | PLAIN_VIEWS]
    hashes = {name: sha(PKG / name) for name in required}
    return hashes, {"meshes": meshes, "totalTriangles": sum(n for _, n in meshes),
                    "boundsMin": low, "boundsMax": high,
                    "materials": len(doc.get("materials", [])), "embeddedTextures": textures,
                    "exportBytes": EXPORT.stat().st_size,
                    "plain": {"meshes": plain_meshes, "boundsMin": plain_low,
                              "boundsMax": plain_high, "embeddedTextures": plain_textures,
                              "exportBytes": PLAIN_EXPORT.stat().st_size}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument("--blender", type=Path)
    args = parser.parse_args()
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    report = {"checkedAtUtc": stamp, "mode": "check" if args.check_only else "rebuild",
              "status": "running", "visualApproval": "pending", "studioImport": "unverified",
              "mapIntegration": "unverified"}
    try:
        if not args.check_only:
            blender = args.blender or shutil.which("blender")
            if not blender and os.name == "nt":
                blender = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Blender Foundation/Blender 4.3/blender.exe"
            if not blender or not Path(blender).exists():
                raise RuntimeError("Blender missing; pass --blender PATH")
            backup = ROOT / ".mapbuild/wrapped-white-crate" / stamp
            backup.mkdir(parents=True)
            for name in ("source/WrappedWhiteCrate.blend", "exports/WrappedWhiteCrate.glb",
                         "source/PlainWoodenCrates.blend", "exports/PlainWoodenCrates.glb",
                         "appraisal.json", "views.png") + tuple("review/" + n + ".png" for n in VIEWS | PLAIN_VIEWS):
                source = PKG / name
                if source.exists():
                    destination = backup / name
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(source, destination)
            report["backup"] = str(backup.relative_to(ROOT))

            def run(label, script, *arguments):
                command = [str(blender), "--factory-startup", "-b", "-t", "4",
                           "--python-exit-code", "1", "--python", script]
                if arguments:
                    command += ["--", *arguments]
                print(label, flush=True)
                with (backup / (label + ".log")).open("w", encoding="utf-8") as log:
                    subprocess.run(command, cwd=ROOT, stdout=log,
                                   stderr=subprocess.STDOUT, check=True, timeout=1800)

            run("author", "tools/blender/build_wrapped_white_crate.py")
            run("author-plain", "tools/blender/build_plain_wooden_crates.py")
            run("appraise", "tools/blender/appraise_asset.py", "--source",
                str(PKG / "source/trellis-original.glb"), "--record", str(PKG / "appraisal.json"))
            appraisal = json.loads((PKG / "appraisal.json").read_text(encoding="utf-8"))
            appraisal["decision"] = DECISION
            (PKG / "appraisal.json").write_text(json.dumps(appraisal, indent=2) + "\n", encoding="utf-8")
            for view, eye in VIEWS.items():
                run("render-" + view, "tools/blender/preview_scene.py", "--glb", str(EXPORT),
                    "--materials", "original", "--no-arena", "--ground", "24",
                    "--eye=" + eye, "--look", "0,1.8,0", "--lens", "32" if view == "top" else "42",
                    "--samples", "16", "--resolution", "1000,700",
                    "--out", str(PKG / ("review/" + view + ".png")))
            for view, eye in PLAIN_VIEWS.items():
                run("render-" + view, "tools/blender/preview_scene.py", "--glb", str(PLAIN_EXPORT),
                    "--materials", "original", "--no-arena", "--ground", "24",
                    "--eye=" + eye, "--look", "0,1.8,0", "--lens", "32" if view == "plain-top" else "42",
                    "--samples", "16", "--resolution", "1000,700",
                    "--out", str(PKG / ("review/" + view + ".png")))
        report["filesSha256"], report["measured"] = validate()
        report["status"] = "passed"
        report["limitations"] = ["Local renders are not user visual approval or Studio import evidence.",
                                 "Static decoration role and 8-stud length are provisional.",
                                 "The plain variant has not been imported or placed in Studio."]
    except Exception as error:
        report["status"] = "failed"
        report["error"] = str(error)
        raise
    finally:
        (PKG / "validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("PASS: wrapped and plain crate local packages; visual approval next")


if __name__ == "__main__":
    main()
