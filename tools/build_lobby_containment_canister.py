"""Rebuild and verify the lobby containment canister, or check its saved files.

From repository root: python tools/build_lobby_containment_canister.py [--check-only]
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
PKG = ROOT / "assets/models/lobby-containment-canister"
EXPORT = PKG / "exports/LobbyContainmentCanister.glb"
VIEWS = {"quarter": "8,5,10", "front": "0,4,12",
         "side": "12,4,0", "rear": "0,4,-12"}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate():
    source_appraisal = json.loads((PKG / "appraisal.json").read_text(encoding="utf-8"))
    if not source_appraisal.get("decision") or source_appraisal["sourceSha256"] != sha(PKG / "source/trellis-original.glb"):
        raise RuntimeError("Source appraisal does not match preserved original")
    doc, blob = gltf_post.read_glb(EXPORT)
    if len(doc.get("meshes", [])) != 18 or len(doc.get("materials", [])) != 10:
        raise RuntimeError("Expected 18 meshes and 10 named materials")
    per_mesh, bounds = {}, []
    for mesh in doc["meshes"]:
        count = 0
        for primitive in mesh["primitives"]:
            if "indices" not in primitive:
                raise RuntimeError("Mesh primitive lacks indices")
            material = doc["materials"][primitive["material"]]
            if material.get("pbrMetallicRoughness", {}).get("baseColorTexture") and "TEXCOORD_0" not in primitive["attributes"]:
                raise RuntimeError("Textured primitive lacks UVs")
            count += doc["accessors"][primitive["indices"]]["count"] // 3
            bounds.append(doc["accessors"][primitive["attributes"]["POSITION"]])
        if not 0 < count < 10000:
            raise RuntimeError(f"Roblox per-mesh triangle limit exceeded: {mesh['name']}")
        per_mesh[mesh["name"]] = count
    if not 72_000 < sum(per_mesh.values()) < 73_000:
        raise RuntimeError("Unexpected total triangle count")
    lo = [min(item["min"][i] for item in bounds) for i in range(3)]
    hi = [max(item["max"][i] for item in bounds) for i in range(3)]
    if abs(lo[1]) > .02 or abs(hi[1]-8) > .02:
        raise RuntimeError("Ground pivot or 8-stud height changed")
    if any(any(k in node for k in ("translation", "rotation", "scale", "matrix")) for node in doc.get("nodes", [])):
        raise RuntimeError("Unexpected node transform in export")
    if len(doc.get("images", [])) != 3 or any(image.get("mimeType") != "image/png" for image in doc["images"]):
        raise RuntimeError("Expected three embedded PNG images")
    if gltf_post.foreign_textures(doc) or doc.get("extensionsRequired"):
        raise RuntimeError("Unsupported texture extension in export")
    sizes = sorted(size for _, size in gltf_post.texture_info(doc, blob))
    if sizes != [(1024, 1024), (1024, 1024), (1086, 1448)]:
        raise RuntimeError(f"Unexpected embedded PNG sizes: {sizes}")
    materials = {m["name"]: m for m in doc["materials"]}
    if materials["Chamber_Glass"].get("alphaMode") != "BLEND" or materials["Energy_Textured_Plume"].get("alphaMode") != "BLEND":
        raise RuntimeError("Glass or plume alpha blending missing")
    if materials["Energy_Cyan"].get("emissiveFactor") is None:
        raise RuntimeError("Energy material is not emissive")
    export_appraisal = json.loads((PKG / "review/export-appraisal.json").read_text(encoding="utf-8"))
    if export_appraisal["sourceSha256"] != sha(EXPORT) or not export_appraisal.get("decision"):
        raise RuntimeError("Saved export appraisal is stale or incomplete")
    span = export_appraisal["measurements"]["size"]
    if not (4.6 < span[0] < 4.9 and 4.6 < span[1] < 4.9 and abs(span[2]-8) < .02):
        raise RuntimeError(f"Unexpected saved export dimensions: {span}")
    names = ["appraisal.json", "views.png", "source/trellis-original.glb",
             "source/reference-clear-blue-chamber.png",
             "source/LobbyContainmentCanister.blend", "exports/LobbyContainmentCanister.glb",
             "textures/LobbyContainmentCanister_Color.png", "textures/LobbyContainmentCanister_MetalRough.png",
             "textures/LobbyContainmentCanister_Energy.png",
             "review/export-appraisal.json", "SetupDecoration.luau", "SetupChamberMotion.luau"]
    names += [f"review/final-{name}.png" for name in VIEWS]
    hashes = {name: sha(PKG / name) for name in names}
    return hashes, {"meshTriangles": per_mesh, "totalTriangles": sum(per_mesh.values()),
                    "boundsGlbYUp": {"min": lo, "max": hi}, "worldDimensionsBlenderXYZ": span,
                    "embeddedImages": 3, "exportBytes": EXPORT.stat().st_size}


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
            backup = ROOT / ".mapbuild/lobby-containment-canister" / stamp
            backup.mkdir(parents=True, exist_ok=True)
            originals = [PKG / "source/LobbyContainmentCanister.blend", EXPORT,
                         PKG / "review/export-appraisal.json", PKG / "validation.json",
                         PKG / "textures/LobbyContainmentCanister_Color.png", PKG / "textures/LobbyContainmentCanister_MetalRough.png"]
            originals += [PKG / f"review/final-{name}.png" for name in VIEWS]
            for path in originals:
                if path.exists():
                    destination = backup / path.relative_to(PKG)
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(path, destination)
            report["backup"] = str(backup.relative_to(ROOT))
            run(blender, backup, "author", "tools/blender/build_lobby_containment_canister.py")
            for name, eye in VIEWS.items():
                run(blender, backup, "render-" + name, "tools/blender/preview_scene.py",
                    "--glb", str(EXPORT), "--place", "0,0,0,0", "--ground", "14",
                    "--eye", eye, "--look", "0,4,0", "--materials", "original",
                    "--no-arena", "--resolution", "900,900",
                    "--out", str(PKG / f"review/final-{name}.png"))
            run(blender, backup, "appraise-export", "tools/blender/appraise_asset.py",
                "--source", str(EXPORT), "--record", str(PKG / "review/export-appraisal.json"))
        report["filesSha256"], report["measured"] = validate()
        report["status"] = "passed"
        report["limitations"] = [
            "This local delivery is a lobby decoration candidate; gameplay collision has not been specified.",
            "72,673 triangles across 18 meshes is a high-detail prop; repeated placement needs a Studio performance check.",
            "Visual approval, Studio texture and collision verification, and lobby placement are pending.",
            "A GLB alpha and emissive material does not prove Studio will render transparent glass, layered energy or glow correctly.",
            "The optional particle motion helper is syntax checked only; Studio texture reuse, containment and performance are unverified.",
        ]
    except Exception as exc:
        report["status"] = "failed"
        report["error"] = str(exc)
        raise
    finally:
        (PKG / "validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("PASS: lobby containment canister saved-file checks; visual approval and Studio stages pending")


if __name__ == "__main__":
    main()


