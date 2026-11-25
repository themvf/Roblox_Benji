"""What every block in a generated map becomes: a numbered plan and a table.

    python tools/map_blocks.py <Name>

Reads docs/design/<name>/blocks.json (written by `lune run tools/map_generate.luau <Name>`)
and measure.json for the walls, and writes:

    docs/design/<name>/blocks.png   the plan, each block numbered and coloured by status
    docs/design/<name>/blocks.md    the same as a table, plus the list of models still to make
                                    with the size each must fill

A block is anything a player can touch that is not floor, wall, stair or rail. Statuses:
  in game              a model is uploaded and drawn over the block
  built, not uploaded  the model exists locally; the game still shows the block
  to make              the design says what it is, the model does not exist yet
  finish only          architecture: it stays a block and gets a material, not a model
  undecided            nobody has said what it is. The design is not finished.
"""

import json
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCALE = 7
MARGIN = 60
COLOURS = {
    "in game": (70, 160, 90),
    "built, not uploaded": (60, 130, 200),
    "to make": (230, 150, 40),
    "finish only": (120, 124, 134),
    "undecided": (210, 40, 60),
}
ORDER = ["undecided", "to make", "built, not uploaded", "in game", "finish only"]


def font(size):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def dims(values):
    return " x ".join(f"{v:g}" for v in (round(v, 1) for v in values))


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: python tools/map_blocks.py <Name>")
    name = sys.argv[1]
    folder = os.path.join(ROOT, "docs", "design", name.lower())
    with open(os.path.join(folder, "blocks.json"), encoding="utf-8") as handle:
        data = json.load(handle)
    blocks = data["blocks"]
    blocks.sort(key=lambda b: (ORDER.index(b["status"]), b.get("asset") or "", b["name"]))
    for number, block in enumerate(blocks, 1):
        block["number"] = number

    # ----- plan
    measure_path = os.path.join(folder, "measure.json")
    walls, bounds = [], None
    if os.path.isfile(measure_path):
        with open(measure_path, encoding="utf-8") as handle:
            measure = json.load(handle)
        bounds = (measure["bounds"]["min"], measure["bounds"]["max"])
        for part in measure["parts"]:
            sx, sy, sz = part["size"]
            x, y, z = part["pos"]
            upright = abs(part["rot"][4]) > 0.999
            if part["collide"] and upright and sy >= 20 and y - sy / 2 < 1 and min(sx, sz) <= 2.5:
                walls.append((x - sx / 2, z - sz / 2, x + sx / 2, z + sz / 2, part["transparency"] > 0.3))
    if not bounds:
        xs = [v for b in blocks for f in b["footprints"] for v in (f[0], f[2])]
        zs = [v for b in blocks for f in b["footprints"] for v in (f[1], f[3])]
        bounds = ((min(xs) - 10, 0, min(zs) - 10), (max(xs) + 10, 0, max(zs) + 10))
    (x0, _, z0), (x1, _, z1) = bounds
    width, height = int((x1 - x0) * SCALE) + MARGIN * 2, int((z1 - z0) * SCALE) + MARGIN * 2 + 60

    def px(x, z):
        return (MARGIN + (x - x0) * SCALE, MARGIN + (z - z0) * SCALE)

    image = Image.new("RGB", (width, height), "white")
    draw = ImageDraw.Draw(image, "RGBA")
    draw.rectangle([px(x0, z0), px(x1, z1)], fill=(244, 242, 238, 255))
    for ax, az, bx, bz, glass in walls:
        draw.rectangle([px(ax, az), px(bx, bz)], fill=(150, 190, 220, 255) if glass else (60, 62, 70, 255))
    label = font(17)
    for block in blocks:
        colour = COLOURS[block["status"]]
        for ax, az, bx, bz, _ in block["footprints"]:
            draw.rectangle([px(ax, az), px(bx, bz)], fill=(*colour, 255), outline=(30, 30, 30, 255))
            cx, cz = px((ax + bx) / 2, (az + bz) / 2)
            text = str(block["number"])
            w = draw.textlength(text, font=label)
            draw.rectangle([cx - w / 2 - 3, cz - 11, cx + w / 2 + 3, cz + 11], fill=(255, 255, 255, 235))
            draw.text((cx - w / 2, cz - 10), text, fill="black", font=label)
    draw.text((MARGIN, 14), f"{name}: what each block becomes   (numbers match blocks.md)", fill="black", font=font(26))
    column, top = MARGIN, MARGIN + int((z1 - z0) * SCALE) + 16
    counts = {status: sum(1 for b in blocks if b["status"] == status) for status in ORDER}
    for status in ORDER:
        if not counts[status]:
            continue
        draw.rectangle([column, top, column + 22, top + 22], fill=(*COLOURS[status], 255), outline=(30, 30, 30, 255))
        text = f"{status} ({counts[status]})"
        draw.text((column + 30, top), text, fill="black", font=font(20))
        column += 60 + int(draw.textlength(text, font=font(20)))
    out_png = os.path.join(folder, "blocks.png")
    image.save(out_png)

    # ----- table
    lines = [
        f"# {name}: what each block becomes",
        "",
        "Generated by `python tools/map_blocks.py " + name + "` from the design file. Do not edit; change",
        f"`assets/environment/source/{name}.design.luau` and regenerate. Plan: [blocks.png](blocks.png).",
        "",
        "A block is anything a player can touch that is not floor, wall, stair or rail. The block is",
        "the collision; a model drawn over it has none. Sizes are studs, long side x short side x height.",
        "",
        "| # | Block | Becomes | Status | Block size | Copies | Model pieces per block |",
        "| --- | --- | --- | --- | --- | --- | --- |",
    ]
    for block in blocks:
        sx, sy, sz = block["size"]
        size = dims((max(sx, sz), min(sx, sz), sy))
        pieces = f"{block['pieces']} x ({dims(block['piece'])})" if block.get("asset") else "none"
        lines.append(
            f"| {block['number']} | {block['name']} | {block.get('becomes') or '**not decided**'} | {block['status']} | "
            f"{size} | {len(block['footprints'])} | {pieces} |"
        )
    to_make = {}
    for block in blocks:
        if block["status"] in ("to make", "built, not uploaded") and block.get("asset"):
            to_make.setdefault(block["asset"], []).append(block)
    if to_make:
        lines += [
            "",
            "## Models still needed",
            "",
            "One model can serve several blocks. Each piece is scaled evenly to its block's piece length,",
            "so make the model to the proportions in the second column; the range shows how far the",
            "blocks that share it differ.",
            "",
            "| Model | Make it this shape (long x deep x tall) | Piece lengths used | Placements | Status | Brief |",
            "| --- | --- | --- | --- | --- | --- |",
        ]
        for key in sorted(to_make):
            used = to_make[key]
            lengths = sorted({round(b["piece"][0], 1) for b in used})
            longest = max(used, key=lambda b: b["pieces"] * len(b["footprints"]))
            placements = sum(b["pieces"] * len(b["footprints"]) for b in used)
            info = data["assets"].get(key, {})
            lines.append(
                f"| `{key}`: {info.get('is', '')} | {dims(longest['piece'])} | {', '.join(f'{v:g}' for v in lengths)} | "
                f"{placements} | {info.get('status', '')} | {info.get('want', '')} |"
            )
    undecided = [b["name"] for b in blocks if b["status"] == "undecided"]
    lines += ["", f"Undecided blocks: {', '.join(undecided) if undecided else 'none'}.", ""]
    out_md = os.path.join(folder, "blocks.md")
    with open(out_md, "w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(lines))
    print(f"blocks: {os.path.relpath(out_png, ROOT)}, {os.path.relpath(out_md, ROOT)}")
    print("  " + ", ".join(f"{counts[s]} {s}" for s in ORDER if counts[s]))


main()
