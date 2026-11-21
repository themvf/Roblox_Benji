"""Assemble hub-concept.html from page.template.html, plan.svg and the renders.

    python docs/design/lobby-experience/hub-concept/build_page.py

Run make_plan.py and render_hero.py first. Renders are saved again as JPEGs for the page.
"""

import math
import os

from PIL import Image

import hub_design as hub

HERE = os.path.dirname(os.path.abspath(__file__))
HALF_VIEW = math.degrees(math.atan(math.tan(math.radians(35)) * 16 / 9))


def main():
    for name, *_ in hub.VIEWS:
        source = os.path.join(HERE, "renders", name + ".png")
        Image.open(source).convert("RGB").save(os.path.join(HERE, "renders", name + ".jpg"), quality=88)
    rows, seen = [], set()
    for text, x, z, _kind in hub.labels:
        title = text.split("\n")[0].title().replace("1V1", "1v1")
        if title in seen or title == "Arrival":
            continue
        seen.add(title)
        distance = math.hypot(x - hub.SPAWN[0], z - hub.SPAWN[1])
        angle = abs(math.degrees(math.atan2(x - hub.SPAWN[0], -(z - hub.SPAWN[1]))))
        rows.append(
            "<tr><td>%s</td><td>%d studs, about %.0f s</td><td>%s</td></tr>"
            % (title, round(distance), distance / hub.WALK_SPEED, "Yes" if angle <= HALF_VIEW else "No, it is behind you")
        )
    with open(os.path.join(HERE, "plan.svg"), encoding="utf-8") as handle:
        plan = handle.read()
    with open(os.path.join(HERE, "page.template.html"), encoding="utf-8") as handle:
        page = handle.read()
    page = page.replace("__PLAN__", plan).replace("__ROWS__", "\n".join(rows))
    with open(os.path.join(HERE, "hub-concept.html"), "w", encoding="utf-8") as handle:
        handle.write(page)
    print("wrote hub-concept.html")


main()
