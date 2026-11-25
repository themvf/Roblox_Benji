"""Rebuild and validate the clean wrecked cargo unit, with export renders.

python tools/build_cargo_c_clean.py
python tools/build_cargo_c_clean.py --check-only
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
PKG = ROOT / "assets/models/cargo-c"
VIEWS = {"front-quarter": "14,9,13", "end": "18,5,0",
         "side": "0,5,17", "rear": "-16,6,-12"}
DECISION = (
    "Clean hard-surface rebuild of the user's wrecked cargo unit reference. "
    "The previous four-tile voxel optimization softened the manufactured panels, "
    "window and torn edges too much and was rejected by the user on 2026-10-11. "
    "The dense TRELLIS source and the prior export are retained for provenance. "
    "This ransacked version recreates the white framed shell, true open doorway "
    "and side hole, blue interior, angled window, broken swung door, scorched "
    "metal, jagged fragments, chipped paint, tipped storage cases, fallen panels, "
    "bent shelves, hanging conduit and scattered scrap. "
    "One mesh with an embedded color and metallic-roughness atlas, six studs tall, "
    "bottom pivot. Decoration role and size remain provisional pending approval."
)

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def validate():
    path = PKG / "exports/CargoWrecked.glb"
    doc, blob = gltf_post.read_glb(path)
    if len(doc.get("meshes", [])) != 1 or len(doc.get("materials", [])) != 1:
        raise RuntimeError("Expected one mesh and one atlas material")
    mesh = doc["meshes"][0]
    if len(mesh["primitives"]) != 1:
        raise RuntimeError("Expected one triangle primitive")
    prim = mesh["primitives"][0]
    if prim.get("mode", 4) != 4 or "TEXCOORD_0" not in prim["attributes"]:
        raise RuntimeError("Expected triangles and UVs")
    tris = doc["accessors"][prim["indices"]]["count"] // 3
    if not 0 < tris < 10000:
        raise RuntimeError("Roblox per-mesh triangle cap exceeded")
    pos = doc["accessors"][prim["attributes"]["POSITION"]]
    lo, hi = pos["min"], pos["max"]
    if abs(lo[1]) > .005 or abs(hi[1]-6) > .005:
        raise RuntimeError("Unexpected bottom pivot or height")
    if not (8.8 < hi[0]-lo[0] < 9.6 and 7.8 < hi[2]-lo[2] < 8.6):
        raise RuntimeError("Unexpected doorway/door footprint")
    if any(k in node for node in doc["nodes"]
           for k in ("matrix", "translation", "rotation", "scale")):
        raise RuntimeError("Unexpected GLB transform")
    if len(doc.get("images", [])) != 2 or any(i.get("mimeType") != "image/png" for i in doc["images"]):
        raise RuntimeError("Expected two embedded PNGs")
    if gltf_post.foreign_textures(doc):
        raise RuntimeError("Unsupported texture format")
    if any(size != (1024,1024) for _,size in gltf_post.texture_info(doc,blob)):
        raise RuntimeError("Expected 1024 texture maps")
    appraisal=json.loads((PKG/"appraisal.json").read_text(encoding="utf-8"))
    if appraisal["sourceSha256"] != sha(path) or appraisal.get("decision") != DECISION:
        raise RuntimeError("Current export appraisal is stale")
    if sha(PKG/"source/trellis-original.glb") != "579cd188088314186390d4010633e6808ebc01658cfbcc8c2e9414c5eb82be3b":
        raise RuntimeError("Original TRELLIS source changed")
    required = ["source/design-reference.png", "source/trellis-original.glb",
                "source/CargoC_Clean.blend", "exports/CargoWrecked.glb",
                "textures/CargoC_Clean_Color.png", "textures/CargoC_Clean_Roughness.png",
                "textures/CargoC_Clean_Metalness.png", "appraisal.json", "views.png",
                "SetupCargoWrecked.luau", "trials/CargoWrecked_voxel_2026-09-29.glb",
                "trials/CargoWrecked_clean_preweather.glb",
                "review/clean-preweather-front-quarter.png"]
    required += [f"review/clean-{v}.png" for v in VIEWS]
    hashes={name:sha(PKG/name) for name in required}
    return hashes,{"triangles":tris,"meshes":1,"boundsGlbYUp":{"min":lo,"max":hi},
                   "exportBytes":path.stat().st_size,
                   "embeddedTextureFormats":[i["mimeType"] for i in doc["images"]]}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--check-only",action="store_true")
    p.add_argument("--blender",type=Path)
    args=p.parse_args()
    stamp=datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    report={"checkedAtUtc":stamp,"mode":"check" if args.check_only else "rebuild",
            "status":"running","visualApproval":"pending","studioImport":"unverified"}
    output=PKG/"validation.json"
    try:
        if not args.check_only:
            blender=args.blender or shutil.which("blender")
            if not blender and os.name=="nt":
                candidate=Path(os.environ.get("ProgramFiles","C:/Program Files"))/"Blender Foundation/Blender 4.3/blender.exe"
                if candidate.exists(): blender=candidate
            if not blender: raise RuntimeError("Blender 4.3 missing; pass --blender PATH")
            backup=ROOT/".mapbuild/cargo-c-clean"/stamp
            backup.mkdir(parents=True)
            for name in ("source/CargoC_Clean.blend", "exports/CargoWrecked.glb",
                         "textures/CargoC_Clean_Color.png", "textures/CargoC_Clean_Roughness.png",
                         "textures/CargoC_Clean_Metalness.png", "appraisal.json", "views.png") + \
                        tuple(f"review/clean-{v}.png" for v in VIEWS):
                f=PKG/name
                if f.exists():
                    dest=backup/name; dest.parent.mkdir(parents=True,exist_ok=True)
                    shutil.copy2(f,dest)
            report["backup"]=str(backup.relative_to(ROOT))
            def run(label,script,*arguments):
                command=[str(blender),"--factory-startup","-b","--python-exit-code","1","--python",script]
                if arguments: command += ["--",*arguments]
                with (backup/(label+".log")).open("w",encoding="utf-8") as log:
                    subprocess.run(command,cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,
                                   check=True,timeout=600)
            run("author","tools/blender/build_cargo_c_clean.py")
            run("appraise","tools/blender/appraise_asset.py","--source",
                str(PKG/"exports/CargoWrecked.glb"),"--record",str(PKG/"appraisal.json"))
            appraisal=json.loads((PKG/"appraisal.json").read_text(encoding="utf-8"))
            appraisal["decision"]=DECISION
            (PKG/"appraisal.json").write_text(json.dumps(appraisal,indent=2)+"\n",encoding="utf-8")
            for view,eye in VIEWS.items():
                run("render-"+view,"tools/blender/preview_scene.py",
                    "--glb","assets/models/cargo-c/exports/CargoWrecked.glb",
                    "--materials","original","--no-arena","--eye="+eye,
                    "--look","0,2.8,0","--lens","40","--resolution","960,640",
                    "--samples","24","--ground","200","--ground-y=-0.05",
                    "--out",str(PKG/f"review/clean-{view}.png"))
        report["filesSha256"],report["measured"]=validate()
        report["status"]="passed"
        report["limitations"]=[
            "Local validation and Blender renders do not establish user visual approval or Studio import.",
            "Six-stud height and non-colliding decoration role are provisional.",
            "Check-only verifies saved files and hashes; it does not regenerate renders.",
        ]
    except Exception as exc:
        report["status"]="failed"; report["error"]=str(exc)
        raise
    finally:
        output.write_text(json.dumps(report,indent=2)+"\n",encoding="utf-8")
    print("PASS: clean cargo-c local package; visual approval and Studio import pending")

if __name__=="__main__": main()
