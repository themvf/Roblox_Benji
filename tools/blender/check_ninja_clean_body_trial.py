"""Write measurable local checks for the saved clean-body proportion study."""
from pathlib import Path
import hashlib
import json

import bpy
import bmesh

ROOT = Path(__file__).resolve().parents[2]
TRIAL = ROOT / "assets/models/ninja-soldier-skins/trials/SciFiSentryCleanBody"
BLEND = TRIAL / "SciFiSentryCleanBody.blend"
bpy.ops.wm.open_mainfile(filepath=str(BLEND))
names = ["Head", "UpperTorso", "LowerTorso"]
for side in ("Left", "Right"):
    names += [side + part for part in ("UpperArm", "LowerArm", "Hand",
                                      "UpperLeg", "LowerLeg", "Foot")]
assert len(names) == 15
regions = {}
for name in names:
    obj = bpy.data.objects[name]
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    open_edges = sum(not edge.is_manifold for edge in bm.edges)
    triangles = sum(len(face.verts) - 2 for face in bm.faces)
    bm.free()
    assert open_edges == 0, (name, open_edges)
    regions[name] = {"baseTriangles": triangles, "nonManifoldEdges": open_edges}
previews = {}
for name in ("front", "side", "rear", "joint-bend"):
    path = TRIAL / (name + ".png")
    assert path.read_bytes().startswith(b"\x89PNG\r\n\x1a\n")
    previews[name] = hashlib.sha256(path.read_bytes()).hexdigest()
report = {
    "localGeometryCheck": "pass for 15 body guide base meshes only",
    "bodyBaseTriangleTotal": sum(r["baseTriangles"] for r in regions.values()),
    "regions": regions,
    "savedBlendSha256": hashlib.sha256(BLEND.read_bytes()).hexdigest(),
    "previewSha256": previews,
    "visualCheck": "failed: still too simplified relative to supplied detailed source",
    "animationCheck": "one manually posed review only; no skinned R15 animation",
    "marketplaceCheck": "not attempted; dynamic head, rigging, cages, UV textures and accessories missing",
}
(TRIAL / "validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
print(json.dumps({"regions": len(regions), "bodyBaseTriangleTotal": report["bodyBaseTriangleTotal"],
                  "visualCheck": report["visualCheck"]}))
