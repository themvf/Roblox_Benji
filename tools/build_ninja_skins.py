"""Rebuild or verify both R15 character skin candidates without publishing them."""
from __future__ import annotations

import argparse
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
import shutil
import struct
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PKG = ROOT / "assets/models/ninja-soldier-skins"
EXPECTED = {
    "SciFiSentry": ("d667838e7ac402cab9952cdd788819328f5c1645e5e58cf44fb2aa6a7dccbef2", 39),
    "TacticalOperator": ("c54379a03a5bcabf6690bd99977e2aa47945076053e2a39e5d02983c4a5ec7c0", 33),
}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inspect_glb(path: Path) -> dict:
    raw = path.read_bytes()
    assert raw[:4] == b"glTF" and struct.unpack_from("<I", raw, 8)[0] == len(raw), path
    chunk_size, chunk_type = struct.unpack_from("<II", raw, 12)
    assert chunk_type == 0x4E4F534A, path
    doc = json.loads(raw[20:20 + chunk_size])
    triangles = []
    for mesh in doc["meshes"]:
        count = sum(doc["accessors"][primitive["indices"]]["count"] // 3
                    for primitive in mesh["primitives"])
        assert count <= 10000, (path, mesh.get("name"), count)
        triangles.append(count)
    assert not doc.get("images"), path
    return {"meshes": len(doc["meshes"]), "triangles": sum(triangles),
            "largestMeshTriangles": max(triangles), "sha256": digest(path), "bytes": len(raw)}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check-only", action="store_true")
    parser.add_argument("--blender", default=r"C:\Program Files\Blender Foundation\Blender 4.3\blender.exe")
    args = parser.parse_args()
    if not args.check_only:
        backup = ROOT / ".mapbuild" / "ninja-soldier-skins" / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        for folder in ("exports", "review"):
            shutil.copytree(PKG / folder, backup / folder, dirs_exist_ok=True)
        subprocess.run(["python", "tools/build_ninja_skin_specs.py"], cwd=ROOT, check=True)
        subprocess.run(["stylua", "src/shared/CharacterSkins/Definitions.lua"], cwd=ROOT, check=True)
        for variant in EXPECTED:
            for script, log_name in (("build_ninja_armor.py", "build"),
                                     ("render_ninja_armor.py", "render")):
                log = PKG / "review" / f"{variant}-{log_name}.log"
                with log.open("w", encoding="utf-8") as handle:
                    subprocess.run([args.blender, "-b", "-noaudio", "--python",
                                    f"tools/blender/{script}", "--", variant], cwd=ROOT,
                                   stdout=handle, stderr=subprocess.STDOUT, check=True)

    record = {"checkedAt": datetime.now(timezone.utc).isoformat(), "ok": True,
              "scope": "Local source, GLB, R15 specs and saved preview files; no Studio import or playtest",
              "variants": {}}
    specs = json.loads((PKG / "source/armor_specs.json").read_text(encoding="utf-8"))["variants"]
    for variant, (expected_hash, expected_pieces) in EXPECTED.items():
        original = PKG / "source" / f"{variant}Source.glb"
        actual_hash = digest(original)
        assert actual_hash == expected_hash, (variant, actual_hash)
        assert len(specs[variant]["pieces"]) == expected_pieces, variant
        for piece in specs[variant]["pieces"]:
            assert piece["attach"] in {"Head", "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm",
                                       "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand",
                                       "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
                                       "LeftFoot", "RightFoot"}, piece
            assert all(d > 0 for d in piece["size"]), piece
        exported = inspect_glb(PKG / "exports" / f"{variant}Armor.glb")
        assert exported["meshes"] == expected_pieces, variant
        previews = {}
        for view in ("front", "side", "rear", "quarter"):
            preview = PKG / "review" / f"{variant}-{view}.png"
            assert preview.read_bytes()[:8] == b"\x89PNG\r\n\x1a\n", preview
            previews[view] = digest(preview)
        scene = PKG / "source" / f"{variant}Armor.blend"
        assert scene.is_file() and scene.stat().st_size > 1000, scene
        record["variants"][variant] = {"sourceSha256": actual_hash,
                                       "pieceCount": expected_pieces, "export": exported,
                                       "editableSceneSha256": digest(scene), "previewsSha256": previews}
    (PKG / "validation.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({name: item["export"] for name, item in record["variants"].items()}, indent=2))


if __name__ == "__main__":
    main()
