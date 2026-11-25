"""Proposed walk-in hub, as data. One source for the plan drawing and the blockout renders.

    python docs/design/lobby-experience/hub-concept/make_plan.py
    blender -b -noaudio --python docs/design/lobby-experience/hub-concept/render_hero.py
    python docs/design/lobby-experience/hub-concept/build_page.py

Concept only. Units are studs in the lobby's own frame (x right, y up, z towards the player's
back; the player arrives facing -z). Nothing here is read by the game.

Third version: a plaza with rooms off it, the structure RIVALS uses (fan-wiki screenshots,
August 2026). The player arrives in a small round plaza. Straight ahead a corridor lined with
mode pads leads to the PLAY gate; the ARMORY and KITS rooms open left and right; the SHOP is
behind. Each place is its own room, so none of them needs empty floor around it.

Fourth version: the same structure opened up after the third felt narrow. The avenue is 80
studs wide instead of 44, the plaza 116 across instead of 72, the halls 64 square with fully
open fronts, and the walls 14 studs tall instead of 26, so they read as edges, not a tunnel.

Fifth version: the whole floor plan scaled up by SCALE (1.4) after the fourth still felt small.
Distances, rooms, openings and the gate grow; wall height, queue pad sizes and props do not.
"""

import math

GOLD = (1.0, 0.77, 0.27)
VIOLET = (0.55, 0.32, 1.0)
CYAN = (0.35, 0.78, 1.0)
GREEN = (0.47, 0.78, 0.63)
LILAC = (0.67, 0.55, 0.92)
GROUND = (0.07, 0.075, 0.09)
FLOOR = (0.18, 0.196, 0.235)
PLATE = (0.133, 0.145, 0.176)
WALL = (0.17, 0.185, 0.225)
STEEL = (0.25, 0.275, 0.33)
STONE = (0.42, 0.41, 0.40)
PURPLE = (0.31, 0.21, 0.38)
KIT_COLOURS = [(1.0, 0.47, 0.16), CYAN, GOLD, (0.35, 0.9, 0.5)]

PLAZA_R = 58
SPAWN = (0.0, 30.0)  # x, z of the arrival point
SPAWNS = [(0, 28), (-9, 30), (9, 30), (-17, 33), (17, 33)]
GATE = (0.0, -152.0)
CHAMBER = (0.0, -118.0, 50)  # x, z, radius of the gate court
HALF_CORRIDOR = 40  # the PLAY avenue is 80 studs wide
ROOM = 64  # armory and kits halls are square
SIDE_OPEN = 24  # half-width of the plaza's side openings and the halls' open fronts
HALL = {"x": 145, "north": -185, "south": 132, "height": 14}  # extent of the drawing
WALK_SPEED = 16.0  # studs per second, Roblox default
SCALE = 1.4  # layout scale applied after build(); see enlarge()
WALL_H = 14  # low walls: a standing player (5 studs) sees sky and the landmarks over them

parts = []
labels = []  # plan annotations: (text, x, z, kind)


def rotate(x, z, degrees):
    a = math.radians(degrees)
    return x * math.cos(a) + z * math.sin(a), -x * math.sin(a) + z * math.cos(a)


def add(kind, name, pos, size, colour, glow=0.0, rot=0.0, plan=True, **extra):
    part = {"kind": kind, "name": name, "pos": list(pos), "size": list(size), "colour": colour, "glow": glow, "rot": rot, "plan": plan}
    part.update(extra)
    parts.append(part)
    return part


def box(name, pos, size, colour, glow=0.0, rot=0.0, plan=True):
    return add("box", name, pos, size, colour, glow, rot, plan)


def group(origin, degrees):
    """Place parts in a frame at `origin` (x, z) turned `degrees` about the vertical."""

    def place(kind, name, pos, size, colour, glow=0.0, rot=0.0, plan=True, **extra):
        x, z = rotate(pos[0], pos[2], degrees)
        return add(kind, name, (origin[0] + x, pos[1], origin[1] + z), size, colour, glow, rot + degrees, plan, **extra)

    return place


