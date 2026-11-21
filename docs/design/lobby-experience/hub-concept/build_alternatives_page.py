"""Assemble alternatives/index.html: the four alternatives beside the fifth concept.

    python docs/design/lobby-experience/hub-concept/alternatives.py
    blender -b -noaudio --python docs/design/lobby-experience/hub-concept/render_alternatives.py
    python docs/design/lobby-experience/hub-concept/build_alternatives_page.py
"""

import html
import math
import os

from PIL import Image

import alternatives

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "alternatives")
HALF_VIEW = math.degrees(math.atan(math.tan(math.radians(35)) * 16 / 9))

WRITE_UPS = {
    "orbit": {
        "idea": "The PLAY gate stands on a dais in the middle of one big round atrium. The pads ring the dais, ARMORY and KITS open off the atrium wall left and right, and the SHOP is behind you.",
        "good": [
            "Shortest walk to a match: Convergence is 3 s away, the gate 5 s.",
            "The anomaly is the centre of the room, so it is in view from almost everywhere, including the hall doors.",
            "Compact, and built from the same round walls and halls the fifth version uses.",
        ],
        "watch": [
            "On arrival the gate fills the view. It is dramatic, but you cannot take in the rest of the room without turning.",
            "Duel and TDM sit just outside the first view, about 55 degrees to each side.",
            "ARMORY and KITS are the furthest of any layout (about 12 s), because they sit outside the ring.",
            "Pads on a circle are harder to scan than pads in a row.",
        ],
    },
    "overlook": {
        "idea": "You arrive on a terrace 12 studs up and look down over the whole PLAY floor: every pad and the gate in one view. A wide central stair and two side stairs lead down. ARMORY and KITS open off the terrace wings; the SHOP is behind you.",
        "good": [
            "The only layout where all five modes and the gate are visible the moment you spawn, from above, so the pads read as a map rather than a row.",
            "Walking down the stairs is a clear moment of committing to play; the terrace stays calm for browsing the armory, kits and shop.",
            "Players on the floor are easy to see from the terrace, so the lobby looks busy.",
            "The lobby markers already allow it: they check footprint, not height.",
        ],
        "watch": [
            "Two levels: the halls and the shop sit on 12-stud platforms, so going from the armory to a pad means walking down a stair.",
            "The gate is 13 s away, about as far as in the fifth version.",
            "Stairs need a ramp or a gentle slope for players who struggle to climb them on a phone.",
        ],
    },
    "boulevard": {
        "idea": "One straight street from the arrival point to the gate court. Every hall is an open storefront off the street, with a blade sign that faces you as you arrive. The leaderboard and canister get their own storefront, a Hall of Fame.",
        "good": [
            "Simplest to read and to build: one direction, signs that face you, and a new destination later is just another storefront.",
            "ARMORY and KITS are the closest of any layout (about 6 s).",
            "The pads sit in the street you have to walk down anyway.",
        ],
        "watch": [
            "Longest walk to the gate (about 18 s) and to Convergence (16 s).",
            "A long straight street with walls is the corridor shape you found claustrophobic in the third version, even at 90 studs wide.",
            "Least sense of a central place to stand and look around.",
        ],
    },
    "islands": {
        "idea": "Floating platforms over the dark-matter void, joined by railed bridges. From the arrival island you look straight up the bridges to the pad island and the gate island beyond it. ARMORY, KITS and SHOP are islands of their own.",
        "good": [
            "The most distinctive and the most open: no walls, sky everywhere, and it fits the dark-matter story.",
            "The route to play is one straight line of bridges, so nobody gets lost.",
            "Each island is a separate piece, easy to add to or move later.",
        ],
        "watch": [
            "People can fall off. The lobby has no fall handling today, so it needs invisible walls along every rail and a recovery teleport.",
            "Bridges are pinch points when a full server crowds towards PLAY.",
            "Heaviest to build and to run: about 860 parts against about 200 for the others, which matters on low-end phones.",
            "The void needs its own lighting and sky work to look deep rather than just dark.",
        ],
    },
}

