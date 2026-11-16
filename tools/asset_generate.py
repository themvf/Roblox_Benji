"""Reference image -> candidate GLBs -> appraisal -> one contact sheet to review.

Replaces the by-hand loop of opening the TRELLIS.2 Space, uploading an image,
clicking Generate, clicking Extract and saving the file. The Space is called
through its public API (the same one the web page uses), so the result is the
same model and the same settings you get in the browser.

    python tools/asset_generate.py brief    wooden-crate --purpose "..." --role decor --height 4
    python tools/asset_generate.py reference wooden-crate --prompt "..." --seeds 4
    python tools/asset_generate.py reference wooden-crate --use 2
    python tools/asset_generate.py generate <image> --name wooden-crate
    python tools/asset_generate.py review   wooden-crate
    python tools/asset_generate.py pick     wooden-crate --seed 2
    python tools/asset_generate.py build    wooden-crate
    python tools/asset_generate.py publish  wooden-crate            (dry run; --confirm uploads)
    python tools/asset_generate.py verify   wooden-crate --check loads --check facing

The rules behind these (triangle budget per role, size and pivot contract, the asset
registry, one session per package, provenance) live in tools/asset_rules.py.

brief     comes FIRST. Writes brief.json: purpose, role, height in studs, pivot, route.
          The role sets the triangle budget and, with the route, how much to generate:
          a held or interactive asset goes the clean route, where the generated mesh is
          only a shape guide and one candidate is enough. reference and generate stop
          without a brief (--no-brief overrides). pick copies its purpose into the
          appraisal decision.
prompt    prints a reference-image prompt in the house framing for Midjourney or any
          other image tool, and records it for provenance.
publish   uploads the built export with tools/roblox/upload_asset.ps1 and writes the id
          to src/shared/AssetRegistry.json, which game code reads. Without --confirm it
          is a dry run. It refuses an export that failed a gate and skips one that is
          already uploaded. register records an id uploaded some other way.
verify    ticks off what was checked by eye in Studio (loads, facing, scale, materials,
          collision); tools/check_asset_registry.luau lists what is still open.
verdict   records whether the current scan build looks good or bad beside its surface
          error; calibrate prints every score with its verdict so the detail gate's
          lines can be moved on evidence.
claim     every command that changes a package claims it for this session for four
          hours; another session is stopped with a message. --take-over or --release.
provenance rewrites provenance.json (reference, generator, seed, date) from disk; pick
          writes it automatically.
build     turns the brief into scene.json (a one-asset scene_kit manifest kept in
          the package), runs scene_kit, checks the export against the triangle cap,
          renders review/views.png of the written file and records validation.json.
          If a mesh is over the cap it rebuilds with a finer tile grid (up to five
          attempts) and records the grid that passed in brief.json. Then it runs
          audit. It never uploads.
audit     renders the export from ten sides plus six close-ups, each twice: textured
          and brightened, and as a hole map (front faces grey, back faces magenta).
          Roblox draws meshes one-sided, so visible magenta is a see-through spot in
          game. Writes review/audit.png, review/audit_closeups.png, the single panels
          in review/audit/ and review/audit.json with the back-face share per view.
          --focus x,y,z adds a close-up at that point of the bounding box; --seed N
          audits a candidate before it is picked.

reference optional first step when you have no image yet: text prompt -> one image
          per seed from the Z-Image Turbo Space, in trials/reference/, plus
          review/references.png. --use <seed> promotes one to source/reference.png,
          after which generate needs no image argument. Your --prompt is wrapped
          as: --style lead (realistic | stylized | blocky), your description, then
          framing (whole subject, at rest, studio light, pure white background).
          --raw sends it untouched. --edit "<one change>" reworks the reference
          already in use (FLUX.1 Kontext Space) and saves the results as seed-101
          upward: the fix for an image that is right except for one blurred or
          miscounted part. Edits vary a lot by seed, so make several and compare.
          Writing the description:
            - The model is literal. A ten-word keyword list gets a logo or a toy.
              Use full sentences, 40-80 words.
            - Order: what it is, overall shape and proportions, the named parts,
              materials, colours, condition.
            - Say what is there, not what is not: "doors closed, cabin empty,
              wheels on the ground", never "no pilots, not flying". There is no
              negative prompt and "no X" tends to add X.
            - Name colours per part ("matte black fuselage, grey rotor blades").
            - Leave out background, lighting and camera; the framing covers them.
            - Match --aspect to the subject (wide for vehicles, tall for trees
              and towers) or its ends get cropped, and a cropped reference
              becomes a cropped mesh.
generate  copies the image to assets/models/<name>/source/reference.<ext>, makes
          one candidate per seed in trials/seed-<n>/, appraises each and writes
          review/candidates.png. Seeds that already have a GLB are skipped, so a
          run that died on GPU quota resumes where it stopped.
review    re-appraises and rebuilds the sheet without calling the Space.
pick      promotes one candidate to source/<Name>.glb and writes the package
          appraisal.json. You still fill in `decision`; check_assets insists.

Candidates live in trials/, which tools/check_assets.luau does not scan, so an
unreviewed batch never fails the build gates.

The Space runs on ZeroGPU. Anonymous callers get very little GPU time; set
HF_TOKEN (a read token from your Hugging Face account) to use your own quota.
The token is read from the environment and never written anywhere.

Needs: pip install gradio_client pillow. Blender for the appraisal (BLENDER env
var, PATH, or the newest install under Program Files).
"""

import argparse
import glob
import json
import math
import os
import re
import shutil
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import asset_rules as rules  # noqa: E402 - budgets, registry, claims, provenance; see that file

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPACE = "microsoft/TRELLIS.2"
EDIT_SPACE = "black-forest-labs/FLUX.1-Kontext-Dev"
EDIT_SEED_BASE = 100  # edits of the current reference are saved as seed-101, seed-102, ...
IMAGE_SPACE = "Tongyi-MAI/Z-Image-Turbo"
# The reference prompt is assembled as: style lead, your description, framing. The model weighs
# the start of a prompt most and has no negative prompt, so the look goes first and everything
# is phrased as what should be there ("unoccupied, at rest") rather than what should not.
REFERENCE_STYLES = {
    "realistic": "Product photograph style render of a game-ready 3D asset, isolated on a seamless pure white background, realistic materials with fine surface detail",
    "stylized": "Stylized low-poly 3D game asset render, isolated on a seamless pure white background, chunky simplified shapes with clean hard edges and flat matte colours",
    "blocky": "Roblox-style blocky 3D character render, isolated on a seamless pure white background, built from faceted low-poly blocks with clean hard edges, oversized head and short body",
}
# Pick the frame to suit the subject: a helicopter in a square frame loses its rotor tips.
REFERENCE_ASPECTS = {"square": "1024x1024 ( 1:1 )", "wide": "1536x1024 ( 3:2 )", "tall": "1024x1536 ( 2:3 )"}
# What image-to-3D needs from a reference, whatever the subject is.
REFERENCE_FRAMING = (
    "One single subject centred in the frame, shown complete from end to end with empty white margin on "
    "every side, front three-quarter view from slightly above. Static and at rest, unoccupied, every part "
    "sharp and in focus. Soft even studio lighting from all sides, uniform pure white background and white "
    "floor, only a faint soft contact shadow directly underneath."
)
APPRAISER = os.path.join(ROOT, "tools", "blender", "appraise_asset.py")
AUDITOR = os.path.join(ROOT, "tools", "blender", "audit_asset.py")
# A view is flagged when more than this share of the asset's pixels are back faces in solid
# patches (hairline seams are eroded away first). A closed, correctly wound mesh shows none.
AUDIT_FLAG_PERCENT = 0.15
AUDIT_BACKGROUND = (236, 239, 244)


def package_dir(name):
    if not re.fullmatch(r"[a-z0-9]+(-[a-z0-9]+)*", name):
        sys.exit(f"--name must be kebab-case like 'wooden-crate', got {name!r}")
    return os.path.join(ROOT, "assets", "models", name)


def pascal(name):
    return "".join(part.capitalize() for part in name.split("-"))


def find_blender():
    env = os.environ.get("BLENDER")
    if env and os.path.isfile(env):
        return env
    found = shutil.which("blender")
    if found:
        return found
    installs = glob.glob(r"C:\Program Files\Blender Foundation\Blender *\blender.exe")

    def version(path):
        match = re.search(r"Blender (\d+)\.(\d+)", path)
        return (int(match.group(1)), int(match.group(2))) if match else (0, 0)

    return max(installs, key=version) if installs else None


def printable(text):
    """Blender prints emoji; a Windows console that is not UTF-8 raises on them."""
    encoding = sys.stdout.encoding or "utf-8"
    return text.encode(encoding, "replace").decode(encoding)


def tail(done):
    """The end of a subprocess's output."""
    return printable((done.stdout or "")[-800:] + (done.stderr or "")[-400:])


def trial_dirs(pkg):
    dirs = glob.glob(os.path.join(pkg, "trials", "seed-*"))
    return sorted(dirs, key=lambda d: int(d.rsplit("-", 1)[1]))


