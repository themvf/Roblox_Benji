"""Assemble alternatives/factions/index.html for the Faction Islands concept.

    python docs/design/lobby-experience/hub-concept/factions.py
    blender -b -noaudio --python docs/design/lobby-experience/hub-concept/render_alternatives.py -- factions
    python docs/design/lobby-experience/hub-concept/build_factions_page.py
"""

import html
import os

from PIL import Image

import factions

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "alternatives", "factions")

SIDES = [
    ("forge", "ARMORY", "Forge Union", "#ff5c1f", "Heat, rivets and a gantry crane over the counter; chimneys glowing at the lip, hand-painted banners, piston columns at the bridge mouth. The people who built the machines run the weapons bench.", "Front left, 12.5 s"),
    ("institute", "KITS", "Coherence Institute", "#80e0ff", "White domes, a floating holo-ring over the kit plinths, frost vents. The government's scientists hand out the abilities.", "Front right, 12.5 s"),
    ("kade", "SHOP", "Kade Dynamics", "#ffcc61", "Chrome and gold, a private rocket on its launch tower, the K on everything. The billionaires sell you things: \"Reality is a market.\"", "Back right, 10.7 s"),
    ("ferrymen", "THE LEDGER", "The Ferrymen", "#9eff40", "Stacked salvage containers with neon tape, a coin ring over a market stall, a ferry moored off the edge over the void. The leaderboard is the Ledger, after the Ferrymen's boss.", "Back left, 10.7 s"),
]


