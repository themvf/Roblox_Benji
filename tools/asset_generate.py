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

questions prints the 10 intake questions. Ask the user all of them in one message
          before writing a brief; reference and generate stop until the brief holds the
          answers (or --assumed records what you chose because they said to decide).
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
import asset_gpu as gpu  # noqa: E402 - plan, cache, usage ledger and queue for hosted GPU runs
import asset_rules as rules  # noqa: E402 - budgets, registry, claims, provenance; see that file
import asset_shape as shape  # noqa: E402 - proportions and counts, checked before GPU and build time

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
    # Images only: source/reference.json (provenance) sorts before reference.png, and
    # handing that to PIL crashed generate, review, build and audit.
    for path in sorted(glob.glob(os.path.join(pkg, "source", "reference.*"))):
        if os.path.splitext(path)[1].lower() in (".png", ".jpg", ".jpeg", ".webp"):
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


def accept(pkg, stage, reason):
    """Record why a failed proportion or count check was passed anyway."""
    brief = read_brief(pkg) or {}
    brief.setdefault("accepted", []).append({"stage": stage, "reason": reason.strip(), "on": time.strftime("%Y-%m-%d"), "by": rules.owner()})
    write_json(os.path.join(pkg, "brief.json"), brief)


def shape_gate(pkg, name, stage, problems, counted, accepting):
    """Stop a picture or mesh whose proportions or counts do not match the brief.

    `problems` are proportion problems already measured. `counted` is what the caller
    counted on the sheet (--counted name=n). Returns the counts as recorded."""
    brief = read_brief(pkg) or {}
    wanted = brief.get("counts") or {}
    try:
        seen = shape.parse_counts(counted, "--counted")
    except ValueError as error:
        sys.exit(str(error))
    missing, wrong = shape.count_problems(wanted, seen)
    if missing:
        sys.exit(
            f"count them first: the brief for {name} says " + ", ".join(f"{k}={v}" for k, v in wanted.items()) + ". Look at the sheet, count each on "
            "the one you are choosing, and pass what you counted:  " + " ".join(f"--counted {k}=<n>" for k in missing)
        )
    failed = ["shape: " + p for p in problems] + ["count: " + w for w in wrong]
    if failed and not (accepting or "").strip():
        sys.exit(
            f"{name} does not match its brief at {stage}:\n  " + "\n  ".join(failed) + "\n"
            "Choose another, fix the picture (reference --edit), or correct the brief if the brief is what is wrong. "
            "To go on with it as it is, say why:  --accept \"<reason>\""
        )
    if failed:
        accept(pkg, stage, accepting + " [" + "; ".join(failed) + "]")
        print("accepted with a reason; it is recorded in the brief and belongs in the report:\n  " + "\n  ".join(failed))
    return seen


def reference_shapes(pkg, brief):
    """Print each reference candidate's outline against what the brief's size allows."""
    if not brief or not shape.target(brief):
        return
    for path in reference_trials(pkg):
        aspect, low, high, problem = shape.image_problem(path, brief)
        if aspect is None:
            continue
        label = os.path.splitext(os.path.basename(path))[0]
        print(f"  {label}: {aspect:.2f} wide per high (the brief allows {low:.2f} to {high:.2f})" + ("  REJECT: " + problem if problem else ""))


