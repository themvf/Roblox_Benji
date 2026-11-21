"""Four alternatives to the fifth hub concept (hub_design.py), as data, for comparison.

    python docs/design/lobby-experience/hub-concept/alternatives.py          # plans + distances
    blender -b -noaudio --python docs/design/lobby-experience/hub-concept/render_alternatives.py -- [variant ...]

Concept only; nothing here is read by the game. Same frame, units and building blocks as
hub_design.py, at its final (enlarged) scale. Every variant keeps the same programme: five
arrival spawns, the five queue pads at their gameplay sizes, an ARMORY, a KITS hall, a SHOP,
the leaderboard, and the lobby's own canister, two stone columns and purple columns.

    orbit      the PLAY gate stands in the middle of one big round atrium; pads ring it
    overlook   arrive on a raised terrace and look down over the whole PLAY floor
    boulevard  one straight street: storefronts either side, the gate at the far end
    islands    floating platforms joined by bridges over the dark-matter void
"""

import math
import os
from types import SimpleNamespace

import hub_design as hub
from hub_design import (
    CYAN,
    FLOOR,
    GOLD,
    GREEN,
    GROUND,
    KIT_COLOURS,
    LILAC,
    PLATE,
    PURPLE,
    STEEL,
    STONE,
    VIOLET,
    WALL,
    add,
    box,
    figure,
    group,
    round_wall,
    wall_on_ring,
)

WALL_H = hub.WALL_H
SIGN = 3.1  # letter size of a sign beam, as in the fifth concept
HERE = os.path.dirname(os.path.abspath(__file__))


# ----------------------------------------------------------------- shared pieces


def start():
    hub.parts.clear()
    hub.labels.clear()


def spawns(points, base=0.0):
    for index, (x, z) in enumerate(points):
        add("cyl", "Spawn%d" % (index + 1), (x, base + 0.15, z), (3, 0.15, 3), GOLD, glow=3)


def pad(name, title, x, z, colour, base=0.0, screen=True, facing=0):
    """A queue pad at its gameplay size, its name on the floor, and a count screen behind it."""
    w, d = {"Convergence": (36, 18), "TDM": (24, 24)}.get(name, (18, 22))
    box("Pad" + name, (x, base + 0.2, z), (w, 0.4, d), colour, glow=1.6)
    box("Pad" + name + "Inner", (x, base + 0.26, z), (w - 1.6, 0.42, d - 1.6), PLATE, plan=False)
    hub.labels.append((title, x, z, "pad"))
    if screen:
        nx, nz = math.sin(math.radians(facing)), math.cos(math.radians(facing))
        count = {"Convergence": "0/12", "Duel": "0/1", "TDM": "0/5"}.get(name, "SOLO")
        stand(name, title, count, x - nx * (d / 2 + 4), z - nz * (d / 2 + 4), colour, facing, base)


def stand(name, title, count, x, z, colour, rot, base=0.0):
    """A free-standing screen on two posts: mode name and how many have joined."""
    nx, nz = math.sin(math.radians(rot)), math.cos(math.radians(rot))
    tx, tz = math.cos(math.radians(rot)), -math.sin(math.radians(rot))
    cy = base + 9.5
    box("Screen" + name, (x, cy, z), (18, 8, 0.4), (0.05, 0.06, 0.09), rot=rot, plan=False)
    box("ScreenFrame" + name, (x - nx * 0.15, cy, z - nz * 0.15), (18.8, 8.8, 0.3), colour, glow=3, rot=rot, plan=False)
    for side in (-1, 1):
        box("ScreenPost", (x + tx * side * 8, base + 2.75, z + tz * side * 8), (0.8, 5.5, 0.8), STEEL, plan=False)
    add("text", "Screen" + name + "Title", (x + nx * 0.4, cy + 2.0, z + nz * 0.4), (1.7, 0, 0), colour, glow=7, text=title, rot=rot)
    add("text", "Screen" + name + "Count", (x + nx * 0.4, cy - 1.8, z + nz * 0.4), (2.4, 0, 0), (0.95, 0.96, 1.0), glow=6, text=count, rot=rot)


