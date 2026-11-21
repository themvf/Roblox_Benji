"""Faction Islands: the Islands alternative reimagined around the four sides of the lore.

    python docs/design/lobby-experience/hub-concept/factions.py      # plan + distances
    blender -b -noaudio --python docs/design/lobby-experience/hub-concept/render_alternatives.py -- factions

Concept only; nothing here is read by the game. The lobby is a neutral Hold on a Convergence Point
(lore: a Hold is a departure lounge where people wait for a seat). The neutral spine runs from the
arrival island over the pad island to the PLAY gate. Each of the four sides runs one island off it,
built in its own style and lit in its own colour, and each island is one of the lobby's destinations:

    Forge Union          ARMORY      heat, rivets, a gantry crane, hand-painted banners   (front left)
    Coherence Institute  KITS        white domes, floating holo-rings, frost vents         (front right)
    Kade Dynamics        SHOP        chrome and gold, a private rocket on its tower        (back right)
    The Ferrymen         THE LEDGER  stacked salvage, neon tape, a moored ferry, the board (back left)

Bridges take their island's colour, and four floor strips on the arrival island point the way,
so "follow the orange bridge" is the whole of the wayfinding.
"""

import math
import os

import alternatives as alt
import hub_design as hub
from alternatives import bearing_to, canister, gate, pad, people, purple, spawns, start
from hub_design import FLOOR, GOLD, GREEN, KIT_COLOURS, LILAC, PLATE, STEEL, VIOLET, WALL, add, box, figure, group

HERE = os.path.dirname(os.path.abspath(__file__))

FORGE = (1.0, 0.36, 0.12)
INSTITUTE = (0.5, 0.88, 1.0)
KADE = (1.0, 0.8, 0.38)
FERRY = (0.62, 1.0, 0.25)
NEUTRAL = (0.85, 0.88, 0.95)
MAGENTA = (1.0, 0.3, 0.72)

ARRIVAL, PADS, GATE = (0.0, 30.0), (0.0, -112.0), (0.0, -255.0)
FORGE_C, INST_C = (-150.0, -102.0), (150.0, -102.0)
FERRY_C, KADE_C = (-150.0, 112.0), (150.0, 112.0)
RADII = {ARRIVAL: 45, PADS: 60, GATE: 58, FORGE_C: 50, INST_C: 50, FERRY_C: 48, KADE_C: 48}
COLOUR = {FORGE_C: FORGE, INST_C: INSTITUTE, FERRY_C: FERRY, KADE_C: KADE}
LINKS = [
    (ARRIVAL, PADS),
    (PADS, GATE),
    (ARRIVAL, FORGE_C),
    (ARRIVAL, INST_C),
    (PADS, FORGE_C),
    (PADS, INST_C),
    (ARRIVAL, FERRY_C),
    (ARRIVAL, KADE_C),
]


def island(name, centre, radius, openings, accent, top):
    cx, cz = centre
    add("cyl", name, (cx, -3, cz), (radius * 2, 6, radius * 2), top)
    add("cyl", name + "Under", (cx, -10, cz), (radius * 1.5, 8, radius * 1.5), PLATE, plan=False)
    add("cyl", name + "Under2", (cx, -19, cz), (radius * 0.8, 10, radius * 0.8), PLATE, plan=False)
    add("cyl", name + "Core", (cx, -26, cz), (radius * 0.35, 6, radius * 0.35), accent, glow=3, plan=False)
    add("ring", name + "Trim", (cx, 0.12, cz), (radius * 2 - 1.2, 0.2, radius * 2 - 1.2), accent, glow=2.5, tube=0.35, flat=True, plan=False)
    segments = 40  # 64 in the first renders; 40 keeps the built lobby's part count down
    length = 2 * math.pi * (radius - 0.6) / segments + 0.2
    for index in range(segments):
        theta = index * 360 / segments
        if any(abs((theta - b + 180) % 360 - 180) < math.degrees(math.asin(14 / radius)) for b in openings):
            continue
        x, z = cx + (radius - 0.6) * math.sin(math.radians(theta)), cz - (radius - 0.6) * math.cos(math.radians(theta))
        box("Rail", (x, 1.6, z), (length, 3.2, 0.5), STEEL, rot=-theta)
        box("RailGlow", (x, 3.3, z), (length, 0.3, 0.7), accent, glow=3, rot=-theta, plan=False)


