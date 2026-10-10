"""Draw the HUD icon set: white glyphs on transparent 256x256 PNGs.

    python tools/ui/draw_icons.py

Writes assets/ui/icons/<Name>.png. Each icon is drawn at 4x and downsampled, so edges
are antialiased. They are white so the HUD can tint them with ImageColor3 -- one
upload per glyph, any colour in game. Bold, filled shapes with no interior detail
under ~12% of the canvas: they are read at 24-40 px on a phone.

Upload them once (Studio: View > Asset Manager > Bulk Import), then put each id in
src/client/UI/Icons.lua. Until an id is there the HUD shows a short text fallback.
"""

import math
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "ui", "icons")
S = 1024  # drawing size; downsampled to 256
W = (255, 255, 255, 255)
CLEAR = (0, 0, 0, 0)


def canvas():
    img = Image.new("RGBA", (S, S), CLEAR)
    return img, ImageDraw.Draw(img)


def p(x, y):
    """Design units are 0..100 across the canvas."""
    return (x * S / 100, y * S / 100)


def u(n):
    return n * S / 100


def line(d, pts, width):
    d.line([p(*q) for q in pts], fill=W, width=int(u(width)), joint="curve")
    r = u(width) / 2
    for q in (pts[0], pts[-1]):
        cx, cy = p(*q)
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=W)


def poly(d, pts, fill=W):
    d.polygon([p(*q) for q in pts], fill=fill)


def rrect(d, x0, y0, x1, y1, r, fill=W):
    d.rounded_rectangle((*p(x0, y0), *p(x1, y1)), radius=u(r), fill=fill)


def circle(d, cx, cy, r, fill=None, outline=None, width=0):
    box = (*p(cx - r, cy - r), *p(cx + r, cy + r))
    d.ellipse(box, fill=fill, outline=outline, width=int(u(width)))


def health(d):
    rrect(d, 38, 12, 62, 88, 6)
    rrect(d, 12, 38, 88, 62, 6)


def ammo(d):
    # one bullet: ogive tip, body, rim
    d.pieslice((*p(34, 8), *p(66, 40)), 180, 360, fill=W)
    rrect(d, 34, 24, 66, 78, 2)
    rrect(d, 30, 80, 70, 92, 3)


def mutate(d):
    # Titan: a clenched fist, knuckles up. (A star burst read as nothing in playtest.)
    for x in (20, 35, 50, 65):
        rrect(d, x, 14, x + 15, 50, 7)
    rrect(d, 20, 34, 80, 80, 12)
    for x in (35, 50, 65):  # gaps between the fingers
        rrect(d, x - 1.2, 14, x + 1.2, 44, 1, fill=CLEAR)
    rrect(d, 10, 46, 58, 66, 10, fill=CLEAR)  # thumb, separated from the fingers
    rrect(d, 13, 49, 55, 63, 7)
    rrect(d, 30, 82, 70, 94, 4)  # wrist


def slam(d):
    # down arrow onto the ground, with impact marks
    rrect(d, 42, 8, 58, 48, 3)
    poly(d, [(26, 44), (74, 44), (50, 70)])
    rrect(d, 10, 80, 90, 90, 4)
    line(d, [(18, 70), (10, 62)], 6)
    line(d, [(82, 70), (90, 62)], 6)


def brace(d):
    shape = [(50, 8), (86, 20), (82, 56), (50, 92), (18, 56), (14, 20)]
    poly(d, shape)
    # inner shield at 62% about its centre: an even outline
    poly(d, [(50 + (x - 50) * 0.62, 50 + (y - 50) * 0.62) for x, y in shape], fill=CLEAR)


def charge(d):
    for x in (14, 46):
        poly(d, [(x, 16), (x + 16, 16), (x + 40, 50), (x + 16, 84), (x, 84), (x + 24, 50)])


def fuel(d):
    # jetpack / fly: a rocket with its flame. (A fuel drop read as nothing in playtest.)
    d.pieslice((*p(36, 4), *p(64, 44)), 180, 360, fill=W)  # nose
    rrect(d, 36, 22, 64, 70, 6)  # body
    circle(d, 50, 38, 6, fill=CLEAR)  # window
    poly(d, [(36, 48), (20, 74), (36, 68)])  # fins
    poly(d, [(64, 48), (80, 74), (64, 68)])
    poly(d, [(41, 74), (59, 74), (50, 97)])  # flame


def scope(d):
    circle(d, 50, 50, 34, outline=W, width=9)
    for a, b in (((50, 6), (50, 34)), ((50, 66), (50, 94)), ((6, 50), (34, 50)), ((66, 50), (94, 50))):
        line(d, [a, b], 8)
    circle(d, 50, 50, 5, fill=W)


def crouch(d):
    # chevron pressing down onto a floor line
    line(d, [(22, 26), (50, 52), (78, 26)], 13)
    rrect(d, 14, 74, 86, 86, 5)


def slide(d):
    # forward arrow skimming the floor, with speed lines
    rrect(d, 34, 52, 74, 64, 4)
    poly(d, [(70, 38), (94, 58), (70, 78)])
    rrect(d, 6, 80, 90, 90, 4)
    line(d, [(8, 30), (34, 30)], 7)
    line(d, [(16, 44), (40, 44)], 7)


def scores(d):
    for y in (22, 50, 78):
        circle(d, 18, y, 8, fill=W)
        rrect(d, 32, y - 6, 88, y + 6, 6)


def speed(d):
    poly(d, [(60, 4), (20, 56), (46, 56), (36, 96), (82, 40), (54, 40), (66, 4)])


def info(d):
    circle(d, 50, 50, 44, fill=W)
    circle(d, 50, 28, 8, fill=CLEAR)
    rrect(d, 42, 42, 58, 80, 4, fill=CLEAR)


def zone(d):
    rrect(d, 18, 8, 28, 94, 4)
    poly(d, [(28, 10), (86, 26), (28, 50)])


def skip(d):
    poly(d, [(10, 18), (46, 50), (10, 82)])
    poly(d, [(44, 18), (80, 50), (44, 82)])
    rrect(d, 80, 18, 92, 82, 3)


ICONS = {
    "Health": health,
    "Ammo": ammo,
    "Mutate": mutate,
    "Slam": slam,
    "Brace": brace,
    "Charge": charge,
    "Fuel": fuel,
    "Scope": scope,
    "Crouch": crouch,
    "Slide": slide,
    "Scores": scores,
    "Speed": speed,
    "Info": info,
    "Zone": zone,
    "Skip": skip,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, draw in ICONS.items():
        img, d = canvas()
        draw(d)
        img.resize((256, 256), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))
    # contact sheet for review, on a dark backdrop like the HUD panel
    sheet = Image.new("RGBA", (128 * 5, 128 * 3), (20, 22, 28, 255))
    for i, name in enumerate(ICONS):
        icon = Image.open(os.path.join(OUT, name + ".png")).resize((96, 96), Image.LANCZOS)
        sheet.alpha_composite(icon, (128 * (i % 5) + 16, 128 * (i // 5) + 16))
    sheet.save(os.path.join(OUT, "_sheet.png"))
    print("wrote", len(ICONS), "icons to", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
