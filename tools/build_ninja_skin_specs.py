"""Reproduce the two clean R15 armor specifications from the supplied references.

The supplied TRELLIS meshes are static and fragmented. This source describes
rigid armor pieces attached to animated R15 limbs; rifles remain weapon Tools.
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PKG = ROOT / "assets/models/ninja-soldier-skins"
JSON = PKG / "source/armor_specs.json"
LUA = ROOT / "src/shared/CharacterSkins/Definitions.lua"


def piece(name, attach, shape, size, offset, color, rotation=None, material="Metal"):
    return {"name": name, "attach": attach, "shape": shape, "size": size,
            "offset": offset, "rotation": rotation or [0, 0, 0],
            "color": color, "material": material}


BLACK = "#11171C"
GRAPHITE = "#20282D"
ARMOR = "#303A40"
TRIM = "#56636B"
VISOR = "#07141A"
CYAN = "#75DDEB"
GOLD = "#B8873C"
TACTICAL = "#16191B"
FABRIC = "#22272A"
RED = "#B54538"

scifi = []
tactical = []


def add(rows, name, attach, shape, size, offset, color, rotation=None, material="Metal"):
    rows.append(piece(name, attach, shape, size, offset, color, rotation, material))


# Angular black exosuit. Cyan visor, high shoulders, breastplate, gauntlets,
# broad thigh shells and antennae preserve the recognizable concept silhouette.
add(scifi, "helmet-shell", "Head", "ball", [1.48, 1.25, 1.52], [0, .08, 0], BLACK)
add(scifi, "helmet-brow", "Head", "block", [1.33, .24, .39], [0, .37, -.49], ARMOR)
add(scifi, "visor-shadow", "Head", "block", [1.17, .27, .12], [0, .12, -.72], VISOR, material="SmoothPlastic")
add(scifi, "cyan-visor-line", "Head", "block", [1.06, .075, .07], [0, .04, -.80], CYAN, material="Neon")
add(scifi, "jaw-guard", "Head", "block", [.76, .30, .26], [0, -.37, -.60], GRAPHITE)
for side, label in ((-1, "left"), (1, "right")):
    add(scifi, label + "-ear-pod", "Head", "ball", [.34, .40, .43], [side * .69, -.06, .04], ARMOR)
    add(scifi, label + "-antenna", "Head", "cylinder", [.055, .85, .055], [side * .56, .84, .38], BLACK, [0, 0, side * 12])
    add(scifi, label + "-chest", "UpperTorso", "block", [.87, 1.29, .38], [side * .49, .04, -.54], ARMOR, [0, side * 9, side * -7])
    add(scifi, label + "-collar", "UpperTorso", "block", [.77, .30, .40], [side * .43, .69, -.39], TRIM, [0, 0, side * -10])
    add(scifi, label + "-shoulder", label.title() + "UpperArm", "ball", [.93, .67, 1.00], [side * .10, .40, -.04], ARMOR)
    add(scifi, label + "-shoulder-ridge", label.title() + "UpperArm", "block", [.84, .20, .78], [side * .13, .73, -.07], TRIM, [0, 0, side * -9])
    add(scifi, label + "-bicep-plate", label.title() + "UpperArm", "block", [.71, .86, .28], [0, -.22, -.32], GRAPHITE)
    add(scifi, label + "-forearm-shell", label.title() + "LowerArm", "block", [.74, 1.05, .40], [0, -.03, -.29], ARMOR)
    add(scifi, label + "-hand-guard", label.title() + "Hand", "block", [.73, .28, .50], [0, .03, -.13], GRAPHITE)
    add(scifi, label + "-thigh-shell", label.title() + "UpperLeg", "block", [.91, 1.43, .43], [0, -.02, -.33], ARMOR)
    add(scifi, label + "-thigh-inset", label.title() + "UpperLeg", "block", [.52, .95, .11], [0, .05, -.58], GRAPHITE)
    add(scifi, label + "-knee", label.title() + "LowerLeg", "ball", [.82, .52, .48], [0, .49, -.33], TRIM)
    add(scifi, label + "-shin", label.title() + "LowerLeg", "block", [.79, 1.12, .38], [0, -.08, -.32], ARMOR)
    add(scifi, label + "-boot", label.title() + "Foot", "block", [.82, .35, 1.13], [0, -.10, -.11], BLACK)
add(scifi, "chest-core", "UpperTorso", "block", [.42, .78, .14], [0, .01, -.78], BLACK)
add(scifi, "chest-core-light", "UpperTorso", "block", [.10, .50, .04], [0, .01, -.87], CYAN, material="Neon")
add(scifi, "abdomen", "LowerTorso", "block", [1.58, .84, .35], [0, .06, -.43], GRAPHITE)
add(scifi, "abdomen-ridge", "LowerTorso", "block", [1.29, .12, .07], [0, .20, -.65], TRIM)
add(scifi, "backpack", "UpperTorso", "block", [1.43, 1.45, .49], [0, .02, .54], GRAPHITE)
add(scifi, "backpack-cap", "UpperTorso", "block", [1.15, .28, .29], [0, .62, .82], ARMOR)

# The earlier source is a heavier modern operator: dark fabric, helmet and gas
# mask, vest pouches, arm guards and kneepads. Red tabs identify it at a glance.
add(tactical, "helmet", "Head", "ball", [1.39, 1.22, 1.36], [0, .09, 0], TACTICAL)
add(tactical, "helmet-brim", "Head", "block", [1.48, .14, .38], [0, .34, -.49], GRAPHITE)
add(tactical, "goggle-visor", "Head", "block", [1.17, .32, .18], [0, .12, -.64], VISOR, material="SmoothPlastic")
add(tactical, "respirator", "Head", "block", [.69, .45, .29], [0, -.32, -.63], ARMOR)
add(tactical, "filter", "Head", "cylinder", [.35, .24, .35], [0, -.44, -.84], GRAPHITE, [90, 0, 0])
for side, label in ((-1, "left"), (1, "right")):
    add(tactical, label + "-headset", "Head", "ball", [.32, .44, .40], [side * .67, .02, -.04], ARMOR)
    add(tactical, label + "-shoulder", label.title() + "UpperArm", "ball", [.84, .51, .77], [side * .07, .39, -.02], GRAPHITE)
    add(tactical, label + "-sleeve-patch", label.title() + "UpperArm", "block", [.16, .39, .41], [side * .46, .12, -.01], ARMOR)
    add(tactical, label + "-forearm-guard", label.title() + "LowerArm", "block", [.69, .83, .27], [0, -.08, -.29], ARMOR)
    add(tactical, label + "-glove", label.title() + "Hand", "ball", [.68, .37, .52], [0, -.03, -.08], TACTICAL)
    add(tactical, label + "-thigh-pocket", label.title() + "UpperLeg", "block", [.67, .68, .30], [side * .04, -.12, -.37], FABRIC, material="SmoothPlastic")
    add(tactical, label + "-knee-pad", label.title() + "LowerLeg", "ball", [.72, .52, .38], [0, .43, -.31], ARMOR)
    add(tactical, label + "-shin-wrap", label.title() + "LowerLeg", "block", [.69, .60, .22], [0, -.23, -.30], GRAPHITE)
    add(tactical, label + "-boot", label.title() + "Foot", "block", [.79, .37, 1.03], [0, -.09, -.08], TACTICAL)
add(tactical, "vest", "UpperTorso", "block", [1.88, 1.42, .37], [0, .02, -.46], GRAPHITE)
add(tactical, "vest-top", "UpperTorso", "block", [1.68, .30, .15], [0, .61, -.65], ARMOR)
for index, x in enumerate((-.54, 0, .54)):
    add(tactical, f"mag-pouch-{index + 1}", "UpperTorso", "block", [.42, .70, .25], [x, -.13, -.78], FABRIC, material="SmoothPlastic")
add(tactical, "waist-belt", "LowerTorso", "block", [1.82, .24, .34], [0, .23, -.24], TACTICAL)
add(tactical, "belt-buckle", "LowerTorso", "block", [.39, .23, .12], [0, .23, -.48], TRIM)
add(tactical, "backpack", "UpperTorso", "block", [1.36, 1.36, .40], [0, .05, .51], FABRIC, material="SmoothPlastic")
add(tactical, "red-shoulder-tab", "RightUpperArm", "block", [.21, .11, .26], [.26, .56, -.35], RED, material="SmoothPlastic")
add(tactical, "red-vest-tab", "UpperTorso", "block", [.28, .09, .06], [.72, .57, -.75], RED, material="SmoothPlastic")

spec = {
    "schema": 1,
    "units": "studs; offsets in each R15 body part's local coordinates; forward is -Z",
    "variants": {
        "SciFiSentry": {"name": "Sci-Fi Sentry", "bodyColor": BLACK,
                        "description": "Black exosuit, cyan visor, broad armor and segmented leg shells.",
                        "source": "sample_2026-10-18T211804.405.glb", "pieces": scifi},
        "TacticalOperator": {"name": "Tactical Operator", "bodyColor": TACTICAL,
                             "description": "Masked black operator with vest pouches, pads and subtle red tabs.",
                             "source": "sample_2026-10-18T022027.540.glb", "pieces": tactical},
    },
}


def lua_value(value, indent=0):
    pad = "    " * indent
    if isinstance(value, dict):
        rows = ["{"]
        for key, item in value.items():
            rows.append(f"{pad}    {key} = {lua_value(item, indent + 1)},")
        rows.append(pad + "}")
        return "\n".join(rows)
    if isinstance(value, list):
        if all(isinstance(item, (int, float)) for item in value):
            return "{ " + ", ".join(str(x) for x in value) + " }"
        rows = ["{"]
        for item in value:
            rows.append(f"{pad}    {lua_value(item, indent + 1)},")
        rows.append(pad + "}")
        return "\n".join(rows)
    return json.dumps(value)


JSON.parent.mkdir(parents=True, exist_ok=True)
LUA.parent.mkdir(parents=True, exist_ok=True)
JSON.write_text(json.dumps(spec, indent=2) + "\n", encoding="utf-8")
LUA.write_text("-- Generated by tools/build_ninja_skin_specs.py; edit the builder.\nreturn "
               + lua_value(spec["variants"]) + "\n", encoding="utf-8")
print(f"wrote {len(scifi)} sci-fi and {len(tactical)} tactical armor pieces")
