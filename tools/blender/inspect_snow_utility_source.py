"""Inspect the imported TRELLIS vehicle's loose components and material maps."""
import json
from pathlib import Path
import bpy
from mathutils import Vector

root = Path(__file__).resolve().parents[2]
source = root / "assets/models/snow-utility-vehicle/source/trellis-original.glb"
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(source))
objects = [ob for ob in bpy.context.scene.objects if ob.type == "MESH"]
report = []
for ob in objects:
    mesh = ob.data
    parent = list(range(len(mesh.vertices)))
    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    for edge in mesh.edges:
        a, b = edge.vertices
        ra, rb = find(a), find(b)
        parent[rb] = ra
    groups = {}
    for poly in mesh.polygons:
        key = find(poly.vertices[0])
        item = groups.setdefault(key, {"faces":0,"triangles":0,"points":[]})
        item["faces"] += 1
        item["triangles"] += max(1, len(poly.vertices)-2)
        item["points"].extend(poly.vertices)
    parts = []
    for item in groups.values():
        points = [ob.matrix_world @ mesh.vertices[i].co for i in set(item["points"])]
        low = [min(p[a] for p in points) for a in range(3)]
        high = [max(p[a] for p in points) for a in range(3)]
        parts.append({"triangles":item["triangles"],"bounds":[low,high]})
    parts.sort(key=lambda x:-x["triangles"])
    report.append({"object":ob.name,"vertices":len(mesh.vertices),"faces":len(mesh.polygons),
                   "components":len(parts),"topComponents":parts[:35],
                   "thresholds":{str(n):{"components":sum(p["triangles"]>=n for p in parts),
                                          "trianglesKept":sum(p["triangles"] for p in parts if p["triangles"]>=n)}
                                 for n in (2,4,8,16,32,64,128)}})
out = root / "assets/models/snow-utility-vehicle/review/source-components.json"
out.write_text(json.dumps(report,indent=2),encoding="utf-8")
print("wrote",out)