def require_brief(pkg, name, skip):
    """Stop a generation that has no brief yet. Route and size decide how much to generate."""
    brief = read_brief(pkg)
    if brief and not skip:
        unanswered = [k for k in rules.INTAKE_REQUIRED if brief.get(k) in (None, "")]
        if unanswered and not brief.get("assumed"):
            sys.exit(
                f"the brief for {name} is missing answers from the user: " + ", ".join(unanswered) + ".\n"
                "Ask them in one message (python tools/asset_generate.py questions), then record the answers with\n"
                f"  python tools/asset_generate.py brief {name} --where ... --copies ... --share game|public --kind ...\n"
                "If the user told you to decide, record what you chose: brief <name> --assumed \"<what and why>\"."
            )
    if brief and not skip and "counts" not in brief:
        sys.exit(
            f"the brief for {name} does not say what must be counted. List every part your description gives a number for "
            "(seats, wheels, blades, legs, doors, paintings), so each can be checked on the picture and the mesh:\n"
            f"  python tools/asset_generate.py brief {name} --count seats=8 --count legs=4\n"
            f"or, if nothing on it has a number:  brief {name} --count none"
        )
    if brief or skip:
        return brief
    sys.exit(
        f"no brief.json in {rel(pkg)}. Ask the user the intake questions (asset_generate.py questions), then\n"
        "write the brief, so the route is decided before GPU time is spent:\n"
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
        brief = read_brief(pkg) or {}
        problem = shape.image_problem(chosen, brief)[3]
        shape_gate(pkg, args.name, f"reference seed {args.use}", [problem] if problem else [], args.counted, args.accept)
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
    reference_shapes(pkg, read_brief(pkg))
    wanted = (read_brief(pkg) or {}).get("counts")
    if wanted:
        print("count on each picture before choosing: " + ", ".join(f"{k}={v}" for k, v in wanted.items()) + ". --use needs --counted for each.")
    print(f"next: open the sheet, then  python tools/asset_generate.py reference {args.name} --use <n>")


# ---------------------------------------------------------------- generation


DRAFT_RESOLUTION = "512"  # enough to choose a shape; the picked seed is run once more at FINAL
FINAL_RESOLUTION = "1024"
MORE_NEEDS_REASON = 2  # with this many candidates already made, another needs --why


def generate_candidates(pkg, image, seeds, args, final=False):
    """Make one candidate per seed. Returns "ok", or "quota" when the GPU quota ran out.

    A draft is trials/seed-N/candidate.glb. A final is the same seed at full resolution,
    trials/seed-N/final.glb, made once for the seed that was picked. Every finished run is
    cached outside the repo and logged with its wall time (tools/asset_gpu.py)."""
    name = os.path.basename(pkg)
    where = (read_brief(pkg) or {}).get("where")
    file_name = "final.glb" if final else "candidate.glb"
    kind = "final" if final else "draft"
    todo = [s for s in seeds if not os.path.isfile(os.path.join(pkg, "trials", f"seed-{s}", file_name))]
    for seed in seeds:
        if seed not in todo:
            print(f"seed {seed}: already generated, skipping")

    def record_for(seed):
        return {
            "space": SPACE,
            "seed": seed,
            "resolution": args.resolution,
            "decimationTarget": args.decimation,
            "textureSize": args.texture,
            "reference": os.path.basename(image),
            "generatedOn": time.strftime("%Y-%m-%d"),
        }

    def keep(seed, glb):
        out_dir = os.path.join(pkg, "trials", f"seed-{seed}")
        os.makedirs(out_dir, exist_ok=True)
        shutil.copyfile(glb, os.path.join(out_dir, file_name))
        note = os.path.join(out_dir, "generation.json")
        if final and os.path.isfile(note):
            shutil.copyfile(note, os.path.join(out_dir, "draft.json"))
        write_json(note, record_for(seed))

    # The cache first: a renamed or cleaned-up package does not pay for the same run twice.
    keys = {seed: gpu.cache_key(image, seed, args.resolution, args.decimation, args.texture, SPACE) for seed in todo}
    for seed in list(todo):
        cached = gpu.cache_get(keys[seed])
        if cached:
            keep(seed, cached)
            gpu.log_run(name, where, kind, seed, args.resolution, 0, "cached", rules.owner())
            print(f"seed {seed}: taken from the cache, no GPU used")
            todo.remove(seed)
    if not todo:
        return "ok"

    picture = gpu.image_id(image)
    if gpu.crashes(image, args.resolution) >= gpu.CRASH_LIMIT and not getattr(args, "try_anyway", False):
        print(f"this picture has already crashed the generator {gpu.CRASH_LIMIT} times at {args.resolution}. Not calling the Space again.")
        return "crash"
    waiting = gpu.retry_after()
    if waiting and not getattr(args, "try_anyway", False):
        print(f"GPU quota was used up; it is expected back about {waiting}. Not calling the Space.")
        return "quota"

    try:
        from gradio_client import Client, handle_file
    except ImportError:
        sys.exit("gradio_client is missing: python -m pip install gradio_client")
    token = os.environ.get("HF_TOKEN")
    if not token:
        print("HF_TOKEN is not set: calling anonymously, which has very little GPU quota.")
    try:
        client = Client(SPACE, token=token, verbose=False)
        client.predict(api_name="/start_session")
        prepared = client.predict(input=handle_file(image), api_name="/preprocess_image")
    except Exception as error:  # noqa: BLE001 - nothing was generated, so nothing was spent
        print(f"could not reach the generator: {printable(str(error))[:300]}")
        if gpu.classify(str(error)) == "quota":
            gpu.note_quota(str(error))
            return "quota"
        return "busy"
    if isinstance(prepared, dict):
        prepared = prepared.get("path")

    busy = 0
    for seed in todo:
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
            print(f"seed {seed}: FAILED after {time.time() - started:.0f}s: {printable(str(error))[:300]}")
            if "quota" in str(error).lower():
                back = gpu.note_quota(str(error))
                gpu.log_run(name, where, kind, seed, args.resolution, time.time() - started, "quota", rules.owner())
                print(f"GPU quota is used up; expected back about {back}. Finished seeds are kept.")
                return "quota"
            outcome = gpu.classify(str(error))
            gpu.log_run(name, where, kind, seed, args.resolution, time.time() - started, outcome, rules.owner(), str(error)[:200], image=picture)
            if outcome == "busy":
                busy += 1
                if busy >= 2:
                    return "busy"
                print("the generator was busy or the connection dropped; the next seed is tried once.")
                continue
            # A crash is about the picture and the settings, not the seed: the hedge crashed five
            # times running. Stop at the limit instead of spending the remaining seeds on it.
            if gpu.crashes(image, args.resolution) >= gpu.CRASH_LIMIT:
                print(f"that is {gpu.CRASH_LIMIT} crashes on this picture at {args.resolution}; stopping.")
                return "crash"
            continue
        glb = result[0] if isinstance(result, (list, tuple)) else result
        if isinstance(glb, dict):
            glb = glb.get("path")
        keep(seed, glb)
        gpu.cache_put(keys[seed], glb, record_for(seed))
        gpu.clear_quota_note()
        seconds = time.time() - started
        gpu.log_run(name, where, kind, seed, args.resolution, seconds, "ok", rules.owner(), getattr(args, "why", None))
        print(f"seed {seed}: done in {seconds:.0f}s, {os.path.getsize(glb) / 1e6:.1f} MB")
    return "ok"


def plan_gate(name, brief):
    """Stop a generation the map's asset plan does not cover. Returns nothing; exits with what to do."""
    where = brief.get("where")
    plan = gpu.plan_for(where)
    if not plan:
        others = gpu.unplanned_assets(where, name)
        if len(others) >= gpu.UNPLANNED_ASSETS:
            sys.exit(
                f"{where} already has {len(others)} generated assets and no asset plan ({', '.join(others)}). Before a third, list what "
                f"the map needs and what each one costs:  asset_generate.py plan \"{where}\" --add <name> --what \"...\" --source reuse|shapes|generate\n"
                "then put the table to the user and record the runs they approve."
            )
        return
    row = next((r for r in plan["assets"] if r["name"] == name), None)
    if not row:
        sys.exit(f"{name} is not in the asset plan for {plan['map']}. Add it first:  asset_generate.py plan \"{plan['map']}\" --add {name} --what \"...\" --source ...")
    if row["source"] != "generate":
        sys.exit(f"the plan for {plan['map']} says {name} is '{row['source']}', which uses no GPU. Change the plan and have the user approve it, or follow it.")
    approved = plan.get("approvedRuns")
    if approved is None:
        sys.exit(f"the asset plan for {plan['map']} is not approved. Show the user:  asset_generate.py plan \"{plan['map']}\"")
    used = gpu.plan_runs(plan)
    if used >= approved:
        sys.exit(
            f"the plan for {plan['map']} has used its {approved} approved GPU runs. Tell the user what is left to make and ask for more:  "
            f"asset_generate.py plan \"{plan['map']}\" --approve <runs> --said \"...\""
        )
    print(f"plan: {plan['map']} has used {used} of {approved} approved GPU runs.")


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
        # Erosion is blind to anything thinner than five pixels, which is every bar of a
        # lattice: the radio tower scored 0% patches with 2-4% of its pixels see-through.
        # So the unfiltered share is judged as well.
        flagged = patches > AUDIT_FLAG_PERCENT or percent > rules.HOLES_FAIL
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
        "Rows 1-2: textured and one-sided, as Roblox draws it." + (f" Brightened (gamma {gamma:.2f}); darker in game." if gamma < 1.0 else ""),
        "Rows 3-4: front faces grey, BACK faces magenta.",
        "Magenta is where Roblox shows straight through:",
        "a hole, a flipped patch, or a one-sided sheet.",
        f"Over {rules.HOLES_FAIL:g}% back faces or {AUDIT_FLAG_PERCENT:g}% patches: " + (", ".join(flagged) if flagged else "none"),
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
        "holesWarnPercent": rules.HOLES_WARN,
        "holesFailPercent": rules.HOLES_FAIL,
        "worstBackFacePercent": max((view["backFacePercent"] for view in views), default=0.0),
        "worstPatchPercent": max((view["backFacePatchPercent"] for view in views), default=0.0),
        "flagged": flagged,
        "views": views,
        "sheets": [rel(path) for path in sheets],
        "panels": rel(panels),
        "limitations": "Blender renders, not Roblox. Lighting, materials and transparency in Studio are not checked.",
    }
    record["passed"] = record["worstBackFacePercent"] <= rules.HOLES_FAIL
    write_json(os.path.join(base, "audit.json"), record)
    return record


def run_audit(pkg, source, base, focus=(), zoom=3.0, height_studs=0.0):
    """Render `source` from every side into <base>/audit/ and write the sheets beside it."""
    blender = find_blender()
    if not blender:
        print("Blender not found (set BLENDER); skipping the audit.")
        return None
    panels = os.path.join(base, "audit")
    if os.path.isdir(panels):
        shutil.rmtree(panels)
    command = [blender, "-b", "-noaudio", "--python", AUDITOR, "--", "--source", source, "--out-dir", panels]
    command += ["--zoom", str(zoom), "--closeup-studs", str(rules.CLOSEUP_STUDS), "--height-studs", str(height_studs or 0.0)]
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
    worst = record["worstBackFacePercent"]
    print(
        f"audit: {worst:g}% of the model shows a back face in the worst view (warn over {rules.HOLES_WARN:g}, "
        f"fail over {rules.HOLES_FAIL:g}); patches {record['worstPatchPercent']:g}%."
    )
    if record["flagged"]:
        print(f"audit: see-through in: {', '.join(record['flagged'])}. Every magenta pixel is a hole in game. LOOK at the close-ups.")
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
    # A candidate is not in studs yet; its close-ups are framed from the brief's height.
    height = (read_brief(pkg) or {}).get("heightStuds", 0.0) if args.seed is not None else 0.0
    if not run_audit(pkg, source, base, args.focus or (), args.zoom, height):
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


def crash_advice(resolution):
    """What to do when a picture has crashed the generator CRASH_LIMIT times at one resolution."""
    if str(resolution) != DRAFT_RESOLUTION:
        return (
            f"the generator crashed {gpu.CRASH_LIMIT} times on this picture at {resolution}. Another try at the same settings is not expected to differ, "
            f"and may still use quota. Use the {DRAFT_RESOLUTION} draft (pick --keep-draft), or change the picture."
        )
    return (
        f"the generator crashed {gpu.CRASH_LIMIT} times on this picture at {resolution}, the lowest setting. The picture is the cause: simplify it "
        "(reference --edit, or a new prompt with fewer loose or see-through parts), or build this asset from shapes (brief --route clean)."
    )