def figure(place, name, x, z, base, height, colour, glow=0.0):
    """A stand-in person: a body and a head, `height` studs tall."""
    body = height * 0.78
    place("cyl", name + "Body", (x, base + body / 2, z), (height * 0.34, body, height * 0.34), colour, glow, plan=False)
    place("sphere", name + "Head", (x, base + body + height * 0.11, z), (height * 0.24,) * 3, colour, glow, plan=False)


def round_wall(name, cx, cz, radius, openings, height=WALL_H, segments=72):
    """A circular wall with gaps. openings: list of (bearing in degrees, half-width in studs);
    bearing 0 is north (-z), 90 is east (+x)."""
    gaps = [(bearing, math.degrees(math.asin(min(1, half / radius)))) for bearing, half in openings]
    step = 360 / segments
    length = 2 * math.pi * radius / segments + 0.4
    for index in range(segments):
        theta = index * step
        # cut only segments centred inside an opening, so the ring meets the walls beside it
        if any(abs((theta - b + 180) % 360 - 180) < g for b, g in gaps):
            continue
        x, z = cx + radius * math.sin(math.radians(theta)), cz - radius * math.cos(math.radians(theta))
        box(name, (x, height / 2, z), (length, height, 1.6), WALL, rot=-theta)


def wall_on_ring(cx, cz, radius, bearing, inset=1.0):
    """Point on the inside face of a round wall, and the rotation that faces the centre."""
    r = radius - inset
    return cx + r * math.sin(math.radians(bearing)), cz - r * math.cos(math.radians(bearing)), -bearing


def gantry(name, cx, cz, radius, bearing, half, text, colour):
    """A sign beam across an opening in a round wall, lettered on the side facing the centre."""
    x, z = cx + radius * math.sin(math.radians(bearing)), cz - radius * math.cos(math.radians(bearing))
    box(name + "Beam", (x, WALL_H + 1.5, z), (half * 2 + 4, 3, 2), STEEL, rot=-bearing)
    ix, iz, rot = wall_on_ring(cx, cz, radius, bearing, 1.2)
    box(name + "BeamGlow", (ix, WALL_H - 0.2, iz), (half * 2, 0.4, 0.4), colour, glow=8, rot=rot, plan=False)
    add("text", name + "Sign", (ix, WALL_H + 1.5, iz), (2.2, 0, 0), colour, glow=9, text=text, rot=rot)


def room(name, centre, size, door_side, accent, opening):
    """A square hall whose side facing the plaza is open across `opening` studs."""
    cx, cz = centre
    half = size / 2
    box(name + "Floor", (cx, 0.05, cz), (size, 0.1, size), PLATE)
    box(name + "WallN", (cx, WALL_H / 2, cz - half), (size, WALL_H, 1.6), WALL)
    box(name + "WallS", (cx, WALL_H / 2, cz + half), (size, WALL_H, 1.6), WALL)
    far, near = (cx - half, cx + half) if door_side == "east" else (cx + half, cx - half)
    box(name + "WallFar", (far, WALL_H / 2, cz), (1.6, WALL_H, size), WALL)
    piece = (size - opening) / 2
    for side in (-1, 1):
        box(name + "WallFront", (near, WALL_H / 2, cz + side * (opening / 2 + piece / 2)), (1.6, WALL_H, piece), WALL)
    box(name + "TopGlow", (far + (1 if door_side == "east" else -1), WALL_H - 0.4, cz), (0.4, 0.4, size - 4), accent, glow=6, plan=False)
    return far


