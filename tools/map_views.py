"""Player's-eye renders of a measured map, as one sheet.

    python tools/map_views.py <Name>

Reads docs/design/<name>/measure.json, renders each of the design's `views` in Blender
(tools/blender/render_map_views.py) into docs/design/<name>/views/, and lays them out as
docs/design/<name>/views.png. Blockout preview only: Blender's lighting, flat colours.
"""

import json
import os
import shutil
import subprocess
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from asset_generate import ROOT, find_blender, printable, sheet_font  # noqa: E402


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: python tools/map_views.py <Name>")
    name = sys.argv[1]
    folder = os.path.join(ROOT, "docs", "design", name.lower())
    measure = os.path.join(folder, "measure.json")
    if not os.path.isfile(measure):
        sys.exit(f"no {os.path.relpath(measure, ROOT)}; run: lune run tools/measure_map.luau {name}")
    blender = find_blender()
    if not blender:
        sys.exit("Blender not found; set the BLENDER environment variable")
    views_dir = os.path.join(folder, "views")
    if os.path.isdir(views_dir):
        shutil.rmtree(views_dir)
    script = os.path.join(ROOT, "tools", "blender", "render_map_views.py")
    done = subprocess.run(
        [blender, "-b", "-noaudio", "--python", script, "--", "--measure", measure, "--out-dir", views_dir],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    listing = os.path.join(views_dir, "views.json")
    if done.returncode != 0 or not os.path.isfile(listing):
        sys.exit("render failed:\n" + printable((done.stdout or "")[-1200:] + (done.stderr or "")[-600:]))
    with open(listing, encoding="utf-8") as handle:
        names = json.load(handle)["views"]
    if not names:
        sys.exit("the design lists no views to render")

    images = [Image.open(os.path.join(views_dir, n + ".png")).convert("RGB") for n in names]
    width, height = images[0].size
    per_row, label_h, gap = 2, 30, 8
    rows = (len(images) + per_row - 1) // per_row
    sheet = Image.new("RGB", (per_row * (width + gap) - gap, rows * (height + label_h + gap)), "white")
    draw = ImageDraw.Draw(sheet)
    for index, (label, image) in enumerate(zip(names, images)):
        left, top = (index % per_row) * (width + gap), (index // per_row) * (height + label_h + gap)
        draw.text((left + 6, top + 4), f"{name}: {label}   (blockout preview, not Roblox lighting)", fill="black", font=sheet_font(20))
        sheet.paste(image, (left, top + label_h))
    out = os.path.join(folder, "views.png")
    sheet.save(out)
    print(f"views: {os.path.relpath(out, ROOT)}")


main()