def bridge(name, a, b, accent):
    ra, rb = RADII[a], RADII[b]
    dx, dz = b[0] - a[0], b[1] - a[1]
    distance = math.hypot(dx, dz)
    ux, uz = dx / distance, dz / distance
    s = (a[0] + ux * (ra - 4), a[1] + uz * (ra - 4))
    e = (b[0] - ux * (rb - 4), b[1] - uz * (rb - 4))
    length = math.hypot(e[0] - s[0], e[1] - s[1])
    mx, mz = (s[0] + e[0]) / 2, (s[1] + e[1]) / 2
    rot = math.degrees(math.atan2(dx, dz))
    width = 24
    box(name, (mx, -1, mz), (width, 2, length), FLOOR, rot=rot)
    box(name + "Under", (mx, -3.5, mz), (width - 6, 3, length - 4), PLATE, rot=rot, plan=False)
    box(name + "Centre", (mx, 0.06, mz), (1.2, 0.1, length - 6), accent, glow=3, rot=rot, plan=False)
    tx, tz = math.cos(math.radians(rot)), -math.sin(math.radians(rot))
    for side in (-1, 1):
        ox, oz = tx * side * (width / 2 - 0.3), tz * side * (width / 2 - 0.3)
        box(name + "Rail", (mx + ox, 1.6, mz + oz), (0.5, 3.2, length - 8), STEEL, rot=rot)
        box(name + "RailGlow", (mx + ox, 3.3, mz + oz), (0.7, 0.3, length - 8), accent, glow=3, rot=rot, plan=False)


def facing(centre):
    """A placer in the island's frame: local +z points at the arrival island, back wall at -z."""
    return group(centre, (180 - bearing_to(centre, ARRIVAL)) % 360)


def signage(place, name, title, faction, accent, wall_colour, width=64):
    place("box", name + "WallBack", (0, 7, -27), (width, 14, 1.6), wall_colour)
    place("box", name + "TopGlow", (0, 13.6, -25.8), (width - 4, 0.4, 0.4), accent, glow=6, plan=False)
    place("box", name + "Beam", (0, 21, -27), (46, 9, 2), STEEL)
    place("text", name + "Sign", (0, 22.6, -25.8), (4.2, 0, 0), accent, glow=9, text=title)
    place("text", name + "Faction", (0, 18.4, -25.8), (1.7, 0, 0), (0.92, 0.93, 0.96), glow=5, text=faction)


def pledge(place, name, x, z, accent):
    """The side's standard at the island's mouth: where a player would pledge, if allegiance is built."""
    place("cyl", name + "Pole", (x, 11, z), (1, 22, 1), STEEL, plan=False)
    place("box", name + "Flag", (x + 4.6, 17.5, z), (8, 9, 0.3), accent, glow=1.4, plan=False)


def forge():
    accent, place = FORGE, facing(FORGE_C)
    hub.labels.append(("ARMORY\nForge Union", FORGE_C[0], FORGE_C[1], "place"))
    signage(place, "Forge", "ARMORY", "FORGE UNION  -  BUILT TO HOLD", accent, (0.24, 0.17, 0.14))
    alt.armory(place, 64, 54, range_door=False)
    # gantry crane straddling the counter, a crate on the hook
    for side in (-1, 1):
        place("box", "CraneLeg", (side * 30, 18, -14), (3, 36, 3), (0.55, 0.22, 0.1))
        place("box", "CraneLegStripe", (side * 30, 3, -12.4), (3.2, 4, 0.2), (1.0, 0.75, 0.1), glow=1.5, plan=False)
    place("box", "CraneBeam", (0, 37, -14), (64, 3, 3), (0.55, 0.22, 0.1), plan=False)
    place("box", "CraneTrolley", (24, 34.5, -14), (5, 2, 4), STEEL, plan=False)
    place("box", "CraneCable", (24, 27, -14), (0.3, 13, 0.3), STEEL, plan=False)
    place("box", "CraneCrate", (24, 18, -14), (7, 5, 7), (0.42, 0.3, 0.18), plan=False)
    # chimneys with a hot glow at the lip
    for x, z, h in ((-26, -34, 46), (-17, -37, 38)):
        place("cyl", "Chimney", (x, h / 2, z), (6, h, 6), (0.3, 0.2, 0.16))
        place("ring", "ChimneyGlow", (x, h - 0.5, z), (6.4, 1, 6.4), accent, glow=8, tube=0.5, flat=True, plan=False)
    # hand-painted banners on the back wall
    for x, colour in ((-24, (0.85, 0.3, 0.15)), (24, (0.92, 0.85, 0.7))):
        place("box", "Banner", (x, 8, -25.9), (7, 11, 0.2), colour, glow=0.4, plan=False)
    # piston columns at the bridge mouths
    for x in (-18, 18):
        place("cyl", "Piston", (x, 5, 30), (3.4, 10, 3.4), STEEL)
        place("cyl", "PistonRod", (x, 12, 30), (1.6, 6, 1.6), (0.8, 0.8, 0.82), plan=False)
        place("ring", "PistonGlow", (x, 10.1, 30), (3.6, 0.6, 3.6), accent, glow=6, tube=0.3, flat=True, plan=False)
    pledge(place, "Forge", -30, 22, accent)
    return place