def build():
    parts.clear()
    labels.clear()
    hx, north, south = HALL["x"], HALL["north"], HALL["south"]
    box("Floor", (0, -1.2, (north + south) / 2), (hx * 2, 2, south - north), GROUND)

    # ----- the plaza: a wide round court, every destination leads off it
    add("cyl", "PlazaFloor", (0, 0.05, 0), (PLAZA_R * 2, 0.1, PLAZA_R * 2), FLOOR)
    round_wall("PlazaWall", 0, 0, PLAZA_R, [(0, HALF_CORRIDOR), (90, SIDE_OPEN), (270, SIDE_OPEN), (180, 20)])
    add("cyl", "Centrepiece", (0, 0.3, 0), (24, 0.6, 24), PLATE)
    add("ring", "CentreRing", (0, 0.65, 0), (24, 0.2, 24), GOLD, glow=2.5, tube=0.3, flat=True)
    add("cyl", "CentreInlay", (0, 0.62, 0), (14, 0.05, 14), VIOLET, glow=1.2, plan=False)
    for index, (x, z) in enumerate(SPAWNS):
        add("cyl", "Spawn%d" % (index + 1), (x, 0.15, z), (3, 0.15, 3), GOLD, glow=3)
    labels.append(("ARRIVAL", SPAWN[0], SPAWN[1] + 9, "place"))
    for bearing in (55, 125, 235, 305):
        x, z, _ = wall_on_ring(0, 0, PLAZA_R, bearing, 5)
        box("PurpleColumn", (x, 20.5, z), (8, 41, 8), PURPLE)
    gantry("Play", 0, 0, PLAZA_R, 0, HALF_CORRIDOR, "PLAY", GOLD)

    # ----- PLAY avenue: pads along both sides, a count screen over each, gate court at the end
    cx, cz, cr = CHAMBER
    start = -math.sqrt(PLAZA_R**2 - HALF_CORRIDOR**2)
    end = cz + math.sqrt(cr**2 - HALF_CORRIDOR**2)
    length = start - end
    # runs into the plaza and the gate court, so no ground shows at the corners where they meet
    box("CorridorFloor", (0, 0.04, (start + end) / 2), (HALF_CORRIDOR * 2, 0.1, length + 30), FLOOR)
    for side in (-1, 1):
        box("CorridorWall", (side * HALF_CORRIDOR, WALL_H / 2, (start + end) / 2), (1.6, WALL_H, length), WALL)
        box("CorridorEdge", (side * 10, 0.12, (start + end) / 2 - 10), (0.5, 0.1, length + 20), GOLD, glow=6)
    for index, z in enumerate((-50, -66, -82)):
        for side in (-1, 1):
            box("Chevron", (side * 3, 0.12, z), (8, 0.1, 1.6), (0.85, 0.86, 0.9), glow=0.6, rot=side * 40, plan=index == 1)
    labels.append(("PLAY AVENUE", 0, -60, "place"))
    pads = [
        ("Duel", "DUEL 1V1", "0/1", -1, -56, GREEN),
        ("TDM", "TEAM DEATHMATCH", "0/5", 1, -56, GOLD),
        ("TrainingObjective", "TRAINING", "SOLO", -1, -86, LILAC),
        ("TrainingTDM", "TRAINING TDM", "SOLO", 1, -86, LILAC),
    ]
    for name, title, count, side, z, colour in pads:
        x = side * (HALF_CORRIDOR - 15)
        w, d = (24, 24) if name == "TDM" else (18, 22)
        box("Pad" + name, (x, 0.2, z), (w, 0.4, d), colour, glow=1.6)
        box("Pad" + name + "Inner", (x, 0.26, z), (w - 1.6, 0.42, d - 1.6), PLATE, plan=False)
        wall = side * (HALF_CORRIDOR - 1.0)
        box("Screen" + name, (wall, 8, z), (0.4, 8, 20), (0.05, 0.06, 0.09), plan=False)
        box("ScreenFrame" + name, (wall + side * 0.1, 8, z), (0.3, 8.8, 20.8), colour, glow=3, plan=False)
        add("text", "Screen" + name + "Title", (wall - side * 0.4, 10.1, z), (1.9, 0, 0), colour, glow=7, text=title, rot=-side * 90)
        add("text", "Screen" + name + "Count", (wall - side * 0.4, 6.1, z), (2.6, 0, 0), (0.95, 0.96, 1.0), glow=6, text=count, rot=-side * 90)
        labels.append((title, x, z, "pad"))

    # ----- the gate court, at the end of the avenue
    add("cyl", "ChamberFloor", (cx, 0.05, cz), (cr * 2, 0.1, cr * 2), FLOOR)
    round_wall("ChamberWall", cx, cz, cr, [(180, HALF_CORRIDOR)], height=20)
    box("PadConvergence", (0, 0.2, -114), (36, 0.4, 18), GOLD, glow=1.6)
    box("PadConvergenceInner", (0, 0.26, -114), (34.4, 0.42, 16.4), PLATE, plan=False)
    add("text", "PadConvergenceText", (0, 0.5, -108), (2.8, 0, 0), GOLD, glow=5, text="CONVERGENCE", flat=True)
    labels.append(("CONVERGENCE", 0, -114, "pad"))
    gx, gz = GATE
    add("ring", "GateRing", (gx, 28, gz), (50, 50, 5), GOLD, glow=9, tube=2.5)
    add("ring", "GateRingInner", (gx, 28, gz - 1.5), (42, 42, 2.2), STEEL, tube=1.1)
    add("sphere", "DarkMatter", (gx, 28, gz - 2), (19, 19, 19), (0.01, 0.005, 0.02))
    add("ring", "Accretion", (gx, 28, gz - 2), (31, 31, 1), VIOLET, glow=14, tube=0.5, tilt=68)
    add("ring", "AccretionOuter", (gx, 28, gz - 2), (37, 37, 1), CYAN, glow=5, tube=0.22, tilt=68)
    box("GateBase", (gx, 1, gz), (58, 2, 10), STEEL)
    for side in (-1, 1):
        box("GatePylon", (gx + side * 28, 11, gz), (5, 22, 7), STEEL)
        box("GatePylonGlow", (gx + side * 28, 11, gz + 3.6), (0.7, 17, 0.3), GOLD, glow=7, plan=False)
        # the two existing 92-stud stone columns stand behind the gate, seen from everywhere
        box("StoneColumn", (gx + side * 26, 46, gz - 10), (16, 92, 16), STONE)
    add("text", "GateSign", (gx, 59, gz + 1), (11, 0, 0), GOLD, glow=10, text="PLAY")
    labels.append(("PLAY GATE", gx, gz + 12, "place"))

    # ----- ARMORY (left) and KITS (right): wide halls, open to the plaza
    for side, title, accent in ((-1, "ARMORY", GOLD), (1, "KITS", VIOLET)):
        mouth = math.sqrt(PLAZA_R**2 - SIDE_OPEN**2)  # where the opening meets the plaza ring
        centre = (side * (PLAZA_R + 8 + ROOM / 2), 0)
        box(title + "PassageFloor", (side * (mouth + PLAZA_R + 8) / 2, 0.05, 0), (PLAZA_R + 8 - mouth, 0.1, SIDE_OPEN * 2), FLOOR)
        for wall in (-1, 1):
            # from the plaza ring to the hall, so there is no gap to slip out through
            box(title + "PassageWall", (side * (mouth + PLAZA_R + 8) / 2, WALL_H / 2, wall * SIDE_OPEN), (PLAZA_R + 8 - mouth, WALL_H, 1.6), WALL)
        far = room(title, centre, ROOM, "east" if side < 0 else "west", accent, SIDE_OPEN * 2)
        gantry(title, 0, 0, PLAZA_R, 90 if side > 0 else 270, SIDE_OPEN, title, accent)
        labels.append((title, centre[0], centre[1], "place"))
        inner = far - side * 1.2  # inside face of the far wall
        if side < 0:
            box("ArmoryCounter", (centre[0] + 6, 1.75, 0), (6, 3.5, 30), STEEL)
            box("ArmoryCounterGlow", (centre[0] + 6, 3.55, 0), (5.4, 0.12, 29), GOLD, glow=1.5, plan=False)
            for slot in range(8):
                z = -24.5 + slot * 7
                y = 6 + (slot % 2) * 4
                box("RackGun%d" % slot, (inner, y, z), (0.6, 1.4, 6), (0.6, 0.62, 0.66), plan=False)
                box("RackLight%d" % slot, (inner + 0.1, y - 2.2, z), (0.3, 0.2, 6), GOLD, glow=4, plan=False)
            # the practice range, later, through the armory's north wall
            box("RangeDoor", (centre[0], 6.5, -ROOM / 2 + 1), (20, 11, 1), STEEL)
            box("RangeDoorGlow", (centre[0], 6.5, -ROOM / 2 + 1.6), (18, 9, 0.2), LILAC, glow=0.6, plan=False)
            add("text", "RangeSign", (centre[0], 13.4, -ROOM / 2 + 1.8), (1.8, 0, 0), LILAC, glow=6, text="PRACTICE RANGE")
            labels.append(("PRACTICE RANGE\n(later)", centre[0], -ROOM / 2 + 6, "place"))
            add("ring", "TargetFloor", (centre[0] - 6, 0.15, 18), (16, 0.2, 16), GOLD, glow=0.5, tube=0.6, flat=True, plan=False)
        else:
            for slot in range(4):
                z = -21 + slot * 14
                colour = KIT_COLOURS[slot]
                kit = group((inner - 9, z), 90)
                kit("cyl", "KitPlinth%d" % slot, (0, 1, 0), (10, 2, 10), STEEL)
                kit("ring", "KitRing%d" % slot, (0, 2.1, 0), (10, 0.3, 10), colour, glow=7, tube=0.3, flat=True, plan=False)
                figure(kit, "Kit%d" % slot, 0, 0, 2, 10, tuple(c * 0.55 for c in colour))
                box("KitBackGlow%d" % slot, (inner, 7, z), (0.3, 11, 7), colour, glow=2.2, plan=False)

    # ----- behind the player: the SHOP, with season posters, the leaderboard and the canister
    depth, width = 52, 64
    mouth = math.sqrt(PLAZA_R**2 - 20**2)
    shop_z = PLAZA_R + 8 + depth / 2
    box("ShopPassageFloor", (0, 0.05, (mouth + PLAZA_R + 8) / 2), (40, 0.1, PLAZA_R + 8 - mouth), FLOOR)
    for side in (-1, 1):
        box("ShopPassageWall", (side * 20, WALL_H / 2, (mouth + PLAZA_R + 8) / 2), (1.6, WALL_H, PLAZA_R + 8 - mouth), WALL)
    box("ShopFloor", (0, 0.05, shop_z), (width, 0.1, depth), PLATE)
    box("ShopWallBack", (0, WALL_H / 2, shop_z + depth / 2), (width, WALL_H, 1.6), WALL)
    for side in (-1, 1):
        box("ShopWallSide", (side * width / 2, WALL_H / 2, shop_z), (1.6, WALL_H, depth), WALL)
        box("ShopWallFront", (side * (20 + (width / 2 - 20) / 2), WALL_H / 2, shop_z - depth / 2), (width / 2 - 20, WALL_H, 1.6), WALL)
    box("ShopCounter", (0, 2, shop_z + 10), (30, 4, 6), STEEL)
    for index, x in enumerate((-20, 0, 20)):
        box("ShopScreen%d" % index, (x, 7.5, shop_z + depth / 2 - 0.6), (15, 11, 0.6), STEEL, plan=False)
        glow = (0.62, 0.42, 0.18) if index != 1 else (0.5, 0.25, 0.6)
        box("ShopScreenGlow%d" % index, (x, 7.5, shop_z + depth / 2 - 1.0), (14, 10, 0.2), glow, glow=2.2, plan=False)
    gantry("Shop", 0, 0, PLAZA_R, 180, 20, "SHOP", GOLD)
    for side in (-1, 1):
        # season posters either side of the shop opening, as RIVALS does at its market
        bx, bz, brot = wall_on_ring(0, 0, PLAZA_R, 180 + side * 30, 0.6)
        box("SeasonPoster", (bx, 7.5, bz), (12, 11, 0.3), (0.3, 0.2, 0.55) if side < 0 else (0.15, 0.4, 0.55), glow=2, rot=brot, plan=False)
    labels.append(("SHOP", 0, shop_z, "place"))
    lx, lz, lrot = wall_on_ring(0, 0, PLAZA_R, 140, 0.8)
    box("Leaderboard", (lx, 7.5, lz), (24, 11, 0.6), STEEL, rot=lrot)
    gx2, gz2, _ = wall_on_ring(0, 0, PLAZA_R, 140, 1.2)
    box("LeaderboardGlow", (gx2, 7.5, gz2), (22.5, 9.5, 0.2), (0.3, 0.42, 0.6), glow=1.5, rot=lrot, plan=False)
    labels.append(("LEADERBOARD", lx - 10, lz - 8, "place"))
    add("cyl", "Canister", (-34, 15.5, 30), (16, 31, 16), (0.2, 0.45, 0.7), glow=1.2)
    add("ring", "CanisterBand", (-34, 6, 30), (17.5, 1, 17.5), STEEL, tube=0.8, flat=True, plan=False)
    add("ring", "CanisterBandTop", (-34, 26, 30), (17.5, 1, 17.5), STEEL, tube=0.8, flat=True, plan=False)
    labels.append(("SEASON\nDISPLAY", -34, 30, "place"))

    # ----- people, for scale (5 studs tall)
    world = group((0, 0), 0)
    for index, (x, z) in enumerate([(-25, -50), (-22, -60), (24, -52), (27, -60), (20, -47), (-5, -114), (6, -112), (-96, 8), (104, -10), (2, 100), (-8, -20), (30, -6)]):
        figure(world, "Player%d" % index, x, z, 0.1, 5.2, (0.75, 0.77, 0.82))
    enlarge()
    return parts