def trial_shape(trial, brief):
    """Proportion problems of one candidate against the brief, from its appraisal."""
    record = os.path.join(trial, "appraisal.json")
    if not brief or not os.path.isfile(record):
        return []
    return shape.mesh_problems(read_json(record).get("measurements", {}).get("size"), brief)


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
    if brief and not args.final:
        problem = shape.image_problem(reference, brief)[3]
        if problem and not (args.accept or "").strip():
            sys.exit(f"reference: {problem}. No GPU was used. Fix the picture or the brief's size, or pass --accept \"<reason>\".")
        if problem:
            accept(pkg, "generate", args.accept + " [shape: " + problem + "]")
    if brief and not args.final:
        plan_gate(args.name, brief)
    count = args.seeds if args.seeds is not None else 1
    seeds = list(range(args.first_seed, args.first_seed + count))
    made = [d for d in trial_dirs(pkg) if os.path.isfile(os.path.join(d, "candidate.glb"))]
    wanted_new = [s for s in seeds if not os.path.isfile(os.path.join(pkg, "trials", f"seed-{s}", "candidate.glb"))]
    if wanted_new and len(made) >= MORE_NEEDS_REASON and not args.why:
        sys.exit(
            f"{args.name} already has {len(made)} candidates. If they fail the same way the picture is the cause, and another seed "
            "will fail too: fix it with  reference --edit  and start again. If you still want another, say what was wrong with the "
            "ones you have:  --why \"...\""
        )
    if args.seeds is None:
        print("one candidate first, as a 512 draft. Look at it before asking for another (--seeds 2).")
    status = generate_candidates(pkg, reference, seeds, args)
    if status == "quota":
        argv = ["generate", "--name", args.name, "--seeds", str(count), "--first-seed", str(args.first_seed), "--resolution", str(args.resolution)]
        if args.why:
            argv += ["--why", args.why]
        added = gpu.queue_add(args.name, argv, rules.owner())
        print(("queued" if added else "already queued") + ": it will run with  asset_generate.py queue --run  once the quota is back. Carry on with other work.")
    elif status == "busy":
        argv = ["generate", "--name", args.name, "--seeds", str(count), "--first-seed", str(args.first_seed), "--resolution", str(args.resolution)]
        gpu.queue_add(args.name, argv + (["--why", args.why] if args.why else []), rules.owner())
        print("the generator was busy or unreachable twice. Queued (asset_generate.py queue --run); carry on with other work.")
    elif status == "crash":
        print(crash_advice(args.resolution))
    appraise_trials(pkg)
    if any(os.path.isfile(os.path.join(d, "candidate.glb")) for d in trial_dirs(pkg)):
        contact_sheet(pkg)
        for trial in trial_dirs(pkg):
            for problem in trial_shape(trial, brief):
                print(f"shape: {os.path.basename(trial)} is {problem}. pick will refuse it without --accept.")
        print(f"next: open the sheet, then  python tools/asset_generate.py pick {args.name} --seed <n>")


IMPORT_SEED_BASE = 200  # models made outside this tool are filed as seed-201, seed-202, ...
PACKED_EXTENSIONS = ("EXT_meshopt_compression", "KHR_draco_mesh_compression", "KHR_mesh_quantization")


def made_by(trial):
    """Who made a candidate: the outside service it was imported from, or the Space and its resolution."""
    note = os.path.join(trial, "generation.json")
    note = read_json(note) if os.path.isfile(note) else {}
    if note.get("service"):
        return note["service"]
    return f"TRELLIS.2 at {note['resolution']}" if note.get("resolution") else "unknown"


def cmd_import(args):
    """File a model made by another service as a candidate, so the same checks score it."""
    pkg = package_dir(args.name)
    brief = require_brief(pkg, args.name, False)
    rules.claim(pkg, "import")
    if not os.path.isfile(args.file):
        sys.exit(f"no such file: {args.file}")
    with open(args.file, "rb") as handle:
        if handle.read(4) != b"glTF":
            sys.exit(f"{args.file} is not a binary glTF file. Download the model as GLB (not FBX, OBJ, USDZ or a zip) and import that.")
    digest = sha256(args.file)
    seed = None
    for trial in trial_dirs(pkg):
        note = os.path.join(trial, "generation.json")
        if os.path.isfile(note) and read_json(note).get("sha256") == digest:
            seed = int(trial.rsplit("-", 1)[1])
            print(f"this file is already imported as seed {seed}; refreshing its record")
    if seed is None:
        taken = [int(d.rsplit("-", 1)[1]) for d in trial_dirs(pkg)]
        seed = max([IMPORT_SEED_BASE] + [n for n in taken if n > IMPORT_SEED_BASE]) + 1
    trial = os.path.join(pkg, "trials", f"seed-{seed}")
    os.makedirs(trial, exist_ok=True)
    # Services ship compressed files (Tripo: gltfpack with EXT_meshopt_compression), which
    # Blender cannot open: the first Tripo import appraised as 0 triangles and the comparison
    # called it a fit. Decode to a plain file first; the geometry is unchanged.
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import outline_check

    packed = [e for e in outline_check.read_glb(args.file)[0].get("extensionsUsed", []) if e in PACKED_EXTENSIONS]
    if packed:
        import gltf_post

        print(f"decoding {', '.join(packed)} so Blender can open it...", flush=True)
        gltf_post.cli("dequantize", args.file, os.path.join(trial, "candidate.glb"))
    else:
        shutil.copyfile(args.file, os.path.join(trial, "candidate.glb"))
    for stale in ("appraisal.json", "audit.json", "views.png"):
        if os.path.isfile(os.path.join(trial, stale)):
            os.remove(os.path.join(trial, stale))
    reference = reference_image(pkg)
    write_json(
        os.path.join(trial, "generation.json"),
        {
            "service": args.service,
            "space": None,
            "seed": seed,
            "resolution": "imported",  # not a draft: pick takes it as it is
            "file": os.path.basename(args.file),
            "sha256": digest,
            "settings": args.settings,
            "decoded": packed or None,
            "reference": os.path.basename(reference) if reference else None,
            "importedOn": time.strftime("%Y-%m-%d"),
        },
    )
    print(f"imported {os.path.basename(args.file)} from {args.service} as seed {seed}")
    appraise_trials(pkg)
    record = os.path.join(trial, "appraisal.json")
    if not os.path.isfile(record) or not read_json(record).get("measurements", {}).get("triangles"):
        sys.exit(f"FAIL: Blender could not read seed {seed} ({os.path.basename(args.file)}); see the error above. It cannot be compared or built until it opens.")
    contact_sheet(pkg)
    for problem in trial_shape(trial, brief):
        print(f"shape: seed {seed} is {problem}.")
    print(f"next: python tools/asset_generate.py compare {args.name}   (then pick {args.name} --seed {seed} to build from it)")