def reference_image(pkg):
    for path in sorted(glob.glob(os.path.join(pkg, "source", "reference.*"))):
        return path
    return None


# ----------------------------------------------------------- reference image


def result_file(result):
    """The first local file in a Space result, whatever shape the component returns."""
    if isinstance(result, str):
        return result if os.path.isfile(result) else None
    if isinstance(result, dict):
        result = [result.get("path"), result.get("image")]
    if isinstance(result, (list, tuple)):
        for item in result:
            found = result_file(item)
            if found:
                return found
    return None


def reference_trials(pkg):
    paths = glob.glob(os.path.join(pkg, "trials", "reference", "seed-*.png"))
    return sorted(paths, key=lambda p: int(re.search(r"seed-(\d+)\.png$", p).group(1)))


def generate_references(pkg, prompt, seeds, resolution):
    try:
        from gradio_client import Client
    except ImportError:
        sys.exit("gradio_client is missing: python -m pip install gradio_client")
    from PIL import Image

    out_dir = os.path.join(pkg, "trials", "reference")
    os.makedirs(out_dir, exist_ok=True)
    record = os.path.join(out_dir, "prompt.json")
    previous = read_json(record) if os.path.isfile(record) else {}
    if previous and (previous.get("prompt"), previous.get("resolution")) != (prompt, resolution):
        print("the prompt or frame changed: replacing the earlier reference candidates")
        for stale in reference_trials(pkg):
            os.remove(stale)
    write_json(record, {"space": IMAGE_SPACE, "prompt": prompt, "resolution": resolution, "generatedOn": time.strftime("%Y-%m-%d")})

    token = os.environ.get("HF_TOKEN")
    if not token:
        print("HF_TOKEN is not set: calling anonymously, which has very little GPU quota.")
    client = None
    for seed in seeds:
        target = os.path.join(out_dir, f"seed-{seed}.png")
        if os.path.isfile(target):
            print(f"seed {seed}: already generated, skipping")
            continue
        client = client or Client(IMAGE_SPACE, token=token, verbose=False)
        started = time.time()
        try:
            result = client.predict(
                prompt=prompt,
                resolution=resolution,
                seed=seed,
                steps=8,
                shift=3.0,
                random_seed=False,
                gallery_images=[],
                api_name="/generate",
            )
        except Exception as error:  # noqa: BLE001 - the Space reports quota and queue errors as text
            print(f"seed {seed}: FAILED after {time.time() - started:.0f}s: {error}")
            if "quota" in str(error).lower():
                print("GPU quota is used up. Set HF_TOKEN or wait, then rerun; finished seeds are kept.")
                return
            continue
        image = result_file(result)
        if not image:
            print(f"seed {seed}: the Space returned no image")
            continue
        Image.open(image).convert("RGB").save(target)
        print(f"seed {seed}: done in {time.time() - started:.0f}s")


def edit_reference(pkg, instruction, count):
    """Change one thing about the current reference and keep the rest: the cheap fix for a
    reference that is right except for a blurred or miscounted part."""
    try:
        from gradio_client import Client, handle_file
    except ImportError:
        sys.exit("gradio_client is missing: python -m pip install gradio_client")
    from PIL import Image

    current = reference_image(pkg)
    if not current:
        sys.exit(f"no source/reference.* in {os.path.relpath(pkg, ROOT)} to edit; make and --use one first")
    out_dir = os.path.join(pkg, "trials", "reference")
    os.makedirs(out_dir, exist_ok=True)
    for stale in glob.glob(os.path.join(out_dir, "seed-1[0-9][0-9].png")):
        os.remove(stale)
    prompt = instruction.strip().rstrip(".") + (
        ". Keep everything else, the camera angle and the plain white background exactly the same."
    )
    write_json(
        os.path.join(out_dir, "edit.json"),
        {"space": EDIT_SPACE, "instruction": prompt, "editedOn": time.strftime("%Y-%m-%d")},
    )
    token = os.environ.get("HF_TOKEN")
    if not token:
        print("HF_TOKEN is not set: calling anonymously, which has very little GPU quota.")
    client = Client(EDIT_SPACE, token=token, verbose=False)
    for seed in range(1, count + 1):
        started = time.time()
        try:
            result = client.predict(
                input_image=handle_file(current),
                prompt=prompt,
                seed=seed,
                randomize_seed=False,
                guidance_scale=2.5,
                steps=28,
                api_name="/infer",
            )
        except Exception as error:  # noqa: BLE001 - the Space reports quota and queue errors as text
            print(f"edit {seed}: FAILED after {time.time() - started:.0f}s: {error}")
            if "quota" in str(error).lower():
                return
            continue
        image = result_file(result)
        if not image:
            print(f"edit {seed}: the Space returned no image")
            continue
        Image.open(image).convert("RGB").save(os.path.join(out_dir, f"seed-{EDIT_SEED_BASE + seed}.png"))
        print(f"edit {seed}: saved as seed-{EDIT_SEED_BASE + seed} in {time.time() - started:.0f}s")


