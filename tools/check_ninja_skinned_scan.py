"""Validate the saved detailed Sentry game-skin candidate without rebuilding it."""
from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
PKG = ROOT / "assets/models/ninja-soldier-skins"
TRIAL = PKG / "trials/SciFiSentrySkinnedScan10"

def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

source = PKG / "source/SciFiSentrySource.glb"
assert digest(source) == "d667838e7ac402cab9952cdd788819328f5c1645e5e58cf44fb2aa6a7dccbef2"
glb = TRIAL / "SciFiSentrySkinnedScan.glb"
raw = glb.read_bytes()
assert raw[:4] == b"glTF" and struct.unpack_from("<I", raw, 8)[0] == len(raw)
json_size, chunk_type = struct.unpack_from("<II", raw, 12)
assert chunk_type == 0x4E4F534A
doc = json.loads(raw[20:20+json_size])
assert len(doc.get("skins", [])) == 1
skin = doc["skins"][0]
assert len(skin["joints"]) == 15
assert len(doc.get("images", [])) == 2
assert all(image["mimeType"] == "image/png" for image in doc["images"])
assert "EXT_texture_webp" not in doc.get("extensionsUsed", [])
bin_header = 20 + json_size
bin_size, bin_type = struct.unpack_from("<II", raw, bin_header)
assert bin_type == 0x004E4942
bin_offset = bin_header + 8
assert bin_offset + bin_size <= len(raw)
texture_dir = TRIAL / "textures"
texture_dir.mkdir(exist_ok=True)
for index, image in enumerate(doc["images"]):
    view = doc["bufferViews"][image["bufferView"]]
    start = bin_offset + view.get("byteOffset", 0)
    content = raw[start:start+view["byteLength"]]
    assert content.startswith(b"\x89PNG\r\n\x1a\n")
    (texture_dir / f"SciFiSentry_EmbeddedMap_{index:02d}.png").write_bytes(content)
triangles = []
for mesh in doc["meshes"]:
    count = 0
    for primitive in mesh["primitives"]:
        assert "JOINTS_0" in primitive["attributes"] and "WEIGHTS_0" in primitive["attributes"]
        count += doc["accessors"][primitive["indices"]]["count"] // 3
    assert count <= 10000, (mesh.get("name"), count)
    triangles.append({"name": mesh.get("name"), "triangles": count})
assert len(triangles) == 5
assert sum(row["triangles"] for row in triangles) < 32000
previews = {}
for name in ("front", "side", "rear", "joint-bend"):
    path = TRIAL / (name + ".png")
    assert path.read_bytes().startswith(b"\x89PNG\r\n\x1a\n")
    previews[name] = digest(path)
textures = {}
for path in sorted((TRIAL / "textures").glob("*.png")):
    assert path.read_bytes().startswith(b"\x89PNG\r\n\x1a\n")
    textures[path.name] = digest(path)
assert len(textures) == 4
blend = TRIAL / "SciFiSentrySkinnedScan.blend"
assert blend.stat().st_size > 1000
report = {
    "checkedAt": datetime.now(timezone.utc).isoformat(),
    "localStructure": "pass",
    "sourceSha256": digest(source),
    "glbSha256": digest(glb),
    "glbBytes": len(raw),
    "editableBlendSha256": digest(blend),
    "bones": 15,
    "meshes": triangles,
    "embeddedTextureFormat": "PNG",
    "namedTextureSha256": textures,
    "previewSha256": previews,
    "visualStatus": "review candidate; user approval not recorded",
    "studioStatus": "not imported or animation tested in Studio",
    "marketplaceStatus": "not compliant: fragmented open source geometry, no dynamic head or cages",
    "knownLimits": ["vertex weights are provisional", "only one manually posed bend reviewed",
                    "source texture may need material tuning in Studio", "game performance not tested"],
}
(TRIAL / "validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"meshes": triangles, "bones": 15, "textures": len(textures),
                  "localStructure": "pass"}, indent=2))
