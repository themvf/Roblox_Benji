"""Rebuild or locally verify three fuel drums and their grouped arrangement."""
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
PKG = ROOT / "assets/models/fuel-drum-set"
NAMES = ("FuelDrum_A", "FuelDrum_B", "FuelDrum_C", "FuelDrum_ThreePack")
SOURCE_SHA = "94e718d8378c8c9fda0c3dcab2aadd5bfcba1751a18d2d1662037ecafbc78149"
DECISION = (
    "Three weathered steel fuel drums for provisional static game decoration. "
    "The supplied 296,253-triangle TRELLIS GLB and saved image show three closely "
    "overlapping drums in one mesh. Spatial separation crosses 1,307 source faces "
    "and topology has 1,888 disconnected components, so clean complete cylinders "
    "were rebuilt instead of cutting incomplete source shells. The source image "
    "guides blue-gray enamel, rolled rims, recessed lids, bungs, rust and grime. "
    "Three slightly different individual drums and a three-drum arrangement are "
    "exported with embedded PNG color and roughness maps. Approximately 3.52-stud "
    "height, decoration role and non-collision are provisional. User visual approval, "
    "Studio import and map integration are pending."
)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def make_contact_sheet():
    width, height = 480, 350
    image = Image.new("RGB", (width * 2, height * 2), (230, 237, 244))
    draw = ImageDraw.Draw(image)
    font_path = Path("C:/Windows/Fonts/arial.ttf")
    font = ImageFont.truetype(str(font_path), 21) if font_path.exists() else ImageFont.load_default()
    for index, name in enumerate(NAMES):
        with Image.open(PKG / "review" / (name + ".png")) as preview:
            thumb = preview.convert("RGB")
            thumb.thumbnail((width - 16, height - 45))
            x = (index % 2) * width + (width - thumb.width) // 2
            y = (index // 2) * height + 3
            image.paste(thumb, (x, y))
        draw.text(((index % 2) * width + 12, (index // 2) * height + height - 36),
                  name, fill=(28, 40, 52), font=font)
    image.save(PKG / "review/contact-sheet.png")


def validate():
    if sha(PKG / "source/trellis-original.glb") != SOURCE_SHA:
        raise RuntimeError("Supplied source GLB changed")
    appraisal = json.loads((PKG / "appraisal.json").read_text(encoding="utf-8"))
    if appraisal.get("sourceSha256") != SOURCE_SHA or appraisal.get("decision") != DECISION:
        raise RuntimeError("Source appraisal decision is missing or stale")
    manifest = json.loads((PKG / "source/drum-manifest.json").read_text(encoding="utf-8"))
    if tuple(manifest["individuals"]) != NAMES[:3] or manifest["group"] != NAMES[3]:
        raise RuntimeError("Variant manifest changed")
    hashes = {}
    measured = []
    for name in NAMES:
        path = PKG / "exports" / (name + ".glb")
        doc, blob = gltf_post.read_glb(path)
        meshes = gltf_post.mesh_triangles(doc)
        expected = 3 if name == "FuelDrum_ThreePack" else 1
        if len(meshes) != expected or any(not 0 < tris < 10000 for _, tris in meshes):
            raise RuntimeError(name + ": unexpected mesh count or triangle budget")
        if any(tris != 2754 for _, tris in meshes):
            raise RuntimeError(name + ": unexpected generated drum geometry")
        if any("TEXCOORD_0" not in p["attributes"] for m in doc["meshes"] for p in m["primitives"]):
            raise RuntimeError(name + ": UVs missing")
        if any(key in node for node in doc["nodes"] for key in ("matrix", "translation", "rotation", "scale")):
            raise RuntimeError(name + ": unexpected node transform")
        if gltf_post.foreign_textures(doc):
            raise RuntimeError(name + ": unsupported texture")
        textures = gltf_post.texture_info(doc, blob)
        if textures != [("image/png", (1024, 1024))] * (2 * expected):
            raise RuntimeError(name + ": embedded PNG textures missing")
        if len(doc.get("materials", [])) != expected or any(
            not all(key in mat.get("pbrMetallicRoughness", {})
                    for key in ("baseColorTexture", "metallicRoughnessTexture"))
            for mat in doc["materials"]
        ):
            raise RuntimeError(name + ": PBR maps not wired")
        positions = [doc["accessors"][p["attributes"]["POSITION"]]
                     for m in doc["meshes"] for p in m["primitives"]]
        low = [min(a["min"][axis] for a in positions) for axis in range(3)]
        high = [max(a["max"][axis] for a in positions) for axis in range(3)]
        if abs(low[1]) > 0.005 or not 3.50 < high[1] < 3.60:
            raise RuntimeError(name + ": ground pivot or height wrong")
        hashes[str(path.relative_to(PKG)).replace("\\", "/")] = sha(path)
        measured.append({"name": name, "meshes": meshes, "boundsMin": low,
                         "boundsMax": high, "textures": textures, "bytes": path.stat().st_size})
    needed = ["source/FuelDrumSet.blend", "source/drum-manifest.json",
              "source/trellis-original.glb", "source/reference-three-drums.png",
              "appraisal.json", "views.png", "review/source-quarter.png",
              "review/contact-sheet.png", "SetupDecoration.luau",
              "trials/drum-analysis.json"]
    needed += ["textures/" + name + "_" + kind + ".png"
               for name in NAMES[:3] for kind in ("Color", "Roughness")]
    needed += ["review/" + name + ".png" for name in NAMES]
    needed += ["review/FuelDrum_A-" + view + ".png" for view in ("rear", "side", "top")]
    needed += ["review/FuelDrum_ThreePack-" + view + ".png"
               for view in ("rear", "side", "top")]
    for name in needed:
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
            backup = ROOT / ".mapbuild/fuel-drum-set" / stamp
            backup.mkdir(parents=True)
            for path in list((PKG / "exports").glob("*.glb")) + list((PKG / "review").glob("*.png")) + [
                PKG / "source/FuelDrumSet.blend", PKG / "source/drum-manifest.json",
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

            run("author", "tools/blender/build_fuel_drum_set.py")
            run("appraise", "tools/blender/appraise_asset.py", "--source",
                str(PKG / "source/trellis-original.glb"), "--record", str(PKG / "appraisal.json"))
            appraisal = json.loads((PKG / "appraisal.json").read_text(encoding="utf-8"))
            appraisal["decision"] = DECISION
            (PKG / "appraisal.json").write_text(json.dumps(appraisal, indent=2) + "\n", encoding="utf-8")
            views = [(name, name, "8,6,9", "0,1.8,0", "42") for name in NAMES[:3]]
            views.append((NAMES[3], NAMES[3], "0,6,11", "0,1.8,0", "42"))
            for name in (NAMES[0], NAMES[3]):
                views += [(name, name + "-rear", "-8,6,-9", "0,1.8,0", "42"),
                          (name, name + "-side", "10,5,0", "0,1.8,0", "42"),
                          (name, name + "-top", "0,12,1", "0,1.8,0", "34")]
            for export, view, eye, look, lens in views:
                run("render-" + view, "tools/blender/preview_scene.py",
                    "--glb", str(PKG / "exports" / (export + ".glb")),
                    "--ground", "24", "--materials", "original", "--no-arena",
                    "--samples", "16", "--resolution", "960,640",
                    "--eye=" + eye, "--look", look, "--lens", lens,
                    "--out", str(PKG / "review" / (view + ".png")))
            run("render-source", "tools/blender/preview_scene.py", "--glb",
                str(PKG / "source/trellis-original.glb"), "--fit-height", "4",
                "--ground", "24", "--materials", "original", "--no-arena",
                "--samples", "12", "--resolution", "960,640", "--eye", "8,6,9",
                "--look", "0,1.8,0", "--lens", "42",
                "--out", str(PKG / "review/source-quarter.png"))
            make_contact_sheet()
        report["filesSha256"], report["measured"] = validate()
        report["status"] = "passed"
        report["limitations"] = [
            "Rebuilt geometry and recreated weathering are based on the source and reference image; this is not a mesh extraction.",
            "Local preview is not user visual approval or verified Studio texture loading.",
            "Static noncolliding decoration and 3.52-stud height are provisional.",
            "No owner, upload IDs, saved placement, or published-map verification has been observed.",
        ]
    except Exception as error:
        report["status"] = "failed"
        report["error"] = str(error)
        raise
    finally:
        (PKG / "validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print("PASS: three fuel drums and grouped arrangement passed local checks")


if __name__ == "__main__":
    main()
