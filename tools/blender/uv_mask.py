"""Which texture pixels a region of a fitted piece uses: a UV-space mask, white where it is.

    blender -b <review/assembled.blend> --python tools/blender/uv_mask.py -- <object> <out.png> <size> \
        <x0> <x1> <z0> <z1> [--from front|top]

Rays are cast at the object from the front (along +Y; the character faces -Y) or from above,
over the box x0..x1, z0..z1 (or y0..y1 for `top`) in Blender studs, and every texel they hit is
painted into the mask, a few pixels wide. kit_look.py retint uses it to treat the painted eyes
under a look's glow plates apart from the rest of the texture: the knight's eye paint is the
same orange as its copper highlights, so colour alone could not find it.
"""

import sys

import bpy
from mathutils import Vector
from mathutils.geometry import barycentric_transform

args = sys.argv[sys.argv.index("--") + 1:]
name, out, size = args[0], args[1], int(args[2])
a0, a1, b0, b1 = (float(v) for v in args[3:7])
mode = args[args.index("--from") + 1] if "--from" in args else "front"

obj = bpy.data.objects[name]
mesh = obj.data
uv = mesh.uv_layers.active.data
inv = obj.matrix_world.inverted()
mesh.calc_loop_triangles()
triangles = {}
for tri in mesh.loop_triangles:
    triangles.setdefault(tri.polygon_index, []).append(tri)

mask = bytearray(size * size)
step = 0.004
direction = (inv.to_3x3() @ Vector((0, 1, 0) if mode == "front" else (0, 0, -1))).normalized()
a = a0
while a <= a1:
    b = b0
    while b <= b1:
        start = Vector((a, -5, b)) if mode == "front" else Vector((a, b, 12))
        ok, location, _, face = obj.ray_cast(inv @ start, direction)
        if ok:
            for tri in triangles[face]:
                corners = [mesh.vertices[i].co for i in tri.vertices]
                uvs = [uv[loop].uv.to_3d() for loop in tri.loops]
                point = barycentric_transform(location, *corners, *uvs)
                if point.x >= -0.01 and point.y >= -0.01:
                    x = int((point.x % 1) * size)
                    y = int((1 - point.y % 1) * size)  # image rows run top-down, UV v bottom-up
                    for dy in range(-3, 4):
                        for dx in range(-3, 4):
                            if 0 <= x + dx < size and 0 <= y + dy < size:
                                mask[(y + dy) * size + x + dx] = 255
                    break
        b += step
    a += step

import numpy as np  # noqa: E402

grid = np.frombuffer(bytes(mask), dtype=np.uint8).reshape(size, size)[::-1] / 255.0  # Blender rows run bottom-up
rgba = np.ones((size, size, 4), dtype=np.float32)
rgba[..., 0] = rgba[..., 1] = rgba[..., 2] = grid
image = bpy.data.images.new("mask", size, size)
image.pixels.foreach_set(rgba.ravel())
image.filepath_raw = out
image.file_format = "PNG"
image.save()
print("MASK", out, sum(1 for v in mask if v), "pixels")