def cmd_compare(args):
    """Every candidate of one asset on the same measures, whoever made it."""
    from PIL import Image, ImageDraw

    pkg = package_dir(args.name)
    brief = read_brief(pkg)
    if not brief:
        sys.exit(f"no brief.json in {rel(pkg)}; the comparison is against the brief")
    allowed = rules.ROLE_BUDGETS[brief["role"]]
    wanted = shape.target(brief)
    rows = []
    for trial in trial_dirs(pkg):
        candidate = os.path.join(trial, "candidate.glb")
        record = os.path.join(trial, "appraisal.json")
        if not os.path.isfile(candidate):
            continue
        if not os.path.isfile(record):
            appraise(candidate, record)
        measured = read_json(record).get("measurements", {}) if os.path.isfile(record) else {}
        audit = os.path.join(trial, "audit.json")
        audited = read_json(audit) if os.path.isfile(audit) else None
        if (not audited or audited.get("sourceSha256") != sha256(candidate)) and not args.no_audit:
            audited = run_audit(pkg, candidate, trial, height_studs=brief.get("heightStuds", 0.0))
        triangles = measured.get("triangles") or 0
        if not triangles:
            print(f"  seed {trial.rsplit('-', 1)[1]} ({made_by(trial)}): could not be read by Blender; left out. Import it again.")
            continue
        size = measured.get("size")
        long_side, short_side = shape.mesh_studs(size, brief) if size and size[2] > 0 else (None, None)
        rows.append(
            {
                "seed": int(trial.rsplit("-", 1)[1]),
                "madeBy": made_by(trial),
                "triangles": triangles,
                # What our own reduction would have to remove. It is where the radio tower tore.
                "cutNeeded": round(max(0.0, 1 - allowed * BUDGET_START / triangles), 3) if triangles > allowed else 0.0,
                "studs": [round(long_side, 1), round(short_side, 1)] if long_side else None,
                "shapeProblems": trial_shape(trial, brief),
                "holesPercent": audited["worstBackFacePercent"] if audited else None,
                "openEdges": measured.get("openEdges"),
                "closeups": rel(os.path.join(trial, "audit_closeups.png")) if audited else None,
                "views": os.path.join(trial, "views.png"),
            }
        )
    if not rows:
        sys.exit(f"{args.name} has no candidates. Generate one, or bring one in:  asset_generate.py import <file.glb> --name {args.name} --from <service>")

    def line(row):
        cut = "fits the budget as delivered" if not row["cutNeeded"] else f"needs a {row['cutNeeded']:.0%} cut"
        size = f"{row['studs'][0]:g} x {row['studs'][1]:g} studs" if row["studs"] else "size unknown"
        fit = "" if not wanted else ("  OFF the brief" if row["shapeProblems"] else "  fits the brief")
        holes = "not audited" if row["holesPercent"] is None else f"{row['holesPercent']:g}% see-through"
        return f"seed {row['seed']:<4} {row['madeBy']:<20} {row['triangles']:>9,} tris, {cut}   {size}{fit}   {holes}   open edges {row['openEdges']}"

    print(f"{args.name}: role {brief['role']}, budget {allowed:,} triangles" + (f", brief {wanted[0]:g} x {wanted[1]:g} x {wanted[2]:g} studs" if wanted else ", brief has no length or width"))
    for row in rows:
        print("  " + line(row))
    counts = brief.get("counts") or {}
    if counts:
        print("  count on each by eye: " + ", ".join(f"{k}={v}" for k, v in counts.items()))
    print("  see-through: over %g%% warns, over %g%% fails a build. A cut past %.0f%% is where shape is lost." % (rules.HOLES_WARN, rules.HOLES_FAIL, CLEAN_REDUCTION * 100))

    row_h, label_h = 420, 30
    shown = [(row, Image.open(row["views"]).convert("RGB")) for row in rows if os.path.isfile(row["views"])]
    review = os.path.join(pkg, "review")
    os.makedirs(review, exist_ok=True)
    out = None
    if shown:
        shown = [(row, im.resize((round(im.width * row_h / im.height), row_h))) for row, im in shown]
        ref_path = reference_image(pkg)
        ref = Image.open(ref_path).convert("RGB") if ref_path else None
        if ref:
            ref = ref.resize((round(ref.width * row_h / ref.height), row_h))
        ref_w = ref.width + 12 if ref else 0
        sheet = Image.new("RGB", (ref_w + max(im.width for _, im in shown), (row_h + label_h) * len(shown)), "white")
        draw = ImageDraw.Draw(sheet)
        font = sheet_font(16)
        for index, (row, im) in enumerate(shown):
            top = index * (row_h + label_h)
            draw.text((8, top + 6), line(row), fill="black", font=font)
            if ref:
                sheet.paste(ref, (0, top + label_h))
            sheet.paste(im, (ref_w, top + label_h))
        out = os.path.join(review, "compare.png")
        sheet.save(out)
    for row in rows:
        row.pop("views")
    write_json(os.path.join(review, "compare.json"), {"asset": args.name, "comparedOn": time.strftime("%Y-%m-%d %H:%M"), "budget": allowed, "brief": wanted, "candidates": rows})
    print(f"sheet: {rel(out) if out else 'none (no views rendered)'}; numbers: {rel(os.path.join(review, 'compare.json'))}")
    print("LOOK at each candidate's close-ups before choosing: " + ", ".join(row["closeups"] for row in rows if row["closeups"]))
    print("Not measured here: how each survives the build's reduction (pick and build one to find out), or how it looks in Studio.")


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
    # Before the 1024 pass and the build are spent on it: is it the briefed shape, with the briefed parts?
    shape_gate(pkg, args.name, f"mesh seed {args.seed}", trial_shape(trial, read_brief(pkg)), args.counted, args.accept)
    # A draft is enough to choose a shape. On the scan route the mesh is the asset, so the
    # chosen seed is run once more at full resolution. On the clean route it is only a
    # guide for the builder, and the draft is kept.
    brief_now = read_brief(pkg) or {}
    made_at = str(read_json(os.path.join(trial, "generation.json")).get("resolution")) if os.path.isfile(os.path.join(trial, "generation.json")) else FINAL_RESOLUTION
    final = os.path.join(trial, "final.glb")
    needs_final = made_at == DRAFT_RESOLUTION and planned_route(brief_now) != "clean" and not args.keep_draft
    if needs_final and not os.path.isfile(final):
        reference = reference_image(pkg)
        if not reference:
            sys.exit("the draft's reference image is gone from source/; cannot run the final pass. Pass --keep-draft to use the draft.")
        print(f"seed {args.seed} was a {DRAFT_RESOLUTION} draft; running it once at {FINAL_RESOLUTION} for the build.")
        final_args = argparse.Namespace(resolution=FINAL_RESOLUTION, decimation=args.decimation, texture=args.texture, why=None, try_anyway=False)
        status = generate_candidates(pkg, reference, [args.seed], final_args, final=True)
        if status == "crash":
            sys.exit(crash_advice(FINAL_RESOLUTION) + " Nothing was picked.")
        if status != "ok" or not os.path.isfile(final):
            again = ["pick", args.name, "--seed", str(args.seed)] + (["--replace"] if args.replace else [])
            for item in args.counted or ():
                again += ["--counted", item]
            gpu.queue_add(args.name, again + (["--accept", args.accept] if args.accept else []), rules.owner())
            sys.exit("the final pass did not run. It is queued (asset_generate.py queue --run). Nothing was picked; or pass --keep-draft to build from the draft.")
        print("LOOK: the final should be the draft's shape with more detail. Compare trials/seed-%d/final.glb with the sheet before building." % args.seed)
    if needs_final or os.path.isfile(final) and not args.keep_draft:
        candidate = final
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
BUDGET_ATTEMPTS = 3  # extra rebuilds allowed to bring the total under the role's budget
BUDGET_START = 0.75  # first try keeps this share of the budget: cutting into tiles adds triangles
BUDGET_AIM = 0.97  # each further try aims just under the budget


ROUTES = ("auto", "scan", "clean")
# Surface error from tools/outline_check.py: the share of the source's visible surface the
# export gets wrong, worst view. Calibrated on the wave runner: its good 12-mesh build scores
# 0.040 and the broken tank 0.061; the build that came out crumpled scores 0.231 and the one
# full of holes 0.347. Those four were scored with 600,000 sample points. At the 4,000,000
# used since 2026-11-16 good builds score 0.012-0.036 and the torn radio tower 0.109; the
# two bad wave runner builds are no longer on disk to rescore. The lines were left where
# they were: nothing measured so far falls between 0.036 and 0.109.
DETAIL_WARN = 0.08
DETAIL_FAIL = 0.15
DETAIL_NOISE = 0.02  # a source that scores more than this against itself: the measure is short of points
# A copied slab of ground: the bottom slice fills this much of the footprint, and this many
# times what the slice above it fills. The radio tower's dirt patch scores 0.86 and 2.8; a
# sculpture on a plinth 1.0 and 1.9; five other builds under 0.2 and 0.5. It is a finding to
# put to the user (keep it, or cut it), not a failure: a plinth is the same shape.
GROUND_FILL = 0.5
GROUND_RATIO = 1.5


def is_close(brief):
    """Can a player get near enough to see bent bars and crumpled panels?"""
    nearest = brief.get("nearestStuds")
    if nearest is None:  # briefs written before the question existed
        return brief.get("role") != "scenery"
    return nearest < rules.SCENERY_MIN_STUDS


def detail_limit(brief):
    """The surface error a build may not exceed. Up close the warning line is the limit: the
    radio tower scored 0.122, between the two lines, with every strut visibly bent."""
    return DETAIL_WARN if is_close(brief) else DETAIL_FAIL