def reference_sheet(pkg):
    from PIL import Image, ImageDraw

    trials = reference_trials(pkg)
    if not trials:
        print("no reference candidates yet; nothing to put on a sheet")
        return None
    # Rows of at most four, so a sheet of eight wide images stays legible when viewed whole.
    row_h, label_h, gap, per_row = 512, 28, 8, 4
    images = [Image.open(path).convert("RGB") for path in trials]
    images = [im.resize((round(im.width * row_h / im.height), row_h)) for im in images]
    cell_w = max(im.width for im in images) + gap
    rows = (len(images) + per_row - 1) // per_row
    sheet = Image.new("RGB", (cell_w * min(per_row, len(images)) - gap, (row_h + label_h) * rows), "#888888")
    draw = ImageDraw.Draw(sheet)
    for index, (path, im) in enumerate(zip(trials, images)):
        left, top = (index % per_row) * cell_w, (index // per_row) * (row_h + label_h)
        draw.text((left + 8, top + 8), os.path.splitext(os.path.basename(path))[0], fill="white")
        sheet.paste(im, (left, top + label_h))
    out = os.path.join(pkg, "review", "references.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.save(out)
    print(f"reference sheet: {os.path.relpath(out, ROOT)}")
    return out


def require_brief(pkg, name, skip):
    """Stop a generation that has no brief yet. Route and size decide how much to generate."""
    brief = read_brief(pkg)
    if brief or skip:
        return brief
    sys.exit(
        f"no brief.json in {rel(pkg)}. Write it first, so the route is decided before GPU time is spent:\n"
        f"  python tools/asset_generate.py brief {name} --purpose \"...\" --role <{'|'.join(ROLES)}> --height <studs>\n"
        "(--no-brief skips this.)"
    )


def cmd_reference(args):
    pkg = package_dir(args.name)
    rules.claim(pkg, "reference")
    if args.use is not None:
        chosen = os.path.join(pkg, "trials", "reference", f"seed-{args.use}.png")
        if not os.path.isfile(chosen):
            sys.exit(f"no reference candidate for seed {args.use} in {os.path.relpath(os.path.dirname(chosen), ROOT)}")
        existing = glob.glob(os.path.join(pkg, "source", "reference.*"))
        if existing and not args.replace:
            sys.exit(f"{os.path.relpath(existing[0], ROOT)} already exists; pass --replace to overwrite it")
        for old in existing:
            os.remove(old)
        os.makedirs(os.path.join(pkg, "source"), exist_ok=True)
        target = os.path.join(pkg, "source", "reference.png")
        shutil.copyfile(chosen, target)
        made = os.path.join(pkg, "trials", "reference", "edit.json" if args.use > EDIT_SEED_BASE else "prompt.json")
        made = read_json(made) if os.path.isfile(made) else {}
        rules.write_reference_record(pkg, "generated", made.get("space"), made.get("prompt") or made.get("instruction"))
        print(f"using seed {args.use} -> {os.path.relpath(target, ROOT)}")
        print(f"next: python tools/asset_generate.py generate --name {args.name}")
        return
    if args.edit:
        edit_reference(pkg, args.edit, args.seeds)
        reference_sheet(pkg)
        print(f"next: open the sheet, then  python tools/asset_generate.py reference {args.name} --use <n> --replace")
        return
    if not args.prompt:
        sys.exit("give --prompt to make candidates, or --use <seed> to choose one")
    require_brief(pkg, args.name, args.no_brief)
    prompt = args.prompt.strip()
    if not args.raw:
        prompt = f"{REFERENCE_STYLES[args.style]}: {prompt.rstrip('.')}. {REFERENCE_FRAMING}"
    seeds = list(range(args.first_seed, args.first_seed + args.seeds))
    generate_references(pkg, prompt, seeds, REFERENCE_ASPECTS[args.aspect])
    reference_sheet(pkg)
    print(f"next: open the sheet, then  python tools/asset_generate.py reference {args.name} --use <n>")


# ---------------------------------------------------------------- generation


def generate_candidates(pkg, image, seeds, args):
    try:
        from gradio_client import Client, handle_file
    except ImportError:
        sys.exit("gradio_client is missing: python -m pip install gradio_client")

    todo = [s for s in seeds if not os.path.isfile(os.path.join(pkg, "trials", f"seed-{s}", "candidate.glb"))]
    for seed in seeds:
        if seed not in todo:
            print(f"seed {seed}: already generated, skipping")
    if not todo:
        return

    token = os.environ.get("HF_TOKEN")
    if not token:
        print("HF_TOKEN is not set: calling anonymously, which has very little GPU quota.")
    client = Client(SPACE, token=token, verbose=False)
    client.predict(api_name="/start_session")
    prepared = client.predict(input=handle_file(image), api_name="/preprocess_image")
    if isinstance(prepared, dict):
        prepared = prepared.get("path")

    for seed in todo:
        out_dir = os.path.join(pkg, "trials", f"seed-{seed}")
        os.makedirs(out_dir, exist_ok=True)
        started = time.time()
        print(f"seed {seed}: generating at {args.resolution}...", flush=True)
        try:
            client.predict(
                image=handle_file(prepared),
                seed=seed,
                resolution=str(args.resolution),
                api_name="/image_to_3d",
            )
            result = client.predict(
                decimation_target=args.decimation,
                texture_size=args.texture,
                api_name="/extract_glb",
            )
        except Exception as error:  # noqa: BLE001 - the Space reports quota and queue errors as text
            print(f"seed {seed}: FAILED after {time.time() - started:.0f}s: {error}")
            if "quota" in str(error).lower():
                print("GPU quota is used up. Set HF_TOKEN or wait, then rerun; finished seeds are kept.")
                return
            continue
        glb = result[0] if isinstance(result, (list, tuple)) else result
        if isinstance(glb, dict):
            glb = glb.get("path")
        shutil.copyfile(glb, os.path.join(out_dir, "candidate.glb"))
        with open(os.path.join(out_dir, "generation.json"), "w", encoding="utf-8") as handle:
            json.dump(
                {
                    "space": SPACE,
                    "seed": seed,
                    "resolution": args.resolution,
                    "decimationTarget": args.decimation,
                    "textureSize": args.texture,
                    "reference": os.path.basename(image),
                    "generatedOn": time.strftime("%Y-%m-%d"),
                },
                handle,
                indent=2,
            )
        size_mb = os.path.getsize(glb) / 1e6
        print(f"seed {seed}: done in {time.time() - started:.0f}s, {size_mb:.1f} MB")


# ----------------------------------------------------------------- appraisal


def appraise(source, record):
    blender = find_blender()
    if not blender:
        print("Blender not found (set BLENDER); skipping appraisal.")
        return False
    done = subprocess.run(
        [blender, "-b", "-noaudio", "--python", APPRAISER, "--", "--source", source, "--record", record],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    if done.returncode != 0 or not os.path.isfile(record):
        print(f"appraisal failed for {source}:\n{tail(done)}")
        return False
    return True


def appraise_trials(pkg, force=False):
    for trial in trial_dirs(pkg):
        glb = os.path.join(trial, "candidate.glb")
        record = os.path.join(trial, "appraisal.json")
        if os.path.isfile(glb) and (force or not os.path.isfile(record)):
            print(f"appraising {os.path.basename(trial)}...", flush=True)
            appraise(glb, record)


# --------------------------------------------------------------------- audit


def sheet_font(size=18):
    from PIL import ImageFont

    try:
        return ImageFont.load_default(size=size)
    except TypeError:  # Pillow before 10.1 has one fixed size
        return ImageFont.load_default()


def panel_grid(rows, cell, header=None):
    """rows: lists of (label, image, flagged). Every image is drawn `cell` pixels square under its label."""
    from PIL import Image, ImageDraw

    label_h, gap = 28, 6
    font = sheet_font()
    columns = max(len(row) for row in rows)
    width = columns * (cell + gap) - gap
    head_h = header.height + gap if header else 0
    sheet = Image.new("RGB", (max(width, header.width if header else 0), head_h + len(rows) * (cell + label_h + gap)), "white")
    if header:
        sheet.paste(header, (0, 0))
    draw = ImageDraw.Draw(sheet)
    for r, row in enumerate(rows):
        top = head_h + r * (cell + label_h + gap)
        for c, (label, image, flagged) in enumerate(row):
            left = c * (cell + gap)
            draw.text((left + 6, top + 4), label, fill="#c00020" if flagged else "black", font=font)
            sheet.paste(image.resize((cell, cell)), (left, top + label_h))
    return sheet


def audit_sheets(pkg, base, source):
    """Measure the hole map and lay the audit renders out as two sheets. Returns the record."""
    import numpy as np
    from PIL import Image, ImageDraw, ImageFilter

    panels = os.path.join(base, "audit")
    listing = read_json(os.path.join(panels, "views.json"))

    def pixels(name):
        return np.asarray(Image.open(os.path.join(panels, name)).convert("RGBA"), dtype=np.float32) / 255.0

    loaded = [(view, pixels(view["color"]), pixels(view["holes"])) for view in listing["views"]]
    # A matte black asset renders as a silhouette. Lift every colour view by the same gamma so
    # surface detail shows; the amount is recorded, because the game will not look this bright.
    lit = [colour[..., :3][colour[..., 3] > 0.5] for _, colour, _ in loaded]
    lit = [values for values in lit if values.size]
    mean = float(np.mean([values.mean() for values in lit])) if lit else 1.0
    gamma = max(0.4, math.log(0.38) / math.log(mean)) if 0.0 < mean < 0.30 else 1.0
    background = np.array(AUDIT_BACKGROUND, dtype=np.float32) / 255.0

    def flatten(rgba, lift=1.0):
        alpha = rgba[..., 3:4]
        rgb = np.clip(rgba[..., :3], 0.0, 1.0) ** lift
        return Image.fromarray(np.uint8((rgb * alpha + background * (1.0 - alpha)) * 255.0 + 0.5))

    views, cells = [], []
    for view, colour, hole in loaded:
        covered = hole[..., 3] > 0.5
        back = covered & (hole[..., 0] > 0.75) & (hole[..., 1] < 0.35) & (hole[..., 2] > 0.75)
        area = max(int(covered.sum()), 1)
        percent = round(100.0 * float(back.sum()) / area, 2)
        # Generated meshes leak hairline back faces along every seam; the Black Hawk shows 0.3-1.3%
        # of them per view with no real hole. Erode the lines away and judge what is left: patches.
        solid = np.asarray(Image.fromarray(np.uint8(back) * 255).filter(ImageFilter.MinFilter(5))) > 0
        patches = round(100.0 * float(solid.sum()) / area, 2)
        flagged = patches > AUDIT_FLAG_PERCENT
        views.append(
            {
                "name": view["name"],
                "kind": view["kind"],
                "backFacePercent": percent,
                "backFacePatchPercent": patches,
                "flagged": flagged,
            }
        )
        cells.append(
            (
                view["kind"],
                (view["name"], flatten(colour, gamma), False),
                (f"{view['name']}  back faces {percent:g}%, patches {patches:g}%", flatten(hole), flagged),
            )
        )
    flagged = [view["name"] for view in views if view["flagged"]]

    cell = 512
    header = Image.new("RGB", (5 * (cell + 6) - 6, cell), "white")
    reference = reference_image(pkg)
    text_left = 12
    if reference:
        ref = Image.open(reference).convert("RGB")
        ref = ref.resize((round(ref.width * cell / ref.height), cell))
        header.paste(ref, (0, 0))
        text_left = ref.width + 24
    lines = [
        f"AUDIT  {rel(source)}",
        "Left: the reference it was generated from." if reference else "No reference image in the package.",
        "Rows 1-2: textured, every side." + (f" Brightened (gamma {gamma:.2f}); darker in game." if gamma < 1.0 else ""),
        "Rows 3-4: front faces grey, BACK faces magenta.",
        "Magenta is where Roblox shows straight through:",
        "a hole, a flipped patch, or a one-sided sheet.",
        f"Patches over {AUDIT_FLAG_PERCENT:g}%: " + (", ".join(flagged) if flagged else "none"),
    ]
    draw = ImageDraw.Draw(header)
    for index, line in enumerate(lines):
        draw.text((text_left, 16 + index * 34), line, fill="#c00020" if index == 6 and flagged else "black", font=sheet_font(22))

    overview = [c for c in cells if c[0] == "overview"]
    closeups = [c for c in cells if c[0] == "closeup"]
    rows = [[c[1] for c in overview[i : i + 5]] for i in range(0, len(overview), 5)]
    rows += [[c[2] for c in overview[i : i + 5]] for i in range(0, len(overview), 5)]
    sheets = [os.path.join(base, "audit.png")]
    panel_grid(rows, cell, header).save(sheets[0])
    if closeups:
        rows = []
        for i in range(0, len(closeups), 6):  # each band: textured close-ups over their hole maps
            rows.append([c[1] for c in closeups[i : i + 6]])
            rows.append([c[2] for c in closeups[i : i + 6]])
        sheets.append(os.path.join(base, "audit_closeups.png"))
        panel_grid(rows, cell).save(sheets[1])

    record = {
        "tool": "tools/asset_generate.py audit",
        "auditedOn": time.strftime("%Y-%m-%d %H:%M"),
        "source": rel(source),
        "sourceSha256": sha256(source),
        "brightenGamma": round(gamma, 3),
        "flagPercent": AUDIT_FLAG_PERCENT,
        "worstBackFacePercent": max((view["backFacePercent"] for view in views), default=0.0),
        "worstPatchPercent": max((view["backFacePatchPercent"] for view in views), default=0.0),
        "flagged": flagged,
        "views": views,
        "sheets": [rel(path) for path in sheets],
        "panels": rel(panels),
        "limitations": "Blender renders, not Roblox. Lighting, materials and transparency in Studio are not checked.",
    }
    write_json(os.path.join(base, "audit.json"), record)
    return record


def run_audit(pkg, source, base, focus=(), zoom=3.0):
    """Render `source` from every side into <base>/audit/ and write the sheets beside it."""
    blender = find_blender()
    if not blender:
        print("Blender not found (set BLENDER); skipping the audit.")
        return None
    panels = os.path.join(base, "audit")
    if os.path.isdir(panels):
        shutil.rmtree(panels)
    command = [blender, "-b", "-noaudio", "--python", AUDITOR, "--", "--source", source, "--out-dir", panels]
    command += ["--zoom", str(zoom)]
    for point in focus:
        command += ["--focus", point]
    print(f"audit: rendering {rel(source)} from every side...", flush=True)
    done = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if done.returncode != 0 or not os.path.isfile(os.path.join(panels, "views.json")):
        print(f"audit render failed:\n{tail(done)}")
        return None
    record = audit_sheets(pkg, base, source)
    for sheet in record["sheets"]:
        print(f"audit sheet: {sheet}")
    if record["flagged"]:
        print(f"audit: back-face patches over {AUDIT_FLAG_PERCENT:g}% in: {', '.join(record['flagged'])}. LOOK at the magenta.")
    else:
        print(f"audit: no view has back-face patches over {AUDIT_FLAG_PERCENT:g}% (worst {record['worstPatchPercent']:g}%).")
    return record


def cmd_audit(args):
    pkg = package_dir(args.name)
    if args.seed is not None:
        base = os.path.join(pkg, "trials", f"seed-{args.seed}")
        source = os.path.join(base, "candidate.glb")
    else:
        base = os.path.join(pkg, "review")
        source = os.path.join(pkg, "exports", pascal(args.name) + ".glb")
    if not os.path.isfile(source):
        sys.exit(f"nothing to audit at {rel(source)}")
    os.makedirs(base, exist_ok=True)
    if not run_audit(pkg, source, base, args.focus or (), args.zoom):
        sys.exit(1)


# ------------------------------------------------------------- contact sheet


def contact_sheet(pkg):
    from PIL import Image, ImageDraw

    rows = []
    for trial in trial_dirs(pkg):
        views = os.path.join(trial, "views.png")
        if not os.path.isfile(views):
            continue
        caption = os.path.basename(trial)
        record = os.path.join(trial, "appraisal.json")
        if os.path.isfile(record):
            with open(record, encoding="utf-8") as handle:
                m = json.load(handle).get("measurements", {})
            caption += f"   {m.get('triangles', '?'):,} tris   open edges {m.get('openEdges', '?')}"
            caption += f"   non-manifold {m.get('nonManifoldEdges', '?')}"
        rows.append((caption, Image.open(views).convert("RGB")))
    if not rows:
        print("no appraised candidates yet; nothing to put on a sheet")
        return None

    row_h = 420
    label_h = 28
    scaled = [(c, im.resize((round(im.width * row_h / im.height), row_h))) for c, im in rows]
    ref_path = reference_image(pkg)
    ref = None
    if ref_path:
        ref = Image.open(ref_path).convert("RGB")
        ref = ref.resize((round(ref.width * row_h / ref.height), row_h))
    ref_w = ref.width + 12 if ref else 0
    width = ref_w + max(im.width for _, im in scaled)
    sheet = Image.new("RGB", (width, (row_h + label_h) * len(scaled)), "white")
    draw = ImageDraw.Draw(sheet)
    for index, (caption, im) in enumerate(scaled):
        top = index * (row_h + label_h)
        draw.text((8, top + 8), caption, fill="black")
        if ref:
            sheet.paste(ref, (0, top + label_h))
        sheet.paste(im, (ref_w, top + label_h))
    out = os.path.join(pkg, "review", "candidates.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    sheet.save(out)
    print(f"contact sheet: {os.path.relpath(out, ROOT)}")
    return out


# ------------------------------------------------------------------ commands


def cmd_generate(args):
    pkg = package_dir(args.name)
    brief = require_brief(pkg, args.name, args.no_brief)
    rules.claim(pkg, "generate")
    if args.image is None:
        reference = reference_image(pkg)
        if not reference:
            sys.exit(f"no image given and no source/reference.* in {os.path.relpath(pkg, ROOT)}; run reference first")
    else:
        if not os.path.isfile(args.image):
            sys.exit(f"no such image: {args.image}")
        os.makedirs(os.path.join(pkg, "source"), exist_ok=True)
        reference = os.path.join(pkg, "source", "reference" + os.path.splitext(args.image)[1].lower())
        if os.path.abspath(args.image) != os.path.abspath(reference):
            shutil.copyfile(args.image, reference)
        if args.made_with or args.prompt_text or not os.path.isfile(os.path.join(pkg, "source", "reference.json")):
            rules.write_reference_record(pkg, "user-supplied", args.made_with, args.prompt_text)
    for problem in rules.reference_problems(reference):
        print(f"reference: {problem}.")
    count = args.seeds
    if count is None:
        # On the clean route the mesh is only a shape guide for the hand-written builder,
        # so one candidate is enough; on the scan route the mesh is the asset, so compare.
        route = planned_route(brief) if brief else "scan"
        count = 1 if route == "clean" else 3
        print(f"route {route}: generating {count} candidate(s)" + (" as a shape guide for the clean builder." if route == "clean" else "."))
    seeds = list(range(args.first_seed, args.first_seed + count))
    generate_candidates(pkg, reference, seeds, args)
    appraise_trials(pkg)
    contact_sheet(pkg)
    print(f"next: open the sheet, then  python tools/asset_generate.py pick {args.name} --seed <n>")


def cmd_review(args):
    pkg = package_dir(args.name)
    appraise_trials(pkg, force=args.force)
    contact_sheet(pkg)


def cmd_pick(args):
    pkg = package_dir(args.name)
    rules.claim(pkg, "pick")
    trial = os.path.join(pkg, "trials", f"seed-{args.seed}")
    candidate = os.path.join(trial, "candidate.glb")
    if not os.path.isfile(candidate):
        sys.exit(f"no candidate for seed {args.seed} in {os.path.relpath(trial, ROOT)}")
    target = os.path.join(pkg, "source", pascal(args.name) + ".glb")
    if os.path.isfile(target) and not args.replace:
        sys.exit(f"{os.path.relpath(target, ROOT)} already exists; pass --replace to overwrite it")
    os.makedirs(os.path.dirname(target), exist_ok=True)
    shutil.copyfile(candidate, target)
    print(f"picked seed {args.seed} -> {os.path.relpath(target, ROOT)}")
    rules.write_provenance(pkg, args.name, args.seed)
    print(f"wrote {rel(os.path.join(pkg, 'provenance.json'))}")
    record = os.path.join(pkg, "appraisal.json")
    brief = read_brief(pkg)
    if appraise(target, record):
        data = read_json(record)
        if brief and not data.get("decision"):
            data["decision"] = decision_text(brief)
            write_json(record, data)
            print(f"wrote {os.path.relpath(record, ROOT)} with the decision from the brief.")
        elif not data.get("decision"):
            print(f"wrote {os.path.relpath(record, ROOT)}; fill in `decision` (what the asset is for).")
    if brief:
        print(f"next: python tools/asset_generate.py build {args.name}")
    else:
        print(f"next: write a brief (asset_generate.py brief {args.name} ...), then build.")


# --------------------------------------------------------------- brief/build

ROLES = ("decor", "cover", "interactive", "held", "scenery")  # budgets per role: tools/asset_rules.py
SINGLE_MESH_MAX_STUDS = 12  # taller than this and one 10k mesh starts to look melted
DENSE_SOURCE_TRIS = 50000  # above this the source is a generated or scanned mesh
DENSE_KEEP = 0.2  # share of source triangles kept
DENSE_TRIS_PER_TILE = 5000  # bisecting adds triangles and splits unevenly; the worst tile ran 8,848
TRI_CAP = 10000  # per mesh; tools/gltf_post.py inspect enforces it
RETRY_TILE_TARGET = 8500  # what a retry aims the worst tile at, leaving room for an uneven split
RETRY_MAX_TILES = 64  # past this many meshes, cut triangles instead of adding tiles
RETRY_MIN_KEEP = 0.15  # never decimate below this share of the source; panels crumple
BUILD_ATTEMPTS = 5


ROUTES = ("auto", "scan", "clean")
# Surface error from tools/outline_check.py: the share of the source's visible surface the
# export gets wrong, worst view. Calibrated on the wave runner: its good 12-mesh build scores
# 0.040 and the broken tank 0.061; the build that came out crumpled scores 0.231 and the one
# full of holes 0.347.
DETAIL_WARN = 0.08
DETAIL_FAIL = 0.15
CLEAN_REDUCTION = 0.9  # ASSET_INTAKE_AND_LESSONS.md: past ~90% reduction the silhouette is gone


def recommend_route(brief, measured, spec):
    """("scan" | "clean", [reasons]). Scan keeps the generated mesh; clean rebuilds it from shapes.

    Advice from numbers already on hand, not a verdict: the outline and surface check after
    a build is what proves a scan route worked."""
    reasons = []
    if brief.get("role") in rules.CLOSE_ROLES:
        reasons.append(f"the role is {brief['role']}, so players are right next to it and its parts may need to move")
    source_tris = measured.get("triangles", 0)
    kept = spec.get("decimate")
    if source_tris and kept and 1 - kept / source_tris > CLEAN_REDUCTION:
        reasons.append(f"it needs a {1 - kept / source_tris:.0%} triangle cut, past the {CLEAN_REDUCTION:.0%} where shape is lost")
    return ("clean" if reasons else "scan"), reasons


def planned_route(brief):
    """The route to plan for before any mesh exists: the brief's, or what its role implies."""
    chosen = brief.get("route", "auto")
    return chosen if chosen != "auto" else recommend_route(brief, {}, {})[0]


def clean_builder(name):
    return os.path.join(ROOT, "tools", "blender", "build_" + name.replace("-", "_") + ".py")


def detail_check(source, export, sheet_path):
    """Outline overlap and surface error of an export against its source, plus a sheet."""
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import outline_check

    scores, a, b = outline_check.compare(source, export)
    errors = outline_check.surface_error(source, export)
    os.makedirs(os.path.dirname(sheet_path), exist_ok=True)
    outline_check.sheet(sheet_path, a, b)
    return {
        "outlineOverlap": {k: round(v, 3) for k, v in scores.items()},
        "surfaceError": {k: round(v, 3) for k, v in errors.items()},
        "worstSurfaceError": round(max(errors.values()), 3),
        "sheet": rel(sheet_path),
    }


def read_json(path):
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def write_json(path, data):
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(data, handle, indent=2)
        handle.write("\n")


def read_brief(pkg):
    path = os.path.join(pkg, "brief.json")
    return read_json(path) if os.path.isfile(path) else None


def decision_text(brief):
    return f"{brief['purpose']} (role: {brief['role']}, about {brief['heightStuds']:g} studs tall)"


def sha256(path):
    import hashlib

    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def rel(path):
    return os.path.relpath(path, ROOT).replace("\\", "/")


def scene_spec(name, pkg, brief):
    """The scene_kit manifest entry a brief implies. `scene` in the brief overrides any field."""
    mode = brief.get("meshes", "auto")
    # Judge by the largest finished dimension, not the height: a wrecked tank 9 studs tall
    # is 26 wide, and 9,000 triangles spread over that came out full of holes.
    largest = brief["heightStuds"]
    record = os.path.join(pkg, "appraisal.json")
    if os.path.isfile(record):
        size = read_json(record).get("measurements", {}).get("size")
        if size and size[2] > 0:
            largest = brief["heightStuds"] * max(size) / size[2]
    tiled = mode == "tiled" or (mode == "auto" and largest > SINGLE_MESH_MAX_STUDS)
    # A dense generated mesh follows the snowmobile's tested route instead: keep about a
    # fifth of the triangles and spread them over many meshes. Cutting 291,000 to 9,000
    # or even 30,000 crumpled the wave runner's panels; 60,000 over 12 meshes did not.
    # ASSET_INTAKE_AND_LESSONS.md: past ~90% reduction the silhouette is gone.
    dense = None
    if os.path.isfile(record) and mode == "auto":
        measured = read_json(record).get("measurements", {})
        source_tris = measured.get("triangles", 0)
        if source_tris > DENSE_SOURCE_TRIS:
            budget = int(source_tris * DENSE_KEEP)
            tiles = -(-budget // DENSE_TRIS_PER_TILE)
            sx, sy = (measured.get("size") or [1, 1, 1])[:2]
            grids = [(nx, -(-tiles // nx)) for nx in range(1, 7)]
            nx, ny = min(grids, key=lambda g: abs(math.log((sx / g[0]) / (sy / g[1]))))
            dense = {"decimate": budget, "tile": [nx, ny]}
    spec = {
        "description": decision_text(brief),
        "source": rel(os.path.join(pkg, "source", pascal(name) + ".glb")),
        "out": rel(os.path.join(pkg, "exports", pascal(name) + ".glb")),
        "fit": {"axis": "z", "size": brief["heightStuds"]},
        # 25,000 across a 2x2 bisect lands each tile under the 10,000 cap with room for an
        # uneven split; the watchtower's worst tile came out at 8,574.
        "decimate": 25000 if tiled else 9000,
        "pivot": brief.get("pivot", "bottom"),
        "optimize": {"texture": 1024},
    }
    if dense:
        spec.update(dense)
    elif tiled:
        spec["tile"] = [2, 2]
    spec.update(brief.get("scene", {}))
    return spec


def cmd_brief(args):
    pkg = package_dir(args.name)
    rules.claim(pkg, "brief")
    brief = read_brief(pkg) or {}
    for key, value in (
        ("purpose", args.purpose),
        ("role", args.role),
        ("heightStuds", args.height),
        ("pivot", args.pivot),
        ("meshes", args.meshes),
        ("route", args.route),
        ("budgetWaiver", args.budget_waiver),
        ("kind", args.kind),
        ("lengthStuds", args.length),
        ("gameName", args.game_name),
    ):
        if value is not None:
            brief[key] = value
    missing = [k for k in ("purpose", "role", "heightStuds") if k not in brief]
    if missing:
        sys.exit("a new brief needs --purpose, --role and --height; missing: " + ", ".join(missing))
    brief.setdefault("pivot", "bottom")
    brief.setdefault("meshes", "auto")
    brief.setdefault("route", "auto")
    brief.setdefault("scene", {})
    brief.setdefault("kind", "prop")
    for item in args.mount or ():
        found = re.fullmatch(r"([A-Za-z][A-Za-z0-9]*)=(-?[\d.]+),(-?[\d.]+),(-?[\d.]+)", item)
        if not found:
            sys.exit(f"--mount takes Name=x,y,z in studs from the pivot (-z is forward), got {item!r}")
        brief.setdefault("mounts", {})[found.group(1)] = [float(found.group(i)) for i in (2, 3, 4)]
    needed = rules.KIND_ROLE.get(brief["kind"])
    if needed and brief["role"] != needed:
        sys.exit(f"kind {brief['kind']} goes with role {needed}, not {brief['role']}; pass --role {needed}")
    os.makedirs(pkg, exist_ok=True)
    write_json(os.path.join(pkg, "brief.json"), brief)
    print(f"wrote {rel(os.path.join(pkg, 'brief.json'))}")
    missing = [name for name in rules.KINDS[brief["kind"]] if name not in brief.get("mounts", {})]
    if missing:
        print(f"kind {brief['kind']}: build will fail until these mounts are set: " + ", ".join(missing) + ". Add each with --mount Name=x,y,z once the model's shape is known.")
    if brief["kind"] != "prop" and not brief.get("gameName"):
        print(f"kind {brief['kind']}: set --game-name to the name game code uses for it, so the gate can check it is wired in.")
    if brief["role"] == "cover":
        print("note: cover a player relies on is a block in the map file; this mesh is its visual shell.")
    print(f"budget: role {brief['role']} allows {rules.ROLE_BUDGETS[brief['role']]:,} triangles in total, {TRI_CAP:,} per mesh.")
    record = os.path.join(pkg, "appraisal.json")
    measured = read_json(record).get("measurements", {}) if os.path.isfile(record) else {}
    route, reasons = recommend_route(brief, measured, scene_spec(args.name, pkg, brief) if measured else {})
    print(f"route: brief says {brief['route']}; the numbers suggest {route}" + (" because " + "; ".join(reasons) if reasons else "") + ".")
    if planned_route(brief) == "clean":
        print(f"clean route: the generated mesh is a shape guide. The asset is written as {rel(clean_builder(args.name))}.")


def mesh_triangles(inspect_text):
    """Per-mesh triangle counts from `gltf_post.py inspect` output."""
    found = re.findall(r"^\s+(\S+)\s+([\d,]+) tris", inspect_text, re.M)
    return [int(count.replace(",", "")) for name, count in found if name != "total"]


def retry_spec(spec, attempts, measured):
    """What to change after a build that failed the triangle cap, or None if out of room.

    Triangles are not spread evenly: a vehicle's body runs down the middle of its long axis.
    So add cuts along the long axis, by the overshoot (at most double per attempt, since one
    crowded tile overstates what the rest need). If the last change did not help, take it back
    and cut the other axis instead, keeping that count even: an odd count across the Black
    Hawk removed the cut on its centreline and the worst tile went from 10,619 to 18,844.
    Only when the grid is full does it give up triangles, never below RETRY_MIN_KEEP."""
    last = attempts[-1]
    factor = min(last["worstMesh"] / RETRY_TILE_TARGET, 2.0)
    grid = list(spec.get("tile") or [1, 1])
    sx, sy = (measured.get("size") or [1, 1, 1])[:2]
    long_axis = 0 if sx >= sy else 1
    axis = long_axis
    if len(attempts) >= 2:
        before = attempts[-2]
        moved = before["tile"] and last["tile"] != before["tile"]
        if moved and last["worstMesh"] >= before["worstMesh"] * 0.95:
            axis = 1 if last["tile"][0] != before["tile"][0] else 0
            grid = list(before["tile"])
            factor = min(before["worstMesh"] / RETRY_TILE_TARGET, 2.0)
    grid[axis] = max(grid[axis] + 1, math.ceil(grid[axis] * factor))
    if axis != long_axis:
        grid[axis] += grid[axis] % 2
    if grid[0] * grid[1] <= RETRY_MAX_TILES:
        return {"tile": grid}
    lowered = int(spec["decimate"] / factor)
    if lowered >= int(measured.get("triangles", 0) * RETRY_MIN_KEEP):
        return {"decimate": lowered}
    return None


def gate_export(name, pkg, brief, route, out, total):
    """Budget, size and pivot of a written export; also notes the build in the registry."""
    budget = rules.budget_check(brief, total)
    contract = rules.contract_check(out, brief, os.path.join(pkg, "review", "mounts.png"))
    state = "within" if budget["within"] else ("OVER, waived: " + budget["waiver"] if budget["waiver"] else "OVER")
    print(f"budget: {total:,} triangles against {budget['budget']:,} for role {budget['role']} ({state})")
    size = contract["sizeStuds"]
    print(f"contract: {size[0]:g} wide x {size[1]:g} tall x {size[2]:g} long studs, pivot {contract['pivot']}" + ("" if contract["passed"] else " -- " + "; ".join(contract["problems"])))
    print(f"mounts: {contract['mountSheet']} shows which end is the front" + (" and where " + ", ".join(contract["mounts"]) + " sit" if contract["mounts"] else "") + ". Look at it.")
    rules.record_build(name, pkg, brief, route, out, total)
    return budget, contract


def gate_failures(name, budget, contract):
    """Exit messages for a build whose budget or contract failed, or an empty list."""
    out = []
    if not budget["passed"]:
        out.append(
            f"FAIL: over budget. {budget['triangles']:,} triangles, role {budget['role']} allows {budget['budget']:,}. "
            f"Use the clean route, lower scene.decimate in the brief, or record why it is acceptable: "
            f"asset_generate.py brief {name} --budget-waiver \"<reason>\"."
        )
    if not contract["passed"]:
        out.append("FAIL: the export does not match the brief: " + "; ".join(contract["problems"]) + ". Fix the builder or the brief.")
    return out


def cmd_build(args):
    pkg = package_dir(args.name)
    rules.claim(pkg, "build")
    brief = read_brief(pkg)
    if not brief:
        sys.exit(f"no brief.json in {rel(pkg)}; run: asset_generate.py brief {args.name} ...")
    spec = scene_spec(args.name, pkg, brief)
    source = os.path.join(ROOT, spec["source"])
    if not os.path.isfile(source):
        sys.exit(f"no source at {spec['source']}; pick a candidate first")
    blender = find_blender()
    if not blender:
        sys.exit("Blender not found; set the BLENDER environment variable")

    if brief.get("route", "auto") == "clean":
        build_clean(args.name, pkg, source, blender, brief)
        return

    manifest = os.path.join(pkg, "scene.json")
    out = os.path.join(ROOT, spec["out"])
    if os.path.isfile(out):
        backup = os.path.join(pkg, "trials", "previous-export.glb")
        os.makedirs(os.path.dirname(backup), exist_ok=True)
        shutil.copyfile(out, backup)
        print(f"backed up the previous export to {rel(backup)}")

    record = os.path.join(pkg, "appraisal.json")
    measured = read_json(record).get("measurements", {}) if os.path.isfile(record) else {}
    kit = os.path.join(ROOT, "tools", "blender", "scene_kit.py")
    attempts, changed = [], {}
    while True:
        write_json(manifest, {"_comment": "Generated from brief.json by tools/asset_generate.py build.", "assets": {args.name: spec}})
        built = subprocess.run(
            [blender, "-b", "-noaudio", "--python", kit, "--", "--manifest", manifest, "--asset", args.name],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        print(printable(built.stdout.rstrip()), flush=True)
        # scene_kit refuses to export a tile over the cap and names each one; that is the
        # failure a finer grid fixes. Anything else is a real build error.
        over = [int(count.replace(",", "")) for count in re.findall(r"FAIL \S+: ([\d,]+) triangles >", built.stdout)]
        inspect_text = ""
        if over:
            passed, worst = False, max(over)
        elif built.returncode != 0 or not os.path.isfile(out):
            sys.exit("build failed; see the scene_kit output above. " + printable(built.stderr[-400:]))
        else:
            inspect = subprocess.run(
                [sys.executable, os.path.join(ROOT, "tools", "gltf_post.py"), "inspect", out],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
            )
            inspect_text = inspect.stdout
            print(printable(inspect_text.rstrip()))
            passed = inspect.returncode == 0
            worst = max(mesh_triangles(inspect_text), default=0)
        attempts.append({"tile": spec.get("tile"), "decimate": spec.get("decimate"), "worstMesh": worst, "passed": passed})
        if passed or args.no_retry or len(attempts) >= BUILD_ATTEMPTS or worst <= TRI_CAP:
            break
        change = retry_spec(spec, attempts, measured)
        if not change:
            print("retry: the grid is full and the triangle count is at its floor; nothing left to try.")
            break
        print(f"retry {len(attempts)}: worst mesh {worst:,} is over the {TRI_CAP:,} cap; rebuilding with {change}", flush=True)
        spec.update(change)
        changed.update(change)
    if not passed:
        tried = "; ".join(f"tile {a['tile']} at {a['decimate']:,} -> worst {a['worstMesh']:,}" for a in attempts)
        sys.exit(
            f"FAIL: a mesh is still over the {TRI_CAP:,}-triangle cap after {len(attempts)} attempt(s): {tried}. "
            "The export on disk is not from this build; validation.json was left alone."
        )
    if changed:
        # Keep what worked, so the next build starts there instead of rediscovering it.
        brief.setdefault("scene", {}).update(changed)
        write_json(os.path.join(pkg, "brief.json"), brief)
        print(f"recorded {changed} under scene in {rel(os.path.join(pkg, 'brief.json'))}")

    # Views of the written file, not of the source: that is the artifact that gets uploaded.
    review = os.path.join(pkg, "review")
    os.makedirs(review, exist_ok=True)

    # Did the reduction keep the shape? Cheap, so it runs before the slow renders.
    detail = detail_check(source, out, os.path.join(review, "detail.png"))
    worst_error = detail["worstSurfaceError"]
    detail["passed"] = worst_error <= DETAIL_FAIL or args.allow_detail_loss
    print(f"detail: surface error {worst_error:.3f} worst view (warn over {DETAIL_WARN}, fail over {DETAIL_FAIL}); sheet {detail['sheet']}")
    route, reasons = recommend_route(brief, measured, spec)
    if worst_error > DETAIL_WARN:
        print("detail: the export has drifted from the source; look at the sheet (red is surface it lost).")
    budget, contract = gate_export(args.name, pkg, brief, "scan", out, sum(mesh_triangles(inspect_text)))
    rendered = appraise(out, os.path.join(review, "export.json"))
    audited = None if args.no_audit else run_audit(pkg, out, review)

    write_json(
        os.path.join(pkg, "validation.json"),
        {
            "checkedOn": time.strftime("%Y-%m-%d %H:%M"),
            "export": spec["out"],
            "exportSha256": sha256(out),
            "sourceSha256": sha256(source),
            "triangleCapPassed": passed,
            "route": {"brief": brief.get("route", "auto"), "suggested": route, "reasons": reasons},
            "detail": detail,
            "budget": budget,
            "contract": contract,
            "buildAttempts": attempts,
            "inspect": inspect_text.strip().splitlines(),
            "views": "review/views.png" if rendered else None,
            "audit": {
                "sheets": audited["sheets"],
                "flaggedViews": audited["flagged"],
                "worstBackFacePercent": audited["worstBackFacePercent"],
                "worstPatchPercent": audited["worstPatchPercent"],
            }
            if audited
            else None,
            "limitations": "Local checks only. Not uploaded, not seen in Studio, not approved.",
        },
    )
    handoff = os.path.join(pkg, "HANDOFF.md")
    if not os.path.isfile(handoff):
        with open(handoff, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(
                f"# {pascal(args.name)} handoff\n\n"
                "## Current stage\n\n"
                "- Stage: 4, local verification. Built from `brief.json`; see `validation.json`.\n"
                "- Next action: look at `review/views.png`, then record visual approval (stage 5).\n"
                "- Blockers: none locally. Not uploaded.\n\n"
                "## Approved decisions\n\n"
                f"- Purpose: {brief['purpose']}\n"
                f"- Role: {brief['role']}; height {brief['heightStuds']:g} studs; pivot {spec['pivot']}.\n\n"
                "## Local artifacts\n\n"
                f"- Brief and manifest: `brief.json`, `scene.json` (rebuild: `python tools/asset_generate.py build {args.name}`)\n"
                f"- Source: `{spec['source']}`\n"
                f"- Export: `{spec['out']}`\n\n"
                "## Roblox IDs and verification status\n\n"
                "- None yet.\n"
            )
    print(f"built {spec['out']}; views: {rel(os.path.join(review, 'views.png'))}")
    if worst_error > DETAIL_FAIL and not args.allow_detail_loss:
        sys.exit(
            f"FAIL: detail lost. Surface error {worst_error:.3f} is over {DETAIL_FAIL}; this export should not be uploaded. "
            f"Use the clean route (asset_generate.py brief {args.name} --route clean, then write "
            f"{rel(clean_builder(args.name))}), keep more triangles under scene.decimate in the brief, "
            "or pass --allow-detail-loss if it is only ever seen from far away."
        )
    failures = gate_failures(args.name, budget, contract)
    if failures:
        sys.exit("\n".join(failures))
    if route == "clean" and brief.get("route", "auto") != "scan":
        print("route: the numbers suggest a clean rebuild for this asset because " + "; ".join(reasons) + ".")
    print(f"next: look at review/audit.png and audit_closeups.png; once approved: asset_generate.py publish {args.name} --confirm")


def build_clean(name, pkg, source, blender, brief):
    """Clean route: run the asset's hand-written builder, then check and record its export.

    The builder is tools/blender/build_<name>.py and writes exports/<Name>Clean.glb. It is
    compared with the generated source for information only: a rebuild from simple shapes
    is meant to differ, so no surface-error floor applies. The eye is the gate here."""
    builder = clean_builder(name)
    if not os.path.isfile(builder):
        sys.exit(
            f"route is clean but there is no {rel(builder)}. A clean build is modelled from shapes; "
            "tools/blender/build_military_wave_runner.py is the worked example."
        )
    out = os.path.join(pkg, "exports", pascal(name) + "Clean.glb")
    built = subprocess.run([blender, "-b", "-noaudio", "--python", builder], capture_output=True, text=True, encoding="utf-8", errors="replace")
    if built.returncode != 0 or not os.path.isfile(out):
        sys.exit("clean build failed. " + printable((built.stdout + built.stderr)[-800:]))
    inspect = subprocess.run(
        [sys.executable, os.path.join(ROOT, "tools", "gltf_post.py"), "inspect", out],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    print(printable(inspect.stdout.rstrip()))
    detail = detail_check(source, out, os.path.join(pkg, "review", "clean-detail.png"))
    detail["passed"] = None  # informational on this route
    budget, contract = gate_export(name, pkg, brief, "clean", out, sum(mesh_triangles(inspect.stdout)))
    write_json(
        os.path.join(pkg, "validation-clean.json"),
        {
            "checkedOn": time.strftime("%Y-%m-%d %H:%M"),
            "route": "clean",
            "builder": rel(builder),
            "export": rel(out),
            "exportSha256": sha256(out),
            "triangleCapPassed": inspect.returncode == 0,
            "inspect": inspect.stdout.strip().splitlines(),
            "detail": detail,
            "budget": budget,
            "contract": contract,
            "limitations": "Local checks only. Shape fidelity is judged by eye on the builder's renders.",
        },
    )
    if inspect.returncode != 0:
        sys.exit("FAIL: the clean export breaks a Roblox limit; see the inspect output above.")
    print(f"built {rel(out)} by the clean route; outline against the source: {detail['outlineOverlap']} (information only)")
    failures = gate_failures(name, budget, contract)
    if failures:
        sys.exit("\n".join(failures))
    print(f"next: look at the review/clean-*.png renders; once approved: asset_generate.py publish {name} --confirm")


# ------------------------------------------------- publish / registry / records

UPLOADER = os.path.join(ROOT, "tools", "roblox", "upload_asset.ps1")


def latest_validation(pkg, export_sha):
    """The validation record that describes this exact export file, or None."""
    for name in ("validation.json", "validation-clean.json"):
        path = os.path.join(pkg, name)
        if os.path.isfile(path) and read_json(path).get("exportSha256") == export_sha:
            return read_json(path)
    return None


def cmd_publish(args):
    """Upload the built export through the existing Open Cloud uploader and record the id.

    Skips the upload when this exact file is already uploaded. Refuses a file that has no
    passing validation, so nothing reaches Roblox that the local gates turned down."""
    pkg = package_dir(args.name)
    rules.claim(pkg, "publish")
    entry = rules.read_registry().get(args.name)
    if not entry or not entry.get("export"):
        sys.exit(f"{args.name} has no built export in {rel(rules.REGISTRY)}; run build first")
    export = os.path.join(ROOT, entry["export"])
    if not os.path.isfile(export):
        sys.exit(f"no file at {entry['export']}; run build first")
    current = sha256(export)
    if entry.get("assetId") and entry.get("uploadedSha256") == current:
        print(f"already uploaded: asset {entry['assetId']} is this exact file. Nothing to do.")
        return
    validation = latest_validation(pkg, current)
    if not validation:
        sys.exit("the export on disk has no validation record (it changed since the last build); run build again")
    blocked = [
        label
        for label, ok in (
            ("triangle cap", validation.get("triangleCapPassed")),
            ("detail", (validation.get("detail") or {}).get("passed") is not False),
            ("budget", (validation.get("budget") or {}).get("passed")),
            ("size and pivot", (validation.get("contract") or {}).get("passed")),
        )
        if not ok
    ]
    if blocked:
        sys.exit("not uploading: the last build failed " + ", ".join(blocked) + ". Fix it and build again.")
    brief = read_brief(pkg) or {}
    command = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", UPLOADER, "-File", export]
    if brief.get("purpose"):
        command += ["-Description", brief["purpose"]]
    if not args.confirm:
        done = subprocess.run(command + ["-DryRun"], capture_output=True, text=True, encoding="utf-8", errors="replace")
        print(printable(done.stdout.rstrip()))
        print(f"dry run only. {entry['export']} passed its gates and is ready. After the review sheets are approved by the user:")
        print(f"  python tools/asset_generate.py publish {args.name} --confirm")
        return
    done = subprocess.run(command, capture_output=True, text=True, encoding="utf-8", errors="replace")
    print(printable(done.stdout.rstrip()))
    found = re.search(r"(?:Uploaded|Previously uploaded) asset: (\d+)", done.stdout)
    if not found:
        sys.exit("upload did not report an asset id. " + printable(done.stderr[-400:]))
    rules.record_upload(args.name, int(found.group(1)), current)
    print(f"recorded asset {found.group(1)} in {rel(rules.REGISTRY)}. Game code reads it from Shared.AssetRegistry.")
    print(f"next: check it in Studio, then  asset_generate.py verify {args.name} --check loads --check facing ...")


def cmd_register(args):
    """Record an id for an export that was uploaded before the registry existed."""
    pkg = package_dir(args.name)
    entry = rules.read_registry().get(args.name)
    if not entry:
        sys.exit(f"{args.name} is not in {rel(rules.REGISTRY)}; run build first so its export is recorded")
    rules.record_upload(args.name, args.asset_id, entry.get("exportSha256"))
    print(f"recorded asset {args.asset_id} for {args.name} against export {entry['exportSha256'][:16]}.")
    del pkg


def cmd_verify(args):
    """Tick off what was checked by eye in Studio. Only a person, or Studio itself, can."""
    studio = rules.record_studio(args.name, args.check or ())
    for check, ok in studio["checks"].items():
        print(f"  {'done' if ok else 'TODO':<5} {check}")
    if studio["verifiedOn"]:
        print(f"all Studio checks recorded ({studio['verifiedOn']}).")


def cmd_verdict(args):
    """Record how the current scan build looks, beside its surface-error score."""
    pkg = package_dir(args.name)
    path = os.path.join(pkg, "validation.json")
    if not os.path.isfile(path) or "detail" not in read_json(path):
        sys.exit(f"{args.name} has no scored scan build; run build first")
    validation = read_json(path)
    write_json(
        rules.verdict_path(pkg),
        {
            "looks": args.looks,
            "note": args.note,
            "exportSha256": validation["exportSha256"],
            "worstSurfaceError": validation["detail"]["worstSurfaceError"],
            "recordedOn": time.strftime("%Y-%m-%d"),
        },
    )
    print(f"recorded: {args.name} looks {args.looks} at surface error {validation['detail']['worstSurfaceError']:.3f}")


def cmd_calibrate(args):
    del args
    print(rules.calibration_report(DETAIL_WARN, DETAIL_FAIL))


def cmd_claim(args):
    pkg = package_dir(args.name)
    if args.release:
        rules.release(pkg)
        print(f"released {args.name}")
        return
    rules.claim(pkg, "claim", take_over=args.take_over)
    print(f"{args.name} is claimed by {rules.owner()} for {rules.CLAIM_HOURS} hours from its last command.")


def cmd_provenance(args):
    pkg = package_dir(args.name)
    if args.made_with or args.prompt_text:
        rules.write_reference_record(pkg, args.origin or "user-supplied", args.made_with, args.prompt_text)
    record = rules.write_provenance(pkg, args.name)
    if not record:
        sys.exit(f"no source/*.glb in {rel(pkg)} to describe")
    print(json.dumps(record, indent=2))


def cmd_prompt(args):
    """Print a reference-image prompt in the house framing, for Midjourney or any image tool."""
    pkg = package_dir(args.name)
    body = f"{REFERENCE_STYLES[args.style]}: {args.describe.strip().rstrip('.')}. {REFERENCE_FRAMING}"
    ratio = {"square": "1:1", "wide": "3:2", "tall": "2:3"}[args.aspect]
    text = f"{body} --ar {ratio} --style raw" if args.tool == "midjourney" else body
    os.makedirs(os.path.join(pkg, "source"), exist_ok=True)
    rules.write_reference_record(pkg, "user-supplied", args.tool, text)
    print(text)
    print(f"\n(recorded in {rel(os.path.join(pkg, 'source', 'reference.json'))}; then write the brief, then: asset_generate.py generate <saved image> --name {args.name})")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="command", required=True)

    ref = sub.add_parser("reference", help="text prompt -> reference image candidates")
    ref.add_argument("name", help="package name, kebab-case")
    ref.add_argument("--prompt", help="full-sentence description of the object")
    ref.add_argument("--seeds", type=int, default=4, help="how many candidates (default 4)")
    ref.add_argument("--first-seed", type=int, default=1)
    ref.add_argument("--style", choices=sorted(REFERENCE_STYLES), default="realistic", help="look the prompt leads with")
    ref.add_argument("--aspect", choices=sorted(REFERENCE_ASPECTS), default="square", help="frame shape; match the subject")
    ref.add_argument("--raw", action="store_true", help="send the prompt as written, without style or framing")
    ref.add_argument("--edit", metavar="INSTRUCTION", help="change one thing about the current reference, keep the rest")
    ref.add_argument("--use", type=int, metavar="SEED", help="promote this candidate to source/reference.png")
    ref.add_argument("--replace", action="store_true", help="with --use, overwrite an existing reference")
    ref.add_argument("--no-brief", action="store_true", help="generate before a brief exists")
    ref.set_defaults(run=cmd_reference)

    gen = sub.add_parser("generate", help="image -> candidates -> contact sheet")
    gen.add_argument("image", nargs="?", help="omit to use the package's source/reference.*")
    gen.add_argument("--name", required=True, help="package name, kebab-case")
    gen.add_argument("--seeds", type=int, help="how many candidates (default 3; 1 on the clean route)")
    gen.add_argument("--no-brief", action="store_true", help="generate before a brief exists")
    gen.add_argument("--made-with", help="tool that made the reference image, e.g. Midjourney (for provenance)")
    gen.add_argument("--prompt-text", help="the prompt that made the reference image (for provenance)")
    gen.add_argument("--first-seed", type=int, default=1)
    gen.add_argument("--resolution", choices=["512", "1024", "1536"], default="1024")
    gen.add_argument("--decimation", type=int, default=300000, help="Space-side triangle target")
    gen.add_argument("--texture", type=int, default=2048, help="Space-side texture size")
    gen.set_defaults(run=cmd_generate)

    rev = sub.add_parser("review", help="rebuild the contact sheet from existing candidates")
    rev.add_argument("name")
    rev.add_argument("--force", action="store_true", help="re-run every appraisal")
    rev.set_defaults(run=cmd_review)

    pick = sub.add_parser("pick", help="promote one candidate to the package source")
    pick.add_argument("name")
    pick.add_argument("--seed", type=int, required=True)
    pick.add_argument("--replace", action="store_true")
    pick.set_defaults(run=cmd_pick)

    brief = sub.add_parser("brief", help="record what the asset is for and how big it is")
    brief.add_argument("name")
    brief.add_argument("--purpose", help="one sentence: what it is and where it goes")
    brief.add_argument("--role", choices=ROLES)
    brief.add_argument("--height", type=float, help="finished height in studs")
    brief.add_argument("--pivot", choices=["bottom", "center", "top", "origin"])
    brief.add_argument("--meshes", choices=["auto", "single", "tiled"], help="one mesh, or a 2x2 tile set")
    brief.add_argument("--route", choices=ROUTES, help="scan keeps the generated mesh; clean rebuilds it from shapes")
    brief.add_argument("--kind", choices=sorted(rules.KINDS), help="vehicle and weapon need mounts; prop (default) does not")
    brief.add_argument("--mount", action="append", metavar="NAME=x,y,z", help="a named point in studs from the pivot, -z forward; repeatable")
    brief.add_argument("--length", type=float, help="finished front-to-back length in studs (weapons)")
    brief.add_argument("--game-name", help="the name game code uses for it, e.g. WaveRunner or WhiteSniper")
    brief.add_argument("--budget-waiver", metavar="REASON", help="why this asset may exceed its role's triangle budget")
    brief.set_defaults(run=cmd_brief)

    build = sub.add_parser("build", help="brief + picked source -> game-ready GLB, checked")
    build.add_argument("name")
    build.add_argument("--no-retry", action="store_true", help="stop at the first triangle-cap failure")
    build.add_argument("--no-audit", action="store_true", help="skip the audit renders (about two minutes)")
    build.add_argument("--allow-detail-loss", action="store_true", help="do not fail when the export has drifted from the source")
    build.set_defaults(run=cmd_build)

    audit = sub.add_parser("audit", help="render the export from every side, with a hole map")
    audit.add_argument("name")
    audit.add_argument("--seed", type=int, help="audit this candidate instead of the export")
    audit.add_argument("--focus", action="append", metavar="X,Y,Z", help="extra close-up at this point, as fractions of the bounding box")
    audit.add_argument("--zoom", type=float, default=3.0, help="magnification of --focus close-ups (default 3)")
    audit.set_defaults(run=cmd_audit)

    pub = sub.add_parser("publish", help="upload the built export and record its id (dry run without --confirm)")
    pub.add_argument("name")
    pub.add_argument("--confirm", action="store_true", help="really upload; only after the user approved the review sheets")
    pub.set_defaults(run=cmd_publish)

    reg = sub.add_parser("register", help="record the id of an export uploaded outside publish")
    reg.add_argument("name")
    reg.add_argument("--asset-id", type=int, required=True)
    reg.set_defaults(run=cmd_register)

    ver = sub.add_parser("verify", help="record Studio checks done by eye")
    ver.add_argument("name")
    ver.add_argument("--check", action="append", choices=rules.STUDIO_CHECKS)
    ver.set_defaults(run=cmd_verify)

    verdict = sub.add_parser("verdict", help="record how the current scan build looks, for calibration")
    verdict.add_argument("name")
    verdict.add_argument("--looks", choices=["good", "bad"], required=True)
    verdict.add_argument("--note")
    verdict.set_defaults(run=cmd_verdict)

    cal = sub.add_parser("calibrate", help="surface-error scores beside verdicts: are the gate's lines right?")
    cal.set_defaults(run=cmd_calibrate)

    claim = sub.add_parser("claim", help="reserve a package for this session, or release it")
    claim.add_argument("name")
    claim.add_argument("--take-over", action="store_true", help="take a package another session still holds")
    claim.add_argument("--release", action="store_true")
    claim.set_defaults(run=cmd_claim)

    prov = sub.add_parser("provenance", help="write provenance.json from what is on disk")
    prov.add_argument("name")
    prov.add_argument("--origin", choices=["user-supplied", "generated"])
    prov.add_argument("--made-with", help="tool that made the reference image")
    prov.add_argument("--prompt-text", help="the prompt that made the reference image")
    prov.set_defaults(run=cmd_provenance)

    prompt = sub.add_parser("prompt", help="print a reference-image prompt in the house framing")
    prompt.add_argument("name")
    prompt.add_argument("--describe", required=True, help="full-sentence description of the object")
    prompt.add_argument("--style", choices=sorted(REFERENCE_STYLES), default="realistic")
    prompt.add_argument("--aspect", choices=sorted(REFERENCE_ASPECTS), default="square")
    prompt.add_argument("--tool", choices=["midjourney", "other"], default="midjourney")
    prompt.set_defaults(run=cmd_prompt)

    args = ap.parse_args()
    args.run(args)


if __name__ == "__main__":
    main()