def institute():
    accent, place = INSTITUTE, facing(INST_C)
    white = (0.78, 0.82, 0.88)
    hub.labels.append(("KITS\nCoherence Institute", INST_C[0], INST_C[1], "place"))
    signage(place, "Institute", "KITS", "COHERENCE INSTITUTE  -  MEASURE TWICE", accent, white)
    alt.kits(place, 50)
    for side in (-1, 1):
        add_dome = place
        add_dome("sphere", "Dome", (side * 28, 0, -16), (28, 28, 28), white)
        add_dome("ring", "DomeBand", (side * 28, 4, -16), (26, 1, 26), accent, glow=5, tube=0.4, flat=True, plan=False)
    # holo-glyph rings floating over the kit plinths
    place("ring", "HoloRing", (0, 42, -16), (30, 30, 1), accent, glow=7, tube=0.35, tilt=20, plan=False)
    place("ring", "HoloRingInner", (0, 42, -16), (20, 20, 1), (0.85, 0.95, 1.0), glow=5, tube=0.2, tilt=55, plan=False)
    place("sphere", "HoloCore", (0, 42, -16), (3, 3, 3), (0.85, 0.95, 1.0), glow=10, plan=False)
    # frost vents
    for x, z in ((-34, 10), (34, 10), (-12, 26), (12, 26)):
        place("cyl", "FrostVent", (x, 1, z), (3, 2, 3), white)
        place("cyl", "FrostPlume", (x, 6, z), (2, 8, 2), (0.8, 0.95, 1.0), glow=1.2, plan=False)
    pledge(place, "Institute", 30, 22, accent)
    return place


def kade():
    accent, place = KADE, facing(KADE_C)
    chrome = (0.62, 0.64, 0.68)
    hub.labels.append(("SHOP\nKade Dynamics", KADE_C[0], KADE_C[1], "place"))
    signage(place, "Kade", "SHOP", "KADE DYNAMICS  -  REALITY IS A MARKET", accent, (0.32, 0.33, 0.36), width=60)
    alt.shop(place, 54)
    # the private rocket on its tower
    rx, rz = -30, -6
    place("cyl", "LaunchPad", (rx, 0.6, rz), (16, 1.2, 16), STEEL)
    place("cyl", "Rocket", (rx, 30, rz), (9, 56, 9), (0.86, 0.87, 0.9))
    place("sphere", "RocketNose", (rx, 58, rz), (9, 12, 9), (0.86, 0.87, 0.9), plan=False)
    for y in (12, 40):
        place("ring", "RocketBand", (rx, y, rz), (9.6, 1, 9.6), accent, glow=4, tube=0.5, flat=True, plan=False)
    for angle in (0, 120, 240):
        fx, fz = math.sin(math.radians(angle)) * 5.5, math.cos(math.radians(angle)) * 5.5
        place("box", "RocketFin", (rx + fx, 5, rz + fz), (1, 8, 4), chrome, rot=angle + 90, plan=False)
    place("box", "Tower", (rx - 11, 34, rz), (4, 68, 4), (0.3, 0.3, 0.33))
    place("box", "TowerGlow", (rx - 9, 34, rz), (0.3, 64, 0.3), accent, glow=6, plan=False)
    # the logo, a gold K on a chrome disc, and gold-trimmed plinths
    place("box", "LogoDisc", (24, 18, -18), (14, 14, 0.6), chrome, plan=False)
    place("ring", "LogoRing", (24, 18, -17.6), (14, 14, 1), accent, glow=6, tube=0.5, plan=False)
    place("text", "Logo", (24, 18, -17.3), (9, 0, 0), accent, glow=10, text="K")
    for x in (10, 34):
        place("box", "ChromePlinth", (x, 1.5, 18), (6, 3, 6), chrome)
        place("box", "ChromePlinthTop", (x, 3.1, 18), (6.2, 0.2, 6.2), accent, glow=5, plan=False)
    pledge(place, "Kade", 30, 24, accent)
    return place