def gate(gx, gz, rot=0.0, base=0.0):
    """The PLAY gate of the fifth concept (ring, anomaly, pylons) with the two stone columns behind."""
    place = group((gx, gz), rot)
    y = base + 39.2
    place("ring", "GateRing", (0, y, 0), (70, 70, 7), GOLD, glow=9, tube=3.5)
    place("ring", "GateRingInner", (0, y, -2.1), (58.8, 58.8, 3), STEEL, tube=1.54)
    place("sphere", "DarkMatter", (0, y, -2.8), (26.6, 26.6, 26.6), (0.01, 0.005, 0.02))
    place("ring", "Accretion", (0, y, -2.8), (43.4, 43.4, 1.4), VIOLET, glow=14, tube=0.7, tilt=68)
    place("ring", "AccretionOuter", (0, y, -2.8), (51.8, 51.8, 1.4), CYAN, glow=5, tube=0.31, tilt=68)
    place("box", "GateBase", (0, base + 1.4, 0), (81.2, 2.8, 14), STEEL)
    for side in (-1, 1):
        place("box", "GatePylon", (side * 39.2, base + 15.4, 0), (7, 30.8, 9.8), STEEL)
        place("box", "GatePylonGlow", (side * 39.2, base + 15.4, 5.0), (1, 23.8, 0.3), GOLD, glow=7, plan=False)
        place("box", "StoneColumn", (side * 36.4, base + 46, -14), (16, 92, 16), STONE)
    place("text", "GateSign", (0, base + 82.6, 1.4), (15.4, 0, 0), GOLD, glow=10, text="PLAY")
    hub.labels.append(("PLAY GATE", gx, gz + 16, "place"))


def hall(name, title, centre, rot, width, depth, opening, accent, base=0.0):
    """A hall whose front (local +z) is open across `opening`, with a sign beam over it.
    Returns a placer in the hall's own frame: x across the front, -z towards the back wall."""
    place = group(centre, rot)
    if base > 0:
        place("box", name + "Plinth", (0, base / 2, 0), (width, base, depth), FLOOR)
    place("box", name + "Floor", (0, base + 0.05, 0), (width, 0.1, depth), PLATE)
    place("box", name + "WallBack", (0, base + WALL_H / 2, -depth / 2), (width, WALL_H, 1.6), WALL)
    piece = (width - opening) / 2
    for side in (-1, 1):
        place("box", name + "WallSide", (side * width / 2, base + WALL_H / 2, 0), (1.6, WALL_H, depth), WALL)
        if piece > 0.5:
            place("box", name + "WallFront", (side * (opening / 2 + piece / 2), base + WALL_H / 2, depth / 2), (piece, WALL_H, 1.6), WALL)
    place("box", name + "TopGlow", (0, base + WALL_H - 0.4, -depth / 2 + 1.2), (width - 4, 0.4, 0.4), accent, glow=6, plan=False)
    place("box", name + "Beam", (0, base + WALL_H + 1.5, depth / 2), (opening + 4, 3, 2), STEEL)
    place("box", name + "BeamGlow", (0, base + WALL_H - 0.2, depth / 2 + 1.2), (opening, 0.4, 0.4), accent, glow=8, plan=False)
    place("text", name + "Sign", (0, base + WALL_H + 1.5, depth / 2 + 1.2), (SIGN, 0, 0), accent, glow=9, text=title)
    hub.labels.append((title, centre[0], centre[1], "place"))
    return place


def armory(place, width, depth, base=0.0, range_door=True):
    place("box", "ArmoryCounter", (0, base + 1.75, 4), (30, 3.5, 6), STEEL)
    place("box", "ArmoryCounterGlow", (0, base + 3.55, 4), (29, 0.12, 5.4), GOLD, glow=1.5, plan=False)
    back = -depth / 2 + 1.2
    for slot in range(8):
        x, y = -24.5 + slot * 7, base + 6 + (slot % 2) * 4
        place("box", "RackGun%d" % slot, (x, y, back), (6, 1.4, 0.6), (0.6, 0.62, 0.66), plan=False)
        place("box", "RackLight%d" % slot, (x, y - 2.2, back + 0.1), (6, 0.2, 0.3), GOLD, glow=4, plan=False)
    if range_door:
        side = -width / 2 + 1
        place("box", "RangeDoor", (side, base + 6.5, -8), (1, 11, 20), STEEL)
        place("box", "RangeDoorGlow", (side + 0.6, base + 6.5, -8), (0.2, 9, 18), LILAC, glow=0.6, plan=False)
        place("text", "RangeSign", (side + 0.8, base + 13.4, -8), (1.8, 0, 0), LILAC, glow=6, text="PRACTICE RANGE", rot=90)


