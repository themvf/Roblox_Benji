"""A kit's look, from one approved concept to a reviewed character: bar -> concept -> crops -> pieces -> review.

    python tools/kit_look.py plan    <Kit> [--pieces helmet,chest,...]
    python tools/kit_look.py bar     <Kit> --outline ... --glow ... --texture ... --proportions ...
    python tools/kit_look.py concept <Kit> [--image file]      prompt for a turnaround sheet, or file one
    python tools/kit_look.py approve <Kit> --said "the user's own words"
    python tools/kit_look.py crop    <Kit> <piece> x0 y0 x1 y1  cut a piece from the concept for Tripo
    python tools/kit_look.py draw    <Kit> <piece> [--image f]  a piece the concept hides: prompt, then file the drawing
    python tools/kit_look.py reset   <Kit> <piece>              set a piece aside (made before the concept, or wrong)
    python tools/kit_look.py finish  <Kit> <piece> --like <piece> [--scratches]  Blender pass: steel, edges, glow
    python tools/kit_look.py retint  <Kit> <piece> [--grain-from p] [--seams #hex]  match a piece to the others' steel
    python tools/kit_look.py make    <Kit> [--pieces a,b] [--confirm]  run Tripo (API) on every ready piece, then intake
    python tools/kit_look.py intake  <Kit> <piece> <file.glb> [--turn deg] [--flip] [--trim 0.4] [--matte 0.85]
    python tools/kit_look.py review  <Kit>                      assemble on R15, render, one sheet
    python tools/kit_look.py verdict <Kit> --looks good|bad --said "the user's words about the sheet"
    python tools/kit_look.py export  <Kit>                      approved look -> one game GLB + registry entry
    python tools/kit_look.py publish <Kit> [--confirm]          upload it (dry run without --confirm)
    python tools/kit_look.py status  <Kit>

Why this order (docs/design/kits/look-benchmarks/STYLE_BAR.md): the bar is set before
anything is drawn; the design is changed on a picture, where it is cheap; every piece is
made from a crop of the same picture, so the pieces share one style; and each piece rides
one R15 body part rigidly, so the character still animates.

Everything lives in assets/kit-looks/<Kit>/: look.json, concept.png, crops/, pieces/, review/,
and the user's two lists: TRIPO.md (one row per piece) and DRAW.md (Midjourney prompts for
pieces the concept does not show well enough to crop).
Pictures come from Midjourney (the user's tool); pieces from Tripo (image to 3D, GLB).

Lessons that shaped it (Black Knight, 2026-11-17):
- A crop under MIN_CROP (240) pixels on its short side is refused: the knight's fist, shin and boot
  were ~150 px of half-hidden limb, and Tripo would have guessed. Those pieces are drawn
  alone in Midjourney with the concept attached as the image reference (`draw`).
- A piece made before the concept was approved rarely matches it; `reset` sets it aside.
- Crop tight: anything at a crop's edge (a sliver of the next piece) is modelled too.
- A crop cut on all four sides (the knight's chest) comes back as a flat slab: Tripo needs the
  piece's whole outline. Torsos are drawn alone, not cropped.
- Blocky R15 limbs are square; a round guard sized to one is hidden by the block's corners.
  A piece that `covers` its body part hides the part (in game, Transparency 1), as BedWars does.
- Tripo P2's facing held for every knight piece at -90 (the shoulder plate's plated side out).
- One front view leaves Tripo guessing the back; the concept prompt asks for a turnaround.
- Midjourney draws limb pieces diagonally and Tripo keeps the angle: draw prompts ask for the
  piece upright, and review stands forearm, thigh and shin pieces upright by their long axis.
- Boots come back knee-high however they are asked for. Boots fit by footprint, and a tall
  one is cut down with `intake --trim 0.4` (the shin piece covers the cut).
- An unqualified "cape" came back as a floor-length hooded robe. A cape rides the chest rigidly,
  so it has no hood and stops at the back of the knees, or the legs walk through it.
- Midjourney draws a cape as a round cloak. Review keeps its back half, fits its width and
  length, and hangs it behind the chest piece.

Lessons from finishing the knight (2026-11-19), where most of the time went after review:
- The gap between chest and shoulder plates was only seen in Studio. Review now shoots rays
  through the torso band and reports holes; verdict refuses while there are any.
- The fist drawing was a right hand and the hands landed on the wrong arms. Filing a fist
  drawing needs --hand, said after looking at it.
- The eyes were painted, and paint cannot glow in Roblox. Glow plates are planned in the bar
  (--glow-plates) and placed before review.
- The cropped helmet carried the concept's warm rim light as flat copper, though the concept
  prompt asks for even lighting. Every cropped piece is finished in Blender like the look's
  `reference` piece; review lists the ones that are not.
- Tripo is for shape (120 credits a run); colour and material are fixed in Blender (free).
- Team colour was never designed. The bar asks for it (--team) before the concept.
"""
import argparse
import datetime
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

BLENDER = r"C:\Program Files\Blender Foundation\Blender 4.3\blender.exe"
BENCHMARKS = ROOT / "docs/design/kits/look-benchmarks"
CHARACTER_BUDGET = 20_000  # triangles for a whole character; ten of them on a phone at once
MESH_CAP = 10_000  # Roblox's per-mesh limit
TRIPO_TURN = -90  # Tripo exports face glTF +X; measured on the knight helmet, 2026-11-17
MIN_CROP = 240  # pixels on a crop's short side; below this, draw the piece instead

# `covers`: the piece IS that body part, which is hidden under it (in game, Transparency 1).
# Blocky R15 limbs are square, so a round guard sized to the limb left the block's corners
# poking through and hid the guard; BedWars-style kits replace the limb instead.
# `sleeve`: a slimmer stand-in for the hidden part, in bodyColor. A shoulder plate is a shell over
# the top of the arm, open underneath and on the chest side, so hiding the upper arm left a hole
# between chest and arm (BlackKnight, in game); showing the whole arm instead poked its corner up
# through the plate. The sleeve (Blender x, y, z studs, lowered by `drop`) fills the hole from inside.
# The chest has one too, the size of the hidden torso: the knight's breastplate narrows at its
# sides, and review's gap check found sky there under the shoulder plates after it was uploaded.
# Where each piece sits on a blocky R15 body, in studs, Blender axes (Z up, the character
# faces -Y, its left is +X). `box` is what the piece is scaled to fit, keeping its own
# proportions; `mirror` makes the right-hand copy. Allowances add up to CHARACTER_BUDGET.
SLOTS = {
    "helmet": {"covers": True, "part": "Head", "centre": [0, 0, 5.62], "box": [2.5, 2.7, 2.8], "allow": 3800,
               "about": "the whole head and anything on it: helm, horns, hood, hair, flames"},
    "chest": {"covers": True, "part": "UpperTorso", "centre": [0, 0, 4.12], "box": [2.6, 1.7, 2.16], "allow": 3000,
              "fillWidth": 2.5, "sleeve": {"size": [2.1, 0.9, 1.6], "drop": 0},
              "about": "breastplate, collar and back plate as one piece"},
    "waist": {"covers": True, "part": "LowerTorso", "centre": [0, 0, 2.5], "box": [2.4, 1.5, 1.6], "allow": 1000,
              "about": "belt, buckle and tassets"},
    "pauldron": {"covers": True, "part": "LeftUpperArm", "centre": [1.62, 0, 4.36], "box": [2.1, 2.1, 1.9], "allow": 1500,
                 "sleeve": {"size": [0.8, 0.8, 0.9], "drop": 0.15},
                 "mirror": True, "about": "the left shoulder; the right is its mirror"},
    "gauntlet": {"covers": True, "upright": True, "part": "LeftLowerArm", "centre": [1.5, 0, 2.95], "box": [1.6, 1.6, 1.3], "allow": 1000,
                 "mirror": True, "about": "the left forearm guard"},
    "fist": {"covers": True, "upright": True, "part": "LeftHand", "centre": [1.5, -0.05, 2.0], "box": [1.15, 1.15, 0.95], "allow": 600,
             "mirror": True, "about": "the left hand, as an armoured fist"},
    "thigh": {"covers": True, "upright": True, "part": "LeftUpperLeg", "centre": [0.56, 0, 2.12], "box": [1.25, 1.35, 1.25], "allow": 800,
              "mirror": True, "about": "the left thigh plate"},
    "greave": {"covers": True, "upright": True, "part": "LeftLowerLeg", "centre": [0.56, 0, 0.98], "box": [1.25, 1.35, 1.15], "allow": 800,
               "mirror": True, "about": "the left shin and knee"},
    "boot": {"covers": True, "fit": "footprint", "part": "LeftFoot", "centre": [0.57, -0.12, 0.26], "box": [1.3, 1.7, 0.55], "allow": 800,
             "mirror": True, "about": "the left boot"},
    "back": {"fit": "cape", "part": "UpperTorso", "centre": [0, 1.1, 3.0], "box": [2.4, 0.6, 3.2], "allow": 1200,
             "about": "cape, wings, banner or pack: whatever hangs off the back"},
}
# What to ask Midjourney for when a piece is drawn on its own: the piece alone, empty, with
# nothing of the body inside, so Tripo models only the armour.
DRAW = {
    "helmet": "a single helmet, shown alone with no head inside, three-quarter front view",
    "chest": ("a single chunky boxy breastplate shaped like a block, as wide as the shoulders and wider than it is "
              "tall, flat square sides, straight not tapered at the waist, no shoulder guards or sleeves, with its "
              "collar and back plate, shown whole and alone with no body inside, front view"),
    "waist": "a single armoured belt with whatever hangs from it, shown alone with no body inside, front view",
    "pauldron": "a single left shoulder plate, shown alone with no arm inside, three-quarter view from the side",
    "gauntlet": "a single armoured forearm guard, standing straight upright, shown alone with no arm inside, three-quarter view",
    "fist": ("a single oversized armoured LEFT-hand gauntlet fist, clenched, hanging straight down with the wrist cuff at the "
             "top and the knuckles at the bottom, the back of the hand and every finger covered in the same painted "
             "plate colour as the rest of the armour (no bare leather, no chrome), shown alone, front view"),
    "thigh": "a single thigh armour plate, standing straight upright, shown alone with no leg inside, three-quarter view",
    "greave": "a single shin guard with its knee cap, standing straight upright, shown alone with no leg inside, three-quarter view",
    "boot": "a single heavy armoured ankle boot, low, ending just above the ankle, shown alone, three-quarter view from the front",
    "back": "a single short cape with no hood, hanging flat from the shoulders and ending at the back of the knees, seen straight from behind, shown alone with no body inside",
}
# A whole-body look (`kit_look.py whole`) is one model cut into the 15 R15 parts, so its pieces
# are named after the parts and placed as cut ("asis"), with no slot box to fit.
R15_PARTS = ["Head", "UpperTorso", "LowerTorso"] + [s + p for s in ("Left", "Right") for p in (
    "UpperArm", "LowerArm", "Hand", "UpperLeg", "LowerLeg", "Foot")]
WHOLE_FACES = 16000  # Tripo's face limit for the whole body; 20,000 is the character budget


def slot(name):
    if name in SLOTS:
        return SLOTS[name]
    allow = {"Head": 4000, "UpperTorso": 3000, "LowerTorso": 1200}.get(name, 1000)
    return {"part": name, "fit": "asis", "covers": True, "allow": allow, "centre": [0, 0, 0], "box": [1, 1, 1],
            "about": f"the {name}, cut from the whole-body model"}


HANDED = {"fist"}  # pieces whose left and right are not interchangeable: filed with --hand
GAP_LIMIT = 0.02  # square studs of sky through the torso band, front or back, that review accepts
DEFAULT_PIECES = ["helmet", "chest", "waist", "pauldron", "gauntlet", "fist", "thigh", "greave", "boot"]
BAR = ("outline", "glow", "texture", "proportions")


def home(kit):
    return ROOT / "assets/kit-looks" / kit


def load(kit):
    path = home(kit) / "look.json"
    if not path.exists():
        raise SystemExit(f"no look for {kit}; start with  python tools/kit_look.py plan {kit}")
    return json.loads(path.read_text(encoding="utf-8"))


def save(kit, look):
    path = home(kit) / "look.json"
    path.write_text(json.dumps(look, indent=2) + "\n", encoding="utf-8")


def rel(path):
    return Path(path).resolve().relative_to(ROOT).as_posix()


def glb_triangles(path):
    """Triangles per mesh, read from the accessors (no Blender needed)."""
    import outline_check

    doc, _ = outline_check.read_glb(path)
    counts = []
    for mesh in doc.get("meshes", []):
        total = 0
        for prim in mesh["primitives"]:
            if "indices" in prim:
                total += doc["accessors"][prim["indices"]]["count"] // 3
            else:
                total += doc["accessors"][prim["attributes"]["POSITION"]]["count"] // 3
        counts.append(total)
    return counts