def ferrymen():
    accent, place = FERRY, facing(FERRY_C)
    hub.labels.append(("THE LEDGER\nFerrymen", FERRY_C[0], FERRY_C[1], "place"))
    signage(place, "Ferry", "THE LEDGER", "THE FERRYMEN  -  EVERYONE PAYS", accent, (0.16, 0.2, 0.19), width=60)
    # the leaderboard is the Ledger
    place("box", "Leaderboard", (0, 8, -25.6), (30, 12, 0.6), STEEL)
    place("box", "LeaderboardGlow", (0, 8, -25.1), (28.5, 10.5, 0.2), (0.25, 0.5, 0.3), glow=1.6, plan=False)
    # stacked salvage containers, neon tape on their edges
    rust, blue, olive = (0.45, 0.2, 0.13), (0.2, 0.3, 0.42), (0.32, 0.34, 0.2)
    for x, y, z, rot, colour in (
        (-28, 4, -14, 90, rust),
        (-28, 12, -12, 80, blue),
        (-30, 20, -14, 95, olive),
        (28, 4, -12, 90, blue),
        (28, 12, -15, 100, rust),
    ):
        place("box", "Container", (x, y, z), (20, 8, 8), colour, rot=rot)
        place("box", "NeonTape", (x, y + 4.05, z), (20.2, 0.2, 0.6), MAGENTA if colour == blue else accent, glow=6, rot=rot, plan=False)
    # the coin ring over the market stall
    place("box", "Stall", (0, 1.75, 6), (24, 3.5, 6), (0.28, 0.24, 0.2))
    place("box", "StallGlow", (0, 3.55, 6), (23, 0.12, 5.4), accent, glow=2, plan=False)
    place("ring", "CoinRing", (0, 37, -26), (16, 16, 2), GOLD, glow=7, tube=1.3, plan=False)
    place("sphere", "Coin", (0, 37, -26.5), (12, 12, 1.2), (0.7, 0.55, 0.2), plan=False)
    place("box", "CoinPost", (0, 28.5, -27.5), (1.2, 6, 1.2), STEEL, plan=False)
    # a ferry moored off the island's edge, out over the void
    place("box", "FerryHull", (-46, -2, 6), (12, 5, 30), (0.22, 0.24, 0.24), rot=10)
    place("box", "FerryCabin", (-46, 3, 2), (8, 6, 10), (0.3, 0.32, 0.3), rot=10, plan=False)
    place("sphere", "FerryLantern", (-46, 8, -10), (2, 2, 2), accent, glow=12, plan=False)
    pledge(place, "Ferry", -28, 24, accent)
    return place


# ----------------------------------------------------------------- signature details
# The art direction on the page (build_factions_page.py, ART) names these props. Each is the
# one thing a player should remember the island by, so each is drawn here at its real size.

HAZARD = (1.0, 0.76, 0.1)
SOOT = (0.12, 0.1, 0.09)
CANVAS = (0.91, 0.86, 0.75)