def kits(place, depth, base=0.0):
    for slot in range(4):
        x, z = -24 + slot * 16, -depth / 2 + 12
        colour = KIT_COLOURS[slot]
        place("cyl", "KitPlinth%d" % slot, (x, base + 1, z), (10, 2, 10), STEEL)
        place("ring", "KitRing%d" % slot, (x, base + 2.1, z), (10, 0.3, 10), colour, glow=7, tube=0.3, flat=True, plan=False)
        figure(place, "Kit%d" % slot, x, z, base + 2, 10, tuple(c * 0.55 for c in colour))
        place("box", "KitBackGlow%d" % slot, (x, base + 7, -depth / 2 + 1.2), (7, 11, 0.3), colour, glow=2.2, plan=False)


def shop(place, depth, base=0.0):
    place("box", "ShopCounter", (0, base + 2, -depth / 2 + 16), (30, 4, 6), STEEL)
    for index, x in enumerate((-20, 0, 20)):
        place("box", "ShopScreen%d" % index, (x, base + 7.5, -depth / 2 + 0.6), (15, 11, 0.6), STEEL, plan=False)
        glow = (0.62, 0.42, 0.18) if index != 1 else (0.5, 0.25, 0.6)
        place("box", "ShopScreenGlow%d" % index, (x, base + 7.5, -depth / 2 + 1.0), (14, 10, 0.2), glow, glow=2.2, plan=False)


def leaderboard(x, z, rot, base=0.0):
    nx, nz = math.sin(math.radians(rot)), math.cos(math.radians(rot))
    box("Leaderboard", (x, base + 7.5, z), (24, 11, 0.6), STEEL, rot=rot)
    box("LeaderboardGlow", (x + nx * 0.4, base + 7.5, z + nz * 0.4), (22.5, 9.5, 0.2), (0.3, 0.42, 0.6), glow=1.5, rot=rot, plan=False)
    hub.labels.append(("LEADERBOARD", x, z + nz * 8, "place"))


def canister(x, z, base=0.0):
    add("cyl", "Canister", (x, base + 15.5, z), (16, 31, 16), (0.2, 0.45, 0.7), glow=1.2)
    add("ring", "CanisterBand", (x, base + 6, z), (17.5, 1, 17.5), STEEL, tube=0.8, flat=True, plan=False)
    add("ring", "CanisterBandTop", (x, base + 26, z), (17.5, 1, 17.5), STEEL, tube=0.8, flat=True, plan=False)


def purple(x, z, base=0.0):
    box("PurpleColumn", (x, base + 20.5, z), (8, 41, 8), PURPLE)


def people(points):
    world = group((0, 0), 0)
    for index, point in enumerate(points):
        x, z, base = point if len(point) == 3 else (*point, 0.0)
        figure(world, "Player%d" % index, x, z, base + 0.1, 5.2, (0.75, 0.77, 0.82))


def passage(name, cx, cz, radius, bearing, half, reach):
    """Floor and walls from a round wall's opening out to `reach` from its centre."""
    mouth = math.sqrt(radius**2 - half**2)
    place = group((cx, cz), -bearing)
    length = reach - mouth
    place("box", name + "PassageFloor", (0, 0.05, -(mouth + reach) / 2), (half * 2, 0.1, length + 2), FLOOR)
    for side in (-1, 1):
        place("box", name + "PassageWall", (side * half, WALL_H / 2, -(mouth + reach) / 2), (1.6, WALL_H, length), WALL)


def ring_sign(name, cx, cz, radius, bearing, half, text, colour):
    """A sign beam across an opening in a round wall, lettered towards the centre."""
    place = group((cx, cz), -bearing)
    place("box", name + "Beam", (0, WALL_H + 1.5, -radius), (half * 2 + 4, 3, 2), STEEL)
    place("box", name + "BeamGlow", (0, WALL_H - 0.2, -radius + 1.2), (half * 2, 0.4, 0.4), colour, glow=8, plan=False)
    place("text", name + "Sign", (0, WALL_H + 1.5, -radius + 1.2), (SIGN, 0, 0), colour, glow=9, text=text)


def blade(name, text, x, z, colour, y=19.0, rot=0.0):
    """A sign board on a post, lettered on the side facing `rot` (0 = towards arrival)."""
    nx, nz = math.sin(math.radians(rot)), math.cos(math.radians(rot))
    box(name + "Blade", (x, y, z), (17, 7, 1), STEEL, rot=rot, plan=False)
    box(name + "BladeGlow", (x, y - 3.7, z), (16, 0.4, 1.2), colour, glow=7, rot=rot, plan=False)
    add("text", name + "BladeText", (x + nx * 0.7, y, z + nz * 0.7), (3.0, 0, 0), colour, glow=9, text=text, rot=rot)


