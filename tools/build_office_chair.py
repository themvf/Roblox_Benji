"""Rebuild and verify the clean and lightly stained office chair packages.

Run from the repository root: python tools/build_office_chair.py
Check saved artifacts only: python tools/build_office_chair.py --check-only
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
PKG = ROOT / "assets/models/office-chair"
VARIANTS = {"clean": "OfficeChair_Clean", "stained": "OfficeChair_YellowStained"}
VIEWS = {"front": "0,4,12", "side": "12,4,0", "rear": "0,4,-12", "quarter": "8,5,8"}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def geometry_signatures(doc, blob):
    signatures = []
    for mesh in doc["meshes"]:
        primitive = mesh["primitives"][0]
        values = []
        for accessor_index in [primitive["indices"], *(primitive["attributes"][key]
                               for key in sorted(primitive["attributes"]))]:
            accessor = doc["accessors"][accessor_index]
            view = doc["bufferViews"][accessor["bufferView"]]
            start = view.get("byteOffset", 0)
            data = blob[start:start + view["byteLength"]]
            values.append((accessor["count"], accessor["componentType"],
                           accessor["type"], hashlib.sha256(data).hexdigest()))
        signatures.append(values)
    return signatures


def validate():
    appraisal = json.loads((PKG / "appraisal.json").read_text(encoding="utf-8"))
    if appraisal["sourceSha256"] != digest(PKG / "source/trellis-original.glb") or not appraisal["decision"]:
        raise RuntimeError("Source appraisal is missing or no longer matches")
    measured = {}
    signatures = {}
    for variant, name in VARIANTS.items():
        doc, blob = gltf_post.read_glb(PKG / "exports" / (name + ".glb"))
        if len(doc.get("meshes", [])) != 3 or len(doc.get("materials", [])) != 1:
            raise RuntimeError(name + ": expected three meshes and one material")
        triangles, bounds = [], []
        for mesh in doc["meshes"]:
            if len(mesh["primitives"]) != 1:
                raise RuntimeError(name + ": expected one primitive per mesh")
            primitive = mesh["primitives"][0]
            count = doc["accessors"][primitive["indices"]]["count"] // 3
            if not 0 < count < 10000 or "TEXCOORD_0" not in primitive["attributes"]:
                raise RuntimeError(name + ": mesh budget or UV check failed")
            triangles.append(count)
            accessor = doc["accessors"][primitive["attributes"]["POSITION"]]
            bounds.append((accessor["min"], accessor["max"]))
        low = [min(box[0][i] for box in bounds) for i in range(3)]
        high = [max(box[1][i] for box in bounds) for i in range(3)]
        if abs(low[1]) > .005 or abs(high[1] - 5) > .005:
            raise RuntimeError(name + ": expected five-stud bottom pivot")
        if max(abs(low[0] + high[0]), abs(low[2] + high[2])) > .05:
            raise RuntimeError(name + ": expected horizontally centered geometry")
        if any(any(k in node for k in ("matrix", "translation", "rotation", "scale"))
               for node in doc["nodes"]):
            raise RuntimeError(name + ": unexpected node transform")
        images = doc.get("images", [])
        if len(images) != 2 or any(i.get("mimeType") != "image/png" for i in images):
            raise RuntimeError(name + ": expected two embedded PNGs")
        if gltf_post.foreign_textures(doc):
            raise RuntimeError(name + ": unsupported texture format")
        if any(size != (2048, 2048) for _, size in gltf_post.texture_info(doc, blob)):
            raise RuntimeError(name + ": unexpected texture size")
        signatures[variant] = geometry_signatures(doc, blob)
        measured[variant] = {"trianglesPerMesh": triangles,
                             "boundsGlbYUp": {"min": low, "max": high},
                             "exportBytes": (PKG / "exports" / (name + ".glb")).stat().st_size}
    if signatures["clean"] != signatures["stained"]:
        raise RuntimeError("The two variants have different geometry")
    if digest(PKG / "textures/OfficeChair_Clean_Color.png") == digest(PKG / "textures/OfficeChair_YellowStained_Color.png"):
        raise RuntimeError("The two variant color maps are identical")
    required = ["source/trellis-original.glb", "source/design-reference.png",
                "source/trellis-color.png", "source/trellis-metallic-roughness.png",
                "source/OfficeChair.blend", "source/stain-metrics.json", "appraisal.json",
                "views.png", "textures/OfficeChair_Clean_Color.png",
                "textures/OfficeChair_YellowStained_Color.png",
                "textures/OfficeChair_MetallicRoughness.png",
                "exports/OfficeChair_Clean.glb", "exports/OfficeChair_YellowStained.glb"]
    required += ["review/%s-%s.png" % (variant, view)
                 for variant in VARIANTS for view in VIEWS]
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
            backup = ROOT / ".mapbuild/office-chair" / stamp
            backup.mkdir(parents=True)
            generated = ["source/OfficeChair.blend", "source/stain-metrics.json",
                         "exports/OfficeChair_Clean.glb", "exports/OfficeChair_YellowStained.glb"]
            generated += ["textures/OfficeChair_%s_Color.png" % v for v in ("Clean", "YellowStained")]
            generated += ["review/%s-%s.png" % (variant, view)
                          for variant in VARIANTS for view in VIEWS]
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

            run("textures", ["python", "tools/make_office_chair_textures.py"])
            base = [str(blender), "--factory-startup", "-b", "-t", "4",
                    "--python-exit-code", "1", "--python"]
            run("author", base + ["tools/blender/build_office_chair.py"])
            for variant, name in VARIANTS.items():
                for view, eye in VIEWS.items():
                    run("render-%s-%s" % (variant, view), base + [
                        "tools/blender/preview_scene.py", "--", "--glb",
                        "assets/models/office-chair/exports/" + name + ".glb",
                        "--materials", "original", "--no-arena", "--eye=" + eye,
                        "--look", "0,2.5,0", "--lens", "55", "--resolution", "900,900",
                        "--samples", "16", "--out", str(PKG / "review" / (variant + "-" + view + ".png"))])
        report["filesSha256"], report["measured"] = validate()
        report["status"] = "passed"
        report["limitations"] = [
            "Local checks do not establish user visual approval, Studio import, or map integration.",
            "Five-stud size and decoration role remain provisional until user review.",
            "Trellis source has residual generated-surface irregularities.",
        ]
    except Exception as exc:
        report["status"] = "failed"
        report["error"] = str(exc)
        raise
    finally:
        (PKG / "validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("PASS: office chair local exports; user visual approval and Studio import pending")


if __name__ == "__main__":
    main()