# Parts whose footprint grows with the layout. Everything else keeps its size and only moves.
GROWS = ("Wall", "Floor", "Beam", "TopGlow", "CorridorEdge", "Centre", "Sign")
GATE_PARTS = ("Gate", "DarkMatter", "Accretion")  # the landmark grows in height too


def enlarge():
    k = SCALE
    for part in parts:
        x, y, z = part["pos"]
        sx, sy, sz = part["size"]
        name = part["name"]
        gate = name.startswith(GATE_PARTS)
        part["pos"] = [x * k, y * k if gate else y, z * k]
        if gate:
            part["size"] = [sx * k, sy * k, sz * k]
            if "tube" in part:
                part["tube"] *= k
        elif any(word in name for word in GROWS):
            if part["kind"] == "text":
                part["size"] = [sx * k, sy, sz]
            else:
                part["size"] = [sx * k, sy, sz * k]
                if "tube" in part:
                    part["tube"] *= k
    labels[:] = [(text, x * k, z * k, kind) for text, x, z, kind in labels]


def _scaled(point):
    return tuple(v * SCALE if index != 1 else v for index, v in enumerate(point)) if len(point) == 3 else tuple(v * SCALE for v in point)




VIEWS = [
    # name, title, camera (x, y, z), target (x, y, z), vertical field of view in degrees
    ("arrival", "First view on arrival (player's eye, default field of view)", (0, 5.5, 32), (0, 20, -152), 70),
    ("aerial", "Bird's eye", (0, 320, 40), (0, 0, -26), 56),
    ("three_quarter", "From above", (170, 140, 150), (-6, 0, -26), 50),
    ("corridor", "Halfway down the PLAY avenue", (-6, 5.5, -40), (2, 20, -152), 70),
    ("gate", "The PLAY gate from the Convergence pad", (-12, 4.2, -98), (2, 30, -152), 72),
    ("kits", "KITS hall, from its open front", (64, 6, 22), (130, 7, -8), 66),
    ("armory", "ARMORY hall, from its open front", (-64, 6, 20), (-130, 7, -6), 66),
    ("back", "Turning round in the plaza: shop, posters, leaderboard and canister", (0, 6, -24), (-2, 8, 100), 72),
]

build()

# After build(): the constants other scripts read describe the enlarged layout.
SPAWN = (SPAWN[0] * SCALE, SPAWN[1] * SCALE)
SPAWNS = [(x * SCALE, z * SCALE) for x, z in SPAWNS]
GATE = (GATE[0] * SCALE, GATE[1] * SCALE)
HALL = {"x": HALL["x"] * SCALE, "north": HALL["north"] * SCALE, "south": HALL["south"] * SCALE, "height": HALL["height"]}
VIEWS = [
    (n, t, (eye[0] * SCALE, eye[1] * (SCALE if n in ("aerial", "three_quarter") else 1), eye[2] * SCALE), _scaled(target), fov)
    for n, t, eye, target, fov in VIEWS
]
