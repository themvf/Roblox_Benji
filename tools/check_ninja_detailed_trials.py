"""Record structural checks for experimental segmented ninja skin exports."""
import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
PKG = ROOT / "assets/models/ninja-soldier-skins"
TRIALS = PKG / "trials"
record = {"checkedAt": datetime.now(timezone.utc).isoformat(),
          "status": "experimental, pose preview fails visual quality gate", "variants": {}}
for variant in ("SciFiSentry", "TacticalOperator"):
    path = TRIALS / f"{variant}DetailedSegmented.glb"
    raw = path.read_bytes()
    assert raw[:4] == b"glTF" and struct.unpack_from("<I", raw, 8)[0] == len(raw)
    json_size, kind = struct.unpack_from("<II", raw, 12)
    assert kind == 0x4E4F534A
    gltf = json.loads(raw[20:20 + json_size])
    manifest = json.loads((TRIALS / f"{variant}DetailedSegmented.json").read_text())
    counts = [sum(gltf["accessors"][p["indices"]]["count"] // 3
                  for p in mesh["primitives"]) for mesh in gltf["meshes"]]
    assert len(counts) == len(manifest["parts"])
    assert max(counts) <= 8000
    assert sum(counts) == sum(part["triangles"] for part in manifest["parts"])
    assert len(gltf.get("images", [])) >= 1
    pose = PKG / "review" / f"{variant}-detailed-pose.png"
    assert pose.read_bytes()[:8] == b"\x89PNG\r\n\x1a\n"
    record["variants"][variant] = {
        "sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw),
        "meshCount": len(counts), "triangles": sum(counts),
        "largestMeshTriangles": max(counts), "embeddedImages": len(gltf["images"]),
        "weaponOffcutTriangles": manifest["weaponOffcutTriangles"],
        "posePreviewSha256": hashlib.sha256(pose.read_bytes()).hexdigest(),
    }
(TRIALS / "validation.json").write_text(json.dumps(record, indent=2) + "\n")
print(json.dumps(record, indent=2))
