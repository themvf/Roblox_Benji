"""Rebuild or locally verify the nine individually placeable roof vents."""
import argparse
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess

from PIL import Image, ImageDraw, ImageFont
import gltf_post

ROOT = Path(__file__).resolve().parents[1]
PKG = ROOT / "assets/models/roof-vent-set"
MANIFEST = PKG / "source/vent-manifest.json"
SOURCE_SHA = "535cce079c9e0f4623d05cf7af279cfc1dd1fc22a33523b3ab140b097c3dd1a1"
DECISION = (
    "Nine separate roof ventilation props for provisional static rooftop decoration, "
    "viewed at player scale from all sides. The supplied TRELLIS GLB is a 3x3 product "
    "sheet with 291,238 triangles in one mesh; the two PNG references establish the "
    "intended vent set and single-vent style. Measured empty coordinate gaps separate "
    "all nine without cutting any source faces. A 60-percent per-prop reduction keeps "
    "their silhouettes and broad detail; original-source trials show the remaining "
    "uneven grille bars predate reduction. Each export is split into mesh parts below "
    "Roblox's 10,000-triangle per-mesh limit and embeds PNG textures. Four-stud maximum "
    "footprint and decoration role are provisional. User visual approval, Studio import, "
    "and map integration are pending."
)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def eyes(name, view):
    if name == "TallVentStack":
        return {"front": ("9,9,12", "0,3.1,0", "36"),
                "rear": ("-9,9,-12", "0,3.1,0", "36"),
                "side": ("11,8,0", "0,3.1,0", "36")}[view]
    if view == "side":
        return "10,5,0", "0,1.8,0", "42"
    swap = name in {"SlantedLouverHood", "RectangularIntakeBox"}
    front = "-8,6,-9" if swap else "8,6,9"
    rear = "8,6,9" if swap else "-8,6,-9"
    return (front if view == "front" else rear), "0,1.8,0", "42"


def view_path(name, view):
    return PKG / "review" / (name + ("" if view == "front" else "-" + view) + ".png")