# Art direction per island. Every material is a Roblox Material, every font a Roblox font family,
# and every effect a stock instance, so a builder can work from this without inventing anything.
ART = [
    {
        "key": "hold",
        "name": "The Hold (arrival, pads, gate)",
        "role": "Neutral ground. Nobody owns it, everyone waits in it.",
        "palette": [("Concrete", "#4a4f58"), ("Emergency amber", "#ff9e33"), ("Shadow", "#22252c"), ("Gate gold", "#ffc445"), ("Dark matter", "#8c52ff")],
        "rows": [
            ("Feel", "A departure lounge, not a home. Bare, functional, slightly tired: the lore's rule for every Hold, with no mascots, no cheerful ads and no uniforms."),
            ("Materials", "Concrete and Slate floors, Metal rails, Neon only for the rail strips and the coloured bridge lines."),
            ("Light", "Low, flat emergency light: amber lamps on the rail posts, dimmer than any faction island, so the islands are the bright, inviting things in view."),
            ("Signature props", "The departures board with the day count and crossing status, beside the bridge to the pads. Piles of bags that were never unpacked along the rails."),
            ("Signs", "Michroma, amber on black, like an airport board. The day count is the largest text in the Hold."),
            ("Sound", "A low tannoy murmur and the slow click of the departures board flipping."),
            ("Motion", "Board rows flip every few seconds. The gate's accretion ring turns slowly."),
            ("Avoid", "Faction colours on the spine. The spine stays neutral so the four colours mean something."),
        ],
    },
    {
        "key": "forge",
        "name": "ARMORY: Forge Union",
        "role": "The workers who built the machines and were left off the List. Hot, loud, hand-made.",
        "palette": [("Rust", "#6e2e17"), ("Warning orange", "#ff5c1f"), ("Hazard yellow", "#ffc21a"), ("Soot", "#2a211d"), ("Banner canvas", "#e8dcc0")],
        "rows": [
            ("Feel", "A dockyard workshop that took over a Hold: welded, patched and proud of it."),
            ("Materials", "CorrodedMetal walls, DiamondPlate floor, Metal for the crane, Fabric for the banners."),
            ("Light", "Warm and uneven. Orange PointLights with a slight flicker, a white-hot weld arc, rotating warning beacons on the crane."),
            ("Signature props", "The gantry crane over the counter with a crate on the hook; two chimneys glowing at the lip; a welding bench throwing sparks; riveted plate seams; a pegboard of painted tool outlines; a hazard-striped threshold where the bridge lands."),
            ("Signs", "Oswald, stencil-cut, painted on. Banners are hand-lettered in red on canvas: SEATS BY LOTTERY."),
            ("Effects", "Sparks (ParticleEmitter, short bursts), chimney smoke, hydraulic hiss puffs from the pistons."),
            ("Sound", "Distant hammering, a grinder, pistons hissing."),
            ("Avoid", "Clean surfaces and anything symmetrical. Nothing here came from a catalogue."),
        ],
    },
    {
        "key": "institute",
        "name": "KITS: Coherence Institute",
        "role": "The official evacuation program. Cold, exact, in control, and keeper of the List.",
        "palette": [("Clinical white", "#e6eef5"), ("Ice cyan", "#80e0ff"), ("Frost", "#c8f0ff"), ("Deep blue", "#1c3a5c"), ("Steel grey", "#8c96a3")],
        "rows": [
            ("Feel", "A field laboratory: calm, quiet, symmetrical, and slightly too clean."),
            ("Materials", "SmoothPlastic white panels, Glass, Ice at the base of the domes, Neon for the circuit traces in the floor."),
            ("Light", "Cool, even SurfaceLights with no flicker, and a soft cyan underglow from the traces."),
            ("Signature props", "Two white domes; a holo-ring with drifting glyphs over the kit plinths; the List, a tall board of names; frost vents; a surveying instrument on a tripod with its beam laid across the floor."),
            ("Signs", "Jura, thin and wide-spaced, cyan on white. Every sign carries a reference number."),
            ("Effects", "Cold mist from the vents (low, slow ParticleEmitter), glyphs rotating on the ring, the List scrolling."),
            ("Sound", "A clean electrical hum and soft confirmation chimes."),
            ("Avoid", "Warm colours and clutter. If something is out of place, it should look deliberate."),
        ],
    },
    {
        "key": "kade",
        "name": "SHOP: Kade Dynamics",
        "role": "The billionaires who paid for the Lattice. Polished, exclusive, and selling seats.",
        "palette": [("Graphite", "#2e3036"), ("Chrome", "#a8acb4"), ("Kade gold", "#ffcc61"), ("Champagne", "#f2e2b8"), ("Velvet", "#8c1019")],
        "rows": [
            ("Feel", "A private terminal for people who never queue: quiet luxury, a showroom more than a shop."),
            ("Materials", "Marble apron, Foil and Metal chrome, Glass, gold Neon trim used sparingly."),
            ("Light", "Crisp white spotlights on the products, gold under-glow along edges, the rocket floodlit from below."),
            ("Signature props", "A private rocket on its launch tower with steam at its feet; jewellery-like drones orbiting it; a velvet-rope queue on gold stanchions; the K on a chrome disc and inlaid in the floor; a price ticker where seats sell out."),
            ("Signs", "Montserrat, wide and light, gold on graphite. Logos everywhere, slogans nowhere: the brand is the message."),
            ("Effects", "Venting steam at the rocket base, drones bobbing on slow tweens, the ticker scrolling."),
            ("Sound", "Soft lounge music and a calm announcer voice reading seat numbers."),
            ("Avoid", "Anything worn, handmade or loud. Gold is an accent, never a surface."),
        ],
    },
    {
        "key": "ferrymen",
        "name": "THE LEDGER: The Ferrymen",
        "role": "Smugglers and salvagers who stopped waiting to be saved. Built from what they stole.",
        "palette": [("Tar", "#1e2624"), ("Neon lime", "#9eff40"), ("Neon magenta", "#ff4db8"), ("Faded blue", "#33506b"), ("Coin gold", "#c8962e")],
        "rows": [
            ("Feel", "A night market on a wreck: improvised, crowded, friendly if you pay."),
            ("Materials", "CorrodedMetal containers, WoodPlanks decking, Fabric tarps, Neon tape on every edge."),
            ("Light", "String lights and neon, a lantern on the moored ferry; the darkest island, lit in pools."),
            ("Signature props", "Stacked salvage containers; two tarps that do not match over the stall; the coin ring above the sign; a ferry moored off the edge over the void; contraband crates; a stolen piece from each other side (an Institute dome, a Kade stanchion, a Forge banner)."),
            ("Signs", "Permanent Marker for tags sprayed on containers (EVERYONE CROSSES); Sarpanch for the Ledger itself."),
            ("Effects", "Neon that buzzes and occasionally drops out, the lantern swaying, coins glinting on the board."),
            ("Sound", "Radio static between songs, haggling voices, water slapping a hull that is not in water."),
            ("Avoid", "Anything new or matched. Every piece should look like it came from somewhere else."),
        ],
    },
]