SUMMARY = {
    "fifth": ("Fifth version (built)", "Plaza with an avenue of pads to the gate", "Gate, avenue and its four pads", "about 15 s", "about 9 s", "Done"),
    "orbit": ("Orbit", "Gate in the middle of a round atrium", "Gate, Convergence, both training pads", "5 s", "12 s", "Small: same pieces as the fifth version"),
    "overlook": ("Overlook", "Terrace looking down on the PLAY floor", "Every pad and the gate", "13 s", "10 s", "Medium: stairs and raised halls"),
    "boulevard": ("Boulevard", "One street of storefronts to the gate", "Street, pads, gate, far storefront signs", "18 s", "6 s", "Small"),
    "islands": ("Islands", "Floating platforms and bridges", "Bridges, pads and gate in one line", "18 s", "11 s", "Large: fall handling, sky and lighting"),
}


def figure(src, alt, caption, width=1280, height=720):
    return '<figure><img src="%s" alt="%s" width="%d" height="%d" loading="lazy"><figcaption>%s</figcaption></figure>' % (
        src,
        html.escape(alt),
        width,
        height,
        html.escape(caption),
    )


def distances(variant):
    rows, seen = [], set()
    for text, x, z, _kind in variant.labels:
        title = text.split("\n")[0].title().replace("1V1", "1v1")
        if title in seen or title in ("Arrival", "Terrace"):
            continue
        seen.add(title)
        distance = math.hypot(x - variant.SPAWN[0], z - variant.SPAWN[1])
        angle = abs(math.degrees(math.atan2(x - variant.SPAWN[0], -(z - variant.SPAWN[1]))))
        rows.append(
            "<tr><td>%s</td><td>%.0f s</td><td>%s</td></tr>"
            % (html.escape(title), distance / variant.WALK_SPEED, "Yes" if angle <= HALF_VIEW else "No")
        )
    return "\n".join(rows)


def section(index, variant):
    key = variant.key
    folder = os.path.join(OUT, key)
    for name, *_ in variant.VIEWS:
        Image.open(os.path.join(folder, name + ".png")).convert("RGB").save(os.path.join(folder, name + ".jpg"), quality=86)
    with open(os.path.join(folder, "plan.svg"), encoding="utf-8") as handle:
        plan = handle.read()
    write = WRITE_UPS[key]
    titles = {name: title for name, title, *_ in variant.VIEWS}
    good = "".join("<li>%s</li>" % html.escape(item) for item in write["good"])
    watch = "".join("<li>%s</li>" % html.escape(item) for item in write["watch"])
    return f"""
  <section id="{key}">
    <div class="eyebrow">Option {"ABCD"[index]}</div>
    <h2>{html.escape(variant.title)}</h2>
    <p>{html.escape(write["idea"])}</p>
    {figure(f"{key}/arrival.jpg", f"{variant.title}: first view on arrival", titles["arrival"] + ", at Roblox's default field of view.")}
    <div class="grid">
      <figure><div class="plan">{plan}</div><figcaption>Plan, to scale. The player arrives facing up; dotted rings are walking time.</figcaption></figure>
      {figure(f"{key}/aerial.jpg", f"{variant.title} from above", "The same layout as a render, from above.")}
      {figure(f"{key}/hero.jpg", f"{variant.title}: {titles['hero']}", titles["hero"] + ".")}
      {figure(f"{key}/three_quarter.jpg", f"{variant.title} from a high corner", "The whole lobby from a high corner.")}
    </div>
    <div class="cols">
      <div><h3>What it does well</h3><ul>{good}</ul></div>
      <div><h3>What to watch</h3><ul>{watch}</ul></div>
      <div class="tbl"><h3>Walk from arrival</h3><table><thead><tr><th>Place</th><th>Walk</th><th>In first view</th></tr></thead><tbody>{distances(variant)}</tbody></table></div>
    </div>
  </section>"""


def main():
    variants = [build() for build in alternatives.VARIANTS.values()]
    rows = "\n".join(
        "<tr>%s</tr>" % "".join("<td>%s</td>" % html.escape(cell) for cell in SUMMARY[key])
        for key in ("fifth", *alternatives.VARIANTS)
    )
    sections = "\n".join(section(index, variant) for index, variant in enumerate(variants))
    with open(os.path.join(HERE, "alternatives.template.html"), encoding="utf-8") as handle:
        page = handle.read()
    page = page.replace("__ROWS__", rows).replace("__SECTIONS__", sections)
    with open(os.path.join(OUT, "index.html"), "w", encoding="utf-8") as handle:
        handle.write(page)
    print("wrote", os.path.join(OUT, "index.html"))


if __name__ == "__main__":
    main()