def surface_findings(export):
    """Ground patch and texture bleed of the written file (tools/surface_checks.py)."""
    sys.path.insert(0, os.path.join(ROOT, "tools"))
    import surface_checks

    ground = surface_checks.ground_patch(export)
    ground["flagged"] = ground["bottomFill"] > GROUND_FILL and ground["ratio"] > GROUND_RATIO
    return ground, surface_checks.texture_bleed(export)


def machine_findings(validation):
    """What the checks already know is wrong or doubtful with a build, in plain words."""
    found = []
    audit = validation.get("audit") or {}
    seen_through = audit.get("worstBackFacePercent") or 0.0
    if seen_through > rules.HOLES_WARN:
        found.append(f"holes: {seen_through:g}% of the model is see-through in the worst view ({', '.join(audit.get('flaggedViews') or []) or 'no view over the fail line'})")
    detail = validation.get("detail") or {}
    if validation.get("route") != "clean" and (detail.get("worstSurfaceError") or 0.0) > DETAIL_WARN:
        found.append(f"shape: the surface has drifted from the source (error {detail['worstSurfaceError']:.3f}); expect bent bars or crumpled panels")
    ground = validation.get("ground") or {}
    if ground.get("flagged"):
        w, d = ground["footprintStuds"]
        found.append(f"base: a slab about {w:g} by {d:g} studs sits under the model, wider than what stands on it. Copied ground, or a wanted base?")
    budget = validation.get("budget") or {}
    if budget and not budget.get("within", True):
        found.append(f"weight: {budget['triangles']:,} triangles against a budget of {budget['budget']:,}")
    return found
CLEAN_REDUCTION = 0.9  # ASSET_INTAKE_AND_LESSONS.md: past ~90% reduction the silhouette is gone