def finish(key, title, hall_extent, spawn_points, views, lights):
    zc = (hall_extent["north"] + hall_extent["south"]) / 2
    t = math.tan(math.radians(28))
    height = max((hall_extent["south"] - hall_extent["north"]) / 2 / t, hall_extent["x"] / (t * 16 / 9)) * 1.12
    views = [("aerial", "From above", (0, height, zc + height * 0.12), (0, 0, zc - height * 0.02), 56)] + views
    return SimpleNamespace(
        key=key,
        title=title,
        parts=[dict(p) for p in hub.parts],
        labels=list(hub.labels),
        SPAWN=spawn_points[0],
        SPAWNS=spawn_points,
        HALL=hall_extent,
        WALK_SPEED=hub.WALK_SPEED,
        VIEWS=views,
        LIGHTS=lights,
    )


# ----------------------------------------------------------------- A: orbit


def orbit():
    """The gate stands on a dais in the middle of one big round atrium. The pads ring the dais,
    the halls open off the atrium wall east and west, the shop is behind the arrival point."""
    start()
    cx, cz, radius = 0.0, -70.0, 110.0
    extent = {"x": 220, "north": -195, "south": 130}
    box("Floor", (0, -1.2, (extent["north"] + extent["south"]) / 2), (extent["x"] * 2, 2, extent["south"] - extent["north"]), GROUND)
    add("cyl", "AtriumFloor", (cx, 0.05, cz), (radius * 2, 0.1, radius * 2), FLOOR)
    round_wall("AtriumWall", cx, cz, radius, [(90, 30), (270, 30), (180, 24)], segments=96)
    add("cyl", "Dais", (cx, 0.6, cz), (64, 1.2, 64), PLATE)
    add("ring", "DaisRing", (cx, 1.25, cz), (64, 0.2, 64), GOLD, glow=2.5, tube=0.4, flat=True)
    gate(cx, cz, 0, base=1.2)
    for bearing in (30, 90, 150, 210, 270, 330):
        purple(cx + 54 * math.sin(math.radians(bearing)), cz - 54 * math.cos(math.radians(bearing)))
    purple(-34, 24)
    purple(34, 24)

    pad("Convergence", "CONVERGENCE", 0, -28, GOLD)
    for name, title, bearing, colour in (
        ("Duel", "DUEL 1V1", 235, GREEN),
        ("TDM", "TEAM DEATHMATCH", 125, GOLD),
        ("TrainingObjective", "TRAINING", 305, LILAC),
        ("TrainingTDM", "TRAINING TDM", 55, LILAC),
    ):
        pad(name, title, cx + 78 * math.sin(math.radians(bearing)), cz - 78 * math.cos(math.radians(bearing)), colour)

    for side, title, accent, contents in ((-1, "ARMORY", GOLD, "armory"), (1, "KITS", VIOLET, "kits")):
        bearing = 90 if side > 0 else 270
        passage(title, cx, cz, radius, bearing, 30, radius + 12)
        ring_sign(title, cx, cz, radius, bearing, 30, title, accent)
        place = hall(title, title, (side * (radius + 12 + 45), cz), -90 * side, 90, 90, 60, accent)
        armory(place, 90, 90) if contents == "armory" else kits(place, 90)
    passage("Shop", cx, cz, radius, 180, 24, radius + 12)
    ring_sign("Shop", cx, cz, radius, 180, 24, "SHOP", GOLD)
    shop(hall("Shop", "SHOP", (0, cz + radius + 12 + 35), 180, 80, 70, 48, GOLD), 70)
    lx, lz, lrot = wall_on_ring(cx, cz, radius, 145, 0.8)
    leaderboard(lx, lz, lrot)
    canister(-48, 5)
    hub.labels.append(("SEASON\nDISPLAY", -48, 5, "place"))

    points = [(0, 20), (-8, 23), (8, 23), (-16, 27), (16, 27)]
    spawns(points)
    hub.labels.append(("ARRIVAL", 0, 34, "place"))
    people([(-60, -20), (-56, -30), (66, -22), (70, -32), (-8, -26), (6, -30), (-150, -60), (160, -80), (4, 80), (60, -112)])
    views = [
        ("arrival", "First view on arrival", (0, 5.5, 24), (0, 38, -70), 70),
        ("three_quarter", "From a high corner", (235, 165, 150), (0, 0, -60), 50),
        ("hero", "From beside the TDM pad, across the dais", (88, 5.5, -10), (-40, 20, -100), 70),
    ]
    lights = [
        ("AREA", (0, 220, -40), (0.6, 0.7, 1.0), 200000, 480),
        ("POINT", (0, 52, -50), GOLD, 14000, 6),
        ("POINT", (0, 44, -76), VIOLET, 8000, 4),
        ("POINT", (-165, 18, -70), GOLD, 5000, 6),
        ("POINT", (165, 18, -70), VIOLET, 5500, 6),
        ("POINT", (0, 22, 10), (1, 0.9, 0.75), 6000, 8),
        ("POINT", (0, 18, 90), GOLD, 4000, 6),
    ]
    return finish("orbit", "Orbit", extent, points, views, lights)


