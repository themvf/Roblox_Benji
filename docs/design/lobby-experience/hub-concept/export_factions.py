"""Write the Faction Islands parts to factions_parts.json for tools/lobbyauthor/faction_islands.luau.

    python docs/design/lobby-experience/hub-concept/export_factions.py

factions.py stays the one source: the plan, the renders and the game lobby all read it. This adds
what a blockout render does not need and the game does:
  - a Roblox material and sign font per part, from the art direction (build_factions_page.ART);
  - invisible barriers along every island rim and bridge, so nobody walks or jumps into the void;
  - the station positions (kiosk, ledger, PLAY sign) to copy into src/shared/Maps/Lobby.lua.
Concept coordinates are lobby studs: x east, z south (the player arrives facing -z), y up from
the island tops.
"""

import json
import math
import os

import factions as fx
from alternatives import bearing_to
from hub_design import rotate

HERE = os.path.dirname(os.path.abspath(__file__))

BARRIER_TOP = 15.0  # studs above the deck; a Roblox jump reaches about 7.2
BRIDGE_HALF = 12.0  # factions.bridge() width / 2

SIDE_OF = {fx.FORGE_C: "Forge", fx.INST_C: "Institute", fx.KADE_C: "Kade", fx.FERRY_C: "Ferrymen"}

# The art direction's materials. Keys are part names (exact, then prefix); a side's own table wins.
MATERIALS = {
    "Forge": {
        "Island": "DiamondPlate",
        "ForgeWallBack": "CorrodedMetal",
        "Crane": "Metal",
        "CraneBanner": "Fabric",
        "Banner": "Fabric",
        "Chimney": "CorrodedMetal",
        "Piston": "Metal",
        "WeldBench": "Metal",
        "Pegboard": "Wood",
        "Rivet": "Metal",
        "ProvingPitGlass": "Glass",
        "EchoTarget": "Metal",
    },
    "Institute": {
        "Island": "SmoothPlastic",
        "InstituteWallBack": "SmoothPlastic",
        "Dome": "SmoothPlastic",
        "ListBoard": "Glass",
        "FrostVent": "Ice",
        "FrostPlume": "Ice",
        "Theodolite": "Metal",
        "TripodLeg": "Metal",
        "KitPodGlass": "Glass",
        "KitsPromptPad": "Metal",
    },
    "Kade": {
        "Island": "Slate",
        "KadeWallBack": "Foil",
        "MarbleApron": "Marble",
        "Rocket": "Metal",
        "LaunchPad": "Metal",
        "Tower": "Metal",
        "LogoDisc": "Foil",
        "ChromePlinth": "Foil",
        "Stanchion": "Metal",
        "Rope": "Fabric",
        "ShopCounter": "Marble",
        "PacksPedestal": "Metal",
        "PassesTerminal": "Metal",
    },
    "Ferrymen": {
        "Island": "WoodPlanks",
        "FerryWallBack": "CorrodedMetal",
        "Container": "CorrodedMetal",
        "Stall": "WoodPlanks",
        "Tarp": "Fabric",
        "TarpPole": "Metal",
        "FerryHull": "CorrodedMetal",
        "FerryCabin": "WoodPlanks",
        "Contraband": "WoodPlanks",
        "StolenBanner": "Fabric",
        "StolenDome": "SmoothPlastic",
        "MarshBase": "Metal",
        "MarshHolo": "Glass",
    },
    "Hold": {
        "Island": "Concrete",
        "Departures": "SmoothPlastic",
        "Bag": "Fabric",
    },
    "All": {
        "Bridge": "Concrete",
        "IslandUnder": "Slate",
        "Rail": "Metal",
        "Beam": "Metal",
        "Gate": "Metal",
        "KitPlinth": "Metal",
        "FlagPole": "Metal",
    },
}

# Sign fonts (Enum.Font names), from the same sheets.
FONTS = [
    ("Forge", "Oswald"),
    ("CraneBannerText", "Oswald"),
    ("Institute", "Jura"),
    ("ListTitle", "Jura"),
    ("Kade", "Montserrat"),
    ("Logo", "Montserrat"),
    ("FloorLogo", "Montserrat"),
    ("TickerText", "Montserrat"),
    ("Ferry", "Sarpanch"),
    ("Tag", "PermanentMarker"),
    ("Departures", "Michroma"),
    ("DayCount", "Michroma"),
    ("DepartureRow", "Michroma"),
]

# Signage & prompt text mappings.
TEXT = {"InstituteSign": "KITS"}

# Scenery a player walks through rather than into.
GHOSTS = (
    "Spark",
    "Glyph",
    "Drone",
    "Bulb",
    "Steam",
    "FrostPlume",
    "Beacon",
    "WeldArc",
    "HoloCore",
    "TheodoliteBeam",
    "BridgeRing",
    "Vista",
    "MarshHolo",
    "ProvingPitFloor",
)


def side_of(part):
    x, z = part["pos"][0], part["pos"][2]
    for centre, name in SIDE_OF.items():
        if math.hypot(x - centre[0], z - centre[1]) <= fx.RADII[centre] + 22:
            return name
    return "Hold"


