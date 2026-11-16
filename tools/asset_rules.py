"""The rules every pipeline asset is held to, in one place.

tools/asset_generate.py calls these; tools/check_asset_registry.luau enforces the same
numbers in CI by reading the registry this module writes. Nothing here calls a network.

  budgets      total triangles allowed per role (the 10,000 cap is per mesh, so it does
               not stop a 70,000-triangle vehicle)
  contract     the written GLB is the height the brief says and sits on its pivot
  registry     src/shared/AssetRegistry.json: asset ids, file hashes, Studio checks.
               Rojo syncs it as a ModuleScript, so game code and tools read one file.
  claim        one session works on a package at a time
  provenance   where the reference and the mesh came from
  reference    is an image a usable reference (plain light background, nothing cropped)
  calibration  surface-error scores beside a human verdict, to move the gate's lines
"""

import glob
import hashlib
import json
import os
import socket
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
REGISTRY = os.path.join(ROOT, "src", "shared", "AssetRegistry.json")

# Total triangles across every mesh of one asset. Starting values, chosen so a phone can
# draw several copies of a close-up asset at once; they are judgment, not measurement.
# Change them here and in tools/check_asset_registry.luau together.
ROLE_BUDGETS = {
    "held": 4000,  # in a hand or on a character
    "interactive": 15000,  # ridden, driven, opened: players are right beside it
    "cover": 10000,  # visual shell around a map block
    "decor": 30000,  # a prop walked past
    "scenery": 60000,  # large and only ever seen from a distance
}
# Roles a player is close enough to that a reduced scan reads as broken.
CLOSE_ROLES = ("held", "interactive")

HEIGHT_TOLERANCE = 0.05  # export height against the brief
PIVOT_TOLERANCE = 0.03  # of the largest dimension

CLAIM_HOURS = 4  # a claim older than this is treated as abandoned
STUDIO_CHECKS = ("loads", "facing", "scale", "materials", "collision")

# Surface-error scores measured before verdicts were recorded per package.
CALIBRATION_SEED = [
    ("wave runner, 70,045 tris in 12 meshes", 0.040, "good"),
    ("broken tank export", 0.061, "good"),
    ("wave runner, 33,994 tris in 4 meshes", 0.231, "bad"),
    ("wave runner, 9,000 tris in 1 mesh", 0.347, "bad"),
]


# What to ask the user before writing a brief: (key, question, how the answer is used).
# One message, all at once, skipping anything the request already answers. After that the
# run is hands-off. `asset_generate.py questions` prints this list for any model to use.
INTAKE = [
    ("purpose", "What is it, in one sentence?", "--purpose"),
    ("where", "Which map or place does it go in?", "--where"),
    (
        "use",
        "What does a player do with it? (a) walk past it  (b) take cover behind it  (c) drive or ride it  "
        "(d) hold it, like a gun or tool  (e) only see it far away  (f) open or use it some other way",
        "a: --role decor --kind prop | b: --role cover --kind prop | c: --role interactive --kind vehicle | "
        "d: --role held --kind weapon | e: --role scenery --kind prop | f: --role interactive --kind prop",
    ),
    ("size", "How big is it? Studs, or a comparison such as 'as tall as a player' (a player is about 5.5 studs).", "--height, and --length for a gun"),
    ("reference", "Do you have a picture of it (give the file), or should one be generated? Realistic, stylized or blocky?", "generate <image>, or reference --style"),
    ("copies", "About how many will be on screen at once?", "--copies; many copies of a heavy model is what slows phones down"),
    ("moving", "Does any part need to move by itself, such as wheels, a door or a rotor?", "--moving; moving parts mean the clean route, built as separate pieces"),
    (
        "kindDetail",
        "Only for a vehicle or gun. Vehicle: land, water or air, and how many seats? "
        "Gun: which existing weapon should it behave like, and what is it called in game?",
        "--game-name; seats become mounts; the existing weapon is the kit base in tools/build_weapons.luau",
    ),
    ("share", "Will it stay in this game, or might you sell it or give it away?", "--share game|public; public needs the rights note in provenance.json filled in"),
    ("stop", "Should I stop at the finished local build for your approval (the default), or also upload once you approve the pictures?", "nothing is ever uploaded without approval"),
]
# Answers a brief must hold before anything is generated.
INTAKE_REQUIRED = ("purpose", "role", "kind", "heightStuds", "where", "copies", "share")