# ----------------------------------------------------------------- B: overlook


def overlook():
    """Arrive on a terrace 12 studs up and look down over the whole PLAY floor: every pad and
    the gate in one view. A grand stair leads down; the halls sit on the terrace wings."""
    start()
    half, top = 120.0, 12.0
    extent = {"x": 215, "north": -245, "south": 150}
    box("Floor", (0, -1.2, (extent["north"] + extent["south"]) / 2), (extent["x"] * 2, 2, extent["south"] - extent["north"]), GROUND)
    box("ArenaFloor", (0, 0.04, -110), (half * 2, 0.1, 240), FLOOR)
    box("TerraceFloor", (0, top / 2, 40), (half * 2, top, 60), FLOOR)
    for x, width in ((0, 60), (-95, 30), (95, 30)):
        for step in range(11):
            height = top - 1 - step
            box("Stair", (x, height / 2, 10 - 1.5 - 3 * step), (width, height, 3), FLOOR if step % 2 else (0.2, 0.216, 0.255))
    for a, b in ((-120, -110), (-80, -30), (30, 80), (110, 120)):
        box("Balustrade", ((a + b) / 2, top + 1.5, 10), (b - a, 3, 1), STEEL)
        box("BalustradeGlow", ((a + b) / 2, top + 3.1, 10), (b - a, 0.3, 1.2), GOLD, glow=4, plan=False)
    tall = 26.0
    for side in (-1, 1):
        box("ArenaWall", (side * half, tall / 2, -110), (1.6, tall, 240), WALL)
        box("TerraceWallSouth", (side * 72, tall / 2, 70), (96, tall, 1.6), WALL)
    box("ArenaWallNorth", (0, tall / 2, -230), (half * 2, tall, 1.6), WALL)

    gate(0, -205)
    pad("Convergence", "CONVERGENCE", 0, -162, GOLD)
    pad("Duel", "DUEL 1V1", -60, -70, GREEN)
    pad("TDM", "TEAM DEATHMATCH", 60, -70, GOLD)
    pad("TrainingObjective", "TRAINING", -60, -125, LILAC)
    pad("TrainingTDM", "TRAINING TDM", 60, -125, LILAC)
    for x, z in ((-100, -40), (100, -40), (-100, -160), (100, -160), (-28, -110), (28, -110), (-70, -205), (70, -205)):
        purple(x, z)

    for side, title, accent in ((-1, "ARMORY", GOLD), (1, "KITS", VIOLET)):
        place = hall(title, title, (side * (half + 45), 40), -90 * side, 90, 90, 40, accent, base=top)
        armory(place, 90, 90, top) if side < 0 else kits(place, 90, top)
    shop(hall("Shop", "SHOP", (0, 105), 180, 80, 70, 48, GOLD, base=top), 70, top)
    leaderboard(75, 68.5, 180, top)
    canister(-75, 45, top)
    hub.labels.append(("SEASON\nDISPLAY", -75, 45, "place"))
    hub.labels.append(("TERRACE", 0, 60, "place"))

    points = [(0, 24), (-8, 27), (8, 27), (-16, 31), (16, 31)]
    spawns(points, top)
    people([(-60, -55), (-55, -62), (62, -56), (-5, -160), (6, -158), (-6, 0), (20, 30, top), (-150, 40, top), (150, 30, top), (2, 100, top), (30, -20)])
    views = [
        ("arrival", "First view on arrival, from the terrace", (0, top + 5.5, 28), (0, 2, -150), 70),
        ("three_quarter", "From a high corner", (230, 170, 170), (0, 0, -60), 50),
        ("hero", "From the foot of the stairs, looking back up at the terrace", (-30, 6, -48), (0, 15, 40), 70),
    ]
    lights = [
        ("AREA", (0, 220, -50), (0.6, 0.7, 1.0), 200000, 480),
        ("POINT", (0, 52, -185), GOLD, 14000, 6),
        ("POINT", (0, 44, -208), VIOLET, 8000, 4),
        ("POINT", (-165, 30, 40), GOLD, 5000, 6),
        ("POINT", (165, 30, 40), VIOLET, 5500, 6),
        ("POINT", (0, 34, 40), (1, 0.9, 0.75), 6000, 8),
        ("POINT", (0, 22, -80), (1, 0.9, 0.75), 6000, 8),
        ("POINT", (0, 30, 100), GOLD, 4000, 6),
    ]
    return finish("overlook", "Overlook", extent, points, views, lights)


