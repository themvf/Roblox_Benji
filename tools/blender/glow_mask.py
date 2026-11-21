"""Paint a texture-space mask of the faces that really glow on a whole-body model.

    blender -b -noaudio --python tools/blender/glow_mask.py -- <spec.json>

Run by `kit_look.py whole --unlight`. Tripo bakes the picture's lighting into the texture: the
Bouncer's magenta rim light came out painted down the sides of his arms, legs and back, the
same colour as his glasses. Colour alone cannot tell them apart, place can: the glow is where
the look says it is (boxes in the model's own frame, as measured on the `--grid` render).

spec.json: source (GLB), turn, mask (JSON of the glowing faces' UV polygons), boxes: a list of
{"x": [lo, hi], "z": [lo, hi], "front": true} in the grid's frame (stood on z=0, centred).
"""
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

spec = json.loads(Path(sys.argv[sys.argv.index("--") + 1]).read_text(encoding="utf-8"))
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=spec["source"])
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
bpy.context.view_layer.update()
turn = Matrix.Rotation(math.radians(spec.get("turn", -90)), 4, "Z")
points, tris = [], []
for o in meshes:
    world = turn @ o.matrix_world
    uv = o.data.uv_layers.active.data
    verts = [world @ v.co for v in o.data.vertices]
    points += verts
    for poly in o.data.polygons:
        tris.append(([verts[o.data.loops[i].vertex_index] for i in poly.loop_indices],
                     [tuple(uv[i].uv) for i in poly.loop_indices], (o.matrix_world.to_3x3() @ poly.normal)))
low = Vector([min(p[i] for p in points) for i in range(3)])
high = Vector([max(p[i] for p in points) for i in range(3)])
shift = Vector((-(low.x + high.x) / 2, -(low.y + high.y) / 2, -low.z))

found = []
for corners, uvs, normal in tris:
    centre = sum(corners, Vector()) / len(corners) + shift
    for box in spec["boxes"]:
        if not (box["x"][0] <= centre.x <= box["x"][1] and box["z"][0] <= centre.z <= box["z"][1]):
            continue
        if box.get("front", True) and centre.y > 0:  # the character faces -Y
            continue
        found.append(uvs)
        break
# Blender's Python has no PIL: hand the UV polygons back and let kit_look.py paint the mask.
Path(spec["mask"]).write_text(json.dumps(found))
print("MASK", spec["mask"], len(found), "faces")