def forge_detail():
    place = facing(FORGE_C)
    # hazard-striped threshold where the bridge lands
    for index in range(10):
        place("box", "Hazard", (-13.5 + index * 3, 0.08, 40), (3, 0.1, 3), HAZARD if index % 2 else SOOT, glow=0.6 if index % 2 else 0, plan=False)
    # riveted plate seams on the back wall
    for row in (3, 11):
        for index in range(15):
            place("sphere", "Rivet", (-28 + index * 4, row, -26.1), (0.6, 0.6, 0.6), (0.5, 0.42, 0.36), plan=False)
    # a hanging protest banner from the crane beam, hand-lettered
    place("box", "CraneBanner", (-12, 29, -13.2), (14, 12, 0.25), CANVAS, glow=0.3, plan=False)
    place("text", "CraneBannerText", (-12, 31, -13.0), (1.6, 0, 0), (0.75, 0.15, 0.08), text="SEATS BY")
    place("text", "CraneBannerText2", (-12, 27.4, -13.0), (1.6, 0, 0), (0.75, 0.15, 0.08), text="LOTTERY")
    # warning beacons on the crane
    for side in (-1, 1):
        place("sphere", "Beacon", (side * 30, 39.3, -14), (1.6, 1.6, 1.6), FORGE, glow=14, plan=False)
    # welding bench with a spray of sparks
    place("box", "WeldBench", (-32, 1.8, 6), (8, 3.6, 5), (0.3, 0.26, 0.24))
    place("sphere", "WeldArc", (-32, 4.2, 6), (0.9, 0.9, 0.9), (1.0, 0.95, 0.8), glow=40, plan=False)
    for index in range(14):
        angle = index * 0.9
        x, y, z = -32 + math.cos(angle) * (1 + index * 0.25), 4.5 + math.sin(index * 1.7) * 1.2, 6 + math.sin(angle) * (1 + index * 0.2)
        place("sphere", "Spark", (x, y, z), (0.25, 0.25, 0.25), (1.0, 0.7, 0.25), glow=25, plan=False)
    # tool wall: outlines of tools painted on a pegboard
    place("box", "Pegboard", (34, 6, 2), (0.4, 8, 12), (0.42, 0.34, 0.24), rot=0, plan=False)
    for index, h in enumerate((5, 3.5, 6, 4)):
        place("box", "ToolOutline", (33.7, 6, -3 + index * 2.8), (0.1, h, 0.5), CANVAS, glow=1, plan=False)


def institute_detail():
    place = facing(INST_C)
    # the List: a tall holo-board of names, the Institute's whole claim to order
    place("box", "ListBoard", (-36, 13, 4), (0.4, 22, 12), (0.12, 0.22, 0.32), glow=0.6, plan=False)
    place("text", "ListTitle", (-35.6, 22, 4), (1.4, 0, 0), INSTITUTE, glow=8, text="THE LIST", rot=90)
    for row in range(12):
        width = 9 if row % 3 else 6
        place("box", "ListRow", (-35.7, 19.5 - row * 1.4, 4 - (9 - width) / 2), (0.1, 0.35, width), (0.75, 0.92, 1.0), glow=4, plan=False)
    # circuit traces inlaid in the floor, running to the kit plinths
    for x in (-24, -8, 8, 24):
        place("box", "Trace", (x, 0.07, 8), (0.5, 0.1, 30), INSTITUTE, glow=4, plan=False)
        place("box", "TraceJog", (x * 0.6, 0.07, 23), (abs(x) * 0.8 + 0.5, 0.1, 0.5), INSTITUTE, glow=4, plan=False)
    # frost collars where the domes meet the floor
    for side in (-1, 1):
        place("ring", "Frost", (side * 28, 0.2, -16), (30, 0.6, 30), (0.88, 0.97, 1.0), glow=2, tube=1.2, flat=True, plan=False)
    # a surveying instrument on a tripod: measure twice
    for angle in (0, 120, 240):
        lx, lz = math.sin(math.radians(angle)) * 1.4, math.cos(math.radians(angle)) * 1.4
        place("box", "TripodLeg", (34 + lx, 2.4, 6 + lz), (0.25, 4.8, 0.25), (0.8, 0.82, 0.86), plan=False)
    place("box", "Theodolite", (34, 5.2, 6), (1.4, 1.2, 1.4), (0.9, 0.92, 0.95), plan=False)
    place("box", "TheodoliteBeam", (34, 5.2, -10), (0.15, 0.15, 30), INSTITUTE, glow=10, plan=False)
    # glyphs drifting around the holo-ring
    for index in range(8):
        angle = index * 45
        x, y = math.sin(math.radians(angle)) * 20, 42 + math.cos(math.radians(angle)) * 8
        place("box", "Glyph", (x, y, -16), (1.6, 1.6, 0.1), INSTITUTE, glow=8, rot=angle, plan=False)