# ----------------------------------------------------------------- C: boulevard


def boulevard():
    """One straight street from the arrival point to the gate court. The halls are open
    storefronts either side with blade signs that face the arrival point."""
    start()
    half = 45.0
    extent = {"x": 125, "north": -300, "south": 80}
    box("Floor", (0, -1.2, (extent["north"] + extent["south"]) / 2), (extent["x"] * 2, 2, extent["south"] - extent["north"]), GROUND)
    box("StreetFloor", (0, 0.04, -60), (half * 2, 0.1, 262), FLOOR)
    box("StreetWallSouth", (0, WALL_H / 2, 70), (half * 2, WALL_H, 1.6), WALL)
    box("StreetMural", (0, 7.5, 68.8), (40, 10, 0.3), (0.3, 0.2, 0.55), glow=2, plan=False)
    for side in (-1, 1):
        for a, b in ((25, 70), (-90, -45), (-190, -160)):
            box("StreetWall", (side * half, WALL_H / 2, (a + b) / 2), (1.6, WALL_H, b - a), WALL)
        box("StreetEdge", (side * 10, 0.12, -70), (0.5, 0.1, 230), GOLD, glow=6)
    # the gate court at the far end
    box("CourtFloor", (0, 0.05, -240), (180, 0.1, 100), FLOOR)
    box("CourtWallNorth", (0, 10, -290), (180, 20, 1.6), WALL)
    for side in (-1, 1):
        box("CourtWall", (side * 90, 10, -240), (1.6, 20, 100), WALL)
        box("CourtWallShoulder", (side * 67.5, 10, -190), (45, 20, 1.6), WALL)
    gate(0, -262)
    pad("Convergence", "CONVERGENCE", 0, -222, GOLD)
    pad("Duel", "DUEL 1V1", -22, -67, GREEN)
    pad("TDM", "TEAM DEATHMATCH", 22, -67, GOLD)
    pad("TrainingObjective", "TRAINING", -22, -175, LILAC)
    pad("TrainingTDM", "TRAINING TDM", 22, -175, LILAC)
    for x, z in ((-40, 45), (40, 45), (-40, -110), (40, -110), (-40, -145), (40, -145), (-80, -205), (80, -205)):
        purple(x, z)

    stores = [
        ("ARMORY", -1, -10, GOLD),
        ("KITS", 1, -10, VIOLET),
        ("SHOP", -1, -125, GOLD),
        ("HALL OF FAME", 1, -125, CYAN),
    ]
    for title, side, z, accent in stores:
        name = title.title().replace(" ", "")
        place = hall(name, title, (side * (half + 35), z), -90 * side, 70, 70, 56, accent)
        if title == "ARMORY":
            armory(place, 70, 70, range_door=False)
        elif title == "KITS":
            kits(place, 70)
        elif title == "SHOP":
            shop(place, 70)
        blade(name, title, side * (half - 9), z + 31, accent)
    leaderboard(half + 69, -125, -90)
    canister(half + 35, -125)
    hub.labels.append(("PRACTICE RANGE\n(later)", -100, 30, "place"))

    points = [(0, 40), (-8, 43), (8, 43), (-16, 47), (16, 47)]
    spawns(points)
    hub.labels.append(("ARRIVAL", 0, 56, "place"))
    people([(-20, -52), (-25, -58), (24, -50), (-4, -222), (8, -220), (-70, -12), (75, 0), (-70, -120), (6, 10), (-30, -170)])
    views = [
        ("arrival", "First view on arrival", (0, 5.5, 46), (0, 30, -262), 70),
        ("three_quarter", "From a high corner", (210, 150, 130), (0, 0, -110), 52),
        ("hero", "Halfway down the street, between the storefronts", (-12, 5.5, -95), (34, 10, -140), 70),
    ]
    lights = [
        ("AREA", (0, 220, -110), (0.6, 0.7, 1.0), 200000, 480),
        ("POINT", (0, 52, -240), GOLD, 14000, 6),
        ("POINT", (0, 44, -265), VIOLET, 8000, 4),
        ("POINT", (-80, 18, -10), GOLD, 5000, 6),
        ("POINT", (80, 18, -10), VIOLET, 5500, 6),
        ("POINT", (-80, 18, -125), GOLD, 4000, 6),
        ("POINT", (80, 18, -125), CYAN, 4000, 6),
        ("POINT", (0, 22, 30), (1, 0.9, 0.75), 6000, 8),
        ("POINT", (0, 22, -120), (1, 0.9, 0.75), 6000, 8),
    ]
    return finish("boulevard", "Boulevard", extent, points, views, lights)


