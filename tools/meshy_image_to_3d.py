"""Meshy image-to-3D for a prop or gun package (paid: Meshy credits on the user's plan).

    python tools/meshy_image_to_3d.py <package> [--picture FILE] [--polycount N] [--confirm]

Sends the package's picture (default source/user-picture.*, else source/reference.png) to
Meshy `/image-to-3d` with no pose, lighting removed and a remesh near the role's triangle
budget, and saves the model to <package>/meshy/model.glb. Without --confirm it prints the
cost and the balance and stops. The task id is written before polling, so an interrupted run
picks the same task up instead of paying again. Then file the model as a candidate:

    python tools/asset_generate.py import --name <package> --from meshy <package>/meshy/model.glb

Characters go through kit_look.py instead (T-pose, multi-view).
"""

import argparse
import json
import sys
import time
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from kit_look import MESHY_MODEL, data_uri, meshy_call, meshy_key  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
CREDITS = 30  # textured image-to-3d on the latest model; +5 for 2k geometry


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("package", help="package name under assets/models")
    ap.add_argument("--picture", help="image to send; default the package's user picture or reference")
    ap.add_argument("--polycount", type=int, default=4000, help="Meshy remesh target, triangles")
    ap.add_argument("--geometry", choices=("standard", "2k"), default="standard")
    ap.add_argument("--pbr", action="store_true", help="also ask for metallic, roughness and normal maps")
    ap.add_argument("--folder", default="meshy", help="output folder in the package; a new one for a second run")
    ap.add_argument("--confirm", action="store_true", help="spend the credits")
    a = ap.parse_args()

    pkg = ROOT / "assets/models" / a.package
    if not (pkg / "brief.json").exists():
        raise SystemExit(f"no brief in {pkg}; write the brief first")
    picture = Path(a.picture).resolve() if a.picture else next(
        (p for p in sorted((pkg / "source").glob("user-picture.*")) if p.suffix.lower() in (".png", ".jpg", ".jpeg")),
        pkg / "source/reference.png",
    )
    folder = pkg / a.folder
    folder.mkdir(exist_ok=True)
    model, task_file = folder / "model.glb", folder / "task.json"
    if model.exists():
        print(f"already made: {model.relative_to(ROOT)}")
        return

    key = meshy_key()
    task = json.loads(task_file.read_text(encoding="utf-8")) if task_file.exists() else {}
    if not task.get("id"):
        balance = meshy_call(key, "/balance").get("balance")
        cost = CREDITS + (5 if a.geometry == "2k" else 0)
        print(f"Meshy image-to-3d ({MESHY_MODEL}, {a.polycount} triangles, geometry {a.geometry}) from "
              f"{picture.relative_to(ROOT)}: about {cost} credits; balance {balance}")
        if not a.confirm:
            raise SystemExit("dry run: nothing spent. Add --confirm to make it.")
        body = {"image_url": data_uri(picture), "ai_model": MESHY_MODEL, "should_texture": True,
                "enable_pbr": a.pbr, "texture_resolution": "2k", "remove_lighting": True,
                "should_remesh": True, "topology": "triangle", "target_polycount": a.polycount,
                "target_formats": ["glb"]}
        if a.geometry == "2k":
            body["geometry_resolution"] = "2k"
        task = {"id": meshy_call(key, "/image-to-3d", body)["result"], "endpoint": "image-to-3d",
                "settings": {k: v for k, v in body.items() if k != "image_url"}, "source": picture.name}
        task_file.write_text(json.dumps(task, indent=1), encoding="utf-8")

    started, last = time.time(), -1
    while True:
        state = meshy_call(key, f"/image-to-3d/{task['id']}")
        if state.get("progress") != last:
            last = state.get("progress")
            print(f"Meshy {state.get('status')} {last}%", flush=True)
        if state.get("status") == "SUCCEEDED":
            break
        if state.get("status") in ("FAILED", "CANCELED"):
            task_file.unlink()  # a failed task is refunded; the next run starts a new one
            raise SystemExit(f"Meshy {state.get('status')}: {str(state.get('task_error'))[:300]}")
        if time.time() - started > 1800:
            raise SystemExit("Meshy still running after 30 min; rerun later to pick the same task up")
        time.sleep(10)
    urllib.request.urlretrieve(state["model_urls"]["glb"], model)
    task["credits"] = state.get("consumed_credits")
    task_file.write_text(json.dumps(task, indent=1), encoding="utf-8")
    print(f"Meshy: {task['credits']} credits; balance now {meshy_call(key, '/balance').get('balance')}")
    print(f"model: {model.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