def intake_text():
    lines = ["Ask the user these in ONE message before writing the brief. Skip any the request already answers.", ""]
    for number, (_, question, use) in enumerate(INTAKE, 1):
        lines.append(f"{number:>2}. {question}")
        lines.append(f"      -> {use}")
    lines += ["", "If they say 'you decide' to one, choose, and say what you chose in the final report.", "After the answers, run the whole flow without further questions and report once."]
    return "\n".join(lines)


def rel(path):
    return os.path.relpath(path, ROOT).replace("\\", "/")


def read_json(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(data, handle, indent=2)
        handle.write("\n")


def sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


# ------------------------------------------------------------------- budgets


def budget_check(brief, total):
    """Is `total` triangles within what the brief's role allows?"""
    budget = ROLE_BUDGETS[brief["role"]]
    waiver = (brief.get("budgetWaiver") or "").strip()
    within = total <= budget
    return {
        "role": brief["role"],
        "budget": budget,
        "triangles": total,
        "waiver": waiver or None,
        "passed": within or bool(waiver),
        "within": within,
    }


# ------------------------------------------------------------------ contract


# What a model needs beyond its shape before game code can use it. A mount is a named
# point in studs from the pivot, in Roblox axes: +X right, +Y up, -Z forward.
#   vehicle  DriverSeat: where the driver's seat part goes. HullCentre: where the centre of
#            the invisible physics block sits (for a boat, this sets the waterline).
#            Extra seats are any further mounts named Passenger...
#   weapon   Grip: where the hand holds it. Muzzle: where shots and flash leave.
KINDS = {"prop": (), "vehicle": ("DriverSeat", "HullCentre"), "weapon": ("Grip", "Muzzle")}
KIND_ROLE = {"vehicle": "interactive", "weapon": "held"}
MOUNT_SLACK = 0.15  # a mount may sit this far outside the bounding box, as a share of the largest dimension


def roblox_triangles(export):
    """The export's triangles as Roblox will hold them: the glTF import turns a model half
    a turn about the vertical, so glTF +Z (a Blender builder's front) becomes Roblox -Z."""
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import outline_check

    tris = outline_check.triangles(export).copy()
    tris[..., 0] *= -1
    tris[..., 2] *= -1
    return tris


def mount_problems(brief, low, high):
    """What is missing or implausible about the brief's mounts for its kind."""
    kind = brief.get("kind", "prop")
    mounts = brief.get("mounts") or {}
    problems = [f"kind {kind} needs a {name} mount: asset_generate.py brief <name> --mount {name}=x,y,z" for name in KINDS[kind] if name not in mounts]
    size = high - low
    slack = float(size.max()) * MOUNT_SLACK
    for name, point in mounts.items():
        outside = [axis for axis, label in enumerate("xyz") if not low[axis] - slack <= point[axis] <= high[axis] + slack]
        if outside:
            problems.append(f"mount {name} at {tuple(point)} is outside the model along " + ", ".join("xyz"[a] for a in outside))
    if kind == "weapon":
        if size[2] < max(size[0], size[1]):
            problems.append("a weapon's long axis must run front to back (z); this one is longest another way")
        if "Grip" in mounts and "Muzzle" in mounts:
            if mounts["Muzzle"][2] >= mounts["Grip"][2]:
                problems.append("the Muzzle is not in front of the Grip (front is -z); the model or the mounts are backwards")
            if mounts["Muzzle"][2] - low[2] > size[2] * 0.2:
                problems.append("the Muzzle is not near the front end of the model")
    if kind == "vehicle" and "DriverSeat" in mounts and mounts["DriverSeat"][1] <= low[1]:
        problems.append("the DriverSeat is at or below the bottom of the model")
    return problems


def mounts_sheet(tris, brief, path):
    """Side and top outline with FRONT marked and every mount drawn where the brief puts it.

    This is the one picture that shows which end the pipeline believes is the front."""
    from PIL import Image, ImageDraw

    flat = tris.reshape(-1, 3)
    low, high = flat.min(0), flat.max(0)
    centre = (low + high) / 2
    cell, margin = 520, 60
    scale = (cell - 2 * margin) / (float((high - low).max()) or 1.0)
    # (title, axis drawn across with its sign, axis drawn up with its sign). Front (-z) is to the left.
    views = (("side: front is left, up is up", (2, 1.0), (1, 1.0)), ("top: front is left, the model's right is up", (2, 1.0), (0, 1.0)))
    sheet = Image.new("RGB", (cell * len(views), cell), "white")
    draw = ImageDraw.Draw(sheet)
    for index, (title, (ax, asign), (ux, usign)) in enumerate(views):
        left = index * cell

        def place(point, left=left, ax=ax, asign=asign, ux=ux, usign=usign):
            x = left + cell / 2 + (point[ax] - centre[ax]) * asign * scale
            y = cell / 2 - (point[ux] - centre[ux]) * usign * scale
            return x, y

        for tri in tris:
            draw.polygon([place(corner) for corner in tri], fill=(196, 200, 208))
        draw.text((left + 12, 10), title, fill="black")
        draw.text((left + 12, cell / 2 - 6), "FRONT", fill=(0, 110, 60))
        for name, point in (brief.get("mounts") or {}).items():
            x, y = place(point)
            draw.ellipse((x - 6, y - 6, x + 6, y + 6), fill=(210, 40, 40), outline="white")
            draw.text((x + 9, y - 7), name, fill=(150, 20, 20))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sheet.save(path)


def contract_check(export, brief, sheet_path=None):
    """Size, pivot and mounts of the written file against the brief, in Roblox axes.

    A model the wrong size or off its pivot still imports; it then floats, sinks or sits
    beside its spawn point, and that is found in Studio one restart at a time. The same
    goes for a gun whose muzzle is behind its grip."""
    tris = roblox_triangles(export)
    points = tris.reshape(-1, 3)
    low, high = points.min(0), points.max(0)
    size = high - low
    largest = float(size.max()) or 1.0
    problems = []
    want = float(brief["heightStuds"])
    if abs(size[1] - want) > want * HEIGHT_TOLERANCE:
        problems.append(f"height is {size[1]:.2f} studs, the brief says {want:g}")
    pivot = brief.get("pivot", "bottom")
    slack = largest * PIVOT_TOLERANCE
    if pivot != "origin":
        for axis, label in ((0, "x"), (2, "z")):
            centre = (low[axis] + high[axis]) / 2
            if abs(centre) > slack:
                problems.append(f"off centre by {centre:+.2f} studs along {label}")
        anchor = {"bottom": low[1], "top": high[1], "center": (low[1] + high[1]) / 2}[pivot]
        if abs(anchor) > slack:
            problems.append(f"pivot is '{pivot}' but that point sits at y = {anchor:+.2f}, not 0")
    length = brief.get("lengthStuds")
    if length and abs(size[2] - length) > length * HEIGHT_TOLERANCE:
        problems.append(f"length is {size[2]:.2f} studs, the brief says {length:g}")
    problems += mount_problems(brief, low, high)
    if sheet_path:
        mounts_sheet(tris, brief, sheet_path)
    return {
        "sizeStuds": [round(float(v), 3) for v in size],
        "heightStuds": want,
        "kind": brief.get("kind", "prop"),
        "mounts": brief.get("mounts") or {},
        "mountSheet": rel(sheet_path) if sheet_path else None,
        "pivot": pivot,
        "problems": problems,
        "passed": not problems,
    }


# ------------------------------------------------------------------ registry


def read_registry():
    return read_json(REGISTRY) if os.path.isfile(REGISTRY) else {}


def write_registry(registry):
    write_json(REGISTRY, dict(sorted(registry.items())))


def blank_studio():
    return {"verifiedOn": None, "checks": {name: False for name in STUDIO_CHECKS}}


def record_build(key, pkg, brief, route, export, triangles):
    """Note a finished local build. Upload fields are kept, so a rebuilt export whose hash
    no longer matches the uploaded one shows up as stale in the gate."""
    registry = read_registry()
    entry = registry.get(key, {})
    entry.update(
        {
            "package": rel(pkg),
            "role": brief["role"],
            "route": route,
            "export": rel(export),
            "exportSha256": sha256(export),
            "triangles": triangles,
            "kind": brief.get("kind", "prop"),
            "gameName": brief.get("gameName"),
            "mounts": brief.get("mounts") or {},
            "share": brief.get("share", "game"),
        }
    )
    if brief.get("budgetWaiver"):
        entry["budgetWaiver"] = brief["budgetWaiver"]
    else:
        entry.pop("budgetWaiver", None)
    entry.setdefault("assetId", None)
    entry.setdefault("uploadedSha256", None)
    entry.setdefault("uploadedOn", None)
    entry.setdefault("studio", blank_studio())
    registry[key] = entry
    write_registry(registry)
    return entry


def record_upload(key, asset_id, uploaded_sha=None):
    """Note an upload. A new id has not been seen in Studio, so its checks start over."""
    registry = read_registry()
    entry = registry.get(key)
    if not entry:
        sys.exit(f"{key} is not in {rel(REGISTRY)}; build it first")
    changed = entry.get("assetId") != asset_id
    entry["assetId"] = asset_id
    entry["uploadedSha256"] = uploaded_sha or entry.get("exportSha256")
    entry["uploadedOn"] = time.strftime("%Y-%m-%d")
    if changed or "studio" not in entry:
        entry["studio"] = blank_studio()
    write_registry(registry)
    return entry


def record_studio(key, checks):
    registry = read_registry()
    entry = registry.get(key)
    if not entry:
        sys.exit(f"{key} is not in {rel(REGISTRY)}")
    studio = entry.setdefault("studio", blank_studio())
    for name in checks:
        studio["checks"][name] = True
    if all(studio["checks"].values()):
        studio["verifiedOn"] = time.strftime("%Y-%m-%d")
    write_registry(registry)
    return studio


# --------------------------------------------------------------------- claim


def owner():
    """Who is running this. ASSET_OWNER wins; a Claude session is told apart by its id."""
    explicit = os.environ.get("ASSET_OWNER")
    if explicit:
        return explicit
    session = os.environ.get("CLAUDE_CODE_SESSION_ID")
    return "session-" + session[:8] if session else "local"


def claim(pkg, command, take_over=False):
    """Mark the package as being worked on by this session, or stop if another one has it.

    Two sessions building the same package overwrite each other's exports and records and
    their work lands in one commit. The claim file is ignored by git."""
    path = os.path.join(pkg, ".claim.json")
    me = owner()
    if os.path.isfile(path):
        held = read_json(path)
        age = (time.time() - held.get("touched", 0)) / 3600
        if held.get("owner") != me and age < CLAIM_HOURS and not take_over:
            sys.exit(
                f"{rel(pkg)} is claimed by {held.get('owner')} (last used {age * 60:.0f} min ago, running "
                f"'{held.get('command')}'). Work on another asset, wait, or if that session is finished: "
                f"python tools/asset_generate.py claim {os.path.basename(pkg)} --take-over"
            )
    os.makedirs(pkg, exist_ok=True)
    write_json(path, {"owner": me, "host": socket.gethostname(), "command": command, "touched": time.time()})


def release(pkg):
    path = os.path.join(pkg, ".claim.json")
    if os.path.isfile(path):
        os.remove(path)


# ---------------------------------------------------------------- provenance


def write_reference_record(pkg, origin, made_with=None, prompt=None):
    """source/reference.json: how the reference image came to exist."""
    write_json(
        os.path.join(pkg, "source", "reference.json"),
        {"origin": origin, "madeWith": made_with, "prompt": prompt, "recordedOn": time.strftime("%Y-%m-%d")},
    )


def write_provenance(pkg, name, seed=None):
    """provenance.json: reference, generator, seed and date for the picked source.

    Needed the day an asset is sold or given away, and not recoverable later: trials/ is
    not committed. Returns the record, or None when there is no source to describe."""
    sources = [p for p in glob.glob(os.path.join(pkg, "source", "*.glb")) if os.path.isfile(p)]
    if not sources:
        return None
    path = os.path.join(pkg, "provenance.json")
    previous = read_json(path) if os.path.isfile(path) else {}
    record = {"asset": name, "recordedOn": time.strftime("%Y-%m-%d")}

    references = sorted(p for p in glob.glob(os.path.join(pkg, "source", "reference.*")) if not p.endswith(".json"))
    reference = {"file": None, "sha256": None, "origin": "unknown", "madeWith": None, "prompt": None}
    if references:
        reference.update(file=rel(references[0]), sha256=sha256(references[0]))
    note = os.path.join(pkg, "source", "reference.json")
    if os.path.isfile(note):
        reference.update({k: v for k, v in read_json(note).items() if k in ("origin", "madeWith", "prompt")})
    elif previous.get("reference"):
        reference.update({k: previous["reference"].get(k) for k in ("origin", "madeWith", "prompt")})
    record["reference"] = reference

    source = sources[0]
    mesh = {"file": rel(source), "sha256": sha256(source)}
    generation = None
    if seed is not None:
        generation = os.path.join(pkg, "trials", f"seed-{seed}", "generation.json")
    else:
        for candidate in glob.glob(os.path.join(pkg, "trials", "seed-*", "candidate.glb")):
            if sha256(candidate) == mesh["sha256"]:
                generation = os.path.join(os.path.dirname(candidate), "generation.json")
    if generation and os.path.isfile(generation):
        mesh["generator"] = read_json(generation)
    elif previous.get("mesh", {}).get("sha256") == mesh["sha256"] and "generator" in previous["mesh"]:
        mesh["generator"] = previous["mesh"]["generator"]
    else:
        mesh["generator"] = None
    record["mesh"] = mesh
    record["rights"] = previous.get("rights") or {
        "note": "Fill in before selling or giving this asset away: whose work the reference is, and the "
        "generator terms that applied on the date above.",
        "checkedOn": None,
    }
    write_json(path, record)
    return record


# ----------------------------------------------------------------- reference


def reference_problems(image_path):
    """Why an image may make a poor reference for image-to-3D. Empty list means none found.

    The generator copies whatever is in the frame: a floor, water or a shadow becomes
    mesh, and a subject cut off by the frame becomes a cut-off model."""
    import numpy as np
    from PIL import Image

    image = Image.open(image_path).convert("RGBA")
    image.thumbnail((256, 256))
    flat = Image.new("RGBA", image.size, "white")
    flat.alpha_composite(image)
    pixels = np.asarray(flat.convert("RGB"), dtype=np.float32)
    height, width = pixels.shape[:2]
    ring = max(2, round(min(height, width) * 0.03))
    border = np.zeros((height, width), dtype=bool)
    border[:ring], border[-ring:], border[:, :ring], border[:, -ring:] = True, True, True, True
    background = np.median(pixels[border], axis=0)
    subject = np.abs(pixels - background).max(axis=2) > 40
    problems = []
    if background.min() < 200:
        problems.append(f"the background is not white (RGB about {tuple(int(v) for v in background)})")
    touching = float(subject[border].mean())
    spread = float(pixels[border].std(axis=0).max())
    if touching > 0.03:
        if spread > 25 and touching > 0.25:
            problems.append("the background is not plain; scenery in the frame becomes part of the mesh")
        else:
            problems.append(f"the subject runs off the edge of the frame ({touching:.0%} of the border); it will be cut off")
    cover = float(subject.mean())
    if cover < 0.08:
        problems.append(f"the subject fills only {cover:.0%} of the frame; small subjects come out soft")
    return problems


# --------------------------------------------------------------- calibration


def verdict_path(pkg):
    return os.path.join(pkg, "review", "verdict.json")


def calibration_rows():
    """(label, worst surface error, verdict or None) for every scored build on disk."""
    rows = list(CALIBRATION_SEED)
    for validation in sorted(glob.glob(os.path.join(ROOT, "assets", "models", "*", "validation.json"))):
        data = read_json(validation)
        detail = data.get("detail")
        if not isinstance(detail, dict) or "worstSurfaceError" not in detail:
            continue
        pkg = os.path.dirname(validation)
        looks = None
        if os.path.isfile(verdict_path(pkg)):
            verdict = read_json(verdict_path(pkg))
            if verdict.get("exportSha256") == data.get("exportSha256"):
                looks = verdict.get("looks")
        rows.append((os.path.basename(pkg), detail["worstSurfaceError"], looks))
    return sorted(rows, key=lambda row: row[1])


def calibration_report(warn, fail):
    rows = calibration_rows()
    lines = [f"  {score:5.3f}  {looks or 'no verdict':<10}  {label}" for label, score, looks in rows]
    good = [score for _, score, looks in rows if looks == "good"]
    bad = [score for _, score, looks in rows if looks == "bad"]
    lines.append("")
    lines.append(f"  current lines: warn over {warn}, fail over {fail}")
    if good and bad:
        if max(good) < min(bad):
            lines.append(f"  highest good {max(good):.3f}, lowest bad {min(bad):.3f}: any fail line between them separates every verdict.")
            if not max(good) < fail <= min(bad):
                lines.append(f"  the fail line is outside that gap; {round((max(good) + min(bad)) / 2, 2)} would sit in the middle of it.")
        else:
            lines.append(f"  good and bad overlap (a good build at {max(good):.3f}, a bad one at {min(bad):.3f}): the score alone cannot decide those.")
    wrong = [label for label, score, looks in rows if (looks == "good" and score > fail) or (looks == "bad" and score <= warn)]
    if wrong:
        lines.append("  the lines disagree with the verdict on: " + ", ".join(wrong))
    lines.append(f"  {len(good) + len(bad)} builds have a verdict; {sum(1 for r in rows if r[2] is None)} do not.")
    return "\n".join(lines)
