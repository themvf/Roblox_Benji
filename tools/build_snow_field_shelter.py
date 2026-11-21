"""Build or verify the closed snow field shelter asset package.

Run from the repository root: python tools/build_snow_field_shelter.py [--check-only]
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
PKG = ROOT / "assets/models/snow-field-shelter"
EXPORT = PKG / "exports/SnowFieldShelter.glb"
VIEWS = {
    "quarter": "28,12,32",
    "front": "0,9,34",
    "side": "36,9,0",
    "rear": "0,9,-34",
}
TEXTURES = (
    "Black_reinforced_seam_Color.png",
    "Charcoal_insulated_fabric_Color.png",
    "Charcoal_insulated_fabric_Normal.png",
    "Dark_sealed_window_Color.png",
    "Door_hardware_Color.png",
    "Graphite_window_gasket_Color.png",
    "Off-white_steel_door_Color.png",
    "White_painted_aluminum_Color.png",
)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate():
    appraisal = json.loads((PKG / "appraisal.json").read_text(encoding="utf-8"))
    source = PKG / "source/trellis-original.glb"
    if appraisal["sourceSha256"] != sha(source) or not appraisal.get("decision"):
        raise RuntimeError("Source appraisal is incomplete or no longer matches the source")
    reference = PKG / "source/reference.png"
    if sha(reference) != sha(ROOT / "Snow Props/degennfts_showcasing_a_3d_models_of_a_field_shelters_and_habi_94c50b19-9fd5-43f9-8f72-7b6b9fcdf083_2.png"):
        raise RuntimeError("Preserved concept image differs from intake reference")
    doc, blob = gltf_post.read_glb(EXPORT)
    if len(doc.get("meshes", [])) != 7 or len(doc.get("materials", [])) != 7:
        raise RuntimeError("Expected seven material-grouped meshes and materials")
    per_mesh = {}
    for mesh in doc["meshes"]:
        triangles = 0
        for primitive in mesh["primitives"]:
            if "TEXCOORD_0" not in primitive["attributes"]:
                raise RuntimeError("Export primitive has no UV map")
            if "indices" not in primitive:
                raise RuntimeError("Export primitive is not indexed")
            triangles += doc["accessors"][primitive["indices"]]["count"] // 3
        if not 0 < triangles < 10000:
            raise RuntimeError(f"Roblox per-mesh triangle limit exceeded: {mesh['name']}")
        per_mesh[mesh["name"]] = triangles
    if len(doc.get("images", [])) != 8 or any(i.get("mimeType") != "image/png" for i in doc["images"]):
        raise RuntimeError("Expected eight embedded PNG maps")
    if gltf_post.foreign_textures(doc):
        raise RuntimeError("Export has unsupported image extension")
    final_appraisal = json.loads((PKG / "review/export-appraisal.json").read_text(encoding="utf-8"))
    if final_appraisal["sourceSha256"] != sha(EXPORT):
        raise RuntimeError("Export appraisal does not match the saved GLB")
    span = final_appraisal["measurements"]["size"]
    if not (24.3 < span[0] < 24.8 and 32.5 < span[1] < 33.1 and 14 < span[2] < 14.5):
        raise RuntimeError(f"Unexpected exported dimensions: {span}")
    names = ["appraisal.json", "views.png", "source/reference.png",
             "source/trellis-original.glb", "source/SnowFieldShelter.blend",
             "exports/SnowFieldShelter.glb", "review/export-appraisal.json",
             "SetupDecoration.luau"]
    names += [f"textures/{name}" for name in TEXTURES]
    names += [f"review/final-{name}.png" for name in VIEWS]
    hashes = {name: sha(PKG / name) for name in names}
    return hashes, {
        "meshTriangles": per_mesh,
        "totalTriangles": sum(per_mesh.values()),
        "embeddedImages": len(doc["images"]),
        "worldDimensionsBlenderXYZ": span,
        "exportBytes": EXPORT.stat().st_size,
    }


def run_blender(blender, backup, label, script, *args):
    command = [str(blender), "--factory-startup", "-b", "--python-exit-code", "1", "--python", script]
    if args:
        command += ["--", *args]
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
                raise RuntimeError("Blender missing; use --blender PATH")
            backup = ROOT / ".mapbuild/snow-field-shelter" / stamp
            backup.mkdir(parents=True, exist_ok=True)
            originals = [PKG / "source/SnowFieldShelter.blend", EXPORT,
                         PKG / "review/export-appraisal.json", PKG / "validation.json"]
            originals += [PKG / "textures" / name for name in TEXTURES]
            originals += [PKG / f"review/final-{name}.png" for name in VIEWS]
            for path in originals:
                if path.exists():
                    destination = backup / path.relative_to(PKG)
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(path, destination)
            report["backup"] = str(backup.relative_to(ROOT))
            run_blender(blender, backup, "author", "tools/blender/build_snow_field_shelter.py")
            for name, eye in VIEWS.items():
                run_blender(blender, backup, "render-" + name, "tools/blender/preview_scene.py",
                            "--glb", str(EXPORT), "--place", "0,0,0,0", "--ground", "80",
                            "--eye", eye, "--look", "0,7,0", "--materials", "original",
                            "--no-arena", "--resolution", "1000,760",
                            "--out", str(PKG / f"review/final-{name}.png"))
            run_blender(blender, backup, "appraise-export", "tools/blender/appraise_asset.py",
                        "--source", str(EXPORT), "--record", str(PKG / "review/export-appraisal.json"))
        report["filesSha256"], report["measured"] = validate()
        report["status"] = "passed"
        report["limitations"] = [
            "Visual approval has not been given for this shelter.",
            "No Studio import, texture appearance, owner, collision, or map placement has been verified.",
            "This is a closed decorative shell with a nonfunctional door and opaque windows.",
            "Authoring size and decoration role are provisional until user approval.",
        ]
    except Exception as exc:
        report["status"] = "failed"
        report["error"] = str(exc)
        raise
    finally:
        (PKG / "validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("PASS: snow field shelter saved-file checks; visual approval and Studio stages pending")


if __name__ == "__main__":
    main()
