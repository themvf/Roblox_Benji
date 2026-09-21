"""Lay six skybox faces out as an unfolded cross so seams are visible before upload.

Faces that do not line up at their shared edges are obvious here and invisible in
an asset viewer, which is the whole reason this exists: the first skybox shipped
with up and dn swapped and nobody could have seen it from the files alone.

    python tools/blender/stitch_skybox.py assets/sky/snowfortress out.png
"""

import os
import sys

from PIL import Image

# (column, row) in a 4x3 cross, and the neighbour each face sits beside.
LAYOUT = {"up": (1, 0), "lf": (0, 1), "ft": (1, 1), "rt": (2, 1), "bk": (3, 1), "dn": (1, 2)}


def main():
    prefix, out = sys.argv[1], sys.argv[2]
    faces = {}
    for name in LAYOUT:
        path = "%s_%s.png" % (prefix, name)
        if not os.path.exists(path):
            raise SystemExit("missing face: " + path)
        faces[name] = Image.open(path).convert("RGB")
    size = faces["ft"].size[0]
    sheet = Image.new("RGB", (size * 4, size * 3), (24, 24, 28))
    for name, (col, row) in LAYOUT.items():
        sheet.paste(faces[name].resize((size, size)), (col * size, row * size))
    scale = min(1.0, 1400 / sheet.size[0])
    if scale < 1.0:
        sheet = sheet.resize((int(sheet.size[0] * scale), int(sheet.size[1] * scale)), Image.LANCZOS)
    sheet.save(out)
    print("wrote %s (%d x %d)" % (out, sheet.size[0], sheet.size[1]))
    # The horizon must cross lf|ft|rt|bk at the same height, or the seams show.
    for name in ("lf", "ft", "rt", "bk"):
        im = faces[name]
        mid = im.crop((im.size[0] // 2 - 2, 0, im.size[0] // 2 + 2, im.size[1])).convert("L")
        col = [sum(mid.getpixel((x, y)) for x in range(4)) / 4 for y in range(im.size[1])]
        horizon = next((y for y in range(1, len(col)) if col[y] - col[y - 1] < -12), None)
        print("  %s horizon at row %s" % (name, horizon if horizon else "not detected"))


main()
