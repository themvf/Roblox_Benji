"""Report connected components of generated character GLBs for cleanup decisions."""
import json
import sys

import bpy

source = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=source)
for obj in [o for o in bpy.context.scene.objects if o.type == "MESH"]:
    mesh = obj.data
    parent = list(range(len(mesh.vertices)))
    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    for edge in mesh.edges:
        a, b = edge.vertices
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra
    components = {}
    for poly in mesh.polygons:
        root = find(poly.vertices[0])
        entry = components.setdefault(root, {"triangles": 0, "vertices": set()})
        entry["triangles"] += len(poly.vertices) - 2
        entry["vertices"].update(poly.vertices)
    out = []
    for entry in components.values():
        co = [mesh.vertices[i].co for i in entry["vertices"]]
        out.append({"triangles": entry["triangles"], "vertices": len(co),
                    "min": [min(v[i] for v in co) for i in range(3)],
                    "max": [max(v[i] for v in co) for i in range(3)]})
    out.sort(key=lambda x: x["triangles"], reverse=True)
    print("COMPONENTS_JSON=" + json.dumps({"source": source, "count": len(out), "top": out[:20]}))
