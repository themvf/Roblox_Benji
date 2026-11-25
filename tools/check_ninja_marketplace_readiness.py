"""Audit current ninja skin files against measured Marketplace body prerequisites.

This is a local preflight, not Roblox Avatar Setup or Marketplace validation.
"""
from __future__ import annotations

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parents[1]
PKG = ROOT / "assets/models/ninja-soldier-skins"
BODY_TRIANGLE_BUDGET = 10_742
SOURCES = {
    "SciFiSentry": "source/SciFiSentrySource.glb",
    "TacticalOperator": "source/TacticalOperatorSource.glb",
}


def inspect(relative: str) -> dict:
    path = PKG / relative
    raw = path.read_bytes()
    assert raw[:4] == b"glTF" and struct.unpack_from("<I", raw, 8)[0] == len(raw)
    length, chunk_type = struct.unpack_from("<II", raw, 12)
    assert chunk_type == 0x4E4F534A
    doc = json.loads(raw[20:20 + length])
    triangles = sum(doc["accessors"][p["indices"]]["count"] // 3
                    for mesh in doc.get("meshes", []) for p in mesh.get("primitives", []))
    return {"path": relative, "sha256": hashlib.sha256(raw).hexdigest(),
            "meshCount": len(doc.get("meshes", [])), "triangles": triangles,
            "overMarketplaceBodyTriangleBudget": triangles > BODY_TRIANGLE_BUDGET,
            "gltfSkinCount": len(doc.get("skins", [])),
            "embeddedImageCount": len(doc.get("images", []))}


report = {
    "checkedAt": datetime.now(timezone.utc).isoformat(),
    "purpose": "Full character bundles for Marketplace and matching selectable game skins",
    "result": "No current GLB is Marketplace-ready",
    "publishedSpec": {
        "bodyTriangleBudget": BODY_TRIANGLE_BUDGET,
        "head": 4000, "torso": 1750, "eachArm": 1248, "eachLeg": 1248,
        "rigidOrLayeredAccessoryPerMesh": 4000,
        "source": "https://create.roblox.com/docs/avatar/character-bodies/specifications",
        "accessorySource": "https://create.roblox.com/docs/avatar/rigid-accessories/specifications",
    },
    "characters": {},
    "notLocallyVerifiable": [
        "Avatar Setup Platform Avatar processing and generated dynamic head/cages",
        "Studio animation and accessory fitting",
        "Marketplace creator eligibility, rights, fees and moderation",
        "bundle composition and catalog publication",
    ],
}
for name, source in SOURCES.items():
    files = [source, f"exports/{name}Armor.glb",
             f"trials/{name}DetailedSegmented.glb"]
    report["characters"][name] = {"files": [inspect(item) for item in files],
                                  "remaining": [
                                      "Clean contiguous A-pose or T-pose humanoid body within body and region budgets",
                                      "Marketplace dynamic head with usable eye and mouth geometry",
                                      "R15 rig, skinning, body cages and accessory attachments",
                                      "Separate helmet and other armor accessories with own geometry limits",
                                      "Texture/detail transfer from approved source and posed visual review",
                                  ]}
path = PKG / "marketplace_readiness.json"
path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({name: row["files"] for name, row in report["characters"].items()}, indent=2))