# ------------------------------------------------------------------ commands
def cmd_plan(a):
    folder = home(a.kit)
    if (folder / "look.json").exists():
        raise SystemExit(f"{rel(folder / 'look.json')} already exists")
    names = a.pieces.split(",") if a.pieces else DEFAULT_PIECES
    unknown = [n for n in names if n not in SLOTS]
    if unknown:
        raise SystemExit(f"unknown pieces {unknown}; slots are {', '.join(SLOTS)}")
    for sub in ("crops", "pieces", "review"):
        (folder / sub).mkdir(parents=True, exist_ok=True)
    look = {
        "kit": a.kit,
        "bar": {key: "" for key in BAR},
        "bodyColor": "#1E2430",
        "concept": None,
        "approved": None,
        "pieces": {name: {"crop": None, "file": None, "turn": TRIPO_TURN, "triangles": None} for name in names},
    }
    save(a.kit, look)
    total = sum(SLOTS[n]["allow"] * (2 if SLOTS[n].get("mirror") else 1) for n in names)
    print(f"wrote {rel(folder / 'look.json')}: {len(names)} pieces, allowances {total:,} of {CHARACTER_BUDGET:,}")
    print("next: kit_look.py bar  (how this kit meets each line of the style bar)")


def plan_missing(look):
    """What has to be decided before the concept is drawn, beyond the four bar lines."""
    missing = [k for k in BAR if not look["bar"][k]]
    if not look.get("glowPlan"):
        missing.append("glow-plates (where the glow must really glow in game, e.g. 'eyes', or 'none')")
    if not look.get("team"):
        missing.append("team (how a red or blue player reads, e.g. 'the glow takes the team colour')")
    return missing


def cmd_bar(a):
    look = load(a.kit)
    for key in BAR:
        value = getattr(a, key)
        if value:
            look["bar"][key] = value
    if a.glow_plates:
        look["glowPlan"] = a.glow_plates
    if a.team:
        look["team"] = a.team
    save(a.kit, look)
    print("bar:", "; ".join(f"{k}: {look['bar'][k] or '(missing)'}" for k in BAR))
    print(f"glow plates: {look.get('glowPlan') or '(missing)'}; team colour: {look.get('team') or '(missing)'}")
    missing = plan_missing(look)
    if missing:
        print("still missing:", "; ".join(missing))


def concept_prompt(look):
    bar = look["bar"]
    return (
        "character turnaround sheet of a chunky stylized Roblox game kit character, shown three times side "
        "by side: front view, side view, back view, the same standing pose in each with the arms held out "
        "away from the body and empty hands, the whole body in frame, hand-painted stylized 3D render like "
        f"a top Roblox kit, {bar['outline']}, {bar['glow']}, {bar['texture']}, {bar['proportions']}, "
        "plain dark navy background, even lighting, no text --ar 16:9"
    )


def cmd_concept(a):
    look = load(a.kit)
    missing = plan_missing(look)
    if missing:
        raise SystemExit(f"set the bar first ({'; '.join(missing)}): the concept is drawn to it")
    if a.image:
        target = home(a.kit) / ("concept" + Path(a.image).suffix.lower())
        shutil.copyfile(a.image, target)
        look["concept"], look["approved"] = rel(target), None
        save(a.kit, look)
        print(f"filed {rel(target)}. Show it to the user beside two benchmarks, then  kit_look.py approve")
        return
    prompt = concept_prompt(look)
    (home(a.kit) / "concept_prompt.txt").write_text(prompt + "\n", encoding="utf-8")
    print(prompt)
    print("\nFor Midjourney; attach any earlier picture of this character as the image reference.")
    print("A single front view works too (the Black Knight's did); the side and back help Tripo.")
    print(f"then  kit_look.py concept {a.kit} --image <the chosen picture>")


def cmd_approve(a):
    look = load(a.kit)
    if not look["concept"]:
        raise SystemExit("no concept filed")
    if a.said.strip().lower() in ("continue", "ok", "go", "next"):
        raise SystemExit("that is not approval of how it looks; record the user's words about the picture")
    look["approved"] = {"said": a.said, "on": datetime.date.today().isoformat()}
    save(a.kit, look)
    print("concept approved:", a.said)