def kade_detail():
    place = facing(KADE_C)
    marble, rope = (0.82, 0.8, 0.76), (0.55, 0.06, 0.1)
    # marble apron with a gold inlay where the bridge arrives
    place("cyl", "MarbleApron", (6, 0.06, 12), (40, 0.12, 40), marble, plan=False)
    place("ring", "GoldInlay", (6, 0.14, 12), (38, 0.2, 38), KADE, glow=5, tube=0.3, flat=True, plan=False)
    place("text", "FloorLogo", (6, 0.16, 12), (10, 0, 0), KADE, glow=4, text="K", flat=True)
    # velvet-rope queue to the counter: a seat is a purchase
    posts = [(-4, 30), (-4, 20), (-4, 10), (16, 10), (16, 20), (16, 30)]
    for x, z in posts:
        place("cyl", "Stanchion", (x, 1.8, z), (0.8, 3.6, 0.8), KADE, glow=2)
        place("sphere", "StanchionTop", (x, 3.8, z), (1.2, 1.2, 1.2), KADE, glow=4, plan=False)
    for (ax, az), (bx, bz) in zip(posts, posts[1:]):
        if ax == bx:
            place("box", "Rope", (ax, 3.0, (az + bz) / 2), (0.35, 0.35, abs(bz - az)), rope, plan=False)
    # jewellery drones orbiting the rocket
    for index in range(6):
        angle = index * 60
        x, z = -30 + math.sin(math.radians(angle)) * 12, -6 + math.cos(math.radians(angle)) * 12
        place("sphere", "Drone", (x, 24 + (index % 3) * 9, z), (1.6, 2.4, 1.6), KADE, glow=6, plan=False)
    # steam at the rocket's feet
    for index, (x, z, s) in enumerate(((-24, -2, 5), (-36, -8, 6), (-30, 3, 4), (-26, -12, 4.5))):
        place("sphere", "Steam", (x, 2, z), (s, s * 0.7, s), (0.82, 0.84, 0.88), plan=False)
    # price ticker across the shop wall
    place("box", "Ticker", (0, 14.6, -25.7), (52, 1.6, 0.3), (0.08, 0.07, 0.05), plan=False)
    place("text", "TickerText", (0, 14.6, -25.4), (1.1, 0, 0), KADE, glow=8, text="SEAT 12A  9,999,999  -  SEAT 12B  SOLD  -  SEAT 12C  SOLD")


def ferrymen_detail():
    place = facing(FERRY_C)
    tarp, blue_tarp = (0.6, 0.18, 0.42), (0.18, 0.32, 0.5)
    # patched tarps over the stall, two colours that do not match; clear of the Ledger board and its sign
    place("box", "Tarp", (-6, 13.5, 2), (14, 0.3, 8), tarp, plan=False)
    place("box", "Tarp2", (7, 14, 1.5), (13, 0.3, 8), blue_tarp, plan=False)
    for x, z in ((-12, 5.5), (12, 5.5), (-12, -2), (12, -2)):
        place("box", "TarpPole", (x, 6.9, z), (0.4, 13.8, 0.4), STEEL, plan=False)
    # string lights from the containers to the flag pole
    for index in range(16):
        t = index / 15
        x, z = -28 + t * 56, 18 - 6 * math.sin(t * math.pi)
        y = 16 - 4 * math.sin(t * math.pi)
        place("sphere", "Bulb", (x, y, z), (0.7, 0.7, 0.7), MAGENTA if index % 3 == 0 else (1.0, 0.85, 0.5), glow=12, plan=False)
    # stolen pieces of the other three sides
    place("sphere", "StolenDome", (36, 0, 10), (12, 12, 12), (0.78, 0.82, 0.88))
    place("cyl", "StolenStanchion", (24, 1.8, 14), (0.8, 3.6, 0.8), KADE, glow=2, plan=False)
    place("box", "StolenBanner", (-28, 10, -9.2), (6, 6, 0.2), CANVAS, glow=0.3, rot=90, plan=False)
    place("box", "StolenBannerStripe", (-28, 10, -9.0), (6, 1.2, 0.2), FORGE, glow=1, rot=90, plan=False)
    # a tag sprayed on the container stack
    place("text", "Tag", (28, 5.2, -1.8), (1.2, 0, 0), FERRY, glow=7, text="EVERYONE")
    place("text", "Tag2", (28, 3.2, -1.8), (1.2, 0, 0), MAGENTA, glow=7, text="CROSSES")
    # a coin motif in the floor, and contraband crates by the boat
    place("ring", "FloorCoin", (0, 0.12, 22), (12, 0.2, 12), GOLD, glow=3, tube=0.5, flat=True, plan=False)
    place("ring", "FloorCoinInner", (0, 0.12, 22), (7, 0.2, 7), GOLD, glow=3, tube=0.3, flat=True, plan=False)
    for x, z, s in ((-34, 12, 4), (-36, 17, 3), (-31, 16, 3.4)):
        place("box", "Contraband", (x, s / 2, z), (s, s, s), (0.36, 0.28, 0.18), plan=False)