# ----------------------------------------------------------------- D: islands


def bearing_to(a, b):
    return math.degrees(math.atan2(b[0] - a[0], -(b[1] - a[1]))) % 360


def island(name, centre, radius, openings):
    cx, cz = centre
    add("cyl", name, (cx, -3, cz), (radius * 2, 6, radius * 2), FLOOR)
    add("cyl", name + "Under", (cx, -10, cz), (radius * 1.5, 8, radius * 1.5), PLATE, plan=False)
    add("cyl", name + "Under2", (cx, -19, cz), (radius * 0.8, 10, radius * 0.8), PLATE, plan=False)
    add("cyl", name + "Core", (cx, -26, cz), (radius * 0.35, 6, radius * 0.35), VIOLET, glow=3, plan=False)
    add("ring", name + "Trim", (cx, 0.12, cz), (radius * 2 - 1.2, 0.2, radius * 2 - 1.2), CYAN, glow=2.5, tube=0.35, flat=True, plan=False)
    segments = 64
    length = 2 * math.pi * (radius - 0.6) / segments + 0.2
    for index in range(segments):
        theta = index * 360 / segments
        if any(abs((theta - b + 180) % 360 - 180) < math.degrees(math.asin(14 / radius)) for b in openings):
            continue
        x, z = cx + (radius - 0.6) * math.sin(math.radians(theta)), cz - (radius - 0.6) * math.cos(math.radians(theta))
        box("Rail", (x, 1.6, z), (length, 3.2, 0.5), STEEL, rot=-theta)
        box("RailGlow", (x, 3.3, z), (length, 0.3, 0.7), CYAN, glow=3, rot=-theta, plan=False)


def bridge(name, a, ra, b, rb, width=24):
    dx, dz = b[0] - a[0], b[1] - a[1]
    distance = math.hypot(dx, dz)
    ux, uz = dx / distance, dz / distance
    s = (a[0] + ux * (ra - 4), a[1] + uz * (ra - 4))
    e = (b[0] - ux * (rb - 4), b[1] - uz * (rb - 4))
    length = math.hypot(e[0] - s[0], e[1] - s[1])
    mx, mz = (s[0] + e[0]) / 2, (s[1] + e[1]) / 2
    rot = math.degrees(math.atan2(dx, dz))
    box(name, (mx, -1, mz), (width, 2, length), FLOOR, rot=rot)
    box(name + "Under", (mx, -3.5, mz), (width - 6, 3, length - 4), PLATE, rot=rot, plan=False)
    tx, tz = math.cos(math.radians(rot)), -math.sin(math.radians(rot))
    for side in (-1, 1):
        ox, oz = tx * side * (width / 2 - 0.3), tz * side * (width / 2 - 0.3)
        box(name + "Rail", (mx + ox, 1.6, mz + oz), (0.5, 3.2, length - 8), STEEL, rot=rot)
        box(name + "RailGlow", (mx + ox, 3.3, mz + oz), (0.7, 0.3, length - 8), CYAN, glow=3, rot=rot, plan=False)