def recommend_route(brief, measured, spec):
    """("scan" | "clean", [reasons]). Scan keeps the generated mesh; clean rebuilds it from shapes.

    Advice from numbers already on hand, not a verdict: the outline and surface check after
    a build is what proves a scan route worked."""
    reasons = []
    if brief.get("role") in rules.CLOSE_ROLES:
        reasons.append(f"the role is {brief['role']}, so players are right next to it and its parts may need to move")
    if brief.get("thin") == "yes":
        reasons.append("it has thin bars or open framework, which a generated mesh tears and a reduction tears further")
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
    measure = outline_check.surface_measure(source, export)
    errors = {name: found["error"] for name, found in measure.items()}
    os.makedirs(os.path.dirname(sheet_path), exist_ok=True)
    outline_check.sheet(sheet_path, a, b)
    return {
        "outlineOverlap": {k: round(v, 3) for k, v in scores.items()},
        "surfaceError": {k: round(v, 3) for k, v in errors.items()},
        "worstSurfaceError": round(max(errors.values()), 3),
        # The source scored against itself: near zero, or the error above cannot be trusted.
        "noise": round(max(found["noise"] for found in measure.values()), 3),
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
            # Start inside the role's budget: a fifth of a 290,000-triangle mesh is 58,000, which
            # no decor asset (30,000) can keep, so every one failed its first build.
            allowed = rules.ROLE_BUDGETS[brief["role"]]
            budget = int(source_tris * DENSE_KEEP) if (brief.get("budgetWaiver") or "").strip() else min(int(source_tris * DENSE_KEEP), int(allowed * BUDGET_START))
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
        ("widthStuds", args.width),
        ("gameName", args.game_name),
        ("where", args.where),
        ("copies", args.copies),
        ("moving", args.moving),
        ("share", args.share),
        ("nearestStuds", args.nearest),
        ("thin", args.thin),
        ("holesWaiver", args.holes_waiver),
        ("detailWaiver", args.detail_waiver),
        ("assumed", args.assumed),
    ):
        if value is not None:
            brief[key] = value
    missing = [k for k in ("purpose", "role", "heightStuds") if k not in brief]
    if missing:
        sys.exit(
            "a new brief needs --purpose, --role and --height; missing: " + ", ".join(missing)
            + ".\nThese come from the user. Ask them:  python tools/asset_generate.py questions"
        )
    brief.setdefault("pivot", "bottom")
    brief.setdefault("meshes", "auto")
    brief.setdefault("route", "auto")
    brief.setdefault("scene", {})
    if args.count:
        try:
            brief["counts"] = shape.parse_counts(args.count, "--count")
        except ValueError as error:
            sys.exit(str(error))
    unanswered = [k for k in rules.INTAKE_REQUIRED if brief.get(k) in (None, "")]
    kind = brief.get("kind", "prop")  # left out of the file until the user has said, so it counts as unanswered
    for item in args.mount or ():
        found = re.fullmatch(r"([A-Za-z][A-Za-z0-9]*)=(-?[\d.]+),(-?[\d.]+),(-?[\d.]+)", item)
        if not found:
            sys.exit(f"--mount takes Name=x,y,z in studs from the pivot (-z is forward), got {item!r}")
        brief.setdefault("mounts", {})[found.group(1)] = [float(found.group(i)) for i in (2, 3, 4)]
    nearest = brief.get("nearestStuds")
    if brief["role"] == "scenery" and nearest is not None and nearest < rules.SCENERY_MIN_STUDS:
        sys.exit(
            f"a player can get within {nearest:g} studs of it, so it is not scenery (that role is for {rules.SCENERY_MIN_STUDS}+ studs "
            "and has the loosest rules). Use --role decor for something walked past, or --role cover."
        )
    needed = rules.KIND_ROLE.get(kind)
    if needed and brief["role"] != needed:
        sys.exit(f"kind {kind} goes with role {needed}, not {brief['role']}; pass --role {needed}")
    os.makedirs(pkg, exist_ok=True)
    write_json(os.path.join(pkg, "brief.json"), brief)
    print(f"wrote {rel(os.path.join(pkg, 'brief.json'))}")
    missing = [name for name in rules.KINDS[kind] if name not in brief.get("mounts", {})]
    if missing:
        print(f"kind {kind}: build will fail until these mounts are set: " + ", ".join(missing) + ". Add each with --mount Name=x,y,z once the model's shape is known.")
    if kind != "prop" and not brief.get("gameName"):
        print(f"kind {kind}: set --game-name to the name game code uses for it, so the gate can check it is wired in.")
    if unanswered:
        print(
            "intake: not answered yet: " + ", ".join(unanswered) + ". reference and generate will stop until they are. "
            "Ask the user (asset_generate.py questions), or pass --assumed with what you chose for them."
        )
    if "counts" not in brief:
        print("counts: not set. List what must come out as an exact number (--count seats=8), or --count none. reference and generate stop until then.")
    elif brief["counts"]:
        print("counts: " + ", ".join(f"{k}={v}" for k, v in brief["counts"].items()) + ". Each is counted on the picture, the mesh and the build.")
    if brief.get("share") == "public":
        print("share: public. Fill in the rights note in provenance.json before it leaves this game.")
    if brief.get("thin") == "yes" and brief.get("route") == "scan":
        print("thin parts on the scan route: expect torn bars. build will fail on holes unless --holes-waiver says why that is acceptable.")
    if brief.get("moving") and planned_route(brief) != "clean":
        print("moving parts: set --route clean, so each moving part is built as its own piece.")
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
    blender = find_blender()
    if not blender:
        sys.exit("Blender not found; set the BLENDER environment variable")

    if brief.get("route", "auto") == "clean" or (brief.get("route", "auto") == "auto" and brief.get("thin") == "yes"):
        # A clean build is modelled from shapes, so it does not need a generated mesh. With
        # one it is compared for information; without one (no GPU quota) it still builds.
        build_clean(args.name, pkg, source if os.path.isfile(source) else None, blender, brief)
        return
    if not os.path.isfile(source):
        sys.exit(f"no source at {spec['source']}; pick a candidate first")

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
    attempts, changed, budget_tries = [], {}, 0
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
        total = sum(mesh_triangles(inspect_text))
        attempts.append({"tile": spec.get("tile"), "decimate": spec.get("decimate"), "worstMesh": worst, "triangles": total, "passed": passed})
        # Under the cap but over the role's budget: the tower, the cabinet wall, the sofa and
        # the daybed were each rebuilt by hand two or three times to find the number. Cutting
        # into tiles adds triangles, so aim from what this build measured, not from a guess.
        allowed = rules.ROLE_BUDGETS[brief["role"]]
        if passed and total > allowed and not (brief.get("budgetWaiver") or "").strip() and not args.no_retry and budget_tries < BUDGET_ATTEMPTS and spec.get("decimate"):
            budget_tries += 1
            lowered = int(spec["decimate"] * allowed / total * BUDGET_AIM)
            floor = int(measured.get("triangles", 0) * RETRY_MIN_KEEP)
            print(f"budget: {total:,} triangles is over the {allowed:,} for role {brief['role']}; rebuilding to keep {lowered:,} before tiling (was {spec['decimate']:,}).", flush=True)
            if lowered < floor:
                print(f"budget: that is under {RETRY_MIN_KEEP:.0%} of the source ({floor:,}). Shape may be lost; the detail and hole checks below decide.")
            spec["decimate"] = lowered
            changed["decimate"] = lowered
            continue
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
    limit = detail_limit(brief)
    detail["limit"] = limit
    detail["passed"] = worst_error <= limit or args.allow_detail_loss
    print(f"detail: surface error {worst_error:.3f} worst view (warn over {DETAIL_WARN}, fail over {limit}); sheet {detail['sheet']}")
    if detail["noise"] > DETAIL_NOISE:
        print(f"detail: the source scores {detail['noise']:.3f} against itself, so about that much of the error is the measure, not the build. Judge this one from the close-ups, and raise SAMPLES in tools/outline_check.py.")
    ground, bleed = surface_findings(out)
    print(f"base: bottom slice fills {ground['bottomFill']:.0%} of the footprint, {ground['ratio']:g} times the slice above it." + (" A slab is under the model: copied ground, or a wanted base? Ask the user." if ground["flagged"] else ""))
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
            "ground": ground,
            "textureBleed": bleed,
            "budget": budget,
            "contract": contract,
            "buildAttempts": attempts,
            "inspect": inspect_text.strip().splitlines(),
            "views": "review/views.png" if rendered else None,
            "audit": {
                "passed": audited["passed"] or bool((brief.get("holesWaiver") or "").strip()),
                "waiver": (brief.get("holesWaiver") or "").strip() or None,
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
    if worst_error > limit and not args.allow_detail_loss:
        sys.exit(
            f"FAIL: detail lost. Surface error {worst_error:.3f} is over {limit}"
            + (" (the limit for something a player can get close to)" if limit < DETAIL_FAIL else "")
            + "; this export should not be uploaded. "
            f"Use the clean route (asset_generate.py brief {args.name} --route clean, then write "
            f"{rel(clean_builder(args.name))}), keep more triangles under scene.decimate in the brief, "
            "or pass --allow-detail-loss if it is only ever seen from far away."
        )
    failures = gate_failures(args.name, budget, contract)
    if audited and not audited["passed"] and not (brief.get("holesWaiver") or "").strip():
        failures.append(
            f"FAIL: holes. {audited['worstBackFacePercent']:g}% of the model is see-through in the worst view (limit {rules.HOLES_FAIL:g}); "
            f"look at review/audit_closeups.png. Use the clean route (asset_generate.py brief {args.name} --route clean, then write "
            f"{rel(clean_builder(args.name))}), or record why it is acceptable with brief --holes-waiver."
        )
    if failures:
        sys.exit("\n".join(failures))
    if route == "clean" and brief.get("route", "auto") != "scan":
        print("route: the numbers suggest a clean rebuild for this asset because " + "; ".join(reasons) + ".")
    print(
        f"next: look at review/audit_closeups.png yourself and record what is wrong: asset_generate.py findings {args.name}. "
        "Then give the user that list with the sheets and record their answer with verdict. publish --confirm needs both."
    )


def clean_appraisal(pkg, export, brief):
    """A shape build with no generated mesh has nothing appraised, and check_assets fails every
    built package without an appraisal. Appraise the export itself and state what it is for."""
    record = os.path.join(pkg, "appraisal.json")
    if os.path.isfile(record) and read_json(record).get("sourceSha256") != sha256(export) and glob.glob(os.path.join(pkg, "source", "*.glb")):
        return  # the appraisal describes the generated mesh; leave it
    if appraise(export, record):
        data = read_json(record)
        data["decision"] = decision_text(brief)
        write_json(record, data)


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
    # Blender exits 0 when a script raises unless told otherwise. A builder that failed its own
    # check left the previous export in place, and that old file was audited and reported as
    # the new build (the red SUV, 2026-11-17). So: fail on an exception, and on a stale file.
    started = time.time()
    built = subprocess.run(
        [blender, "-b", "-noaudio", "--python-exit-code", "1", "--python", builder], capture_output=True, text=True, encoding="utf-8", errors="replace"
    )
    if built.returncode == 0 and os.path.isfile(out) and os.path.getmtime(out) < started - 2:
        sys.exit(f"FAIL: {rel(builder)} ran but did not write {rel(out)}; the file on disk is from an earlier build.\n" + printable(built.stdout[-800:]))
    if built.returncode != 0 or not os.path.isfile(out):
        sys.exit("clean build failed. " + printable((built.stdout + built.stderr)[-800:]))
    inspect = subprocess.run(
        [sys.executable, os.path.join(ROOT, "tools", "gltf_post.py"), "inspect", out],
        capture_output=True, text=True, encoding="utf-8", errors="replace",
    )
    print(printable(inspect.stdout.rstrip()))
    detail = detail_check(source, out, os.path.join(pkg, "review", "clean-detail.png")) if source else {"outlineOverlap": None}
    detail["passed"] = None  # informational on this route
    budget, contract = gate_export(name, pkg, brief, "clean", out, sum(mesh_triangles(inspect.stdout)))
    clean_appraisal(pkg, out, brief)
    # A hand-built mesh can have flipped or missing faces too, and the user needs the same
    # close-ups to approve. Same audit as a scan, same hole lines.
    audited = run_audit(pkg, out, os.path.join(pkg, "review"))
    waiver = (brief.get("holesWaiver") or "").strip()
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
            "audit": {
                "passed": audited["passed"] or bool(waiver),
                "waiver": waiver or None,
                "sheets": audited["sheets"],
                "flaggedViews": audited["flagged"],
                "worstBackFacePercent": audited["worstBackFacePercent"],
                "worstPatchPercent": audited["worstPatchPercent"],
            }
            if audited
            else None,
            "limitations": "Local checks only. Shape fidelity is judged by eye on the builder's renders.",
        },
    )
    if inspect.returncode != 0:
        sys.exit("FAIL: the clean export breaks a Roblox limit; see the inspect output above.")
    print(f"built {rel(out)} by the clean route; outline against the source: {detail['outlineOverlap']} (information only)")
    failures = gate_failures(name, budget, contract)
    if audited and not audited["passed"] and not waiver:
        failures.append(
            f"FAIL: holes. {audited['worstBackFacePercent']:g}% of the model is see-through in the worst view (limit {rules.HOLES_FAIL:g}); "
            "a face in the builder is flipped or missing. Look at review/audit_closeups.png."
        )
    if failures:
        sys.exit("\n".join(failures))
    print(
        f"next: look at review/audit_closeups.png yourself and record what is wrong: asset_generate.py findings {name}. "
        "Then give the user that list with the sheets and record their answer with verdict. publish --confirm needs both."
    )


# ------------------------------------------------- publish / registry / records

UPLOADER = os.path.join(ROOT, "tools", "roblox", "upload_asset.ps1")