def hold_detail():
    """The neutral arrival island is a Hold: bare concrete, emergency lighting, a departures board."""
    amber = (1.0, 0.62, 0.2)
    # beside the bridge to the pads, angled at the spawns, clear of the gate in the first view
    board = group((-17, -2), 20)
    y = 10
    board("box", "Departures", (0, y, 0), (20, 10, 0.6), (0.05, 0.05, 0.06))
    board("box", "DeparturesFrame", (0, y, -0.2), (20.8, 10.8, 0.3), STEEL, plan=False)
    for side in (-1, 1):
        board("box", "DeparturesPost", (side * 9, 2.5, 0), (1, 5, 1), STEEL)
    board("text", "DeparturesTitle", (0, y + 3.6, 0.4), (1.3, 0, 0), amber, glow=8, text="DEPARTURES")
    board("text", "DayCount", (0, y + 1.2, 0.4), (1.9, 0, 0), (1.0, 0.95, 0.85), glow=9, text="DAY 214")
    for row, text in enumerate(("CROSSING 1   OPEN", "CROSSING 2   BOARDING", "CROSSING 3   HELD")):
        board("text", "DepartureRow", (0, y - 1.4 - row * 1.5, 0.4), (0.8, 0, 0), amber, glow=6, text=text)
    # bags never unpacked, along the rail
    for x, z, w in ((-34, 18, 3), (-31, 21, 2.4), (-36, 23, 2.8), (33, 34, 3), (36, 30, 2.4)):
        box("Bag", (x, w * 0.35, z), (w, w * 0.7, w * 0.6), (0.3, 0.27, 0.24), plan=False)
    # emergency lamps on the rail
    for bearing in range(20, 360, 40):
        x, z = ARRIVAL[0] + 43 * math.sin(math.radians(bearing)), ARRIVAL[1] - 43 * math.cos(math.radians(bearing))
        add("sphere", "EmergencyLamp", (x, 4.2, z), (1, 1, 1), amber, glow=12, plan=False)


def compass():
    """Four floor strips from the arrival ring, each pointing at its side's bridge."""
    for target, colour in COLOUR.items():
        bearing = bearing_to(ARRIVAL, target)
        rot = (180 - bearing) % 360
        nx, nz = math.sin(math.radians(bearing)), -math.cos(math.radians(bearing))
        box("Compass", (ARRIVAL[0] + nx * 26, 0.08, ARRIVAL[1] + nz * 26), (2, 0.1, 22), colour, glow=4, rot=rot, plan=False)


