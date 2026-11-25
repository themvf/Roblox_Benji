"""Rebuild and verify the lobby stone column, or check its saved files.

From repository root: python tools/build_lobby_stone_column.py [--check-only]
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
PKG = ROOT / "assets/models/lobby-stone-column"
EXPORT = PKG / "exports/LobbyStoneColumn.glb"
VIEWS = {"quarter": "5,7,10", "front": "0,6,12",
         "side": "12,6,0", "rear": "0,6,-12"}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate():
    source_appraisal = json.loads((PKG / "appraisal.json").read_text(encoding="utf-8"))
    if not source_appraisal.get("decision") or source_appraisal["sourceSha256"] != sha(PKG / "source/trellis-original.glb"):
        raise RuntimeError("Source appraisal does not match preserved original")
    doc, blob = gltf_post.read_glb(EXPORT)
    if len(doc.get("meshes", [])) != 6 or len(doc.get("materials", [])) != 1:
        raise RuntimeError("Expected six meshes sharing one material")
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
    if not 42_000 < sum(per_mesh.values()) < 44_000:
        raise RuntimeError("Unexpected total triangle count")
    lo = [min(item["min"][i] for item in bounds) for i in range(3)]
    hi = [max(item["max"][i] for item in bounds) for i in range(3)]
    if abs(lo[1]) > .02 or abs(hi[1]-12) > .02:
        raise RuntimeError("Ground pivot or 12-stud height changed")
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
    if not (2.3 < span[0] < 2.5 and 2.3 < span[1] < 2.5 and abs(span[2]-12) < .02):
        raise RuntimeError(f"Unexpected saved export dimensions: {span}")
    names = ["appraisal.json", "views.png", "source/trellis-original.glb",
             "source/LobbyStoneColumn.blend", "exports/LobbyStoneColumn.glb",
             "textures/LobbyStoneColumn_Color.png", "textures/LobbyStoneColumn_MetalRough.png",
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
            backup = ROOT / ".mapbuild/lobby-stone-column" / stamp
            backup.mkdir(parents=True, exist_ok=True)
            originals = [PKG / "source/LobbyStoneColumn.blend", EXPORT,
                         PKG / "review/export-appraisal.json", PKG / "validation.json",
                         PKG / "textures/LobbyStoneColumn_Color.png", PKG / "textures/LobbyStoneColumn_MetalRough.png"]
            originals += [PKG / f"review/final-{name}.png" for name in VIEWS]
            for path in originals:
                if path.exists():
                    destination = backup / path.relative_to(PKG)
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(path, destination)
            report["backup"] = str(backup.relative_to(ROOT))
            run(blender, backup, "author", "tools/blender/build_lobby_stone_column.py")
            for name, eye in VIEWS.items():
                run(blender, backup, "render-" + name, "tools/blender/preview_scene.py",
                    "--glb", str(EXPORT), "--place", "0,0,0,0", "--ground", "20",
                    "--eye", eye, "--look", "0,6,0", "--materials", "original",
                    "--no-arena", "--resolution", "900,900",
                    "--out", str(PKG / f"review/final-{name}.png"))
            run(blender, backup, "appraise-export", "tools/blender/appraise_asset.py",
                "--source", str(EXPORT), "--record", str(PKG / "review/export-appraisal.json"))
        report["filesSha256"], report["measured"] = validate()
        report["status"] = "passed"
        report["limitations"] = [
            "This local delivery is a lobby decoration candidate; gameplay collision has not been specified.",
            "42,900 triangles across six meshes is a high-detail prop; repeated placement needs a Studio performance check.",
            "Visual approval, Studio texture and collision verification, and lobby placement are pending.",
            "A successful PNG GLB export does not prove Studio will apply the packed metal/roughness map.",
        ]
    except Exception as exc:
        report["status"] = "failed"
        report["error"] = str(exc)
        raise
    finally:
        (PKG / "validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("PASS: lobby stone column saved-file checks; visual approval and Studio stages pending")


if __name__ == "__main__":
    main()