def current_export(pkg, name):
    """The export the registry holds for this asset (a clean build is <Name>Clean.glb), else the scan export."""
    entry = rules.read_registry().get(name) or {}
    if entry.get("export") and os.path.isfile(os.path.join(ROOT, entry["export"])):
        return os.path.join(ROOT, entry["export"])
    return os.path.join(pkg, "exports", pascal(name) + ".glb")


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
            ("holes", (validation.get("audit") or {}).get("passed") is not False),
        )
        if not ok
    ]
    if blocked:
        sys.exit("not uploading: the last build failed " + ", ".join(blocked) + ". Fix it and build again.")
    brief = read_brief(pkg) or {}
    # A warning is not a pass. Each one needs a written reason before anything is uploaded.
    warned = []
    error = 0.0 if validation.get("route") == "clean" else (validation.get("detail") or {}).get("worstSurfaceError") or 0.0
    if error > DETAIL_WARN and not (brief.get("detailWaiver") or "").strip():
        warned.append(f"detail warning (surface error {error:.3f}, over {DETAIL_WARN}); reason goes in brief --detail-waiver")
    seen_through = (validation.get("audit") or {}).get("worstBackFacePercent") or 0.0
    if seen_through > rules.HOLES_WARN and not (brief.get("holesWaiver") or "").strip():
        warned.append(f"holes warning ({seen_through:g}% see-through, over {rules.HOLES_WARN:g}); reason goes in brief --holes-waiver")
    if validation.get("audit") is None:
        warned.append("this build was never audited for holes; run build again")
    if warned:
        sys.exit("not uploading until each warning has a written reason:\n  " + "\n  ".join(warned))
    verdict = read_json(rules.verdict_path(pkg)) if os.path.isfile(rules.verdict_path(pkg)) else {}
    approved = verdict.get("exportSha256") == current and verdict.get("looks") == "good" and verdict.get("said")
    if args.confirm and not approved:
        sys.exit(
            "not uploading: the user has not approved this exact build. Show them review/audit.png and review/audit_closeups.png, "
            f"ask whether it looks right, then record their words: asset_generate.py verdict {args.name} --looks good --said \"...\""
        )
    command = ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", UPLOADER, "-File", export]
    if brief.get("purpose"):
        command += ["-Description", brief["purpose"]]
    if not args.confirm:
        done = subprocess.run(command + ["-DryRun"], capture_output=True, text=True, encoding="utf-8", errors="replace")
        print(printable(done.stdout.rstrip()))
        print(f"dry run only. {entry['export']} passed its gates." + ("" if approved else " Still needed: the user's verdict on the review sheets (asset_generate.py verdict)."))
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
    export = current_export(pkg, args.name)
    validation = latest_validation(pkg, sha256(export)) if os.path.isfile(export) else None
    if not validation:
        sys.exit(f"{args.name} has no validated build of the export on disk; run build first")
    said = (args.said or "").strip()
    if said.lower().strip(" .!") in rules.NOT_A_VERDICT:
        sys.exit(
            f"{said!r} does not say the user looked at the build. Show them review/audit.png and review/audit_closeups.png and ask: "
            "'Does this look right, including up close?' Record what they answer."
        )
    if not said:
        sys.exit("--said is required: the user's own words about the review sheets. A model's opinion is not a verdict.")
    found = current_findings(pkg, validation["exportSha256"])
    if not found:
        sys.exit(
            f"no written review of this build yet. Look at the close-ups yourself first and record what is wrong "
            f"(asset_generate.py findings {args.name}), give the user that list, and then record their answer."
        )
    error = (validation.get("detail") or {}).get("worstSurfaceError")
    write_json(
        rules.verdict_path(pkg),
        {
            "looks": args.looks,
            "said": said,
            "findingsShown": found["measured"] + found["seen"],
            "note": args.note,
            "exportSha256": validation["exportSha256"],
            "worstSurfaceError": error,
            "worstBackFacePercent": (validation.get("audit") or {}).get("worstBackFacePercent"),
            "recordedOn": time.strftime("%Y-%m-%d"),
        },
    )
    print(f"recorded: the user says {args.name} looks {args.looks}" + (f" (surface error {error:.3f})" if error is not None else ""))


REVIEW_GUIDE = """Open review/audit_closeups.png and review/audit.png and go through every panel. The user should
not have to find defects; you do, and they answer yes or no to your list. Look for:
  - bars, rails, antennas or wires that are bent, ragged, broken off or fused together
  - gaps you can see through in the textured rows (those are drawn the way Roblox draws them)
  - panels that are crumpled, melted or smeared
  - parts in the reference that are missing, or counted wrong (legs, wheels, blades, rungs)
  - things copied from the reference that are not the subject: ground, floor, cables, shadows
  - anything that would look wrong from as close as a player can get
Record each as  --defect "where: what"  (repeatable), or --none if every panel is sound.
What the checks measured is added for you."""


def findings_path(pkg):
    return os.path.join(pkg, "review", "findings.json")


def current_findings(pkg, export_sha):
    path = findings_path(pkg)
    if os.path.isfile(path):
        data = read_json(path)
        if data.get("exportSha256") == export_sha:
            return data
    return None


def cmd_findings(args):
    """The model's own written review of the close-ups, before the user is asked anything."""
    pkg = package_dir(args.name)
    export = current_export(pkg, args.name)
    validation = latest_validation(pkg, sha256(export)) if os.path.isfile(export) else None
    if not validation:
        sys.exit(f"{args.name} has no validated build of the export on disk; run build first")
    measured = machine_findings(validation)
    wanted = (read_brief(pkg) or {}).get("counts") or {}
    if not args.defect and not args.none:
        print(REVIEW_GUIDE)
        if wanted:
            print("\nCount on the build and pass each with --counted name=<n>: " + ", ".join(f"{k} (brief: {v})" for k, v in wanted.items()))
        if measured:
            print("\nAlready measured:\n  " + "\n  ".join(measured))
        sys.exit(1)
    if args.defect and args.none:
        sys.exit("--none and --defect together; pick one")
    try:
        counted = shape.parse_counts(args.counted, "--counted")
    except ValueError as error:
        sys.exit(str(error))
    missing, wrong = shape.count_problems(wanted, counted)
    if missing:
        sys.exit("count these on the build first and pass what you counted: " + " ".join(f"--counted {k}=<n>" for k in missing) + f"  (the brief says " + ", ".join(f"{k}={wanted[k]}" for k in missing) + ")")
    measured = measured + ["count: " + line for line in wrong]
    record = {
        "exportSha256": validation["exportSha256"],
        "reviewedBy": rules.owner(),
        "measured": measured,
        "counted": counted,
        "seen": args.defect or [],
        "recordedOn": time.strftime("%Y-%m-%d %H:%M"),
    }
    write_json(findings_path(pkg), record)
    total = measured + record["seen"]
    print(f"recorded {len(total)} finding(s) for {args.name}. Put this to the user with the two sheets, then ask: does it look right, or what should change?")
    for line in total or ["nothing found by the checks or by you"]:
        print(f"  - {line}")


def cmd_quota(args):
    del args
    print(gpu.usage_report())


def cmd_queue(args):
    pending = gpu.queue_list()
    if args.drop:
        for entry in [e for e in pending if e["asset"] == args.drop]:
            gpu.queue_remove(entry)
            print("dropped: " + " ".join(entry["argv"]))
        return
    if not pending:
        print("the queue is empty.")
        return
    if not args.run_now:
        for entry in pending:
            print(f"  {entry['queuedOn']}  {entry['owner']:<18} {' '.join(entry['argv'])}   ({entry['root']})")
        waiting = gpu.retry_after()
        print(f"quota expected back about {waiting}." if waiting else "quota is not known to be out; run them:  asset_generate.py queue --run")
        return
    waiting = gpu.retry_after()
    if waiting:
        print(f"quota is still out until about {waiting}; nothing run.")
        return
    for entry in pending:
        print("running: " + " ".join(entry["argv"]), flush=True)
        script = os.path.join(entry["root"], "tools", "asset_generate.py")
        done = subprocess.run([sys.executable, script] + entry["argv"], cwd=entry["root"], capture_output=True, text=True, encoding="utf-8", errors="replace")
        print(printable(done.stdout.rstrip()[-1500:]))
        if gpu.retry_after():
            print("the quota ran out again; the rest stays queued.")
            return
        gpu.queue_remove(entry)
        if done.returncode != 0:
            print(f"that request failed for another reason and was dropped from the queue: {printable(done.stderr[-300:])}")


def cmd_find(args):
    hits = gpu.find(" ".join(args.words))
    if not hits:
        print("nothing in assets/models or the runtime models matches. That is not proof nothing fits: check the prop folders too.")
        return
    for name, state, purpose in hits:
        print(f"  {name:<34} {state:<34} {purpose}")
    print("Reuse, rescale or recolour one of these before making a new asset.")


