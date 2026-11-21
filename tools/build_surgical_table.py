"""Rebuild and verify four separately placeable surgical-room props.

python tools/build_surgical_table.py
python tools/build_surgical_table.py --check-only
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
PKG = ROOT / "assets/models/surgical-table"
ITEMS = {
    "table": ("SurgicalTable.glb", 5, 1),
    "lights": ("SurgicalLights.glb", 5, 0),
    "monitor": ("PatientMonitor.glb", 6, 0),
    "iv": ("IVStand.glb", 4, 0),
}
VIEWS = ("front", "side", "rear", "quarter")
CAMERA = {
    "table": {"eyes": ("-13,5,5", "0,5,18", "13,5,-5", "12,6,10"),
              "look": "0,2.6,0", "lens": "45"},
    "lights": {"eyes": ("-12,6,8", "0,6,16", "14,6,-8", "10,6,10"),
               "look": "0,4,0", "lens": "40"},
    "monitor": {"eyes": ("-8,5,4", "0,5,12", "8,5,-4", "8,5,8"),
                "look": "0,2.5,0", "lens": "50"},
    "iv": {"eyes": ("-11,6,7", "0,6,14", "11,6,-7", "8,5,8"),
           "look": "0,3,0", "lens": "45"},
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate():
    appraisal = json.loads((PKG / "appraisal.json").read_text(encoding="utf-8"))
    if not appraisal.get("decision") or appraisal["sourceSha256"] != digest(PKG / "source/trellis-original.glb"):
        raise RuntimeError("Source appraisal missing or inconsistent")
    layout = json.loads((PKG / "source/assembly-layout.json").read_text(encoding="utf-8"))
    if set(layout) != set(ITEMS):
        raise RuntimeError("Assembly layout does not list all separate props")
    measured = {}
    for item, (filename, mesh_count, image_count) in ITEMS.items():
        if layout[item]["export"] != filename or len(layout[item]["placementRobloxXYZStuds"]) != 3:
            raise RuntimeError(item + ": invalid assembly placement")
        export = PKG / "exports" / filename
        doc, blob = gltf_post.read_glb(export)
        if len(doc.get("meshes", [])) != mesh_count or len(doc.get("materials", [])) != mesh_count:
            raise RuntimeError(item + ": unexpected meshes or materials")
        counts, bounds = [], []
        for mesh in doc["meshes"]:
            if len(mesh["primitives"]) != 1:
                raise RuntimeError(item + ": unexpected multiprimitive mesh")
            primitive = mesh["primitives"][0]
            count = doc["accessors"][primitive["indices"]]["count"] // 3
            if not 0 < count < 10000 or "TEXCOORD_0" not in primitive["attributes"]:
                raise RuntimeError(item + ": triangle budget or UV check failed")
            counts.append(count)
            accessor = doc["accessors"][primitive["attributes"]["POSITION"]]
            bounds.append((accessor["min"], accessor["max"]))
        low = [min(box[0][i] for box in bounds) for i in range(3)]
        high = [max(box[1][i] for box in bounds) for i in range(3)]
        if abs(low[1]) > .005 or max(abs(low[0] + high[0]), abs(low[2] + high[2])) > .005:
            raise RuntimeError(item + ": expected centered ground pivot")
        if any(any(key in node for key in ("matrix", "translation", "rotation", "scale"))
               for node in doc["nodes"]):
            raise RuntimeError(item + ": unexpected export transform")
        if gltf_post.foreign_textures(doc):
            raise RuntimeError(item + ": unsupported texture")
        images = doc.get("images", [])
        if len(images) != image_count or any(img.get("mimeType") != "image/png" for img in images):
            raise RuntimeError(item + ": unexpected embedded images")
        if item == "table" and gltf_post.texture_info(doc, blob)[0][1] != (1024, 1024):
            raise RuntimeError("Table blue-vinyl texture is not 1024 pixels")
        measured[item] = {"meshCount": mesh_count, "trianglesPerMesh": counts,
                          "totalTriangles": sum(counts),
                          "boundsGlbYUp": {"min": low, "max": high},
                          "embeddedPngCount": image_count,
                          "exportBytes": export.stat().st_size}
    required = ["source/trellis-original.glb", "source/design-reference.png",
                "source/SurgicalTable.blend", "source/assembly-layout.json",
                "appraisal.json", "views.png", "textures/SurgicalTable_BlueVinyl_Color.png"]
    required += ["exports/" + filename for filename, _, _ in ITEMS.values()]
    required += ["review/%s-%s.png" % (item, view) for item in ITEMS for view in VIEWS]
    return {name: digest(PKG / name) for name in required}, measured


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
                candidate = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "Blender Foundation/Blender 4.3/blender.exe"
                if candidate.exists():
                    blender = candidate
            if not blender:
                raise RuntimeError("Blender 4.3 missing; pass --blender PATH")
            backup = ROOT / ".mapbuild/surgical-table" / stamp
            backup.mkdir(parents=True)
            generated = ["source/SurgicalTable.blend", "source/assembly-layout.json",
                         "textures/SurgicalTable_BlueVinyl_Color.png"]
            generated += ["exports/" + filename for filename, _, _ in ITEMS.values()]
            generated += ["review/%s-%s.png" % (item, view)
                          for item in ITEMS for view in VIEWS]
            for name in generated:
                path = PKG / name
                if path.exists():
                    target = backup / name
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(path, target)
            report["backup"] = str(backup.relative_to(ROOT))

            def run(label, command):
                with (backup / (label + ".log")).open("w", encoding="utf-8") as log:
                    subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                   check=True, timeout=600)

            run("texture", ["python", "tools/make_surgical_table_texture.py"])
            base = [str(blender), "--factory-startup", "-b", "-t", "4",
                    "--python-exit-code", "1", "--python"]
            run("author", base + ["tools/blender/build_surgical_table.py"])
            for item, (filename, _, _) in ITEMS.items():
                camera = CAMERA[item]
                for index, view in enumerate(VIEWS):
                    run("render-%s-%s" % (item, view), base + [
                        "tools/blender/preview_scene.py", "--", "--glb",
                        "assets/models/surgical-table/exports/" + filename,
                        "--ground", "16", "--materials", "original", "--no-arena",
                        "--eye=" + camera["eyes"][index], "--look", camera["look"],
                        "--lens", camera["lens"], "--resolution", "900,900",
                        "--samples", "16", "--out",
                        str(PKG / "review" / (item + "-" + view + ".png"))])
        report["filesSha256"], report["measured"] = validate()
        report["status"] = "passed"
        report["limitations"] = [
            "Four exports are independent visual props; no functional medical interaction or real lighting is implemented.",
            "Appearance, scale, and roles await user review; Studio import and map placement remain unverified.",
            "Check-only verifies saved structure and hashes, not visual quality.",
        ]
    except Exception as exc:
        report["status"] = "failed"
        report["error"] = str(exc)
        raise
    finally:
        (PKG / "validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("PASS: four independent surgical-room exports; approval and Studio import pending")


if __name__ == "__main__":
    main()
