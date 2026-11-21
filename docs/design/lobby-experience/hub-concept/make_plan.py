"""Bird's-eye plan of the proposed hub (hub_design.py) as an SVG, to scale.

    python docs/design/lobby-experience/hub-concept/make_plan.py

Writes plan.svg beside this file. North (the PLAY gate) is up; the player arrives facing up.
"""

import math
import os

import hub_design as hub

HERE = os.path.dirname(os.path.abspath(__file__))
SCALE = 2.5  # pixels per stud
MARGIN = 14  # studs around the hall
HALF_VIEW = math.degrees(math.atan(math.tan(math.radians(35)) * 16 / 9))  # 70 vertical at 16:9


def hexa(colour, lift=0.0):
    return "#%02x%02x%02x" % tuple(int(255 * min(1, c + lift)) for c in colour)


def main(hub=hub, path=os.path.join(HERE, "plan.svg")):
    hx, north, south = hub.HALL["x"], hub.HALL["north"], hub.HALL["south"]
    x0, z0 = -hx - MARGIN, north - MARGIN
    width, height = (hx * 2 + MARGIN * 2) * SCALE, (south - north + MARGIN * 2) * SCALE

    def px(x, z):
        return (x - x0) * SCALE, (z - z0) * SCALE

    out = [
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" font-family="Montserrat, Arial, sans-serif" role="img" '
        'aria-label="Top-down plan of the proposed lobby hub">' % (width, height),
        '<rect width="100%%" height="100%%" fill="#0b0d12"/>',
    ]
    # what the player sees on arrival, and how far a few seconds of walking reaches
    sx, sz = px(*hub.SPAWN)
    reach = 320 * SCALE
    left, right = math.radians(-90 - HALF_VIEW), math.radians(-90 + HALF_VIEW)
    cone = "M%.1f %.1f L%.1f %.1f A%d %d 0 0 1 %.1f %.1f Z" % (
        sx, sz, sx + reach * math.cos(left), sz + reach * math.sin(left), reach, reach,
        sx + reach * math.cos(right), sz + reach * math.sin(right),
    )
    shapes, top = [], []
    for part in hub.parts:
        if not part["plan"] or part["kind"] == "text" or part["name"].startswith("Player"):
            continue
        cx, cz = px(part["pos"][0], part["pos"][2])
        w, d = part["size"][0] * SCALE, part["size"][2] * SCALE
        glow = part["glow"] > 0
        fill = hexa(part["colour"], 0.0 if glow else 0.06)
        name = part["name"]
        if name == "Floor":
            shapes.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="#1c1f27"/>' % (cx - w / 2, cz - d / 2, w, d))
            shapes.append('<clipPath id="hall"><rect x="%.1f" y="%.1f" width="%.1f" height="%.1f"/></clipPath>' % (cx - w / 2, cz - d / 2, w, d))
            shapes.append('<path d="%s" fill="#ffc846" fill-opacity="0.07" stroke="#ffc846" stroke-opacity="0.5" stroke-dasharray="6 6" clip-path="url(#hall)"/>' % cone)
            for seconds in (4, 8, 12):
                r = seconds * hub.WALK_SPEED * SCALE
                shapes.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="#8a93a8" stroke-opacity="0.35" stroke-dasharray="2 7" clip-path="url(#hall)"/>' % (sx, sz, r))
                top.append('<text x="%.1f" y="%.1f" font-size="11" fill="#8a93a8" text-anchor="middle">%d s walk</text>' % (sx, sz + r - 5, seconds))
            continue
        if part["kind"] in ("cyl", "sphere"):
            shapes.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="#00000066"/>' % (cx, cz, w / 2, fill))
        elif part["kind"] == "ring":
            if part.get("flat"):
                shapes.append('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="%s" stroke-width="3"/>' % (cx, cz, w / 2, fill))
            else:
                thick = max(4.0, part["tube"] * 2 * SCALE)
                shapes.append('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="3" fill="%s"/>' % (cx - w / 2, cz - thick / 2, w, thick, fill))
        else:
            shapes.append(
                '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" fill-opacity="%s" stroke="#00000066" transform="rotate(%.1f %.1f %.1f)"/>'
                % (cx - w / 2, cz - d / 2, w, d, fill, "0.85" if name.startswith("Pad") else "1", -part["rot"], cx, cz)
            )
    out += shapes
    for x, z in hub.SPAWNS:
        cx, cz = px(x, z)
        out.append('<circle cx="%.1f" cy="%.1f" r="5" fill="#ffc846" stroke="#0b0d12" stroke-width="2"/>' % (cx, cz))
    out.append('<path d="M%.1f %.1f l-7 14 h14 z" fill="#ffffff"/>' % (sx, sz - 34))
    for text, x, z, kind in hub.labels:
        cx, cz = px(x, z)
        lines = text.split("\n")
        size = 12 if kind == "pad" else 15
        fill = "#0b0d12" if kind == "pad" and "TRAINING" not in text else "#f4f5fa"
        if kind == "pad" and len(text) > 12:
            size = 10
        for index, line in enumerate(lines):
            out.append(
                '<text x="%.1f" y="%.1f" font-size="%d" font-weight="700" fill="%s" text-anchor="middle" paint-order="stroke" stroke="%s" stroke-width="%s">%s</text>'
                % (cx, cz + 5 + index * (size + 3) - (len(lines) - 1) * (size + 3) / 2, size, fill, "#0b0d12", "0" if fill == "#0b0d12" else "4", line)
            )
    out += top
    # scale bar and compass
    bx, by = 20, height - 24
    out.append('<rect x="%d" y="%d" width="%d" height="4" fill="#f4f5fa"/>' % (bx, by, 100 * SCALE))
    out.append('<text x="%d" y="%d" font-size="12" fill="#f4f5fa">100 studs (about 6 s on foot)</text>' % (bx, by - 8))
    out.append('<text x="%d" y="26" font-size="12" fill="#ffc846" text-anchor="end">shaded: what a player sees on arrival without turning</text>' % (width - 20))
    out.append("</svg>")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(out))
    print("wrote", path)
    # distances a designer will ask about
    for text, x, z, kind in hub.labels:
        distance = math.hypot(x - hub.SPAWN[0], z - hub.SPAWN[1])
        angle = abs(math.degrees(math.atan2(x - hub.SPAWN[0], -(z - hub.SPAWN[1]))))
        print("%-34s %5.0f studs  %4.1f s  %5.1f deg off centre  %s" % (
            text.replace("\n", " "), distance, distance / hub.WALK_SPEED, angle,
            "in first view" if angle <= HALF_VIEW else "needs a turn"))


if __name__ == "__main__":
    main()