BUILD_NOTES = [
    "One colour per side, used for its rail glow, bridge line, sign and lights, and nowhere else. Faction colours never touch the Red and Blue team colours, which stay in matches only; the Forge orange is the one to check against Red on the HUD.",
    "Each island is recognised first by silhouette, from the arrival island: crane and chimneys, domes and ring, rocket and tower, container stack and coin. Signs come second.",
    "Text on islands goes on SurfaceGuis on the sign beams, through the project's Theme type ramp; the departures board is the one exception, deliberately in its own airport style.",
    "Budget: about 150 parts per island in the real build, with railings merged into a few meshes. The crane, rocket, domes, ferry and containers are the five props worth uploading as models; everything else is built from parts.",
    "Effects stay cheap on phones: at most two ParticleEmitters per island, low rates, and none of them in the view from the arrival spawns.",
    "The void below gets a dark-matter skybox and slow drifting particles; anything far away is skybox, not geometry, per the project's scenery rule.",
]


def art_card(entry):
    swatches = "".join(
        '<li><span class="chip" style="background:%s"></span><span>%s<br><code>%s</code></span></li>' % (hex_, html.escape(label), hex_)
        for label, hex_ in entry["palette"]
    )
    rows = "".join("<tr><th scope=\"row\">%s</th><td>%s</td></tr>" % (html.escape(k), html.escape(v)) for k, v in entry["rows"])
    return f"""<article class="art" style="--side:{entry['palette'][1][1]}">
      <h3>{html.escape(entry['name'])}</h3>
      <p class="muted">{html.escape(entry['role'])}</p>
      <ul class="swatches">{swatches}</ul>
      <table class="spec"><tbody>{rows}</tbody></table>
    </article>"""


def jpg(name):
    Image.open(os.path.join(OUT, name + ".png")).convert("RGB").save(os.path.join(OUT, name + ".jpg"), quality=86)
    return name + ".jpg"


def figure(name, caption):
    return '<figure><img src="%s" alt="%s" width="1280" height="720" loading="lazy"><figcaption>%s</figcaption></figure>' % (
        jpg(name),
        html.escape(caption),
        html.escape(caption),
    )


def main():
    variant = factions.factions()
    titles = {name: title for name, title, *_ in variant.VIEWS}
    with open(os.path.join(OUT, "plan.svg"), encoding="utf-8") as handle:
        plan = handle.read()
    sides = "\n".join(
        f"""<article class="side" style="--side:{colour}">
      {figure(key, titles[key] + ".")}
      <div><div class="eyebrow">{html.escape(faction)}</div><h3>{html.escape(title)}</h3>
      <p>{html.escape(text)}</p><p class="muted">{html.escape(where)} from arrival</p></div>
    </article>"""
        for key, title, faction, colour, text, where in SIDES
    )
    with open(os.path.join(HERE, "factions.template.html"), encoding="utf-8") as handle:
        page = handle.read()
    page = (
        page.replace("__ARRIVAL__", figure("arrival", titles["arrival"] + ", at Roblox's default field of view."))
        .replace("__PLAN__", plan)
        .replace("__AERIAL__", figure("aerial", "The same layout as a render, from above."))
        .replace("__HERO__", figure("hero", titles["hero"] + "."))
        .replace("__CORNER__", figure("three_quarter", "The whole lobby from a high corner."))
        .replace("__SIDES__", sides)
        .replace("__PARTS__", str(len(variant.parts)))
        .replace("__ART__", "\n".join(art_card(entry) for entry in ART))
        .replace("__NOTES__", "".join("<li>%s</li>" % html.escape(note) for note in BUILD_NOTES))
    )
    with open(os.path.join(OUT, "index.html"), "w", encoding="utf-8") as handle:
        handle.write(page)
    print("wrote", os.path.join(OUT, "index.html"))


if __name__ == "__main__":
    main()