def make_contact_sheet(manifest):
    names = [asset["name"] for asset in manifest["assets"]]
    tile_w, tile_h = 420, 330
    image = Image.new("RGB", (tile_w * 3, tile_h * 3), (232, 238, 244))
    draw = ImageDraw.Draw(image)
    font_path = Path("C:/Windows/Fonts/arial.ttf")
    font = ImageFont.truetype(str(font_path), 21) if font_path.exists() else ImageFont.load_default()
    for index, name in enumerate(names):
        with Image.open(view_path(name, "front")) as preview:
            thumb = preview.convert("RGB")
            thumb.thumbnail((tile_w - 16, tile_h - 50))
            x = (index % 3) * tile_w + (tile_w - thumb.width) // 2
            y = (index // 3) * tile_h + 4
            image.paste(thumb, (x, y))
        draw.text(((index % 3) * tile_w + 12, (index // 3) * tile_h + tile_h - 38),
                  name, fill=(29, 40, 52), font=font)
    image.save(PKG / "review/contact-sheet.png")


def validate():
    if sha(PKG / "source/trellis-original.glb") != SOURCE_SHA:
        raise RuntimeError("Original GLB changed")
    appraisal = json.loads((PKG / "appraisal.json").read_text(encoding="utf-8"))
    if appraisal.get("sourceSha256") != SOURCE_SHA or appraisal.get("decision") != DECISION:
        raise RuntimeError("Appraisal decision missing or stale")
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    assets = manifest["assets"]
    if len(assets) != 9 or len({a["name"] for a in assets}) != 9:
        raise RuntimeError("Expected nine independent exports")
    if {(a["gridRowBottomFirst"], a["gridColumnLeftFirst"]) for a in assets} != {
            (row, col) for row in range(3) for col in range(3)}:
        raise RuntimeError("A source-grid prop is missing or duplicated")
    if manifest["sourceFaces"] != 291236 or sum(a["sourceTriangles"] for a in assets) != 291236:
        raise RuntimeError("Source faces were lost or assigned twice")
    if manifest["retainedRatio"] != 0.6:
        raise RuntimeError("Unexpected geometry reduction")
    hashes = {}
    measured = []
    for asset in assets:
        name = asset["name"]
        export = PKG / asset["export"]
        doc, blob = gltf_post.read_glb(export)
        parts = gltf_post.mesh_triangles(doc)
        if len(parts) < 2 or any(not 0 < tris < 10000 for _, tris in parts):
            raise RuntimeError(name + ": per-mesh triangle budget failed")
        if sum(tris for _, tris in parts) != asset["exportTriangles"] or (
                [tris for _, tris in parts] != asset["partTriangles"]):
            raise RuntimeError(name + ": manifest triangle counts differ from saved GLB")
        if any(not part.startswith(name + "_Part") for part, _ in parts):
            raise RuntimeError(name + ": wrong mesh identity")
        if any("TEXCOORD_0" not in p["attributes"] for m in doc["meshes"] for p in m["primitives"]):
            raise RuntimeError(name + ": UVs missing")
        if any(key in node for node in doc["nodes"] for key in ("matrix", "translation", "rotation", "scale")):
            raise RuntimeError(name + ": unexpected node transform")
        if gltf_post.foreign_textures(doc):
            raise RuntimeError(name + ": unsupported texture")
        textures = gltf_post.texture_info(doc, blob)
        if textures != [("image/png", (2048, 2048))] * 2:
            raise RuntimeError(name + ": expected two embedded 2048px PNG textures")
        mats = doc.get("materials", [])
        if len(mats) != 1 or not all(key in mats[0].get("pbrMetallicRoughness", {})
                                      for key in ("baseColorTexture", "metallicRoughnessTexture")):
            raise RuntimeError(name + ": color or packed surface texture is not wired")
        positions = [doc["accessors"][p["attributes"]["POSITION"]]
                     for m in doc["meshes"] for p in m["primitives"]]
        low = [min(a["min"][axis] for a in positions) for axis in range(3)]
        high = [max(a["max"][axis] for a in positions) for axis in range(3)]
        if abs(low[1]) > 0.005 or abs(low[0] + high[0]) > 0.2 or abs(low[2] + high[2]) > 0.2:
            raise RuntimeError(name + ": ground pivot or centering failed")
        if not 3.9 < max(high[0] - low[0], high[2] - low[2]) < 4.1:
            raise RuntimeError(name + ": footprint is not about four studs")
        if sha(export) in hashes.values():
            raise RuntimeError("Two exports are identical")
        hashes[asset["export"]] = sha(export)
        for view in ("front", "rear", "side"):
            path = view_path(name, view)
            hashes[str(path.relative_to(PKG)).replace("\\", "/")] = sha(path)
        measured.append({"name": name, "meshes": parts, "boundsMin": low,
                         "boundsMax": high, "textures": textures, "bytes": export.stat().st_size})
    required = ["source/trellis-original.glb", "source/RoofVentSet.blend",
                "source/vent-manifest.json", "source/roof-vent-reference.png",
                "source/nine-vent-reference.png", "appraisal.json", "views.png",
                "textures/RoofVents_Color.png", "textures/RoofVents_ORM.png",
                "review/contact-sheet.png", "SetupDecoration.luau",
                "trials/grid-analysis.json", "trials/raw/SlantedLouverHood.png",
                "trials/raw/WideRoofLouver.png"]
    for name in required:
        hashes[name] = sha(PKG / name)
    return hashes, measured


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
            backup = ROOT / ".mapbuild/roof-vent-set" / stamp
            backup.mkdir(parents=True)
            for path in list((PKG / "exports").glob("*.glb")) + list((PKG / "review").glob("*.png")) + [
                PKG / "source/RoofVentSet.blend", PKG / "source/vent-manifest.json",
                PKG / "appraisal.json", PKG / "views.png"]:
                if path.exists():
                    dest = backup / path.relative_to(PKG)
                    dest.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(path, dest)
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

            run("author", "tools/blender/build_roof_vent_set.py")
            run("appraise", "tools/blender/appraise_asset.py", "--source",
                str(PKG / "source/trellis-original.glb"), "--record", str(PKG / "appraisal.json"))
            appraisal = json.loads((PKG / "appraisal.json").read_text(encoding="utf-8"))
            appraisal["decision"] = DECISION
            (PKG / "appraisal.json").write_text(json.dumps(appraisal, indent=2) + "\n", encoding="utf-8")
            manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
            for asset in manifest["assets"]:
                name = asset["name"]
                for view in ("front", "rear", "side"):
                    eye, look, lens = eyes(name, view)
                    run("render-" + name + "-" + view, "tools/blender/preview_scene.py",
                        "--glb", str(PKG / asset["export"]), "--ground", "24",
                        "--materials", "original", "--no-arena", "--samples", "12",
                        "--resolution", "960,640", "--eye=" + eye,
                        "--look", look, "--lens", lens, "--out", str(view_path(name, view)))
            make_contact_sheet(manifest)
        report["filesSha256"], report["measured"] = validate()
        report["status"] = "passed"
        report["limitations"] = [
            "Local textured renders and geometry checks do not establish user visual approval or Studio import.",
            "The TRELLIS source already has uneven grille bars in two vents; raw-source trials show this.",
            "Four-stud maximum footprint and static decoration are provisional.",
            "No placement, owner, asset IDs, Roblox texture loading, or published-map check has been observed.",
        ]
    except Exception as error:
        report["status"] = "failed"
        report["error"] = str(error)
        raise
    finally:
        (PKG / "validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("PASS: nine separate roof-vent GLBs passed local checks")


if __name__ == "__main__":
    main()