def cmd_plan(args):
    plan = gpu.read_plan(args.map) or {"map": args.map, "assets": [], "approvedRuns": None}
    changed = False
    if args.add:
        if not args.source or not args.what:
            sys.exit("--add needs --what and --source reuse|shapes|generate")
        if args.source == "reuse" and not args.reuses:
            sys.exit("--source reuse needs --reuses <existing package or model>")
        plan["assets"] = [row for row in plan["assets"] if row["name"] != args.add]
        plan["assets"].append({"name": args.add, "what": args.what, "source": args.source, "reuses": args.reuses, "why": args.why})
        changed = True
        if args.source != "reuse":
            hits = gpu.find(args.add + " " + args.what)[:4]
            if hits:
                print("already in the repo, check before making a new one:")
                for name, state, purpose in hits:
                    print(f"  {name:<34} {state:<30} {purpose}")
    if args.remove:
        plan["assets"] = [row for row in plan["assets"] if row["name"] != args.remove]
        changed = True
    if args.approve is not None:
        said = (args.said or "").strip()
        if not said:
            sys.exit("--approve needs --said: the user's own words agreeing to this number of GPU runs")
        plan.update(approvedRuns=args.approve, approvedSaid=said, approvedOn=time.strftime("%Y-%m-%d"))
        changed = True
    if changed:
        gpu.write_plan(plan)
    elif not plan["assets"]:
        sys.exit(f"no asset plan for {args.map} yet. Add each asset the map needs:  plan \"{args.map}\" --add <name> --what \"...\" --source reuse|shapes|generate")
    print(gpu.plan_text(plan))


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
    ref.add_argument("--counted", action="append", metavar="NAME=N", help="with --use: what you counted on that picture, for each count in the brief")
    ref.add_argument("--accept", metavar="REASON", help="with --use: go on although its shape or a count does not match the brief")
    ref.set_defaults(run=cmd_reference)

    gen = sub.add_parser("generate", help="image -> candidates -> contact sheet")
    gen.add_argument("image", nargs="?", help="omit to use the package's source/reference.*")
    gen.add_argument("--name", required=True, help="package name, kebab-case")
    gen.add_argument("--seeds", type=int, help="how many candidates in all (default 1; ask for a second only after looking at the first)")
    gen.add_argument("--why", help="what was wrong with the candidates you have; needed for a third")
    gen.add_argument("--try-anyway", action="store_true", help="call the Space even though the quota was recorded as used up")
    gen.add_argument("--final", action="store_true", help=argparse.SUPPRESS)
    gen.add_argument("--accept", metavar="REASON", help="go on although the picture's outline does not fit the brief's size")
    gen.add_argument("--no-brief", action="store_true", help="generate before a brief exists")
    gen.add_argument("--made-with", help="tool that made the reference image, e.g. Midjourney (for provenance)")
    gen.add_argument("--prompt-text", help="the prompt that made the reference image (for provenance)")
    gen.add_argument("--first-seed", type=int, default=1)
    gen.add_argument("--resolution", choices=["512", "1024", "1536"], default=DRAFT_RESOLUTION, help="512 drafts; pick runs the chosen seed at 1024")
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
    pick.add_argument("--keep-draft", action="store_true", help="build from the 512 draft; skip the 1024 final pass")
    pick.add_argument("--counted", action="append", metavar="NAME=N", help="what you counted on this candidate, for each count in the brief")
    pick.add_argument("--accept", metavar="REASON", help="go on although its proportions or a count do not match the brief")
    pick.add_argument("--decimation", type=int, default=300000, help="Space-side triangle target for the final pass")
    pick.add_argument("--texture", type=int, default=2048, help="Space-side texture size for the final pass")
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
    brief.add_argument("--length", type=float, help="finished front-to-back length in studs")
    brief.add_argument("--width", type=float, help="finished side-to-side width in studs")
    brief.add_argument("--count", action="append", metavar="NAME=N", help="a part that must come out as an exact number, e.g. seats=8; repeatable; 'none' if nothing")
    brief.add_argument("--game-name", help="the name game code uses for it, e.g. WaveRunner or WhiteSniper")
    brief.add_argument("--where", help="the map or place it goes in")
    brief.add_argument("--copies", type=int, help="about how many are on screen at once")
    brief.add_argument("--moving", help="parts that move by themselves, e.g. 'wheels, rotor'; empty string for none")
    brief.add_argument("--share", choices=["game", "public"], help="stays in this game, or may be sold or given away")
    brief.add_argument("--nearest", type=float, metavar="STUDS", help="how close a player can get; 0 for can touch it")
    brief.add_argument("--thin", choices=["yes", "no"], help="has thin bars, railings, wires or open framework")
    brief.add_argument("--holes-waiver", metavar="REASON", help="why see-through patches in this asset are acceptable")
    brief.add_argument("--detail-waiver", metavar="REASON", help="why a detail warning on this asset is acceptable")
    brief.add_argument("--assumed", help="answers you chose because the user said to decide; shown in the final report")
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

    verdict = sub.add_parser("verdict", help="record what the user said about the current build's review sheets")
    verdict.add_argument("name")
    verdict.add_argument("--looks", choices=["good", "bad"], required=True)
    verdict.add_argument("--said", help="the user's own words after looking at the review sheets; required")
    verdict.add_argument("--note")
    verdict.set_defaults(run=cmd_verdict)

    fnd = sub.add_parser("findings", help="record what you see wrong in the review sheets, before asking the user")
    fnd.add_argument("name")
    fnd.add_argument("--defect", action="append", metavar='"where: what"', help="one defect you can see; repeatable")
    fnd.add_argument("--none", action="store_true", help="every panel is sound")
    fnd.add_argument("--counted", action="append", metavar="NAME=N", help="what you counted on the build, for each count in the brief")
    fnd.set_defaults(run=cmd_findings)

    imp = sub.add_parser("import", help="file a model made by another service as a candidate, to be checked like any other")
    imp.add_argument("file", help="the downloaded .glb")
    imp.add_argument("--name", required=True, help="package name; it needs a brief")
    imp.add_argument("--from", dest="service", required=True, help="who made it, e.g. meshy, tripo")
    imp.add_argument("--settings", help="what you asked the service for, e.g. 'image to 3D, 30k triangles, PBR'")
    imp.set_defaults(run=cmd_import)

    cmp = sub.add_parser("compare", help="every candidate of one asset on the same measures, whoever made it")
    cmp.add_argument("name")
    cmp.add_argument("--no-audit", action="store_true", help="skip the hole renders for candidates not audited yet")
    cmp.set_defaults(run=cmd_compare)

    quota = sub.add_parser("quota", help="GPU runs in the last day, measured seconds per run, and when the quota is back")
    quota.set_defaults(run=cmd_quota)

    queue = sub.add_parser("queue", help="requests parked when the GPU quota ran out; --run tries them again")
    queue.add_argument("--run", dest="run_now", action="store_true", help="try the parked requests again")
    queue.add_argument("--drop", metavar="ASSET", help="remove this asset's parked requests")
    queue.set_defaults(run=cmd_queue)

    find = sub.add_parser("find", help="what already in the repo could be reused, before making something new")
    find.add_argument("words", nargs="+")
    find.set_defaults(run=cmd_find)

    plan = sub.add_parser("plan", help="a map's asset list: reuse, shapes or generate each, and the GPU runs the user approved")
    plan.add_argument("map")
    plan.add_argument("--add", metavar="NAME", help="package name of an asset the map needs")
    plan.add_argument("--what", help="what it is, in a few words")
    plan.add_argument("--source", choices=gpu.SOURCES, help="reuse something owned, build from shapes (no GPU), or generate")
    plan.add_argument("--reuses", help="the existing package or model a reuse row points at")
    plan.add_argument("--why", help="why this source, e.g. 'organic, seen up close'")
    plan.add_argument("--remove", metavar="NAME")
    plan.add_argument("--approve", type=int, metavar="RUNS", help="GPU runs the user agreed to for this map")
    plan.add_argument("--said", help="the user's own words approving that number")
    plan.set_defaults(run=cmd_plan)

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

    ask = sub.add_parser("questions", help="the questions to ask the user before writing a brief")
    ask.set_defaults(run=lambda _args: print(rules.intake_text()))

    args = ap.parse_args()
    args.run(args)


if __name__ == "__main__":
    main()