def factions():
    start()
    extent = {"x": 235, "north": -320, "south": 180}
    box("Floor", (0, -140, (extent["north"] + extent["south"]) / 2), (extent["x"] * 2, 2, extent["south"] - extent["north"]), (0.02, 0.015, 0.04))
    add("cyl", "Void", (0, -138, -45), (4000, 0.5, 4000), (0.12, 0.07, 0.25), glow=0.08, plan=False)
    for centre, radius in RADII.items():
        openings = [bearing_to(centre, b if a == centre else a) for a, b in LINKS if centre in (a, b)]
        top = {FORGE_C: (0.26, 0.2, 0.18), INST_C: (0.36, 0.4, 0.46), KADE_C: (0.27, 0.28, 0.31), FERRY_C: (0.15, 0.19, 0.18)}.get(centre, FLOOR)
        island("Island", centre, radius, openings, COLOUR.get(centre, NEUTRAL), top)
    for index, (a, b) in enumerate(LINKS):
        bridge("Bridge%d" % index, a, b, COLOUR.get(b, COLOUR.get(a, NEUTRAL)))

    # neutral spine: arrival, pads, gate
    add("ring", "ArrivalRing", (0, 0.15, 30), (24, 0.2, 24), GOLD, glow=2.5, tube=0.3, flat=True)
    compass()
    canister(-22, 52)
    hub.labels.append(("SEASON\nDISPLAY", -22, 52, "place"))
    purple(22, 55)
    pad("Duel", "DUEL 1V1", -22, -92, GREEN)
    pad("TDM", "TEAM DEATHMATCH", 22, -92, GOLD)
    pad("TrainingObjective", "TRAINING", -22, -134, LILAC)
    pad("TrainingTDM", "TRAINING TDM", 22, -134, LILAC)
    pad("Convergence", "CONVERGENCE", 0, -218, GOLD)
    gate(0, -266)
    for bearing in (120, 240):
        purple(48 * math.sin(math.radians(bearing)), -255 - 48 * math.cos(math.radians(bearing)))

    forge()
    institute()
    kade()
    ferrymen()
    forge_detail()
    institute_detail()
    kade_detail()
    ferrymen_detail()
    hold_detail()

    points = [(0, 30), (-8, 33), (8, 33), (-16, 37), (16, 37)]
    spawns(points)
    hub.labels.append(("ARRIVAL", 0, 48, "place"))
    people([(-20, -80), (-24, -86), (25, -80), (-5, -215), (7, -213), (-165, -100), (172, -104), (150, 112), (-150, 110), (2, -30), (-80, -40), (90, 70)])

    def approach(centre, distance=68, height=6.0, lift=15):
        ux, uz = ARRIVAL[0] - centre[0], ARRIVAL[1] - centre[1]
        length = math.hypot(ux, uz)
        eye = (centre[0] + ux / length * distance, height, centre[1] + uz / length * distance)
        return eye, (centre[0] - ux / length * 10, lift, centre[1] - uz / length * 10)

    views = [
        ("arrival", "First view on arrival", (0, 5.5, 36), (0, 22, -266), 70),
        ("three_quarter", "From a high corner", (300, 170, 240), (0, -20, -60), 50),
        ("hero", "From above the Convergence pad, looking back over all four islands", (0, 60, -205), (0, -5, 10), 70),
        ("forge", "Crossing the orange bridge to the Forge Union armory", *approach(FORGE_C), 62),
        ("institute", "Crossing the blue bridge to the Coherence Institute kits", *approach(INST_C), 62),
        ("kade", "Crossing the gold bridge to the Kade Dynamics shop", *approach(KADE_C, lift=22), 62),
        ("ferrymen", "Crossing the green bridge to the Ferrymen's Ledger", *approach(FERRY_C), 62),
    ]
    lights = [
        ("AREA", (0, 240, -45), (0.6, 0.7, 1.0), 220000, 600),
        ("AREA", (0, -110, -45), VIOLET, 60000, 520),
        ("POINT", (0, 52, -235), GOLD, 14000, 6),
        ("POINT", (0, 44, -270), VIOLET, 8000, 4),
        ("POINT", (FORGE_C[0], 26, FORGE_C[1]), FORGE, 7000, 6),
        ("POINT", (INST_C[0], 26, INST_C[1]), INSTITUTE, 6500, 6),
        ("POINT", (KADE_C[0], 26, KADE_C[1]), KADE, 6500, 6),
        ("POINT", (FERRY_C[0], 26, FERRY_C[1]), FERRY, 6000, 6),
        ("POINT", (0, 22, 30), (1, 0.9, 0.75), 6000, 8),
        ("POINT", (0, 22, -112), (1, 0.9, 0.75), 6000, 8),
    ]
    return alt.finish("factions", "Faction Islands", extent, points, views, lights)


def main():
    import make_plan

    variant = factions()
    folder = os.path.join(HERE, "alternatives", "factions")
    os.makedirs(folder, exist_ok=True)
    print("==", len(variant.parts), "parts")
    make_plan.main(variant, os.path.join(folder, "plan.svg"))
    for text, x, z, _ in variant.labels:
        if "\n" in text or text in ("PLAY GATE",):
            d = math.hypot(x - ARRIVAL[0], z - ARRIVAL[1])
            print("%-28s %5.0f studs  %4.1f s straight line" % (text.replace("\n", " / "), d, d / hub.WALK_SPEED))


if __name__ == "__main__":
    main()
