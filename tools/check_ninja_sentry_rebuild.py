"""Verify saved, isolated Sentry articulation-repair trial without rebuilding."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
PKG = ROOT / "assets/models/ninja-soldier-skins"
TRIAL = PKG / "trials/SciFiSentryRebuiltArmor"
SOURCE = PKG / "trials/SciFiSentrySkinnedScan10/SciFiSentrySkinnedScan.glb"
EXPORT = TRIAL / "SciFiSentryRebuiltArmor.glb"
BLEND = TRIAL / "SciFiSentryRebuiltArmor.blend"
MANIFEST = TRIAL / "manifest.json"
VALIDATION = TRIAL / "validation.json"
EXPECTED_SOURCE = "c91f6f36e1fa449be9c8a529d800928e23924ab1bd1b3d94eaf102fe9e5cc1c9"


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def glb_json(path: Path) -> dict:
    raw = path.read_bytes()
    assert raw[:4] == b"glTF" and struct.unpack_from("<I", raw, 8)[0] == len(raw)
    length, kind = struct.unpack_from("<II", raw, 12)
    assert kind == 0x4E4F534A
    return json.loads(raw[20:20 + length])


def main() -> None:
    assert sha(SOURCE) == EXPECTED_SOURCE, "Base Sentry trial changed"
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    doc = glb_json(EXPORT)
    assert BLEND.stat().st_size > 100_000
    assert manifest["nonmanifoldEdgesInRebuiltObjects"] == 0
    assert manifest["closedRebuiltObjects"] >= 50
    assert len(doc.get("skins", [])) == 1
    assert len(doc["skins"][0]["joints"]) == 15
    assert len(doc["meshes"]) >= 50
    counts = {mesh["name"]: sum(doc["accessors"][part["indices"]]["count"] // 3
                                 for part in mesh["primitives"])
              for mesh in doc["meshes"]}
    assert max(counts.values()) <= 10_000
    assert len(doc.get("images", [])) >= 8
    for view in ("front", "side", "rear", "joint-bend"):
        assert (TRIAL / f"{view}.png").stat().st_size > 10_000
    VALIDATION.write_text(json.dumps({
        "checkedAtUtc": datetime.now(timezone.utc).isoformat(),
        "status": "local structural pass; posed visual trial only",
        "sourceSha256": EXPECTED_SOURCE,
        "exportSha256": sha(EXPORT),
        "blendSha256": sha(BLEND),
        "meshCount": len(doc["meshes"]),
        "totalTriangles": sum(counts.values()),
        "largestMeshTriangles": max(counts.values()),
        "glTfSkinCount": 1,
        "jointCount": len(doc["skins"][0]["joints"]),
        "embeddedImageCount": len(doc["images"]),
        "closedRebuiltObjects": manifest["closedRebuiltObjects"],
        "removedScanFaces": sum(manifest["removedScanFacesByPart"].values()),
        "reviewSha256": {v: sha(TRIAL / f"{v}.png")
                         for v in ("front", "side", "rear", "joint-bend")},
        "visualApproval": "pending",
        "studioImport": "not attempted for this trial",
        "marketplaceReadiness": "fails: no dynamic head/cages/Avatar Setup",
        "limitations": ["This rebuild still retains fragmented scan helmet, torso, shoulders, shins, and feet.",
                        "The clean pieces use procedural finishes; source PBR detail is not yet transferred to them.",
                        "Only a modest joint-bend pose was rendered; full Roblox animation is unverified."],
    }, indent=2) + "\n", encoding="utf-8")
    print("PASS: Sentry articulation-repair trial local structure")


if __name__ == "__main__":
    main()
