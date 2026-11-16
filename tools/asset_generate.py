"""Reference image -> candidate GLBs -> appraisal -> one contact sheet to review.

Replaces the by-hand loop of opening the TRELLIS.2 Space, uploading an image,
clicking Generate, clicking Extract and saving the file. The Space is called
through its public API (the same one the web page uses), so the result is the
same model and the same settings you get in the browser.

    python tools/asset_generate.py generate <image> --name wooden-crate --seeds 3
    python tools/asset_generate.py review   wooden-crate
    python tools/asset_generate.py pick     wooden-crate --seed 2
    python tools/asset_generate.py brief    wooden-crate --purpose "..." --role decor --height 4
    python tools/asset_generate.py build    wooden-crate

brief     writes brief.json: purpose, role, height in studs, pivot. Write it at any
          point before build; pick copies its purpose into the appraisal decision.
build     turns the brief into scene.json (a one-asset scene_kit manifest kept in
          the package), runs scene_kit, checks the export against the triangle cap,
          renders review/views.png of the written file and records validation.json.
          It never uploads.

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
import os
import re
import shutil
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPACE = "microsoft/TRELLIS.2"
APPRAISER = os.path.join(ROOT, "tools", "blender", "appraise_asset.py")


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


def trial_dirs(pkg):
    dirs = glob.glob(os.path.join(pkg, "trials", "seed-*"))
    return sorted(dirs, key=lambda d: int(d.rsplit("-", 1)[1]))


def reference_image(pkg):
    for path in sorted(glob.glob(os.path.join(pkg, "source", "reference.*"))):
        return path
    return None


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
        print(f"appraisal failed for {source}:\n{(done.stdout or '')[-800:]}{(done.stderr or '')[-400:]}")
        return False
    return True


def appraise_trials(pkg, force=False):
    for trial in trial_dirs(pkg):
        glb = os.path.join(trial, "candidate.glb")
        record = os.path.join(trial, "appraisal.json")
        if os.path.isfile(glb) and (force or not os.path.isfile(record)):
            print(f"appraising {os.path.basename(trial)}...", flush=True)
            appraise(glb, record)


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
    if not os.path.isfile(args.image):
        sys.exit(f"no such image: {args.image}")
    pkg = package_dir(args.name)
    os.makedirs(os.path.join(pkg, "source"), exist_ok=True)
    reference = os.path.join(pkg, "source", "reference" + os.path.splitext(args.image)[1].lower())
    if os.path.abspath(args.image) != os.path.abspath(reference):
        shutil.copyfile(args.image, reference)
    seeds = list(range(args.first_seed, args.first_seed + args.seeds))
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

ROLES = ("decor", "cover", "interactive")
SINGLE_MESH_MAX_STUDS = 12  # taller than this and one 10k mesh starts to look melted


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
    if tiled:
        spec["tile"] = [2, 2]
    spec.update(brief.get("scene", {}))
    return spec


def cmd_brief(args):
    pkg = package_dir(args.name)
    brief = read_brief(pkg) or {}
    for key, value in (
        ("purpose", args.purpose),
        ("role", args.role),
        ("heightStuds", args.height),
        ("pivot", args.pivot),
        ("meshes", args.meshes),
    ):
        if value is not None:
            brief[key] = value
    missing = [k for k in ("purpose", "role", "heightStuds") if k not in brief]
    if missing:
        sys.exit("a new brief needs --purpose, --role and --height; missing: " + ", ".join(missing))
    brief.setdefault("pivot", "bottom")
    brief.setdefault("meshes", "auto")
    brief.setdefault("scene", {})
    os.makedirs(pkg, exist_ok=True)
    write_json(os.path.join(pkg, "brief.json"), brief)
    print(f"wrote {rel(os.path.join(pkg, 'brief.json'))}")
    if brief["role"] == "cover":
        print("note: cover a player relies on is a block in the map file; this mesh is its visual shell.")


def cmd_build(args):
    pkg = package_dir(args.name)
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

    manifest = os.path.join(pkg, "scene.json")
    write_json(manifest, {"_comment": "Generated from brief.json by tools/asset_generate.py build.", "assets": {args.name: spec}})
    out = os.path.join(ROOT, spec["out"])
    if os.path.isfile(out):
        backup = os.path.join(pkg, "trials", "previous-export.glb")
        os.makedirs(os.path.dirname(backup), exist_ok=True)
        shutil.copyfile(out, backup)
        print(f"backed up the previous export to {rel(backup)}")

    kit = os.path.join(ROOT, "tools", "blender", "scene_kit.py")
    built = subprocess.run([blender, "-b", "-noaudio", "--python", kit, "--", "--manifest", manifest, "--asset", args.name])
    if built.returncode != 0 or not os.path.isfile(out):
        sys.exit("build failed; see the scene_kit output above")

    inspect = subprocess.run(
        [sys.executable, os.path.join(ROOT, "tools", "gltf_post.py"), "inspect", out],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )
    print(inspect.stdout.rstrip())
    passed = inspect.returncode == 0

    # Views of the written file, not of the source: that is the artifact that gets uploaded.
    review = os.path.join(pkg, "review")
    os.makedirs(review, exist_ok=True)
    rendered = appraise(out, os.path.join(review, "export.json"))

    write_json(
        os.path.join(pkg, "validation.json"),
        {
            "checkedOn": time.strftime("%Y-%m-%d %H:%M"),
            "export": spec["out"],
            "exportSha256": sha256(out),
            "sourceSha256": sha256(source),
            "triangleCapPassed": passed,
            "inspect": inspect.stdout.strip().splitlines(),
            "views": "review/views.png" if rendered else None,
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
    if not passed:
        sys.exit("FAIL: a mesh is over the 10,000-triangle cap. Set meshes to tiled in the brief, or lower scene.decimate.")
    print(f"built {spec['out']}; views: {rel(os.path.join(review, 'views.png'))}")
    print("next: look at the views, then upload with tools/roblox/upload_asset.ps1 once approved.")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="command", required=True)

    gen = sub.add_parser("generate", help="image -> candidates -> contact sheet")
    gen.add_argument("image")
    gen.add_argument("--name", required=True, help="package name, kebab-case")
    gen.add_argument("--seeds", type=int, default=3, help="how many candidates (default 3)")
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
    brief.set_defaults(run=cmd_brief)

    build = sub.add_parser("build", help="brief + picked source -> game-ready GLB, checked")
    build.add_argument("name")
    build.set_defaults(run=cmd_build)

    args = ap.parse_args()
    args.run(args)


if __name__ == "__main__":
    main()