def islands():
    """Floating platforms over the dark-matter void, joined by railed bridges. The arrival
    island looks straight up the bridges to the pad island and the gate island beyond it."""
    start()
    extent = {"x": 230, "north": -320, "south": 230}
    box("Floor", (0, -140, (extent["north"] + extent["south"]) / 2), (extent["x"] * 2, 2, extent["south"] - extent["north"]), (0.02, 0.015, 0.04))
    add("cyl", "Void", (0, -138, -45), (4000, 0.5, 4000), (0.12, 0.07, 0.25), glow=0.08, plan=False)
    arrival, pads_c, gate_c = (0.0, 30.0), (0.0, -112.0), (0.0, -255.0)
    armory_c, kits_c, shop_c = (-175.0, 20.0), (175.0, 20.0), (0.0, 180.0)
    radii = {arrival: 45, pads_c: 60, gate_c: 58, armory_c: 46, kits_c: 46, shop_c: 40}
    links = [(arrival, pads_c), (pads_c, gate_c), (arrival, armory_c), (arrival, kits_c), (arrival, shop_c)]
    for centre, radius in radii.items():
        openings = [bearing_to(centre, b if a == centre else a) for a, b in links if centre in (a, b)]
        island("Island", centre, radius, openings)
    for index, (a, b) in enumerate(links):
        bridge("Bridge%d" % index, a, radii[a], b, radii[b])

    # arrival island
    add("ring", "ArrivalRing", (0, 0.15, 30), (24, 0.2, 24), GOLD, glow=2.5, tube=0.3, flat=True)
    canister(-30, 38)
    hub.labels.append(("SEASON\nDISPLAY", -30, 38, "place"))
    purple(-25.5, 55.5)
    purple(25.5, 55.5)
    # pad island
    pad("Duel", "DUEL 1V1", -22, -92, GREEN)
    pad("TDM", "TEAM DEATHMATCH", 22, -92, GOLD)
    pad("TrainingObjective", "TRAINING", -22, -134, LILAC)
    pad("TrainingTDM", "TRAINING TDM", 22, -134, LILAC)
    for bearing in (45, 135, 225, 315):
        purple(52 * math.sin(math.radians(bearing)), -112 - 52 * math.cos(math.radians(bearing)))
    # gate island
    pad("Convergence", "CONVERGENCE", 0, -218, GOLD)
    gate(0, -266)
    for bearing in (120, 240):
        purple(48 * math.sin(math.radians(bearing)), -255 - 48 * math.cos(math.radians(bearing)))
    # destination islands: a back wall, the contents and a sign, all facing the arrival island
    for title, centre, accent in (("ARMORY", armory_c, GOLD), ("KITS", kits_c, VIOLET), ("SHOP", shop_c, GOLD)):
        rot = (180 - bearing_to(centre, arrival)) % 360  # local +z points at the arrival island
        place = group(centre, rot)
        place("box", title + "WallBack", (0, WALL_H / 2, -26), (64, WALL_H, 1.6), WALL)
        place("box", title + "TopGlow", (0, WALL_H - 0.4, -24.8), (60, 0.4, 0.4), accent, glow=6, plan=False)
        place("box", title + "Beam", (0, WALL_H + 5, -26), (40, 6, 2), STEEL)
        place("text", title + "Sign", (0, WALL_H + 5, -24.8), (4.2, 0, 0), accent, glow=9, text=title)
        hub.labels.append((title, centre[0], centre[1], "place"))
        if title == "ARMORY":
            armory(place, 64, 54, range_door=False)
        elif title == "KITS":
            kits(place, 50)
        else:
            shop(place, 54)
    lrot = (180 - bearing_to(shop_c, arrival)) % 360
    leaderboard(28, 164, lrot - 35)
    bridge("RangeStub", armory_c, 46, (-175.0, -110.0), 40)
    hub.labels.append(("PRACTICE RANGE\n(later)", -175, -75, "place"))

    points = [(0, 30), (-8, 33), (8, 33), (-16, 37), (16, 37)]
    spawns(points)
    hub.labels.append(("ARRIVAL", 0, 48, "place"))
    people([(-20, -80), (-24, -86), (25, -80), (-5, -215), (7, -213), (-170, 30), (168, 18), (4, 170), (2, -30), (-60, 26)])
    views = [
        ("arrival", "First view on arrival", (0, 5.5, 36), (0, 26, -266), 70),
        ("three_quarter", "From a high corner", (270, 150, 220), (0, -20, -60), 50),
        ("hero", "On the bridge to the pad island", (-6, 5.5, -30), (4, 18, -200), 70),
    ]
    lights = [
        ("AREA", (0, 240, -45), (0.6, 0.7, 1.0), 220000, 560),
        ("AREA", (0, -110, -45), VIOLET, 60000, 500),
        ("POINT", (0, 52, -235), GOLD, 14000, 6),
        ("POINT", (0, 44, -270), VIOLET, 8000, 4),
        ("POINT", (-175, 22, 20), GOLD, 5000, 6),
        ("POINT", (175, 22, 20), VIOLET, 5500, 6),
        ("POINT", (0, 22, 30), (1, 0.9, 0.75), 6000, 8),
        ("POINT", (0, 22, -112), (1, 0.9, 0.75), 6000, 8),
        ("POINT", (0, 22, 180), GOLD, 4000, 6),
    ]
    return finish("islands", "Islands", extent, points, views, lights)


VARIANTS = {"orbit": orbit, "overlook": overlook, "boulevard": boulevard, "islands": islands}


def main():
    import make_plan

    for key, build in VARIANTS.items():
        variant = build()
        folder = os.path.join(HERE, "alternatives", key)
        os.makedirs(folder, exist_ok=True)
        print("==", key, len(variant.parts), "parts")
        make_plan.main(variant, os.path.join(folder, "plan.svg"))


if __name__ == "__main__":
    main()