def cmd_crop(a):
    from PIL import Image

    look = load(a.kit)
    if not look["concept"]:
        raise SystemExit("file a concept first")
    if not look["approved"] and not a.unapproved:
        raise SystemExit("the concept is not approved; pieces are cut from an approved concept only")
    piece = look["pieces"].get(a.piece)
    if piece is None:
        raise SystemExit(f"{a.piece} is not in this look's plan")
    image = Image.open(ROOT / look["concept"]).convert("RGB")
    box = (a.x0, a.y0, a.x1, a.y1)
    short = min(a.x1 - a.x0, a.y1 - a.y0)
    if short < MIN_CROP and not a.force:
        raise SystemExit(
            f"{a.piece}: the crop is {short} px on its short side (under {MIN_CROP}); Tripo would guess at it.\n"
            f"Draw it instead:  kit_look.py draw {a.kit} {a.piece}   (or --force for a trial)")
    part = image.crop(box)
    side = int(max(part.size) * 1.25)
    # Pad with the crop's own background colour. A white border round a dark crop came back
    # from Tripo as white flaps of geometry beside the knight's helmet.
    edge = [part.getpixel((x, y)) for x in range(part.width) for y in (0, part.height - 1)]
    edge += [part.getpixel((x, y)) for y in range(part.height) for x in (0, part.width - 1)]
    background = tuple(sorted(c[i] for c in edge)[len(edge) // 2] for i in range(3))
    canvas = Image.new("RGB", (side, side), background)
    canvas.paste(part, ((side - part.width) // 2, (side - part.height) // 2))
    out = home(a.kit) / "crops" / f"{a.piece}.png"
    canvas.save(out)
    piece["crop"], piece["source"] = list(box), "crop"
    save(a.kit, look)
    write_tripo_sheet(a.kit, look)
    print(f"wrote {rel(out)}; the Tripo list is {rel(home(a.kit) / 'TRIPO.md')}")


def display_name(kit):
    return re.sub(r"(?<=[a-z])(?=[A-Z])", " ", kit)


def style_line(look):
    """The bar in words Midjourney can use on any one piece: no hex codes, no other pieces."""
    bar = look["bar"]
    glow = re.sub(r"\(.*?\)", "", bar["glow"].split(":")[0]).replace("one ", "").strip()
    texture = bar["texture"].replace(";", ",")
    return (f"{texture}, thin seams of {glow} between the plates, hand-painted stylized 3D game asset, "
            "plain dark navy background, no text --ar 1:1")


def draw_prompt(look, name):
    # A look that is not plate armour (the Bouncer's leather jacket and trousers) names each
    # piece itself (`subject` on the piece) and its own material line (`drawStyle`).
    piece = look["pieces"].get(name, {})
    if piece.get("subject"):
        style = look.get("drawStyle") or style_line(look)
        return f"{piece['subject']}, from the {display_name(look['kit'])} in the attached concept, {style}"
    if name == "back":  # cloth, not plate: the armour's texture line would make a steel cape
        return (f"{DRAW[name]}, from the {display_name(look['kit'])} in the attached concept, dark fabric matching "
                "the concept with faint worn texture and a ragged torn hem, hand-painted stylized 3D game asset like a "
                "top Roblox kit, plain dark navy background, no text --ar 3:4")
    return f"{DRAW[name]}, from the {display_name(look['kit'])}'s armour in the attached concept, {style_line(look)}"


def cmd_draw(a):
    from PIL import Image

    look = load(a.kit)
    piece = look["pieces"].get(a.piece)
    if piece is None:
        raise SystemExit(f"{a.piece} is not in this look's plan")
    if not a.image:
        piece.update({"source": "draw", "crop": None})
        save(a.kit, look)
        write_tripo_sheet(a.kit, look)
        print(draw_prompt(look, a.piece))
        print(f"\n(in {rel(home(a.kit) / 'DRAW.md')}; attach concept.jpg as the image reference, then  draw {a.kit} {a.piece} --image <file>)")
        return
    # Midjourney drew the knight's fist as a right hand though the prompt said left, and the
    # mirrored pair landed on the wrong arms (thumbs outside). Say which hand it is, having looked.
    if a.piece in HANDED and not a.hand:
        raise SystemExit(f"look at the drawing and say which hand it is: --hand left|right "
                         "(a fist's thumb is on the right of a left hand seen from the back of the hand)")
    image = Image.open(a.image).convert("RGB")
    out = home(a.kit) / "crops" / f"{a.piece}.png"
    image.save(out)
    piece.update({"source": "drawn", "crop": None, "drawing": os.path.basename(a.image)})
    if a.hand:
        piece["handed"] = a.hand
        if a.hand == "right":
            print("a right hand: the left arm gets its mirror image (handed: right)")
    save(a.kit, look)
    write_tripo_sheet(a.kit, look)
    print(f"filed the drawing as {rel(out)}: it is this piece's Tripo input now")


def cmd_retint(a):
    """Make a piece read as the same steel as the rest: warm patches to the steel hue, scratch
    detail borrowed from another piece, the highlights lifted, paint under the look's glow plates
    darkened, and glow seams in the gaps between plates (glb_matte.retint). Always works from the
    piece as Tripo made it, kept beside it, so it can be re-run with other settings."""
    import glb_matte
    import numpy as np
    from PIL import Image

    look = load(a.kit)
    piece = look["pieces"].get(a.piece)
    if piece is None or not piece.get("file"):
        raise SystemExit(f"{a.piece} has no piece filed")
    current = ROOT / piece["file"]
    original = current.with_name(f"{a.piece}.set-aside-before-retint.glb")
    if not original.exists():
        shutil.copy(current, original)
    part = SLOTS[a.piece]["part"]
    mask = None
    glows = [g for g in look.get("glows", []) if g["part"] == part]
    if glows:
        blend = home(a.kit) / "review" / "assembled.blend"
        if not blend.exists():
            raise SystemExit(f"run  kit_look.py review {a.kit}  first: the glow mask is cast on the fitted piece")
        grids = []
        for i, glow in enumerate(glows):
            out = current.with_name(f"{a.piece}.glow{i}.png")
            (cx, _, cz), (sx, _, sz) = glow["centre"], glow["size"]
            box = [cx - sx / 2 - 0.05, cx + sx / 2 + 0.05, cz - sz / 2 - 0.04, cz + sz / 2 + 0.04]
            subprocess.run([BLENDER, "-b", str(blend), "--python", str(ROOT / "tools/blender/uv_mask.py"), "--",
                            f"{part}__{a.piece}", str(out), "1024", *(str(v) for v in box)],
                           capture_output=True, check=True)
            grids.append(np.asarray(Image.open(out).convert("L")))
            out.unlink()
        mask = current.with_name(f"{a.piece}.glowmask.png")
        Image.fromarray(np.maximum.reduce(grids)).save(mask)
    grain = ROOT / look["pieces"][a.grain_from]["file"] if a.grain_from else None
    changed = glb_matte.retint(original, current, grain_from=grain, dark_mask=mask, seams=a.seams)
    piece["retint"] = {"grainFrom": a.grain_from, "seams": a.seams, "glowMask": bool(mask)}
    save(a.kit, look)
    print(f"{a.piece}: {changed:.0%} of the texture retinted; Tripo's original kept as {rel(original)}")
    print(f"next:  kit_look.py review {a.kit}")


# The Blender finishing pass's settings, tuned on the knight's helmet (2026-11-18). Fractions of
# the piece's largest dimension; see tools/blender/finish_piece.py.
FINISH = {"size": 2048, "samples": 24, "edge": 1.0, "edgeRadius": 0.02, "ridgeStart": 0.998, "ridgeFull": 0.96,
          "cavity": 0.06, "creviceStart": 0.8, "creviceFull": 0.4, "glowAmount": 0.95}


def steel_palette(path):
    """Colour by brightness of a piece that already looks right: the steel, not its glow."""
    import glb_matte
    import numpy as np

    a = np.asarray(glb_matte._texture(path).convert("RGB").resize((1024, 1024))).reshape(-1, 3).astype(float)
    lum = a @ [0.2126, 0.7152, 0.0722]
    blue = a[:, 2] >= a[:, 0]
    stops = []
    for low in range(0, 256, 32):
        chosen = blue & (lum >= low) & (lum < low + 32)
        if chosen.sum() > 50:
            stops.append([round((low + 16) / 255, 3), [round(c / 255, 3) for c in a[chosen].mean(0)]])
    return stops


def cmd_finish(a):
    """The Blender finishing pass (tools/blender/finish_piece.py) on a piece as Tripo made it:
    the steel palette of a piece that already looks right, worn edges and glowing crevices found
    on the 3D shape, baked into the piece's texture; then that piece's scratches on top and the
    paint under any glow plates darkened. Preferred over retint, whose seams follow only paint."""
    import glb_matte

    look = load(a.kit)
    piece = look["pieces"].get(a.piece)
    if piece is None or not piece.get("file"):
        raise SystemExit(f"{a.piece} has no piece filed")
    a.like = a.like or look.get("reference")
    if not a.like:
        raise SystemExit(f"say which piece's steel to match: --like <piece>, or  kit_look.py reference {a.kit} <piece>")
    current = ROOT / piece["file"]
    original = current.with_name(f"{a.piece}.set-aside-before-retint.glb")
    if not original.exists():
        shutil.copy(current, original)
    like = ROOT / look["pieces"][a.like]["file"]
    spec = dict(FINISH, steel=steel_palette(like), glow=a.glow)
    work = home(a.kit) / "review"
    work.mkdir(exist_ok=True)
    spec_path, baked = work / f"finish-{a.piece}.json", work / f"finish-{a.piece}.png"
    spec_path.write_text(json.dumps(spec), encoding="utf-8")
    done = subprocess.run([BLENDER, "-b", "-noaudio", "--python", str(ROOT / "tools/blender/finish_piece.py"), "--",
                           str(original), str(baked), str(spec_path)],
                          capture_output=True, text=True, encoding="utf-8", errors="replace")
    if done.returncode != 0 or not baked.exists():
        sys.stdout.write(done.stdout[-3000:] + done.stderr[-3000:])
        raise SystemExit("the bake failed")
    mask = current.with_name(f"{a.piece}.glowmask.png")
    glb_matte.replace_texture(original, current, baked, dark_mask=mask if mask.exists() else None,
                              grain_from=like if a.scratches else None)
    piece["finish"] = {"like": a.like, "glow": a.glow, "scratches": a.scratches}
    piece.pop("retint", None)
    save(a.kit, look)
    print(f"{a.piece}: finished in Blender like the {a.like}; Tripo's original kept as {rel(original)}")
    print(f"next:  kit_look.py review {a.kit}")


def cmd_reference(a):
    """The one piece whose steel every other piece is finished to match. Pick it at the first
    review: the piece that already looks most like the concept (the knight's shoulder plate)."""
    look = load(a.kit)
    piece = look["pieces"].get(a.piece)
    if piece is None or not piece.get("file"):
        raise SystemExit(f"{a.piece} has no piece filed")
    look["reference"] = a.piece
    save(a.kit, look)
    print(f"{a.piece} is the reference; finish others with  kit_look.py finish {a.kit} <piece> --scratches")


def unfinished_crops(look):
    """Cropped pieces not yet finished in Blender: they carry the concept's painted lighting."""
    return [n for n, p in look["pieces"].items()
            if p.get("file") and p.get("source") == "crop" and not p.get("finish") and n != look.get("reference")]


def cmd_reset(a):
    look = load(a.kit)
    piece = look["pieces"].get(a.piece)
    if piece is None or not piece.get("file"):
        raise SystemExit(f"{a.piece} has no piece filed")
    old = ROOT / piece["file"]
    kept = old.with_name(f"{a.piece}-set-aside-{datetime.date.today().isoformat()}.glb")
    if old.exists():
        old.rename(kept)
    look.setdefault("setAside", []).append({"piece": a.piece, "file": rel(kept)})
    piece.update({"file": None, "triangles": None})
    save(a.kit, look)
    write_tripo_sheet(a.kit, look)
    print(f"set aside as {rel(kept)}; {a.piece} needs making again")


def write_tripo_sheet(kit, look):
    rows = [f"# {kit}: pieces to make in Tripo", "",
            "For each: Image to 3D with the crop, then Export GLB with Retopo, Triangle, at the face count below.",
            "Send the GLB back; it is filed with  kit_look.py intake. Make only the LEFT side of a mirrored piece.", "",
            "| Piece | Tripo input | Faces | What it covers | Done |", "| --- | --- | --- | --- | --- |"]
    drawing = []
    for name, piece in look["pieces"].items():
        slot = SLOTS[name]
        source = piece.get("source")
        if source in ("crop", "drawn") or (source is None and piece["crop"]):
            given = f"crops/{name}.png" + (" (drawn)" if source == "drawn" else "")
        elif source == "draw":
            given = "draw it first: DRAW.md"
            drawing.append(name)
        else:
            given = "not cut yet"
        rows.append(f"| {name} | {given} | {slot['allow']:,} | {slot['about']} | {'yes' if piece['file'] else ''} |")
    (home(kit) / "TRIPO.md").write_text("\n".join(rows) + "\n", encoding="utf-8")
    lines = [f"# {kit}: pieces to draw in Midjourney first", "",
             "These pieces are too small or hidden in the concept to crop. Draw each alone with",
             "concept.jpg attached as the image reference, then put the picture through Tripo at the",
             "face count in TRIPO.md, and send both back.", ""]
    for name in drawing:
        lines += [f"**{name}** ({SLOTS[name]['allow']:,} faces)", "```", draw_prompt(look, name), "```", ""]
    path = home(kit) / "DRAW.md"
    if drawing:
        path.write_text("\n".join(lines), encoding="utf-8")
    elif path.exists():
        path.unlink()


def cmd_intake(a):
    import gltf_post
    import glb_matte
    import outline_check

    look = load(a.kit)
    piece = look["pieces"].get(a.piece)
    if piece is None:
        raise SystemExit(f"{a.piece} is not in this look's plan")
    if not look.get("approved"):
        print("note: the concept is not approved yet; a piece made now may not match it")
    out = home(a.kit) / "pieces" / f"{a.piece}.glb"
    work = home(a.kit) / "pieces" / f"{a.piece}.decoded.glb"
    doc, _ = outline_check.read_glb(a.file)
    packed = set(doc.get("extensionsUsed", [])) & {"EXT_meshopt_compression", "KHR_draco_mesh_compression", "KHR_mesh_quantization"}
    if packed:
        print("decoding", ", ".join(sorted(packed)))
        gltf_post.cli("dequantize", a.file, work)
        source = work
    else:
        source = a.file
    was = glb_matte.matte(source, out, a.matte)
    if work.exists():
        work.unlink()
    if was:
        print("shine: roughness %.2f, metal %.2f -> matte %.2f" % (was[0], was[1], a.matte))
    meshes = glb_triangles(out)
    total = sum(meshes)
    allow = SLOTS[a.piece]["allow"]
    piece.update({"file": rel(out), "triangles": total, "from": os.path.basename(a.file)})
    if a.turn is not None:
        piece["turn"] = a.turn
    piece["flip"] = a.flip
    if a.trim is not None:
        piece["trim"] = a.trim or None
    save(a.kit, look)
    write_tripo_sheet(a.kit, look)
    print(f"{a.piece}: {total:,} triangles in {len(meshes)} mesh(es); allowance {allow:,}")
    if max(meshes, default=0) > MESH_CAP:
        print(f"  FAIL: a mesh is over Roblox's {MESH_CAP:,} cap; re-export from Tripo at {allow:,} faces")
    elif total > allow:
        print(f"  over allowance: fine for review, but re-export at {allow:,} faces before it goes in the game")
    print(f"next: kit_look.py review {a.kit}  (check the facing; fix with --turn on intake)")


def cmd_review(a):
    from PIL import Image, ImageDraw

    look = load(a.kit)
    missing = [k for k in BAR if not look["bar"][k]]
    if missing:
        raise SystemExit(f"the look does not say how it meets the bar: {', '.join(missing)}")
    folder = home(a.kit)
    scene = scene_for(a.kit, look)
    scene_path = folder / "review" / "scene.json"
    scene_path.write_text(json.dumps(scene, indent=2), encoding="utf-8")
    done = subprocess.run(
        [BLENDER, "-b", "-noaudio", "--python", str(ROOT / "tools/blender/assemble_kit_look.py"),
         "--python-exit-code", "1", "--", str(scene_path)],
        capture_output=True, text=True, encoding="utf-8", errors="replace")
    if done.returncode != 0:
        sys.stdout.write(done.stdout[-3000:] + done.stderr[-3000:])
        raise SystemExit("Blender failed")
    report = json.loads((folder / "review" / "report.json").read_text(encoding="utf-8"))
    gaps = report.get("gaps", {})

    # One sheet: the concept and two benchmarks on top, the renders below.
    views = ["front", "quarter", "side", "back", "head", "hands", "pose", "dark"]
    tile_w, tile_h = 420, 520
    top = []
    if look["concept"]:
        top.append(("concept", ROOT / look["concept"]))
    top += [("bar: " + p.stem, p) for p in sorted(BENCHMARKS.glob("*.jpg"))[:2]]
    sheet = Image.new("RGB", (tile_w * 4, (tile_h + 28) * 3), (255, 255, 255))
    draw = ImageDraw.Draw(sheet)
    # Row one: concept and benchmarks. Rows two and three: the renders.
    for start, group in ((0, top), (4, [(v, folder / "review" / f"{v}.png") for v in views])):
        for j, (label, path) in enumerate(group):
            i = start + j
            x, y = (i % 4) * tile_w, (i // 4) * (tile_h + 28)
            im = Image.open(path).convert("RGB")
            if label in gaps:  # mark each hole on the render it shows in
                im = mark_gaps(im, gaps[label]["holes"], label)
                label += f"  GAPS {gaps[label]['area']} sq studs" if gaps[label]["area"] > GAP_LIMIT else ""
            if label.startswith("bar:"):  # a kit screen: keep the character, drop the menus
                w, h = im.size
                im = im.crop((int(w * 0.36), int(h * 0.18), int(w * 0.66), int(h * 0.92)))
            im.thumbnail((tile_w, tile_h))
            sheet.paste(im, (x + (tile_w - im.width) // 2, y + 28 + (tile_h - im.height) // 2))
            draw.text((x + 8, y + 8), label, fill=(0, 0, 0))
    out =folder / "review" / "sheet.png"
    sheet.save(out)

    print(f"sheet: {rel(out)}")
    total = 0
    for name, p in look["pieces"].items():
        count = report["triangles"].get(name)
        mirror = 2 if slot(name).get("mirror") else 1
        if count:
            total += count * mirror
        state = f"{count:,} x{mirror}" if count else "missing (bare body shown)"
        print(f"  {name:13s} {state:28s} allowance {slot(name)['allow']:,}")
    print(f"  character: {total:,} of {CHARACTER_BUDGET:,} triangles" + ("  OVER" if total > CHARACTER_BUDGET else ""))
    for side, gap in gaps.items():
        state = "GAPS: sky shows between torso and arms (red on the sheet)" if gap["area"] > GAP_LIMIT else "closed"
        print(f"  {side} gaps: {gap['area']} sq studs, {state}")
    if not look.get("reference"):
        print(f"  no reference piece: pick the one whose steel looks right,  kit_look.py reference {a.kit} <piece>")
    for name in unfinished_crops(look):
        print(f"  {name}: cropped, not finished; it carries the concept's painted light.  kit_look.py finish {a.kit} {name} --scratches")
    if look.get("glowPlan", "none") != "none" and not look.get("glows"):
        print(f"  glow plates planned ({look['glowPlan']}) but none placed: add them to look.json `glows`")
    if not look.get("team"):
        print(f"  team colour undecided:  kit_look.py bar {a.kit} --team \"...\"")
    print("Look at the sheet beside the benchmarks: does it meet all four lines of the bar?")


def mark_gaps(image, holes, side):
    """Draw review's measured holes onto the front or back render. The camera numbers match
    VIEWS in assemble_kit_look.py (50 mm lens, 36 mm sensor width, 900x1100, distance 16)."""
    from PIL import ImageDraw

    if not holes:
        return image
    w, h = image.size
    focal = 50 / 36 * max(w, h)  # pixels: Blender fits the 36 mm sensor to the longer side
    draw = ImageDraw.Draw(image)
    for x, z in holes:  # holes lie near y = 0, 16 studs from either camera; the slight tilt is ignored
        u = (x if side == "front" else -x) * focal / 16
        v = (z - 3.3) * focal / 16
        cx, cy = w / 2 + u, h / 2 - v
        draw.rectangle((cx - 2, cy - 2, cx + 2, cy + 2), fill=(255, 0, 0))
    return image


TRIPO_MODEL = "P2"  # beat v3.1 on the knight helmet (fewer stray flaps, sharper eyes); 120 vs 40 credits
# Small pieces go on v3.1 at a third of the price: the knight's shin guard on v3.1 was hard to
# tell from its P2 one at game size, with no flaps (2026-11-19). The pieces a player sees up
# close and that carry the design stay on P2.
TRIPO_HERO = {"helmet", "chest", "pauldron"}
TRIPO_SMALL_MODEL = "v3.1"


def unlight_whole(kit, look, model, boxes):
    """Take the picture's coloured rim light out of a whole-body texture, keeping the real glow.
    Tripo paints the picture's lighting into the texture; the Bouncer's magenta rim light came
    out down his sides in the same colour as his glasses. The glow is told apart by place (the
    `boxes`, in the --grid frame), and every other glow-coloured pixel becomes plain leather."""
    import colorsys

    import glb_matte
    import numpy as np
    from PIL import Image, ImageDraw, ImageFilter

    folder = home(kit)
    lit = model.with_name("model.lit.glb")  # Tripo's texture, kept
    if not lit.exists():
        shutil.copy(model, lit)
    work = folder / "review"
    spec = {"source": str(lit), "turn": look["whole"].get("turn", -90), "mask": str(work / "glow-faces.json"),
            "boxes": boxes}
    (work / "glow-mask.json").write_text(json.dumps(spec), encoding="utf-8")
    done = subprocess.run([BLENDER, "-b", "-noaudio", "--python", str(ROOT / "tools/blender/glow_mask.py"),
                           "--python-exit-code", "1", "--", str(work / "glow-mask.json")],
                          capture_output=True, text=True, encoding="utf-8", errors="replace")
    if done.returncode != 0:
        sys.stdout.write(done.stdout[-3000:] + done.stderr[-3000:])
        raise SystemExit("Blender failed")
    faces = json.loads((work / "glow-faces.json").read_text(encoding="utf-8"))
    texture = glb_matte._texture(lit).convert("RGB")
    w, h = texture.size
    mask = Image.new("L", (w, h), 0)
    paint = ImageDraw.Draw(mask)
    for uvs in faces:
        paint.polygon([(u * w, (1 - v) * h) for u, v in uvs], fill=255)  # Blender v runs up the image
    mask = mask.filter(ImageFilter.MaxFilter(9))
    keep = np.asarray(mask) > 127
    rgb = np.asarray(texture).astype(float) / 255
    hue, sat, val = (np.asarray(texture.convert("HSV")).astype(float) / 255).transpose(2, 0, 1)
    glow_hue = colorsys.rgb_to_hsv(*(int(look.get("glowColor", "#FF3CDC")[i:i + 2], 16) / 255 for i in (1, 3, 5)))[0]
    # from violet to pink: the second audit still found lavender rim light down the sleeves and
    # purple on the backs of the boots with only the glow's own hue (+-0.09) caught
    offset = (hue - glow_hue + 0.5) % 1 - 0.5
    near = (offset > -0.16) & (offset < 0.12)
    tinted = near & (sat > 0.1) & ~keep  # 0.18 left a pale pink streak down each sleeve
    # plain leather: the pixel's own lightness, dimmed (the rim light also brightened it), in
    # the leather's own cool near-black
    light = rgb.mean(axis=2) * 0.62
    leather = np.stack([light * 0.98, light * 0.99, light * 1.04], axis=2)  # 1.12 blue read as wet plastic
    out = np.where(tinted[..., None], leather, rgb)
    picture = work / "whole-unlit.png"
    # 1024 is Roblox's texture cap; at Tripo's 4096 every cut part carried a 14 MB copy
    Image.fromarray(np.clip(out * 255, 0, 255).astype(np.uint8)).resize((1024, 1024), Image.LANCZOS).save(picture)
    darken = [b for b in boxes if b.get("darken")]
    if darken:
        # Paint under Neon slats is darkened, or the glasses read twice: bright slats on a bright
        # painted lens (second audit). Same face-finding as the glow mask, for those boxes only.
        spec["boxes"], spec["mask"] = darken, str(work / "darken-faces.json")
        (work / "darken-mask.json").write_text(json.dumps(spec), encoding="utf-8")
        subprocess.run([BLENDER, "-b", "-noaudio", "--python", str(ROOT / "tools/blender/glow_mask.py"),
                        "--python-exit-code", "1", "--", str(work / "darken-mask.json")],
                       capture_output=True, text=True, encoding="utf-8", errors="replace", check=True)
        under = Image.new("L", (1024, 1024), 0)
        paint = ImageDraw.Draw(under)
        for uvs in json.loads((work / "darken-faces.json").read_text(encoding="utf-8")):
            paint.polygon([(u * 1024, (1 - v) * 1024) for u, v in uvs], fill=255)
        image = np.asarray(Image.open(picture).convert("RGB")).astype(float)
        dim = (np.asarray(under.filter(ImageFilter.MaxFilter(5))) > 127)[..., None]
        image = np.where(dim, image * darken[0]["darken"], image)
        Image.fromarray(image.astype(np.uint8)).save(picture)
    glb_matte.replace_texture(lit, model, picture)
    shutil.copy(model, model.with_name("model.unlit.glb"))  # what --detail starts from
    look["whole"]["unlight"] = boxes
    save(kit, look)
    print(f"unlit: {tinted.mean():.1%} of the texture was glow-coloured light; {len(faces)} faces kept glowing "
          f"({keep.mean():.1%} of the texture)")


def detail_whole(kit, look, model, crop):
    """Worn cream edges, darker creases and leather grain over a whole-body model, keeping its
    own paint (tools/blender/finish_piece.py with keepPaint and grain). Tripo saw only the
    front, so the Bouncer's back was flat dark leather and his boots and gloves smooth plastic.
    The grain is a patch of the user's own picture (`crop`, pixels), high-passed so only its
    creases and scuffs are laid on, from all six sides. The glow faces are put back after."""
    import glb_matte
    import numpy as np
    from PIL import Image, ImageDraw, ImageFilter

    folder = home(kit)
    work = folder / "review"
    start = model.with_name("model.unlit.glb")
    if not start.exists():
        shutil.copy(model, start)
    patch = Image.open(folder / "crops" / "whole.png").convert("L").crop(tuple(crop)).resize((512, 512), Image.LANCZOS)
    detail = np.asarray(patch).astype(float) - np.asarray(patch.filter(ImageFilter.GaussianBlur(14))).astype(float)
    grain = work / "whole-grain.png"
    Image.fromarray(np.clip(128 + detail * 3.0, 0, 255).astype(np.uint8)).save(grain)
    spec = dict(FINISH, size=1024, keepPaint=True, grain=str(grain), grainScale=5.0, grainAmount=0.9,
                steel=[[0, [0, 0, 0]], [1, [1, 1, 1]]], edge=0.3, ridgeFull=0.985, edgeColor=[0.59, 0.5, 0.41],  # 0-1, not 0-255
                glow="#07080B", glowAmount=0.6)  # stitch= (finish_piece.py) hatched whole patches, not seams: off
    spec_path, baked = work / "whole-detail.json", work / "whole-detail.png"
    spec_path.write_text(json.dumps(spec), encoding="utf-8")
    done = subprocess.run([BLENDER, "-b", "-noaudio", "--python", str(ROOT / "tools/blender/finish_piece.py"), "--",
                           str(start), str(baked), str(spec_path)],
                          capture_output=True, text=True, encoding="utf-8", errors="replace")
    if done.returncode != 0 or not baked.exists():
        sys.stdout.write(done.stdout[-3000:] + done.stderr[-3000:])
        raise SystemExit("the bake failed")
    # Put back exactly as it was: the glow (overlay and edges dull the glasses and zip) and the
    # whole head (worn edges painted bronze tips on every spike of the Bouncer's hair).
    out = Image.open(baked).convert("RGB")
    before = glb_matte._texture(start).convert("RGB").resize(out.size)
    keep = list(look["whole"].get("unlight", []))
    if look["whole"].get("marks"):
        keep.append({"x": [-9, 9], "z": [look["whole"]["marks"]["neck"], 9], "front": False})
    faces_file = work / "keep-faces.json"
    mask_spec = {"source": str(start), "turn": look["whole"].get("turn", -90), "mask": str(faces_file), "boxes": keep}
    (work / "keep-mask.json").write_text(json.dumps(mask_spec), encoding="utf-8")
    subprocess.run([BLENDER, "-b", "-noaudio", "--python", str(ROOT / "tools/blender/glow_mask.py"),
                    "--python-exit-code", "1", "--", str(work / "keep-mask.json")],
                   capture_output=True, text=True, encoding="utf-8", errors="replace", check=True)
    if keep:
        mask = Image.new("L", out.size, 0)
        paint = ImageDraw.Draw(mask)
        for uvs in json.loads(faces_file.read_text(encoding="utf-8")):
            paint.polygon([(u * out.width, (1 - v) * out.height) for u, v in uvs], fill=255)
        kept = mask.filter(ImageFilter.MaxFilter(5))
        # charcoal, not black: black on the navy kit screen all but vanished (second audit)
        rgb = np.asarray(out).astype(float)
        grey = rgb.mean(axis=2, keepdims=True)
        rgb = grey + (rgb - grey) * 0.45  # the picture's navy light read as blue steel, not leather
        # Tone: a charcoal floor (pure black vanished on the kit screen) and a soft ceiling on
        # the picture's painted highlights, which a second audit read as chrome on the sleeves.
        rgb = 9 + rgb * 0.9
        rgb = np.where(rgb > 70, 70 + (rgb - 70) * 0.35, rgb)
        lifted = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8))
        out = Image.composite(before, lifted, kept)
    out.save(baked)
    glb_matte.replace_texture(start, model, baked)
    glb_matte.matte(model, model, 0.95)  # the leather read as wet plastic at 0.85
    look["whole"]["detail"] = {"grainFrom": crop}
    save(kit, look)
    print(f"detailed: worn edges, creases and grain baked into {rel(model)}")


def cmd_skinned(a):
    """The whole-body model prepared for Studio's Avatar Setup against the match body
    (docs/design/kits/MATCH_BODY.md; tools/blender/prepare_avatar_setup.py): accessories off,
    fitted to the match joint heights in an A-pose, fused watertight, paint baked. Writes
    assets/kit-looks/<Kit>/skinned/: Body.glb, Hair.glb, Headgear.glb, <Kit>-AvatarSetup.fbx,
    previews and prepare.json. The rigid cut (`whole`) stays as the comparison."""
    look = load(a.kit)
    whole = look.get("whole", {})
    if not whole.get("model") or not whole.get("marks"):
        raise SystemExit(f"cut the whole-body model first:  kit_look.py whole {a.kit} --marks ...")
    marks = {k: v for k, v in (json.loads(a.marks) if a.marks else whole["marks"]).items()
             if k not in ("collar", "decimate", "overlap", "overlapHip", "handScale", "caps", "tuck")}
    out = home(a.kit) / a.name
    source = os.path.abspath(a.source) if a.source else str(ROOT / whole["model"])
    turn = a.turn if a.turn is not None else whole.get("turn", -90)
    spec = {"source": source, "out": str(out), "turn": turn,
            "marks": marks, "swing": a.swing, "voxel": 0.004, "faces": a.faces, "texture": 1024,
            "fbx": f"{a.kit}-AvatarSetup.fbx", "cage": a.cage}
    out.mkdir(exist_ok=True)
    (out / "prepare-spec.json").write_text(json.dumps(spec, indent=1), encoding="utf-8")
    done = subprocess.run([BLENDER, "-b", "-noaudio", "--python", str(ROOT / "tools/blender/prepare_avatar_setup.py"),
                           "--python-exit-code", "1", "--", str(out / "prepare-spec.json")],
                          capture_output=True, text=True, encoding="utf-8", errors="replace")
    if done.returncode != 0:
        sys.stdout.write(done.stdout[-3000:] + done.stderr[-3000:])
        raise SystemExit("Blender failed")
    write_fbx(out, spec["fbx"])
    report = json.loads((out / "prepare.json").read_text(encoding="utf-8"))
    look.setdefault(a.name, {}).update({"prepared": report, "stage": "prepared for Avatar Setup",
                                       "source": rel(Path(source)) if a.source else whole["model"]})
    save(a.kit, look)
    print(json.dumps(report, indent=1))
    a.folder = str(out)
    cmd_audit(a)


AUDIT_SHEETS = {
    # the back three-quarter leads: it is the view players see most in a third-person shooter
    "views": ["view-back-three-quarter", "view-back", "view-front", "view-three-quarter", "view-right", "view-left"],
    "close-front": [f"close-{n}-front" for n in ("head", "chest", "hips", "boots", "hand-left", "hand-right")],
    "close-back": [f"close-{n}-back" for n in ("head", "chest", "hips", "boots", "hand-left", "hand-right")],
}


def skinned_build(folder):
    """Hashes of what a skinned folder hands to Studio: the parts and the FBX."""
    import hashlib

    files = sorted([*folder.glob("*.glb"), *folder.glob("*.fbx")])
    return {f.name: hashlib.sha256(f.read_bytes()).hexdigest()[:16] for f in files}


def cmd_audit(a):
    """Render the visual audit of a skinned look: six views, front and back close-ups and each
    accessory alone. It runs before anything is reported or handed over, whatever the route
    (the DarkArmour trial went to the user with floating debris nobody had looked at). Then read
    every sheet and record what you saw with `findings`; `ready` refuses until you have."""
    from PIL import Image

    folder = Path(a.folder).resolve()
    if not (folder / "Body.glb").exists():
        raise SystemExit(f"no Body.glb in {folder}")
    done = subprocess.run([BLENDER, "-b", "-noaudio", "--python", str(ROOT / "tools/blender/audit_skinned.py"),
                           "--python-exit-code", "1", "--", str(folder)],
                          capture_output=True, text=True, encoding="utf-8", errors="replace")
    if done.returncode != 0:
        sys.stdout.write(done.stdout[-3000:] + done.stderr[-3000:])
        raise SystemExit("Blender failed")
    audit = folder / "audit"
    if (folder / "joints-front.png").exists():  # where the joints were measured, drawn on the model
        shutil.copyfile(folder / "joints-front.png", audit / "joints-front.png")
    # movement belongs to the audit too: poses with the rifle held, and the shoulder camera
    poses = audit / "poses"
    done = subprocess.run([BLENDER, "-b", "-noaudio", "--python", str(ROOT / "tools/blender/pose_matrix.py"),
                           "--python-exit-code", "1", "--", str(folder), "--out", str(poses)],
                          capture_output=True, text=True, encoding="utf-8", errors="replace")
    if done.returncode != 0:
        sys.stdout.write(done.stdout[-3000:] + done.stderr[-3000:])
        raise SystemExit("pose test failed")
    matrix = json.loads((poses / "pose-matrix.json").read_text(encoding="utf-8"))
    body = next(iter(matrix["bodies"].values()))
    for pose in matrix["poses"]:
        for view in ("front", "side", "camera"):
            tile = poses / f"{folder.name}-{pose}-{view}.png"
            if tile.exists():
                shutil.copyfile(tile, audit / f"pose-{pose}-{view}.png")
    sheets = dict(AUDIT_SHEETS)
    sheets["alone"] = sorted(p.stem for p in audit.glob("alone-*.png"))
    sheets["joints"] = ["joints-front"] if (audit / "joints-front.png").exists() else []
    sheets["poses-front"] = [f"pose-{p}-front" for p in matrix["poses"]]
    sheets["poses-side"] = [f"pose-{p}-side" for p in matrix["poses"]]
    sheets["camera"] = sorted(p.stem for p in audit.glob("pose-*-camera.png"))
    made = []
    for name, tiles in sheets.items():
        if not tiles:
            continue
        w, h = (350, 400) if name == "views" else (330, 330)
        if name == "camera":
            w, h = 640, 360
        elif name.startswith("poses"):
            w, h = 260, 310
        elif name == "joints":
            w, h = 700, 700
        sheet = Image.new("RGB", (w * len(tiles), h), "white")
        for i, t in enumerate(tiles):
            tile = Image.open(audit / f"{t}.png").convert("RGBA")
            backdrop = Image.new("RGBA", tile.size, (200, 205, 212, 255))  # camera tiles are transparent
            backdrop.alpha_composite(tile)
            tile = backdrop.convert("RGB")
            if name == "camera":  # the crosshair, where the Weapons Kit draws it
                from PIL import ImageDraw

                d, (tw, th) = ImageDraw.Draw(tile), tile.size
                d.line([(tw / 2 - 18, th / 2), (tw / 2 + 18, th / 2)], fill=(255, 0, 0), width=3)
                d.line([(tw / 2, th / 2 - 18), (tw / 2, th / 2 + 18)], fill=(255, 0, 0), width=3)
            sheet.paste(tile.resize((w, h)), (i * w, 0))
        sheet.save(audit / f"sheet-{name}.png")
        made.append(f"sheet-{name}.png")
    moves = {pose: {k: v for k, v in r.items()} for pose, r in body["poses"].items()}
    state = {"rendered": datetime.datetime.now().isoformat(timespec="seconds"), "build": skinned_build(folder),
             "sheets": made, "weights": body["weights"], "poses": moves, "findings": None}
    worst = max(r["stretchedOver2x"] for r in moves.values())
    barrel = max(r.get("rifleThroughBody", {}).get("front", 0) for r in moves.values())
    cover = max(r.get("crosshairCovered", 0) for r in moves.values())
    print(f"moves: weights {body['weights']}; worst stretch {worst:.2%}; rifle barrel through body "
          f"{barrel} faces at worst; crosshair covered {cover:.0%} at worst")
    (audit / "status.json").write_text(json.dumps(state, indent=1), encoding="utf-8")
    print("audit sheets:", ", ".join(rel(audit / s) for s in made))
    print(f"NOT READY: read every sheet, then  kit_look.py findings {rel(folder)} --defects \"...\" --passed \"...\"")


def cmd_findings(a):
    """Record what the audit sheets showed, for this exact build."""
    folder = Path(a.folder).resolve()
    status = folder / "audit" / "status.json"
    if not status.exists():
        raise SystemExit(f"no audit yet:  kit_look.py audit {rel(folder)}")
    state = json.loads(status.read_text(encoding="utf-8"))
    if state["build"] != skinned_build(folder):
        raise SystemExit(f"the files changed since the audit was rendered; run  kit_look.py audit {rel(folder)}  again")
    state["findings"] = {"recorded": datetime.datetime.now().isoformat(timespec="seconds"),
                         "defects": a.defects, "passed": a.passed}
    status.write_text(json.dumps(state, indent=1), encoding="utf-8")
    print(f"findings recorded for {rel(folder)}")


def audit_ready(folder):
    """None when the audit covers this build and has findings; otherwise why not."""
    status = folder / "audit" / "status.json"
    if not status.exists():
        return "never audited"
    state = json.loads(status.read_text(encoding="utf-8"))
    if state["build"] != skinned_build(folder):
        return "files changed since the audit"
    if not state.get("findings"):
        return "audit rendered but no findings recorded"
    return None


def cmd_ready(a):
    """Exit 1 unless the folder's current files have an audit with recorded findings. Run it before
    sending any FBX or GLB to the user."""
    folder = Path(a.folder).resolve()
    why = audit_ready(folder)
    if why:
        print(f"NOT READY {rel(folder)}: {why}")
        raise SystemExit(1)
    state = json.loads((folder / "audit" / "status.json").read_text(encoding="utf-8"))
    print(f"ready {rel(folder)}: audited {state['rendered']}; defects: {state['findings']['defects']}")


TPOSE_PROMPT = (
    "Turn the character to face the camera straight on, standing upright in a T-pose: both arms "
    "straight out to the sides at shoulder height, fully inside the picture with both hands visible, "
    "legs straight with the feet a little apart, clear empty background between the arms and the "
    "body and between the legs. Light it flat and even from the front with neutral white studio "
    "light: no coloured light, no rim light, no strong shadows or reflections, so the colours are "
    "the character's own. Keep the same character, face, hair, clothes, armour, colours, "
    "proportions and style. Plain light grey background."
)


def tpose_prompt(remove):
    """The T-pose edit, plus anything the picture has that the look should not (`--remove`):
    the generator copies whatever is in the picture, so a detail is taken out here, before the
    3D model, where it costs one edit instead of a texture repair."""
    if not remove:
        return TPOSE_PROMPT
    things = "; ".join(remove)
    return (TPOSE_PROMPT + f" Remove {things} completely; where it was, continue the surrounding "
            "material and colour seamlessly, with nothing new added in its place.")


BACK_PROMPT = ("Rotate the camera 180 degrees around the character to show it from directly behind: we see "
               "the back of the head, the back of the armour and clothing and the backs of the legs. Do not "
               "show the face. Keep exactly the same character: same body, proportions, armour, clothing, "
               "colours, hair, materials and art style, same T-pose with arms straight out at shoulder height, "
               "same scale and position in the frame, same flat even neutral white light, plain light grey "
               "background.")


BACK_MIN_CHANGE = 0.37


def back_score(front_path, back_path):
    """Is a Kontext back view really the back? Kontext sometimes returns the front again with the hair
    turned (DarkArmourAuto back seed 1). A real back: the silhouette matches the mirrored front (IoU >=
    0.8), the face's skin is mostly gone from the top quarter, and it differs from the front picture by
    at least BACK_MIN_CHANGE of the front's own colour spread. Relative, because an all-black character
    changes little in absolute terms: failed backs scored 0.06 (BouncerAuto) and 0.32 (DarkArmourAuto),
    real ones 0.42, 0.42 (BouncerAuto) and 0.67 (DarkArmourAuto). The score is that ratio."""
    import numpy as np
    from PIL import Image

    def load(p):
        im = np.asarray(Image.open(p).convert("RGB").resize((256, 256)), dtype=np.float32) / 255
        corner = np.concatenate([im[:6, :6].reshape(-1, 3), im[:6, -6:].reshape(-1, 3)]).mean(0)
        mask = np.abs(im - corner).max(2) > 0.08
        rows = np.where(mask.any(1))[0]
        top = rows.min() + int(0.25 * (rows.max() - rows.min()))
        r, g, b = im[..., 0], im[..., 1], im[..., 2]
        # Check the central face region, not horns or other gold accessories at
        # the sides of the head. Those can remain visible from behind.
        cols = np.where(mask.any(0))[0]
        centre = (int(cols.min()) + int(cols.max())) // 2
        half = max(1, int((cols.max() - cols.min()) * 0.105))
        skin = ((r > 0.55) & (r > g) & (g > b) & (r - b > 0.15) & mask)[:top, max(0, centre-half):min(256, centre+half)].sum()
        return im, mask, skin

    fa, fm, fskin = load(front_path)
    ba, bm, bskin = load(back_path)
    mirrored = bm[:, ::-1]
    iou = float((fm & mirrored).sum() / max((fm | mirrored).sum(), 1))
    spread = float(np.abs(fa - fa[fm].mean(0)).mean(2)[fm].mean())
    diff = float(np.abs(fa - ba).mean(2)[fm & bm].mean()) / max(spread, 1e-4)
    face_gone = bool(fskin < 50 or bskin < 0.3 * fskin)
    usable = bool(iou >= 0.8 and diff >= BACK_MIN_CHANGE and face_gone)
    return usable, diff, f"silhouette {iou:.2f}, changed {diff:.2f}, face skin {bskin}/{fskin}"


def tpose_score(path):
    """How usable a T-pose edit is, from its silhouette alone: (usable, score, notes). Usable means
    nothing touches the side edges and the arms are spread; the score prefers symmetry."""
    import numpy as np
    from PIL import Image

    im = np.asarray(Image.open(path).convert("RGB")).astype(np.int32)
    h, w, _ = im.shape
    corners = np.concatenate([im[:8, :8].reshape(-1, 3), im[:8, -8:].reshape(-1, 3)])
    bg = np.median(corners, axis=0)
    mask = np.abs(im - bg).sum(axis=2) > 60
    cols, rows = np.where(mask.any(axis=0))[0], np.where(mask.any(axis=1))[0]
    if not len(cols):
        return False, 0.0, "no character found"
    edge = int(w * 0.02)
    touches = mask[:, :edge].any() or mask[:, -edge:].any()
    spread = (cols[-1] - cols[0]) / max(1, rows[-1] - rows[0])
    centre = (cols[0] + cols[-1]) // 2
    half = min(centre - cols[0], cols[-1] - centre)
    left = mask[:, centre - half:centre]
    right = mask[:, centre:centre + half][:, ::-1]
    sym = (left & right).sum() / max(1, (left | right).sum())
    usable = bool((not touches) and spread > 0.8)
    notes = f"spread {spread:.2f}, symmetry {sym:.2f}" + (", touches the edge" if touches else "")
    return usable, float(sym + min(spread, 1.2) * 0.2), notes


def run_blender(script, *args):
    done = subprocess.run([BLENDER, "-b", "-noaudio", "--python", str(ROOT / "tools/blender" / script),
                           "--python-exit-code", "1", "--", *map(str, args)],
                          capture_output=True, text=True, encoding="utf-8", errors="replace")
    if done.returncode != 0:
        sys.stdout.write(done.stdout[-3000:] + done.stderr[-3000:])
        raise SystemExit(f"{script} failed")
    return done.stdout


def write_fbx(folder, name):
    """The Avatar Setup FBX from a prepared folder's GLBs, in studs and facing the camera, read back
    (tools/blender/write_fbx.py). The first Studio trial imported at 605 studs, facing away."""
    run_blender("write_fbx.py", folder, name)
    check = json.loads((Path(folder) / "fbx-check.json").read_text(encoding="utf-8"))
    print(f"fbx: {check['file']} {check['heightStuds']} studs tall, front {check['frontInFile']}, "
          f"parts {', '.join(check['parts'])}")


def cmd_fbx(a):
    """Rewrite a prepared folder's FBX from its GLBs, then re-audit it (the FBX is part of the build)."""
    folder = Path(a.folder).resolve()
    name = next((f.name for f in folder.glob("*-AvatarSetup.fbx")), f"{folder.parent.name}-AvatarSetup.fbx")
    write_fbx(folder, name)
    cmd_audit(a)


def cmd_character(a):
    """One user picture to a skinned body ready for Studio's Avatar Setup, with no stops:
    widened canvas -> FLUX.1 Kontext T-pose edit in neutral light (best seed picked from its
    silhouette) -> TRELLIS.2 (free) -> joints measured off the mesh -> prepare_avatar_setup.py ->
    audit (views, close-ups, accessories, joints, poses with a rifle, shoulder camera) -> STUDIO.md.
    Each stage keeps its output, so a rerun after a GPU-quota stop starts at the first missing one.
    The only steps left to people: approving the picture, and the Studio run itself."""
    from gradio_client import Client, handle_file
    from PIL import Image

    out = Path(a.out).resolve() if a.out else ROOT / "assets" / "kit-looks" / "trials" / a.name
    for sub in ("source", "tpose", "trellis", "skinned"):
        (out / sub).mkdir(parents=True, exist_ok=True)
    token = os.environ.get("HF_TOKEN")

    wide = out / "source" / "picture-wide.png"
    if not wide.exists():
        if not a.image:
            raise SystemExit("--image is needed the first time")
        shutil.copyfile(a.image, out / "source" / ("picture" + Path(a.image).suffix.lower()))
        im = Image.open(a.image).convert("RGB")
        w, h = im.size
        bg = tuple(sum(c) // 4 for c in zip(im.getpixel((5, 5)), im.getpixel((w - 6, 5)),
                                           im.getpixel((5, h // 2)), im.getpixel((w - 6, h // 2))))
        # A square canvas with a margin, so arms straightened out to the sides still fit. Square alone was
        # not enough for a picture that is already square (CodeHoodTripo: all three edits touched the edge).
        side = int(max(w, h) * 1.3)
        canvas = Image.new("RGB", (side, side), bg)
        canvas.paste(im, ((side - w) // 2, (side - h) // 2))
        canvas.save(wide)
        print("1 canvas widened")

    pick_file = out / "tpose" / "pick.json"
    if a.remove is None and pick_file.exists():
        # a rerun without --remove keeps the earlier list; only a different list redoes the edit
        a.remove = json.loads(pick_file.read_text(encoding="utf-8")).get("remove") or None
    prompt = tpose_prompt(a.remove)
    if pick_file.exists() and json.loads(pick_file.read_text(encoding="utf-8")).get("prompt") != prompt:
        # a different edit: everything made from the old one is set aside (kept, not deleted)
        aside = out / "superseded" / datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
        aside.mkdir(parents=True)
        for sub in ("tpose", "trellis", "tripo", "skinned"):
            if (out / sub).exists():
                shutil.move(str(out / sub), str(aside / sub))
                (out / sub).mkdir()
        print(f"2 the edit changed; the earlier build is kept in {rel(aside)}")
    if not pick_file.exists():
        client = Client("black-forest-labs/FLUX.1-Kontext-Dev", token=token, verbose=False)
        scored = []
        for seed in range(1, a.seeds + 1):
            target = out / "tpose" / f"seed-{seed}.png"
            if not target.exists():
                result = client.predict(input_image=handle_file(str(wide)), prompt=prompt, seed=seed,
                                        randomize_seed=False, guidance_scale=2.5, steps=28, api_name="/infer")
                image = result[0] if isinstance(result, (list, tuple)) else result
                shutil.copyfile(image.get("path") if isinstance(image, dict) else image, target)
            usable, score, notes = tpose_score(target)
            scored.append({"seed": seed, "usable": usable, "score": round(score, 3), "notes": notes})
            print(f"2 T-pose seed {seed}: {notes}{'' if usable else ' (not usable)'}")
        good = [x for x in scored if x["usable"]]
        if not good:
            raise SystemExit("no T-pose edit was usable; rerun with --seeds higher, or check the picture")
        best = max(good, key=lambda x: x["score"])
        pick_file.write_text(json.dumps({"prompt": prompt, "remove": a.remove or [], "seeds": scored, "picked": best["seed"]}, indent=1),
                             encoding="utf-8")
    picked = json.loads(pick_file.read_text(encoding="utf-8"))["picked"]
    print(f"2 T-pose: seed {picked}")

    # The back view comes first: TRELLIS gets it painted on afterwards, Tripo takes it as an input.
    # Side views were tried and dropped: Kontext draws a T-pose in profile with the arms reaching forward
    # (8 of 8 tries, DarkArmourAuto/multiview, 2026-11-20).
    front_pic = out / "tpose" / f"seed-{picked}.png"
    pick = json.loads(pick_file.read_text(encoding="utf-8"))
    if "back" not in pick:
        client = Client("black-forest-labs/FLUX.1-Kontext-Dev", token=token, verbose=False)
        tried = []
        for seed in range(1, a.seeds + 1):
            target = out / "tpose" / f"back-{seed}.png"
            if not target.exists():
                result = client.predict(input_image=handle_file(str(front_pic)), prompt=BACK_PROMPT, seed=seed,
                                        randomize_seed=False, guidance_scale=2.5, steps=28, api_name="/infer")
                image = result[0] if isinstance(result, (list, tuple)) else result
                shutil.copyfile(image.get("path") if isinstance(image, dict) else image, target)
            usable, score, notes = back_score(front_pic, target)
            tried.append({"seed": seed, "usable": usable, "score": round(score, 3), "notes": notes})
            print(f"3a back view seed {seed}: {notes}{'' if usable else ' (not usable)'}")
            if usable:
                break  # each try is a GPU call; the first that passes is good enough
        good = [x for x in tried if x["usable"]]
        pick["back"] = max(good, key=lambda x: x["score"])["seed"] if good else None
        pick["backTried"] = tried
        pick_file.write_text(json.dumps(pick, indent=1), encoding="utf-8")
    back_pic = out / "tpose" / f"back-{pick['back']}.png" if pick["back"] else None

    if a.generator == "tripo":
        source, turn, prep = tripo_character(a, out, front_pic, back_pic)
    else:
        source, turn, prep = trellis_character(out, token, front_pic, back_pic, picked)

    folder = out / "skinned"
    joints = folder / "joints.json"
    if not joints.exists():
        run_blender("measure_joints.py", source, turn, joints)
    measured = json.loads(joints.read_text(encoding="utf-8"))
    print(f"4 joints measured: neck {measured['marks']['neck']}, hip {measured['marks']['hip']}, "
          f"arm line {measured['marks']['shoulder'][1]} (drawn on joints-front.png)")
    marks = dict(measured["marks"])
    if not prep["hairCut"]:
        marks.pop("hairCut", None)

    spec = {"source": str(source), "out": str(folder), "turn": turn, "swing": 0, "voxel": 0.004, "faces": a.faces,
            "texture": 1024, "fbx": f"{a.name}-AvatarSetup.fbx", "cage": prep["cage"],
            "headgearIsHair": not a.headgear, "marks": marks}
    (folder / "prepare-spec.json").write_text(json.dumps(spec, indent=1), encoding="utf-8")
    if not (folder / "Body.glb").exists() or a.rebuild:
        for part in ("Body", "Hair", "Headgear"):  # a rebuild with no hair must not ship the old Hair.glb
            for f in (folder / f"{part}.glb", folder / f"{part}Color.png"):
                f.unlink(missing_ok=True)
        run_blender("prepare_avatar_setup.py", folder / "prepare-spec.json")
    if not (folder / "fbx-check.json").exists() or a.rebuild:
        write_fbx(folder, spec["fbx"])
    report =json.loads((folder / "prepare.json").read_text(encoding="utf-8"))
    print(f"5 prepared: body {report['bodyTriangles']:,} triangles, {report['bodyOpenEdges']} open edges, "
          f"hair {report.get('HairTriangles', 0):,}, debris dropped {report.get('debrisFacesDropped', 0):,}")

    (folder / "STUDIO.md").write_text(STUDIO_TEMPLATE.format(name=a.name, fbx=spec["fbx"]), encoding="utf-8")
    a.folder = str(folder)
    cmd_audit(a)


def trellis_character(out, token, front_pic, back_pic, picked):
    """TRELLIS.2 (free) from the T-pose, then the pictures painted back on. TRELLIS rebuilds the shape well
    but repaints it and guesses the back. Returns (source GLB, turn, prep settings)."""
    from gradio_client import Client, handle_file

    model = out / "trellis" / "model.glb"
    if not model.exists():
        client = Client("microsoft/TRELLIS.2", token=token, verbose=False)
        client.predict(api_name="/start_session")
        prepared = client.predict(input=handle_file(str(front_pic)), api_name="/preprocess_image")
        prepared = prepared.get("path") if isinstance(prepared, dict) else prepared
        client.predict(image=handle_file(prepared), seed=101, resolution="1024", api_name="/image_to_3d")
        result = client.predict(decimation_target=300000, texture_size=2048, api_name="/extract_glb")
        glb = result[0] if isinstance(result, (list, tuple)) else result
        shutil.copyfile(glb.get("path") if isinstance(glb, dict) else glb, model)
    print(f"3 TRELLIS model: {rel(model)}")
    painted = out / "trellis" / "model-painted.glb"
    if not painted.exists():
        front_only = out / "trellis" / "model-projected.glb"
        run_blender("project_picture.py", model, front_pic, front_only, "--front", "-y", "--texture", 2048,
                    "--report", out / "trellis" / "project.json")
        if back_pic:
            run_blender("project_picture.py", front_only, back_pic, painted,
                        "--front", "+y", "--texture", 2048, "--report", out / "trellis" / "project-back.json")
        else:
            print("3b no usable back view: the back keeps TRELLIS's paint")
            shutil.copyfile(front_only, painted)
    print(f"3b painted: front from seed {picked}, back from {back_pic.name if back_pic else 'TRELLIS'} -> {rel(painted)}")
    # TRELLIS fuses spiky hair onto the head and its surfaces are noisy: cut the hair off at the measured
    # height and bake through a wide cage.
    return painted, 0, {"cage": 6, "hairCut": True}


def tripo_character(a, out, front_pic, back_pic):
    """Tripo multi-view from the T-pose and the back view (paid: about 120 credits with detailed texture).
    Without --confirm it prints the estimate and stops. Tripo P2 writes the front along +x, hence the
    turn of -90; write_fbx's toe check fails the build if that ever changes.
    Prep settings from the DarkArmourTripo trial (2026-11-20): a bake cage of 1 voxel (wider cages pulled
    the hidden face inside the collar and under the hair lock onto the jaw as jagged brown) and no hair
    cut (Tripo's hair hugs the head; cutting it left a gap line at the hairline and dropped the streak)."""
    if not back_pic:
        raise SystemExit("no usable back view: Tripo multi-view needs one; rerun with --seeds higher")
    model = out / "tripo" / "model.glb"
    model.parent.mkdir(exist_ok=True)
    if not model.exists():
        env = tripo_env()
        args = ["make", str(front_pic), str(back_pic), "-p", "texture=true", "-p", "pbr=false",
                "-p", "texture_quality=detailed", "--name", f"{a.name.lower()}-multiview",
                "-o", str(out / "tripo" / "out"), "--no-open", "--yes", "--quiet", "--json"]
        estimate = tripo_run(env, args + ["--dry-run"]).get("generation_credits_estimate")
        balance = tripo_run(env, ["balance", "--json"]).get("balance")
        print(f"3 Tripo multi-view: about {estimate} credits; balance {balance}")
        if not a.confirm:
            raise SystemExit("dry run: nothing spent. Add --confirm to make it.")
        result = tripo_run(env, args)
        if result.get("status") != "success" or not result.get("model_file"):
            raise SystemExit(f"Tripo failed: {str(result.get('error') or result.get('status'))[:300]}")
        shutil.copyfile(result["model_file"], model)
        print(f"3 Tripo: {result.get('credits_consumed')} credits; balance now "
              f"{tripo_run(env, ['balance', '--json']).get('balance')}")
    print(f"3 Tripo model: {rel(model)}")
    return model, -90, {"cage": 1, "hairCut": False}


STUDIO_TEMPLATE = """# {name}: Avatar Setup in Studio

Made by `python tools/kit_look.py character {name}`: T-pose edit, TRELLIS.2, joints measured off
the mesh, prepared against the match body (docs/design/kits/MATCH_BODY.md). Before this goes to
anyone, `python tools/kit_look.py ready <this folder>` must pass.

1. **New place.** Studio > New > Baseplate (a scratch place).
2. **Import.** Home > Import 3D > `{fbx}`. Turn **Upload To Roblox off**, then Import. The file is
   written in studs facing the camera (`fbx-check.json`), so do **not** rescale or rotate anything.
   Check the body is about 6 studs tall and its face points the same way as the Front of the view
   cube. If either is wrong, stop and report it: turning parts one at a time moves the hair
   off the head (the first trial did that).
   Note: "Upload To Roblox off" does not stop Studio creating Roblox assets. Import and Avatar
   Setup still create private assets for the meshes and textures on your account. Nothing is
   published to the Marketplace.
3. **Arrange.** Make a Folder `{name}` in Workspace. Inside it, put each part in a Model of its own
   with the same name (`Body`, `Hair`, plus `Headgear` if there is one). Delete the empty import model.
4. **Open Avatar Setup.** Select the folder, then Avatar tab > Avatar Setup.
5. **Configure.** Preset: Development Avatar. Type: Body for `Body`, Rigid for the rest. Gear icon:
   **Reduce triangle count off**, **Handle face as 2D decal on**.
6. **Set Up.** If it errors, copy the error word for word and stop. If it asks what a part is,
   `Headgear` (visor, headset) is a hat or face **accessory**, never Face itself.
7. **Check Body > Animations.** Play idle, walk and jump. Screenshot each from the front and side.
   If the head stretches into spikes in idle but not in jump, a facial animation is pulling it: in a
   copy of the finished character delete `FaceControls` and play idle again, and note whether the spikes stop.
8. **Save to File.** Right-click the finished character in Explorer > Save to File, as
   `{name}Rig.rbxm` in this folder. Not the Save button inside Avatar Setup: that uploads.

Send back: any error word for word, the two screenshots, and the `.rbxm`.
"""


def cmd_whole(a):
    """One model of the whole character from one picture, cut at the R15 joints. The Bouncer made
    piece by piece from nine pictures looked like "a lot of random pieces put together"; one model
    shares one texture. Steps, one flag per call:
      --image <png>          the user's whole-body A-pose picture becomes the Tripo input
      --make [--confirm]     Tripo P2 on it at WHOLE_FACES (prints the cost without --confirm)
      --model-file <glb>     file a model made elsewhere (Tripo's site) instead
      --grid                 a front view with a measuring grid, to read the joints off
      --marks '<json>'       the joints read off the grid; cuts the model and makes it the look
    The cut model also goes to Studio's Avatar Setup as is (see the kit-look skill)."""
    import glb_matte
    from PIL import Image, ImageDraw

    look = load(a.kit)
    folder = home(a.kit)
    whole = look.setdefault("whole", {})
    picture = folder / "crops" / "whole.png"
    model = folder / "pieces" / "whole" / "model.glb"
    if a.image:
        picture.parent.mkdir(exist_ok=True)
        Image.open(a.image).convert("RGB").save(picture)
        whole.update({"drawing": os.path.basename(a.image)})
        save(a.kit, look)
        print(f"filed {rel(picture)} as the whole-body Tripo input; next  kit_look.py whole {a.kit} --make")
        return
    if a.make:
        if not picture.exists():
            raise SystemExit(f"no whole-body picture yet:  kit_look.py whole {a.kit} --image <file>")
        env = tripo_env()
        out = folder / "tripo" / "whole"
        args = ["make", str(picture), "--model", a.model or TRIPO_MODEL, "-p", f"face_limit={WHOLE_FACES}",
                "-p", "texture=true", "-p", "pbr=false", "-p", "texture_quality=detailed",
                "--name", f"{a.kit.lower()}-whole", "-o", str(out), "--no-open", "--yes", "--quiet", "--json"]
        estimate = tripo_run(env, args + ["--dry-run"]).get("generation_credits_estimate")
        balance = tripo_run(env, ["balance", "--json"]).get("balance")
        print(f"whole body on {a.model or TRIPO_MODEL}: about {estimate} credits; balance {balance}")
        if not a.confirm:
            print("dry run: nothing spent. Add --confirm to make it.")
            return
        result = tripo_run(env, args)
        if result.get("status") != "success" or not result.get("model_file"):
            raise SystemExit(f"Tripo failed: {str(result.get('error') or result.get('status'))[:300]}")
        print(f"{result.get('credits_consumed')} credits; balance now", tripo_run(env, ["balance", "--json"]).get("balance"))
        a.model_file = result["model_file"]
    if a.model_file:
        model.parent.mkdir(parents=True, exist_ok=True)
        glb_matte.matte(a.model_file, model, 0.85)
        whole.update({"model": rel(model), "from": os.path.basename(a.model_file), "triangles": sum(glb_triangles(model))})
        save(a.kit, look)
        print(f"filed {rel(model)} ({whole['triangles']:,} triangles); next  kit_look.py whole {a.kit} --grid")
        return
    if not model.exists():
        raise SystemExit(f"no whole-body model yet:  kit_look.py whole {a.kit} --make")
    if a.unlight or a.detail:
        if a.unlight:
            unlight_whole(a.kit, look, model, json.loads(a.unlight))
        if a.detail:
            detail_whole(a.kit, look, model, json.loads(a.detail))
        if not (a.marks or whole.get("marks")):
            return
        a.marks = a.marks or json.dumps(whole["marks"])  # re-cut with the cleaned texture (new marks win)
    work = folder / "review"
    work.mkdir(exist_ok=True)
    spec = {"source": str(model), "out": str(folder / "pieces" / "whole"), "turn": whole.get("turn", -90)}
    if a.grid:
        spec["grid"] = str(work / "whole-front.png")
    elif a.marks:
        import glb_matte
        import numpy as np

        whole["marks"] = json.loads(a.marks)
        spec["marks"] = whole["marks"]
        # one near-black, colourless texel to paint the lids on every cut (split_whole_body.py)
        pixels = np.asarray(glb_matte._texture(model).convert("RGB").resize((256, 256))).astype(float)
        darkness = pixels.mean(axis=2) + (pixels.max(axis=2) - pixels.min(axis=2)) * 2
        darkness[:8, :] = darkness[-8:, :] = darkness[:, :8] = darkness[:, -8:] = 999  # not on an edge
        y, x = np.unravel_index(np.argmin(darkness), darkness.shape)
        spec["capUV"] = [(x + 0.5) / 256, 1 - (y + 0.5) / 256]
    else:
        raise SystemExit("say what to do: --image, --make, --model-file, --grid or --marks")
    spec_path = work / "whole-split.json"
    spec_path.write_text(json.dumps(spec), encoding="utf-8")
    done = subprocess.run([BLENDER, "-b", "-noaudio", "--python", str(ROOT / "tools/blender/split_whole_body.py"),
                           "--python-exit-code", "1", "--", str(spec_path)],
                          capture_output=True, text=True, encoding="utf-8", errors="replace")
    if done.returncode != 0:
        sys.stdout.write(done.stdout[-3000:] + done.stderr[-3000:])
        raise SystemExit("Blender failed")
    if a.grid:
        frame = json.loads((work / "whole-front.json").read_text(encoding="utf-8"))
        im = Image.open(work / "whole-front.png").convert("RGB")
        draw = ImageDraw.Draw(im)
        px = frame["pixels"] / frame["side"]  # pixels per model unit

        def to_px(x, z):
            return frame["pixels"] / 2 + x * px, frame["pixels"] / 2 - (z - frame["centre"][1]) * px

        step = frame["height"] / 40
        for i in range(-40, 41):
            x0, _ = to_px(i * step, 0)
            _, z0 = to_px(0, i * step)
            colour = (255, 0, 0) if i % 5 == 0 else (150, 150, 255)
            draw.line([(x0, 0), (x0, frame["pixels"])], fill=colour, width=1)
            draw.line([(0, z0), (frame["pixels"], z0)], fill=colour, width=1)
            if i % 5 == 0:
                draw.text((x0 + 2, 2), f"{i * step:.3f}", fill=(255, 0, 0))
                draw.text((2, z0 + 2), f"{i * step:.3f}", fill=(255, 0, 0))
        im.save(work / "whole-grid.png")
        whole["frame"] = frame
        save(a.kit, look)
        print(f"grid: {rel(work / 'whole-grid.png')}  (lines every {step:.4f} units; +x is the character's left, "
              f"on the viewer's right)")
        print("read the joints off it, then  kit_look.py whole " + a.kit + " --marks '{\"neck\": z, \"waist\": z, "
              "\"hip\": z, \"knee\": z, \"ankle\": z, \"shoulder\": [x, z], \"elbow\": [x, z], \"wrist\": [x, z], "
              "\"armRadius\": r}'")
        return
    split = json.loads((folder / "pieces" / "whole" / "split.json").read_text(encoding="utf-8"))
    missing = [p for p in R15_PARTS if p not in split["triangles"]]
    if look["pieces"] and not all(n in R15_PARTS for n in look["pieces"]):
        look.setdefault("setAside", {})["pieces"] = look["pieces"]
        look.setdefault("setAside", {})["glows"] = look.get("glows", [])
        look["glows"] = []
        look.pop("reference", None)
    look["pieces"] = {p: {"file": rel(folder / "pieces" / "whole" / f"{p}.glb"), "turn": 0, "source": "whole",
                          "triangles": split["triangles"][p]} for p in R15_PARTS if p in split["triangles"]}
    look.pop("verdict", None)
    save(a.kit, look)
    for p in R15_PARTS:
        print(f"  {p:13s} {split['triangles'].get(p, 0):,} triangles")
    if missing:
        print("  MISSING (no faces landed there; check the marks):", ", ".join(missing))
    print(f"next:  kit_look.py review {a.kit}")


def tripo_model(name, chosen=None):
    return chosen or (TRIPO_MODEL if name in TRIPO_HERO else TRIPO_SMALL_MODEL)


def tripo_env():
    """The CLI reads TRIPO_API_KEY. The user keeps the key in a Windows user variable named
    TRIPO_API; read it from there if this shell predates it. The key is never printed."""
    env = dict(os.environ, TRIPO_ANALYTICS_ENABLED="0")
    if not env.get("TRIPO_API_KEY"):
        key = env.get("TRIPO_API")
        if not key and os.name == "nt":
            import winreg

            try:
                with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as reg:
                    key = winreg.QueryValueEx(reg, "TRIPO_API")[0]
            except OSError:
                key = None
        if not key:
            raise SystemExit("no Tripo key: set TRIPO_API_KEY (or the TRIPO_API user variable), or run  tripo login")
        env["TRIPO_API_KEY"] = key
    return env


def tripo_run(env, args):
    exe = shutil.which("tripo")
    if not exe:
        raise SystemExit("the Tripo CLI is not installed:  npm install -g tripo-cli")
    done = subprocess.run([exe, *args], capture_output=True, text=True, encoding="utf-8", errors="replace", env=env)
    try:
        return json.loads(done.stdout)
    except json.JSONDecodeError:
        return {"error": (done.stdout + done.stderr)[-600:]}


def cmd_make(a):
    """Run pieces through Tripo image-to-3D at their face counts, then intake each result."""
    from concurrent.futures import ThreadPoolExecutor

    look = load(a.kit)
    if not look.get("approved"):
        raise SystemExit("the concept is not approved; pieces are made from an approved concept only")
    wanted = a.pieces.split(",") if a.pieces else [n for n, p in look["pieces"].items() if not p["file"]]
    jobs = []
    for name in wanted:
        piece = look["pieces"].get(name)
        source = home(a.kit) / "crops" / f"{name}.png"
        if piece is None or piece.get("source") not in ("crop", "drawn") or not source.exists():
            print(f"  {name}: no Tripo input yet (crop or drawing) -- skipped")
            continue
        jobs.append((name, source))
    if not jobs:
        raise SystemExit("nothing to make")
    env = tripo_env()

    def args_for(name, source, dry):
        out = home(a.kit) / "tripo" / name
        return ["make", str(source), "--model", tripo_model(name, a.model), "-p", f"face_limit={SLOTS[name]['allow']}",
                "-p", "texture=true", "-p", "pbr=false", "-p", "texture_quality=detailed",
                "--name", f"{a.kit.lower()}-{name}", "-o", str(out), "--no-open", "--yes", "--quiet", "--json"] + (
                    ["--dry-run"] if dry else [])

    estimate = sum(tripo_run(env, args_for(n, s, True)).get("generation_credits_estimate", 0) for n, s in jobs)
    balance = tripo_run(env, ["balance", "--json"]).get("balance")
    models = ", ".join(f"{n} {tripo_model(n, a.model)}" for n, _ in jobs)
    print(f"{len(jobs)} piece(s) ({models}): about {estimate:,} credits; balance {balance}")
    if not a.confirm:
        print("dry run: nothing spent. Add --confirm to make them.")
        return
    with ThreadPoolExecutor(max_workers=6) as pool:
        results = list(pool.map(lambda job: (job[0], tripo_run(env, args_for(job[0], job[1], False))), jobs))
    for name, result in results:
        model = result.get("model_file")
        if result.get("status") != "success" or not model:
            print(f"  {name}: FAILED {str(result.get('error') or result.get('status'))[:300]}")
            continue
        print(f"  {name}: {result.get('credits_consumed')} credits")
        intake = argparse.Namespace(kit=a.kit, piece=name, file=model, turn=None, matte=0.85, flip=False, trim=None)
        cmd_intake(intake)
    print("balance now", tripo_run(env, ["balance", "--json"]).get("balance"))


def cmd_verdict(a):
    """The user's own words about the review sheet, tied to the exact sheet and pieces they saw."""
    import hashlib

    look = load(a.kit)
    sheet = home(a.kit) / "review" / "sheet.png"
    if not sheet.exists():
        raise SystemExit("no review sheet yet: run  kit_look.py review")
    if a.said.strip().lower() in ("continue", "ok", "go", "next"):
        raise SystemExit("that is not a verdict on how it looks; record the user's words about the sheet")
    report = json.loads((home(a.kit) / "review" / "report.json").read_text(encoding="utf-8"))
    open_gaps = {s: g["area"] for s, g in report.get("gaps", {}).items() if g["area"] > GAP_LIMIT}
    if a.looks == "good" and open_gaps and not a.gaps_ok:
        raise SystemExit(f"review measured sky through the torso and arms {open_gaps} (sq studs, red on the sheet). "
                         "Close it (fillWidth, sleeve, slot centres) and review again, or record why it is fine "
                         "with --gaps-ok \"...\"")
    pieces = {n: hashlib.sha256((ROOT / p["file"]).read_bytes()).hexdigest()[:16]
              for n, p in look["pieces"].items() if p["file"]}
    look["verdict"] = {"looks": a.looks, "said": a.said, "on": datetime.date.today().isoformat(),
                       "sheet": hashlib.sha256(sheet.read_bytes()).hexdigest()[:16], "pieces": pieces,
                       "gaps": report.get("gaps") and {s: g["area"] for s, g in report["gaps"].items()}}
    if a.gaps_ok:
        look["verdict"]["gapsOk"] = a.gaps_ok
    save(a.kit, look)
    print(f"recorded: the user says {a.kit} looks {a.looks} ({len(pieces)} pieces)")


UPLOADER = ROOT / "tools/roblox/upload_asset.ps1"


def registry_key(kit):
    return re.sub(r"(?<=[a-z])(?=[A-Z])", "-", kit).lower() + "-look"


def scene_for(kit, look, export=None):
    folder = home(kit)
    scene = {
        "out": str(folder / "review"),
        "bodyColor": look["bodyColor"],
        "glows": look.get("glows", []),
        "pieces": [
            {"name": name, "file": str(ROOT / p["file"]), "turn": p["turn"], "flip": p.get("flip", False),
             "trim": p.get("trim"), "handed": p.get("handed"), **slot(name), **p.get("slot", {})}
            for name, p in look["pieces"].items() if p["file"]
        ],
    }
    if export:
        scene["export"] = str(export)
    return scene


def cmd_export(a):
    """The approved look as one game model plus where each piece attaches, into the asset registry."""
    import hashlib

    import asset_rules as rules

    look = load(a.kit)
    verdict = look.get("verdict")
    if not verdict or verdict["looks"] != "good":
        raise SystemExit("no good verdict from the user on the review sheet:  kit_look.py verdict")
    now = {n: hashlib.sha256((ROOT / p["file"]).read_bytes()).hexdigest()[:16]
           for n, p in look["pieces"].items() if p["file"]}
    if now != verdict["pieces"]:
        changed = sorted(set(now.items()) ^ set(verdict["pieces"].items()))
        raise SystemExit(f"pieces changed since the user approved the look ({changed}); review and ask again")
    folder = home(a.kit)
    out = folder / "exports" / f"{a.kit}Look.glb"
    out.parent.mkdir(exist_ok=True)
    scene_path = folder / "exports" / "scene.json"
    scene_path.write_text(json.dumps(scene_for(a.kit, look, out), indent=2), encoding="utf-8")
    done = subprocess.run([BLENDER, "-b", "-noaudio", "--python", str(ROOT / "tools/blender/assemble_kit_look.py"),
                           "--python-exit-code", "1", "--", str(scene_path)],
                          capture_output=True, text=True, encoding="utf-8", errors="replace")
    if done.returncode != 0 or not out.exists():
        sys.stdout.write(done.stdout[-3000:] + done.stderr[-3000:])
        raise SystemExit("export failed")
    import glb_matte

    glb_matte.shrink_textures(out, out)  # Tripo ships 4096 textures; Roblox caps them at 1024
    manifest = json.loads(out.with_suffix(".json").read_text(encoding="utf-8"))
    counts = glb_triangles(out)
    total = sum(counts)
    if max(counts) > MESH_CAP:
        raise SystemExit(f"a mesh has {max(counts):,} triangles; Roblox rejects over {MESH_CAP:,}")
    brief = {"purpose": f"{display_name(a.kit)} kit look: armour pieces welded to an R15 character in matches",
             "role": "interactive", "route": "scan", "kind": "prop", "share": "game",
             "made": "Midjourney concept and drawings by the user; Tripo P2 image-to-3D; fitted by kit_look.py"}
    (folder / "brief.json").write_text(json.dumps(brief, indent=2) + "\n", encoding="utf-8")
    (folder / "provenance.json").write_text(json.dumps({
        "concept": look["concept"], "approved": look["approved"], "verdict": verdict,
        "pieces": {n: {"from": p.get("from"), "source": p.get("source")} for n, p in look["pieces"].items()},
        "generator": "Tripo API (tripo-cli), model P2", "rights": "made for this game",
    }, indent=2) + "\n", encoding="utf-8")
    registry = rules.read_registry()
    key = registry_key(a.kit)
    entry = registry.get(key, {})
    entry.update({
        "package": rel(folder), "role": "interactive", "route": "scan", "kind": "prop", "share": "game",
        "export": rel(out), "exportSha256": rules.sha256(str(out)), "triangles": total,
        "gameName": a.kit,
        "budgetWaiver": (f"A whole kit character, budgeted at {CHARACTER_BUDGET:,} triangles for ten on a phone "
                         "(kit_look.py CHARACTER_BUDGET), not as one interactive prop."),
        "kitLook": {"pieces": [{k: m[k] for k in ("mesh", "part", "offset", "covers")} for m in manifest["pieces"]],
                    "hides": manifest["hides"], "sleeves": manifest.get("sleeves", []),
                    "glows": manifest.get("glows", []), "bodyColor": look["bodyColor"],
                    "templateTorsoHeight": manifest["template"]["UpperTorso"]["size"][2]},
    })
    registry[key] = entry
    rules.write_registry(registry)
    print(f"exported {rel(out)}: {len(counts)} meshes, {total:,} triangles, {out.stat().st_size / 1e6:.1f} MB; "
          f"registry entry {key}")
    if entry.get("assetId") and entry.get("uploadedSha256") != entry["exportSha256"]:
        print("  the uploaded asset is an older export: publish again")
    print(f"next:  kit_look.py publish {a.kit}   (dry run), then --confirm with the user's go-ahead")


def cmd_publish(a):
    import asset_rules as rules

    key = registry_key(a.kit)
    entry = rules.read_registry().get(key)
    if not entry:
        raise SystemExit(f"{key} is not exported yet:  kit_look.py export {a.kit}")
    command = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(UPLOADER),
               "-File", str(ROOT / entry["export"]), "-Description", f"{display_name(a.kit)} kit look"]
    if not a.confirm:
        done = subprocess.run(command + ["-DryRun"], capture_output=True, text=True, encoding="utf-8", errors="replace")
        print(done.stdout.strip()[-1500:])
        print(f"dry run only. Upload with  kit_look.py publish {a.kit} --confirm  once the user says go.")
        return
    done = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace")
    found = re.search(r"(?:Uploaded|Previously uploaded) asset: (\d+)", done.stdout)
    if not found:
        raise SystemExit("upload did not report an asset id: " + (done.stdout + done.stderr)[-600:])
    rules.record_upload(key, int(found.group(1)), entry["exportSha256"])
    print(f"uploaded asset {found.group(1)}; recorded in the registry as {key}")


def cmd_status(a):
    look = load(a.kit)
    print(json.dumps({k: look[k] for k in ("bar", "concept", "approved")}, indent=2))
    for name, p in look["pieces"].items():
        source = {"crop": "cropped", "draw": "to draw (DRAW.md)", "drawn": "drawn"}.get(p.get("source"), "not started")
        print(f"  {name:9s} {source:18s}  piece {p['file'] or '-'}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("plan")
    p.add_argument("kit")
    p.add_argument("--pieces")
    p = sub.add_parser("bar")
    p.add_argument("kit")
    for key in BAR:
        p.add_argument("--" + key)
    p.add_argument("--glow-plates", help="what must truly glow in game (Neon plates), e.g. 'eyes'; or 'none'")
    p.add_argument("--team", help="how team colour reads on this look")
    p = sub.add_parser("reference")
    p.add_argument("kit")
    p.add_argument("piece", help="the piece whose steel the others are finished to match")
    p = sub.add_parser("concept")
    p.add_argument("kit")
    p.add_argument("--image")
    p = sub.add_parser("approve")
    p.add_argument("kit")
    p.add_argument("--said", required=True)
    p = sub.add_parser("crop")
    p.add_argument("kit")
    p.add_argument("piece")
    for key in ("x0", "y0", "x1", "y1"):
        p.add_argument(key, type=int)
    p.add_argument("--unapproved", action="store_true", help="cut for a trial before approval")
    p.add_argument("--force", action="store_true", help="cut a crop under MIN_CROP anyway")
    p = sub.add_parser("draw")
    p.add_argument("kit")
    p.add_argument("piece")
    p.add_argument("--image", help="the Midjourney picture of this piece")
    p.add_argument("--hand", choices=("left", "right"), help="which hand the drawing is (required for a fist)")
    p = sub.add_parser("retint")
    p.add_argument("kit")
    p.add_argument("piece")
    p.add_argument("--grain-from", help="a piece whose scratches and edges to borrow (the shoulder plate)")
    p.add_argument("--seams", help="glow colour for the gaps between plates, e.g. #FF7A1E")
    p = sub.add_parser("finish")
    p.add_argument("kit")
    p.add_argument("piece")
    p.add_argument("--like", help="a piece whose steel already looks right; default the look's reference")
    p.add_argument("--glow", default="#FF7A1E", help="colour baked into crevices")
    p.add_argument("--scratches", action="store_true", help="lay the --like piece's scratches over the steel")
    p = sub.add_parser("reset")
    p.add_argument("kit")
    p.add_argument("piece")
    p = sub.add_parser("intake")
    p.add_argument("kit")
    p.add_argument("piece")
    p.add_argument("file")
    p.add_argument("--turn", type=float)
    p.add_argument("--matte", type=float, default=0.85)
    p.add_argument("--flip", action="store_true", help="the piece came out upside down")
    p.add_argument("--trim", type=float, help="keep only this bottom fraction of the height (a tall boot: 0.4); 0 clears it")
    p = sub.add_parser("make")
    p.add_argument("kit")
    p.add_argument("--pieces", help="comma list; default every piece not filed yet")
    p.add_argument("--model", help="one model for every piece; default P2 for helmet, chest and shoulder, v3.1 for the rest")
    p.add_argument("--confirm", action="store_true", help="spend the credits (without it: estimate only)")
    p = sub.add_parser("whole")
    p.add_argument("kit")
    p.add_argument("--image")
    p.add_argument("--make", action="store_true")
    p.add_argument("--confirm", action="store_true")
    p.add_argument("--model", help="Tripo model; default P2")
    p.add_argument("--model-file")
    p.add_argument("--grid", action="store_true")
    p.add_argument("--marks")
    p.add_argument("--unlight", help="glow boxes as JSON; recolours the rest of the glow-coloured light")
    p.add_argument("--detail", help="[x0, y0, x1, y1] leather patch of the picture: worn edges, creases, grain")
    p = sub.add_parser("skinned")
    p.add_argument("kit")
    p.add_argument("--swing", type=float, default=20, help="degrees the arms are swung out to an A-pose")
    p.add_argument("--faces", type=int, default=12000, help="body triangles after fusing")
    p.add_argument("--source", help="another whole-body GLB of the same picture (e.g. TRELLIS); uses the same marks")
    p.add_argument("--turn", type=float, help="degrees about Z that face --source to -Y (whole.turn otherwise)")
    p.add_argument("--name", default="skinned", help="output folder under the kit, so routes sit side by side")
    p.add_argument("--cage", type=float, default=3, help="bake cage, in voxels")
    p.add_argument("--marks", help="joints of --source as JSON (model units), when its pose differs; hairCut too")
    p = sub.add_parser("audit")
    p.add_argument("folder", help="a prepared skinned folder (Body.glb, Hair.glb, ...)")
    p = sub.add_parser("findings")
    p.add_argument("folder")
    p.add_argument("--defects", required=True, help="what the sheets showed wrong, most severe first, or 'none'")
    p.add_argument("--passed", required=True, help="what was checked and held up")
    p = sub.add_parser("fbx", help="rewrite a prepared folder's FBX (studs, front +Z, read back), then re-audit")
    p.add_argument("folder")
    p = sub.add_parser("ready")
    p.add_argument("folder")
    p = sub.add_parser("character")
    p.add_argument("name", help="folder name; assets/kit-looks/trials/<name> unless --out")
    p.add_argument("--image", help="the user's picture of the character (any pose)")
    p.add_argument("--out", help="output folder")
    p.add_argument("--seeds", type=int, default=3, help="T-pose edits to try (free, GPU quota)")
    p.add_argument("--faces", type=int, default=12000, help="body triangles")
    p.add_argument("--headgear", action="store_true", help="keep above-neck pieces as headgear, not hair")
    p.add_argument("--rebuild", action="store_true", help="re-run the prep even if Body.glb exists")
    p.add_argument("--generator", choices=("trellis", "tripo"), default="trellis",
                   help="trellis: free (HF GPU quota); tripo: multi-view from the T-pose and back view, paid")
    p.add_argument("--confirm", action="store_true", help="spend the Tripo credits the dry run printed")
    p.add_argument("--remove", action="append",
                   help="a detail in the picture the look should not have, e.g. 'the magenta zip down the "
                        "front of the jacket' (repeatable); a changed list redoes the edit onward")
    p = sub.add_parser("review")
    p.add_argument("kit")
    p = sub.add_parser("verdict")
    p.add_argument("kit")
    p.add_argument("--looks", choices=("good", "bad"), required=True)
    p.add_argument("--said", required=True)
    p.add_argument("--gaps-ok", help="why review's measured gaps are acceptable (the user's reason)")
    p = sub.add_parser("export")
    p.add_argument("kit")
    p = sub.add_parser("publish")
    p.add_argument("kit")
    p.add_argument("--confirm", action="store_true")
    p = sub.add_parser("status")
    p.add_argument("kit")
    a = parser.parse_args()
    {"plan": cmd_plan, "bar": cmd_bar, "concept": cmd_concept, "approve": cmd_approve, "crop": cmd_crop,
     "draw": cmd_draw, "reference": cmd_reference, "reset": cmd_reset, "retint": cmd_retint, "finish": cmd_finish, "make": cmd_make, "verdict": cmd_verdict,
     "export": cmd_export, "publish": cmd_publish,
     "intake": cmd_intake, "review": cmd_review, "whole": cmd_whole, "skinned": cmd_skinned, "status": cmd_status,
     "audit": cmd_audit, "findings": cmd_findings, "ready": cmd_ready, "character": cmd_character, "fbx": cmd_fbx}[a.cmd](a)


if __name__ == "__main__":
    main()
