"""Build or verify the separate open-door field shelter export."""

import argparse
import datetime as dt
import json
import os
from pathlib import Path
import shutil

import build_snow_field_shelter as base
import gltf_post


PKG = base.PKG
ROOT = base.ROOT
EXPORT = PKG / "exports/SnowFieldShelter_OpenDoor.glb"
APPRAISAL = PKG / "review/open-export-appraisal.json"
VIEWS = base.VIEWS


def validate():
    source = json.loads((PKG / "appraisal.json").read_text(encoding="utf-8"))
    if source["sourceSha256"] != base.sha(PKG / "source/trellis-original.glb") or not source.get("decision"):
        raise RuntimeError("Shared source appraisal is invalid")
    doc, blob = gltf_post.read_glb(EXPORT)
    if len(doc.get("meshes", [])) != 8 or len(doc.get("materials", [])) != 8:
        raise RuntimeError("Expected eight material-grouped open shelter meshes")
    per_mesh = {}
    for mesh in doc["meshes"]:
        triangles = 0
        for primitive in mesh["primitives"]:
            if "TEXCOORD_0" not in primitive["attributes"] or "indices" not in primitive:
                raise RuntimeError("Open shelter primitive lacks indexed UV geometry")
            triangles += doc["accessors"][primitive["indices"]]["count"] // 3
        if not 0 < triangles < 10000:
            raise RuntimeError(f"Per-mesh triangle limit exceeded: {mesh['name']}")
        per_mesh[mesh["name"]] = triangles
    if len(doc.get("images", [])) != 9 or any(image.get("mimeType") != "image/png" for image in doc["images"]):
        raise RuntimeError("Expected nine embedded PNG maps")
    if gltf_post.foreign_textures(doc):
        raise RuntimeError("Unsupported GLB texture format")
    export_appraisal = json.loads(APPRAISAL.read_text(encoding="utf-8"))
    if export_appraisal["sourceSha256"] != base.sha(EXPORT) or not export_appraisal.get("decision"):
        raise RuntimeError("Open export appraisal is stale or incomplete")
    span = export_appraisal["measurements"]["size"]
    if not (24.3 < span[0] < 24.8 and 35.3 < span[1] < 35.9 and 14 < span[2] < 14.5):
        raise RuntimeError(f"Unexpected open shelter dimensions: {span}")
    names = ["appraisal.json", "source/reference.png", "source/trellis-original.glb",
             "source/SnowFieldShelter_OpenDoor.blend", "exports/SnowFieldShelter_OpenDoor.glb",
             "review/open-export-appraisal.json", "SetupOpenDecoration.luau"]
    names += [f"textures/{name}" for name in base.TEXTURES]
    names += ["textures/Slate_interior_walkway_Color.png"]
    names += [f"review/open-{name}.png" for name in VIEWS]
    hashes = {name: base.sha(PKG / name) for name in names}
    return hashes, {"meshTriangles": per_mesh, "totalTriangles": sum(per_mesh.values()),
                    "embeddedImages": len(doc["images"]), "worldDimensionsBlenderXYZ": span,
                    "exportBytes": EXPORT.stat().st_size}


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
            backup = ROOT / ".mapbuild/snow-field-shelter-open" / stamp
            backup.mkdir(parents=True, exist_ok=True)
            originals = [PKG / "source/SnowFieldShelter_OpenDoor.blend", EXPORT,
                         APPRAISAL, PKG / "validation-open.json"]
            originals += [PKG / "textures" / name for name in (*base.TEXTURES, "Slate_interior_walkway_Color.png")]
            originals += [PKG / f"review/open-{name}.png" for name in VIEWS]
            for path in originals:
                if path.exists():
                    destination = backup / path.relative_to(PKG)
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(path, destination)
            report["backup"] = str(backup.relative_to(ROOT))
            base.run_blender(blender, backup, "author-open", "tools/blender/build_snow_field_shelter.py", "--doors-open")
            for name, eye in VIEWS.items():
                base.run_blender(blender, backup, "render-" + name, "tools/blender/preview_scene.py",
                                 "--glb", str(EXPORT), "--place", "0,0,0,0", "--ground", "80",
                                 "--eye", eye, "--look", "0,7,0", "--materials", "original",
                                 "--no-arena", "--resolution", "1000,760",
                                 "--out", str(PKG / f"review/open-{name}.png"))
            base.run_blender(blender, backup, "appraise-open", "tools/blender/appraise_asset.py",
                             "--source", str(EXPORT), "--record", str(APPRAISAL))
        report["filesSha256"], report["measured"] = validate()
        report["status"] = "passed"
        report["limitations"] = [
            "Appearance is pending user approval and Studio texture verification.",
            "Door is fixed open; no hinge animation or working door script is included.",
            "The opening and short walkway are visible, but gameplay passage and collision have not been validated.",
            "No Studio import or saved map placement is verified.",
        ]
    except Exception as exc:
        report["status"] = "failed"
        report["error"] = str(exc)
        raise
    finally:
        (PKG / "validation-open.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("PASS: open-door shelter saved-file checks; visual approval and Studio stages pending")


if __name__ == "__main__":
    main()
