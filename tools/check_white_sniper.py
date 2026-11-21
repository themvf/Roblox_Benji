"""Validate the deliverable rifle GLB and write its local evidence record."""
from datetime import datetime, timezone
from hashlib import sha256
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
PKG = ROOT / "assets/models/white-sniper"


def digest(path):
    return sha256(path.read_bytes()).hexdigest()


def glb_json(path):
    with path.open("rb") as f:
        magic, version, length = struct.unpack("<III", f.read(12))
        assert magic == 0x46546C67 and version == 2 and length == path.stat().st_size
        chunk_size, chunk_type = struct.unpack("<II", f.read(8))
        assert chunk_type == 0x4E4F534A
        return json.loads(f.read(chunk_size))


def main():
    export = PKG / "exports/WhiteSniper.glb"
    source = PKG / "source/White Sniper.glb"
    blend = PKG / "source/WhiteSniper.blend"
    doc = glb_json(export)
    counts = []
    for mesh in doc["meshes"]:
        total = 0
        for primitive in mesh["primitives"]:
            assert primitive.get("mode", 4) == 4
            total += doc["accessors"][primitive["indices"]]["count"] // 3
        counts.append(total)
    assert len(counts) == 8, counts
    assert all(0 < count <= 9500 for count in counts), counts
    assert sum(counts) == 72000, counts
    assert len(doc["images"]) == 2
    assert all(image["mimeType"] == "image/png" for image in doc["images"])
    assert all("TEXCOORD_0" in primitive["attributes"] for mesh in doc["meshes"] for primitive in mesh["primitives"])
    for name in ("side.png", "front.png", "rear.png"):
        assert (PKG / "review" / name).stat().st_size > 10000
    assert source.is_file() and blend.is_file()
    result = {
        "checkedAt": datetime.now(timezone.utc).isoformat(),
        "status": "local-pass",
        "sourceSha256": digest(source),
        "exportSha256": digest(export),
        "blendSha256": digest(blend),
        "meshTriangles": counts,
        "totalTriangles": sum(counts),
        "embeddedImageMimeTypes": [image["mimeType"] for image in doc["images"]],
        "texturedViews": ["review/side.png", "review/front.png", "review/rear.png"],
        "limits": "No Studio import, wield, in-game damage, death timer, or map placement verified by this check.",
    }
    (PKG / "validation.json").write_text(json.dumps(result, indent=2) + "\n")
    print(f"WhiteSniper local pass: {counts}, 2 embedded PNG textures")


if __name__ == "__main__":
    main()
