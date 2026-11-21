"""Inspect spatial distribution of an unrigged character scan."""
import json
import sys
from collections import Counter

import bpy

path = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)
for obj in bpy.context.scene.objects:
    if obj.type != "MESH":
        continue
    mesh = obj.data
    print("MESH", obj.name, "vertices", len(mesh.vertices), "faces", len(mesh.polygons))
    print("BOUND", [(min(v.co[i] for v in mesh.vertices), max(v.co[i] for v in mesh.vertices)) for i in range(3)])
    print("MATERIALS", [m.name for m in mesh.materials])
    print("UV", [(uv.name, len(uv.data)) for uv in mesh.uv_layers])
    hist = Counter()
    for poly in mesh.polygons:
        center = poly.center
        zb = round(center.z * 20) / 20
        xb = round(abs(center.x) * 20) / 20
        hist[(zb, xb)] += len(poly.vertices) - 2
    for z in sorted({key[0] for key in hist}, reverse=True):
        print("Z", z, " ".join(f"{x:.2f}:{hist[z,x]}" for x in sorted({key[1] for key in hist if key[0] == z})))
for img in bpy.data.images:
    print("IMAGE", img.name, tuple(img.size), img.filepath, img.packed_file is not None)
