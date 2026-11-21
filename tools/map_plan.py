"""Top-down plan of a measured map: floors, walls, cover, lanes, chokes and the longest lines of fire.

    python tools/map_plan.py <Name>

Reads docs/design/<name>/measure.json (written by `lune run tools/measure_map.luau <Name>`)
and writes docs/design/<name>/plan.png. North (-z) is up, Blue (-x) is on the left.

Legend: pale = floor a player can reach, orange tint = an upper floor, dark = full-height
solid, mid grey = full cover (6 studs or taller), tan = low cover, blue outline = glass.
Coloured lines are the lanes, dashed boxes the named chokes, red lines the longest lines of
fire (thick when over the target).
"""

import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCALE = 6  # pixels per stud
MARGIN = 70
LANE_COLOURS = ["#1f77b4", "#2ca02c", "#9467bd", "#8c564b"]


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: python tools/map_plan.py <Name>")
    name = sys.argv[1]
    folder = os.path.join(ROOT, "docs", "design", name.lower())
    with open(os.path.join(folder, "measure.json"), encoding="utf-8") as handle:
        data = json.load(handle)

    (x0, _, z0), (x1, _, z1) = data["bounds"]["min"], data["bounds"]["max"]
    width, height = int((x1 - x0) * SCALE) + MARGIN * 2, int((z1 - z0) * SCALE) + MARGIN * 2 + 120

    def px(x, z):
        return (MARGIN + (x - x0) * SCALE, MARGIN + (z - z0) * SCALE)

    image = Image.new("RGB", (width, height), "white")
    draw = ImageDraw.Draw(image, "RGBA")

    # floors a player can reach; the lowest level is the base, anything higher is tinted
    levels = sorted({round(f[2]) for f in data["floors"]})
    base = min(levels, key=lambda y: -sum(1 for f in data["floors"] if round(f[2]) == y))
    half = data["cell"] / 2
    for x, z, y in data["floors"]:
        if y <= base + 1.5:
            draw.rectangle([px(x - half, z - half), px(x + half, z + half)], fill=(236, 233, 226, 255))
    # solids, lowest first so tall ones draw on top
    solids = [p for p in data["parts"] if p["collide"]]
    solids.sort(key=lambda p: p["pos"][1] + p["size"][1] / 2)
    for part in solids:
        cx, cy, cz = part["pos"]
        sx, sy, sz = part["size"]
        r = part["rot"]
        top, bottom = cy + sy / 2, cy - sy / 2
        if top <= base + 0.5:
            continue  # the floor slab itself
        corners = []
        for dx, dz in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            lx, lz = dx * sx / 2, dz * sz / 2
            corners.append(px(cx + r[0] * lx + r[2] * lz, cz + r[6] * lx + r[8] * lz))
        glass = part["transparency"] > 0.3
        tilted = abs(r[4]) < 0.999
        if glass:
            draw.polygon(corners, fill=(120, 180, 220, 70), outline=(40, 110, 180, 255))
        elif tilted:
            draw.polygon(corners, fill=(214, 150, 80, 200), outline=(120, 70, 20, 255))
        elif bottom > base + 20:
            continue  # the roof: it would tint everything under it
        elif bottom > base + 6:
            draw.polygon(corners, fill=(240, 170, 60, 70), outline=(190, 120, 30, 160))  # overhead: mezzanine, lintel, roof
        elif top - base >= 20:
            draw.polygon(corners, fill=(40, 42, 50, 255))
        elif top - base >= 6:
            draw.polygon(corners, fill=(110, 114, 126, 255), outline=(40, 42, 50, 255))
        else:
            draw.polygon(corners, fill=(196, 164, 120, 255), outline=(110, 84, 50, 255))
    # upper floors a player can reach
    for x, z, y in data["floors"]:
        if y > base + 1.5:
            draw.rectangle([px(x - half, z - half), px(x + half, z + half)], fill=(240, 150, 40, 90))

    small, medium, large = font(15), font(20), font(28)
    for choke in data.get("chokes", []):
        (ax, az), (bx, bz) = choke["region"]
        draw.rectangle([px(ax, az), px(bx, bz)], outline=(200, 0, 120, 255), width=2)
    for index, lane in enumerate(data.get("lanes", [])):
        colour = LANE_COLOURS[index % len(LANE_COLOURS)]
        points = [px(x, z) for x, z in lane["path"]]
        if len(points) > 1:
            draw.line(points, fill=colour, width=4)
        if lane.get("narrowestAt"):
            nx, _, nz = lane["narrowestAt"]
            cx, cz = px(nx, nz)
            draw.ellipse([cx - 7, cz - 7, cx + 7, cz + 7], outline=colour, width=3)
    limit = data.get("targets", {}).get("maxSightline", 120)
    for line in data.get("sightlines", []):
        a, b = line["from"], line["to"]
        over = line["length"] > limit
        draw.line([px(a[0], a[2]), px(b[0], b[2])], fill=(220, 30, 30, 230 if over else 120), width=3 if over else 1)
    for objective in data["objectives"]:
        x, _, z = objective["pos"]
        radius = objective["radius"]
        draw.ellipse([px(x - radius, z - radius), px(x + radius, z + radius)], outline=(230, 150, 0, 255), width=4)
        cx, cz = px(x, z)
        draw.text((cx - 8, cz - 16), objective["id"], fill=(160, 90, 0, 255), font=large)
    for team, colour in (("Blue", (40, 100, 220, 255)), ("Red", (210, 50, 50, 255))):
        for x, _, z in data["spawns"][team]:
            draw.rectangle([px(x - 3, z - 3), px(x + 3, z + 3)], fill=colour)
    for vantage in data.get("vantages", []):
        x, _, z = vantage["at"]
        cx, cz = px(x, z)
        draw.polygon([(cx, cz - 10), (cx + 9, cz + 8), (cx - 9, cz + 8)], fill=(150, 60, 200, 255))

    # legend and the headline numbers
    top = MARGIN + int((z1 - z0) * SCALE) + 16
    draw.text((MARGIN, 18), f"{name}   {data.get('revision', '')}   north is up, Blue left, Red right", fill="black", font=large)
    column = MARGIN
    for index, lane in enumerate(data.get("lanes", [])):
        colour = LANE_COLOURS[index % len(LANE_COLOURS)]
        draw.line([(column, top + 12), (column + 40, top + 12)], fill=colour, width=5)
        text = f"{lane['name']}: {lane['seconds']:.1f} s, narrowest {lane['narrowest']:.0f}"
        draw.text((column + 48, top), text, fill="black", font=medium)
        column += 60 + int(draw.textlength(text, font=medium))
    notes = [
        "orange ring = objective, purple triangle = vantage, magenta box = named choke, circle on a lane = its narrowest point",
        f"red = longest lines of fire (thick = over the {limit:g}-stud target); "
        + ("longest %.0f studs" % data["sightlines"][0]["length"] if data.get("sightlines") else "none over 60 studs"),
        "FAILED: " + "; ".join(data["failures"]) if data.get("failures") else "All measured targets met.",
    ]
    for index, note in enumerate(notes):
        draw.text((MARGIN, top + 34 + index * 24), note[:230], fill=(170, 0, 0) if note.startswith("FAILED") else "black", font=small)

    out = os.path.join(folder, "plan.png")
    image.save(out)
    print(f"plan: {os.path.relpath(out, ROOT)}")


main()
