"""Rebuild and verify the snow utility vehicle, or check its saved files.

From repository root: python tools/build_snow_utility_vehicle.py [--check-only]
"""

import argparse
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

import gltf_post


ROOT = Path(__file__).resolve().parents[1]
PKG = ROOT / "assets/models/snow-utility-vehicle"
EXPORT = PKG / "exports/SnowUtilityVehicle.glb"
VIEWS = {"quarter": "13,8,18", "front": "0,6,22",
         "side": "22,6,0", "rear": "0,6,-22"}
REFERENCE = ROOT / "Snow Vehicles/degennfts_showcasing_a_3d_models_of_a_sci_fi_futuristic_utili_ae929d03-2769-4f9c-9903-add5600d69bc_1.png"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate():
    source_appraisal = json.loads((PKG / "appraisal.json").read_text(encoding="utf-8"))
    if not source_appraisal.get("decision") or source_appraisal["sourceSha256"] != sha(PKG / "source/trellis-original.glb"):
        raise RuntimeError("Source appraisal does not match preserved original")
    if sha(PKG / "source/reference.png") != sha(REFERENCE):
        raise RuntimeError("Preserved reference does not match intake image")
    doc, blob = gltf_post.read_glb(EXPORT)
    if len(doc.get("meshes", [])) != 9 or len(doc.get("materials", [])) != 1:
        raise RuntimeError("Expected nine meshes sharing one material")
    per_mesh, bounds = {}, []
    for mesh in doc["meshes"]:
        count = 0
        for primitive in mesh["primitives"]:
            if "indices" not in primitive or "TEXCOORD_0" not in primitive["attributes"]:
                raise RuntimeError("Mesh primitive lacks indices or UVs")
            count += doc["accessors"][primitive["indices"]]["count"] // 3
            bounds.append(doc["accessors"][primitive["attributes"]["POSITION"]])
        if not 0 < count < 10000:
            raise RuntimeError(f"Roblox per-mesh triangle limit exceeded: {mesh['name']}")
        per_mesh[mesh["name"]] = count
    if not 69_000 < sum(per_mesh.values()) < 71_000:
        raise RuntimeError("Unexpected total triangle count")
    lo = [min(item["min"][i] for item in bounds) for i in range(3)]
    hi = [max(item["max"][i] for item in bounds) for i in range(3)]
    if abs(lo[1]) > .005 or abs(hi[1]-7) > .005:
        raise RuntimeError("Ground pivot or seven-stud height changed")
    if any(any(k in node for k in ("translation", "rotation", "scale", "matrix")) for node in doc.get("nodes", [])):
        raise RuntimeError("Unexpected node transform in export")
    if len(doc.get("images", [])) != 2 or any(image.get("mimeType") != "image/png" for image in doc["images"]):
        raise RuntimeError("Expected two embedded PNG images")
    if gltf_post.foreign_textures(doc) or doc.get("extensionsRequired"):
        raise RuntimeError("Unsupported texture extension in export")
    if any(size != (1024, 1024) for _, size in gltf_post.texture_info(doc, blob)):
        raise RuntimeError("Expected 1024 by 1024 PNG maps")
    export_appraisal = json.loads((PKG / "review/export-appraisal.json").read_text(encoding="utf-8"))
    if export_appraisal["sourceSha256"] != sha(EXPORT) or not export_appraisal.get("decision"):
        raise RuntimeError("Saved export appraisal is stale or incomplete")
    span = export_appraisal["measurements"]["size"]
    if not (8.3 < span[0] < 8.6 and 14 < span[1] < 14.3 and abs(span[2]-7) < .02):
        raise RuntimeError(f"Unexpected saved export dimensions: {span}")
    names = ["appraisal.json", "views.png", "source/reference.png", "source/trellis-original.glb",
             "source/SnowUtilityVehicle.blend", "exports/SnowUtilityVehicle.glb",
             "textures/Vehicle_Color.png", "textures/Vehicle_MetalRough.png",
             "review/export-appraisal.json", "SetupDecoration.luau"]
    names += [f"review/final-{name}.png" for name in VIEWS]
    hashes = {name: sha(PKG / name) for name in names}
    return hashes, {"meshTriangles": per_mesh, "totalTriangles": sum(per_mesh.values()),
                    "boundsGlbYUp": {"min": lo, "max": hi}, "worldDimensionsBlenderXYZ": span,
                    "embeddedImages": 2, "exportBytes": EXPORT.stat().st_size}


def run(blender, backup, label, script, *arguments):
    command = [str(blender), "--factory-startup", "-b", "--python-exit-code", "1", "--python", script]
    if arguments:
        command += ["--", *arguments]
    with (backup / f"{label}.log").open("w", encoding="utf-8") as log:
        subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                       check=True, timeout=600)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument("--blender", type=Path)
    args = parser.parse_args()
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
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
            backup = ROOT / ".mapbuild/snow-utility-vehicle" / stamp
            backup.mkdir(parents=True, exist_ok=True)
            originals = [PKG / "source/SnowUtilityVehicle.blend", EXPORT,
                         PKG / "review/export-appraisal.json", PKG / "validation.json",
                         PKG / "textures/Vehicle_Color.png", PKG / "textures/Vehicle_MetalRough.png"]
            originals += [PKG / f"review/final-{name}.png" for name in VIEWS]
            for path in originals:
                if path.exists():
                    destination = backup / path.relative_to(PKG)
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(path, destination)
            report["backup"] = str(backup.relative_to(ROOT))
            run(blender, backup, "author", "tools/blender/build_snow_utility_vehicle.py")
            for name, eye in VIEWS.items():
                run(blender, backup, "render-" + name, "tools/blender/preview_scene.py",
                    "--glb", str(EXPORT), "--place", "0,0,0,0", "--ground", "35",
                    "--eye", eye, "--look", "0,3,0", "--materials", "original",
                    "--no-arena", "--resolution", "1000,760",
                    "--out", str(PKG / f"review/final-{name}.png"))
            run(blender, backup, "appraise-export", "tools/blender/appraise_asset.py",
                "--source", str(EXPORT), "--record", str(PKG / "review/export-appraisal.json"))
        report["filesSha256"], report["measured"] = validate()
        report["status"] = "passed"
        report["limitations"] = [
            "The current package is a stationary visual prop, not a drivable Roblox vehicle.",
            "70,178 triangles across nine meshes is relatively high; avoid mass placement until Studio performance is checked.",
            "Visual approval, Studio texture/physics verification, and map integration are pending.",
            "A successful PNG GLB export does not prove Studio will apply the packed metal/roughness map.",
        ]
    except Exception as exc:
        report["status"] = "failed"
        report["error"] = str(exc)
        raise
    finally:
        (PKG / "validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("PASS: snow utility vehicle saved-file checks; visual approval and Studio stages pending")


if __name__ == "__main__":
    main()
