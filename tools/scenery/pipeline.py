"""Create and build repository-backed Roblox scenery packages.

Usage (from the repository root):
    python tools/scenery/pipeline.py init --name mud-grassland --url <url>
    python tools/scenery/pipeline.py build --package assets/scenery/mud-grassland
    python tools/scenery/pipeline.py verify --package assets/scenery/mud-grassland

The Blender implementation remains in tools/blender/scene_kit.py. This wrapper
keeps provenance, source files, export settings, and verification beside each
asset so a new Sketchfab model follows the same path every time.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def package_name(value: str) -> str:
    return "-".join(value.lower().strip().replace("_", "-").split())


def read_manifest(package: Path) -> dict:
    path = package / "manifest.json"
    if not path.exists():
        raise SystemExit(f"missing manifest: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def find_blender(requested: str) -> str:
    """Resolve Blender from PATH or the standard Windows install locations."""
    found = shutil.which(requested)
    if found:
        return found
    candidates = []
    for root in (Path("C:/Program Files/Blender Foundation"),
                 Path("C:/Program Files (x86)/Blender Foundation")):
        if root.exists():
            candidates.extend(root.glob("Blender */blender.exe"))
    if candidates:
        return str(sorted(candidates, key=lambda p: p.parent.name)[-1])
    return requested


def init_package(args: argparse.Namespace) -> None:
    name = package_name(args.name)
    package = ROOT / "assets" / "scenery" / name
    if package.exists() and any(package.iterdir()):
        raise SystemExit(f"refusing to overwrite non-empty package: {package}")
    (package / "source").mkdir(parents=True, exist_ok=True)
    (package / "textures").mkdir(exist_ok=True)
    (package / "exports").mkdir(exist_ok=True)
    manifest = {
        "_comment": "Blender-compatible manifest. See tools/scenery/pipeline.py.",
        "metadata": {
            "name": args.name,
            "sourceUrl": args.url,
            "creator": args.creator or "",
            "license": args.license or "",
            "retrievedOn": str(date.today()),
            "intendedUse": "scenery",
            "collisionPolicy": "decorative mesh is non-collidable; author simple collision in Studio",
        },
        "assets": {
            name: {
                "description": f"{args.name} scenery export",
                "source": f"assets/scenery/{name}/source/{name}.glb",
                "out": f"assets/scenery/{name}/exports/{name}.glb",
                "textures": f"assets/scenery/{name}/textures",
                "fit": {"axis": "x", "size": args.width},
                "decimate": args.triangles,
                "tile": [args.tiles, args.tiles],
                "pivot": "bottom",
                "up": "z",
            }
        },
    }
    (package / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (package / "verification.json").write_text(json.dumps({"status": "Not built", "checks": []}, indent=2) + "\n", encoding="utf-8")
    readme = (
        f"# {args.name}\n\n"
        f"Source page: {args.url}\n\n"
        "Put the downloaded source in `source/` using the filename in `manifest.json`. "
        "Creator and license fields are optional provenance notes.\n\n"
        "## Build\n\n"
        "```powershell\n"
        f"python tools/scenery/pipeline.py build --package assets/scenery/{name}\n"
        f"python tools/scenery/pipeline.py verify --package assets/scenery/{name}\n"
        "```\n\n"
        "The resulting GLB is scenery only. Keep it outside playable bounds and add simple "
        "authored collision separately in the Studio review step.\n"
    )
    (package / "README.md").write_text(readme, encoding="utf-8")
    print(package)


def build_package(args: argparse.Namespace) -> None:
    package = (ROOT / args.package).resolve()
    manifest = read_manifest(package)
    for name, spec in manifest["assets"].items():
        source = ROOT / spec["source"]
        if not source.exists():
            raise SystemExit(f"source is missing for {name}: {source}")
    blender = find_blender(args.blender)
    command = [blender, "-b", "-noaudio", "--python", str(ROOT / "tools/blender/scene_kit.py"), "--",
               "--manifest", str(package / "manifest.json"), "--all"]
    print("running:", " ".join(command))
    subprocess.run(command, cwd=ROOT, check=True)


def verify_package(args: argparse.Namespace) -> None:
    package = (ROOT / args.package).resolve()
    manifest = read_manifest(package)
    checks = []
    for name, spec in manifest["assets"].items():
        source = ROOT / spec["source"]
        output = ROOT / spec["out"]
        exists = output.exists() and output.stat().st_size > 0
        record = {"asset": name, "sourceExists": source.exists(), "exportExists": exists}
        if exists:
            record["exportBytes"] = output.stat().st_size
            record["sha256"] = hashlib.sha256(output.read_bytes()).hexdigest()
        checks.append(record)
    if not all(x["sourceExists"] for x in checks):
        status = "Source pending"
    elif not all(x["exportExists"] for x in checks):
        status = "Needs changes"
    else:
        status = "Export-verified"
    result = {"status": status, "checkedOn": str(date.today()), "checks": checks}
    (package / "verification.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    if status != "Export-verified":
        raise SystemExit(1)


def main() -> None:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)
    init = sub.add_parser("init", help="scaffold a provenance and export package")
    init.add_argument("--name", required=True)
    init.add_argument("--url", required=True)
    init.add_argument("--creator")
    init.add_argument("--license")
    init.add_argument("--width", type=float, default=128.0)
    init.add_argument("--triangles", type=int, default=10000)
    init.add_argument("--tiles", type=int, default=1)
    init.set_defaults(func=init_package)
    build = sub.add_parser("build", help="run the Blender export")
    build.add_argument("--package", required=True)
    build.add_argument("--blender", default="blender")
    build.set_defaults(func=build_package)
    verify = sub.add_parser("verify", help="hash and record the export")
    verify.add_argument("--package", required=True)
    verify.set_defaults(func=verify_package)
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