def material_for(name, side):
    """Longest matching key wins, so IslandUnder is Slate everywhere while Island is the side's."""
    if name.endswith("Glow"):
        return None
    found = [
        (len(key), priority, table[key])
        for priority, table in ((1, MATERIALS.get(side, {})), (0, MATERIALS["All"]))
        for key in table
        if name.startswith(key)
    ]
    return max(found)[2] if found else None


def font_for(name):
    for prefix, font in FONTS:
        if name.startswith(prefix):
            return font
    return None


def barrier(pos, length, rot):
    return {
        "kind": "box",
        "name": "Barrier",
        "pos": [pos[0], BARRIER_TOP / 2, pos[1]],
        "size": [length, BARRIER_TOP, 0.6],
        "colour": [1, 1, 1],
        "glow": 0,
        "rot": rot,
        "invisible": True,
    }


def island_barriers():
    """Chords around each rim, broken exactly where a bridge deck meets it."""
    out = []
    for centre, radius in fx.RADII.items():
        r = radius - 0.6
        openings = [bearing_to(centre, b if a == centre else a) for a, b in fx.LINKS if centre in (a, b)]
        half = math.degrees(math.asin((BRIDGE_HALF + 0.3) / r))
        openings.sort()
        # walk the rim from the edge of each opening to the edge of the next
        spans = []
        for index, here in enumerate(openings):
            after = openings[(index + 1) % len(openings)]
            a = (here + half) % 360
            spans.append((a, ((after - half) - a) % 360))
        for a, span in spans:
            pieces = max(1, math.ceil(math.radians(span) * r / 8))
            for k in range(pieces):
                t0 = math.radians(a + span * k / pieces)
                t1 = math.radians(a + span * (k + 1) / pieces)
                p0 = (centre[0] + r * math.sin(t0), centre[1] - r * math.cos(t0))
                p1 = (centre[0] + r * math.sin(t1), centre[1] - r * math.cos(t1))
                mid = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2)
                length = math.hypot(p1[0] - p0[0], p1[1] - p0[1]) + 0.4
                theta = math.degrees((t0 + t1) / 2)
                out.append(barrier(mid, length, -theta))
    return out


def bridge_barriers():
    out = []
    for a, b in fx.LINKS:
        ra, rb = fx.RADII[a], fx.RADII[b]
        dx, dz = b[0] - a[0], b[1] - a[1]
        distance = math.hypot(dx, dz)
        ux, uz = dx / distance, dz / distance
        s = (a[0] + ux * (ra - 4), a[1] + uz * (ra - 4))
        e = (b[0] - ux * (rb - 4), b[1] - uz * (rb - 4))
        length = math.hypot(e[0] - s[0], e[1] - s[1])
        mx, mz = (s[0] + e[0]) / 2, (s[1] + e[1]) / 2
        rot = math.degrees(math.atan2(dx, dz))
        tx, tz = math.cos(math.radians(rot)), -math.sin(math.radians(rot))
        for side in (-1, 1):
            off = side * (BRIDGE_HALF - 0.3)
            out.append(barrier((mx + tx * off, mz + tz * off), length, rot + 90))
    return out


def local(centre, x, z):
    """Island-frame point (factions.facing) to lobby coordinates, and the frame's turn."""
    degrees = (180 - bearing_to(centre, fx.ARRIVAL)) % 360
    rx, rz = rotate(x, z, degrees)
    return (round(centre[0] + rx, 2), round(centre[1] + rz, 2)), degrees


def stations():
    # A station's sign faces Roblox's -Z (its Front); the island's arrival side is its local +z,
    # so the marker yaw is the frame's turn plus 180.
    kiosk, turn = local(fx.FORGE_C, 0, 4)
    board, board_turn = local(fx.FERRY_C, 0, -25.6)
    return {
        "Kiosk": {"pos": [kiosk[0], 0, kiosk[1]], "yaw": round((turn + 180) % 360, 2)},
        "Board": {"pos": [board[0], 2, board[1]], "yaw": round((board_turn + 180) % 360, 2)},
        "Play": {"pos": [0, 18, -48]},
    }


def main():
    variant = fx.factions()
    out = []
    for part in variant.parts:
        if part["name"] in ("Floor", "Void"):
            continue  # the render's void plane; in game the void is the sky
        item = {k: v for k, v in part.items() if k != "plan"}
        item["colour"] = list(part["colour"])
        side = side_of(part)
        item["side"] = side
        material = material_for(part["name"], side)
        if material:
            item["material"] = material
        if part["kind"] == "text":
            item["text"] = TEXT.get(part["name"], part["text"])
            font = font_for(part["name"])
            if font:
                item["font"] = font
        if part["name"].startswith(GHOSTS):
            item["ghost"] = True
        out.append(item)
    out += island_barriers() + bridge_barriers()
    path = os.path.join(HERE, "factions_parts.json")
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump({"stations": stations(), "parts": out}, handle, indent=1)
        handle.write("\n")
    print("wrote %s (%d parts, %d barriers)" % (path, len(out), sum(1 for p in out if p.get("invisible"))))
    print(json.dumps(stations(), indent=1))


if __name__ == "__main__":
    main()
