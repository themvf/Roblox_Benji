"""Spend less hosted GPU on asset generation: plan, cache, measure, queue.

The free GPU quota is one pool per account per day, shared by every session. On
2026-11-16 ten penthouse props took about 23 generations that nobody had budgeted, a
radio tower took three and shipped nothing, and the next asset arrived to an empty quota.

  plan     assets/plans/<map>.json: every asset a map needs, each marked reuse, shapes or
           generate, and the number of GPU runs the user approved. `generate` checks it.
  find     what is already in the repo that could be reused, before anything is made.
  cache    a finished candidate is kept outside the repo, keyed on the image, seed and
           settings, so a renamed or cleaned-up package never pays for it twice.
  ledger   one line per GPU call: who, which asset, how long. This is the measurement
           the budgets and the 512-versus-1024 question rest on.
  queue    a request that hits an empty quota is parked and run after the reset.

Everything except the plans lives in %LOCALAPPDATA%/RobloxCodex/gpu (or $ASSET_GPU_HOME),
so every checkout and worktree on this machine shares it. Nothing here calls a network.
"""

import glob
import hashlib
import json
import os
import re
import shutil
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOME = os.environ.get("ASSET_GPU_HOME") or os.path.join(os.environ.get("LOCALAPPDATA") or os.path.expanduser("~"), "RobloxCodex", "gpu")
PLANS = os.path.join(ROOT, "assets", "plans")
SOURCES = ("reuse", "shapes", "generate")
RUNS_PER_GENERATED = 2  # a 512 draft and one 1024 final
UNPLANNED_ASSETS = 2  # a map's third generated asset needs a plan


def _path(name):
    os.makedirs(HOME, exist_ok=True)
    return os.path.join(HOME, name)


def _read(path, default):
    if not os.path.isfile(path):
        return default
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def _write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(data, handle, indent=2)
        handle.write("\n")


def slug(text):
    return re.sub(r"[^a-z0-9]+", "-", (text or "").lower()).strip("-")


# --------------------------------------------------------------------- cache


def cache_key(image, seed, resolution, decimation, texture, space):
    digest = hashlib.sha256()
    with open(image, "rb") as handle:
        digest.update(handle.read())
    digest.update(f"|{space}|{seed}|{resolution}|{decimation}|{texture}".encode())
    return digest.hexdigest()[:32]


def cache_get(key):
    """The cached candidate for this key, or None."""
    path = os.path.join(_path("cache"), key, "candidate.glb")
    return path if os.path.isfile(path) else None


def cache_put(key, glb, record):
    folder = os.path.join(_path("cache"), key)
    os.makedirs(folder, exist_ok=True)
    shutil.copyfile(glb, os.path.join(folder, "candidate.glb"))
    _write(os.path.join(folder, "generation.json"), record)


# -------------------------------------------------------------------- ledger


CRASH_LIMIT = 2  # crashes on one picture at one resolution before the tool stops calling
CRASH_DAYS = 7
BUSY_WORDS = ("queue", "timeout", "timed out", "too many", "busy", "overload", "connection", "502", "503", "504", "aborted", "unavailable")


def classify(error_text):
    """quota, busy or crash. The hedge failed five times in a row with a bare RuntimeError
    and each one was retried as if it might be different; a crash on the picture is not."""
    text = (error_text or "").lower()
    if "quota" in text:
        return "quota"
    if any(word in text for word in BUSY_WORDS):
        return "busy"
    return "crash"


def image_id(image):
    digest = hashlib.sha256()
    with open(image, "rb") as handle:
        digest.update(handle.read())
    return digest.hexdigest()[:16]


def crashes(image, resolution):
    """How many times this picture has crashed the generator at this resolution lately."""
    wanted = image_id(image)
    return sum(1 for row in runs(CRASH_DAYS) if row["outcome"] == "crash" and row.get("image") == wanted and row["resolution"] == str(resolution))


def log_run(asset, where, kind, seed, resolution, seconds, outcome, owner, note=None, image=None):
    """One line per attempt. outcome: ok, cached, quota, busy or crash. Only `ok` is known to have spent GPU."""
    line = {
        "at": time.strftime("%Y-%m-%d %H:%M:%S"),
        "asset": asset,
        "where": where,
        "kind": kind,  # draft, final or image
        "seed": seed,
        "resolution": str(resolution),
        "seconds": round(seconds, 1),
        "outcome": outcome,
        "owner": owner,
        "note": note,
        "image": image,
    }
    with open(_path("ledger.jsonl"), "a", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps(line) + "\n")


def runs(since_days=None):
    path = _path("ledger.jsonl")
    if not os.path.isfile(path):
        return []
    with open(path, encoding="utf-8") as handle:
        rows = [json.loads(line) for line in handle if line.strip()]
    if since_days is None:
        return rows
    cutoff = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(time.time() - since_days * 86400))
    return [row for row in rows if row["at"] >= cutoff]


def note_quota(error_text):
    """Remember when the Space said the quota comes back ("Try again in 23:16:55")."""
    found = re.search(r"[Tt]ry again in (\d+):(\d+):(\d+)", error_text)
    wait = int(found.group(1)) * 3600 + int(found.group(2)) * 60 + int(found.group(3)) if found else 3600
    state = _read(_path("state.json"), {})
    state["retryAfter"] = time.time() + wait
    state["retryAfterText"] = time.strftime("%Y-%m-%d %H:%M", time.localtime(state["retryAfter"]))
    _write(_path("state.json"), state)
    return state["retryAfterText"]


def retry_after():
    """Local time text when the quota is expected back, or None if it is not known to be out."""
    state = _read(_path("state.json"), {})
    return state.get("retryAfterText") if state.get("retryAfter", 0) > time.time() else None


def clear_quota_note():
    state = _read(_path("state.json"), {})
    if state.pop("retryAfter", None) is not None:
        state.pop("retryAfterText", None)
        _write(_path("state.json"), state)


def usage_report():
    day = [row for row in runs(1) if row["outcome"] == "ok"]
    lines = [f"GPU runs in the last 24 hours: {len(day)}, {sum(row['seconds'] for row in day):.0f} seconds of wall time (queue waits included)."]
    by_asset = {}
    for row in day:
        entry = by_asset.setdefault(row["asset"], [0, 0.0])
        entry[0] += 1
        entry[1] += row["seconds"]
    for asset, (count, seconds) in sorted(by_asset.items(), key=lambda item: -item[1][1]):
        lines.append(f"  {count:>3} run(s) {seconds:>6.0f}s  {asset}")
    speeds = {}
    for row in runs():
        if row["outcome"] == "ok" and row["kind"] in ("draft", "final"):
            speeds.setdefault(row["resolution"], []).append(row["seconds"])
    for resolution, seconds in sorted(speeds.items()):
        lines.append(f"  measured at {resolution}: {sum(seconds) / len(seconds):.0f}s a run over {len(seconds)} run(s)")
    saved = sum(1 for row in runs() if row["outcome"] == "cached")
    if saved:
        lines.append(f"  the cache has answered {saved} request(s) without a GPU run")
    waiting = retry_after()
    lines.append(f"quota: out until about {waiting}." if waiting else "quota: not known to be out.")
    pending = queue_list()
    if pending:
        lines.append(f"queue: {len(pending)} request(s) waiting; run them with  asset_generate.py queue --run")
    return "\n".join(lines)


# --------------------------------------------------------------------- queue


def queue_list():
    return _read(_path("queue.json"), [])


def queue_add(asset, argv, owner):
    """Park a command to rerun after the quota resets. The same command is never queued twice."""
    pending = queue_list()
    if any(entry["argv"] == argv and entry["root"] == ROOT for entry in pending):
        return False
    pending.append({"asset": asset, "argv": argv, "root": ROOT, "owner": owner, "queuedOn": time.strftime("%Y-%m-%d %H:%M")})
    _write(_path("queue.json"), pending)
    return True


def queue_remove(entry):
    _write(_path("queue.json"), [e for e in queue_list() if e != entry])


# ---------------------------------------------------------------------- find


def find(words):
    """Packages and runtime models whose name or stated purpose mentions any of the words."""
    tokens = [t for t in re.split(r"[^a-z0-9]+", words.lower()) if len(t) > 2]
    if not tokens:
        return []
    registry = _read(os.path.join(ROOT, "src", "shared", "AssetRegistry.json"), {})
    hits = []
    for folder in sorted(glob.glob(os.path.join(ROOT, "assets", "models", "*"))):
        if not os.path.isdir(folder):
            continue
        name = os.path.basename(folder)
        brief = _read(os.path.join(folder, "brief.json"), {})
        text = name + " " + str(brief.get("purpose", ""))
        if not brief:
            text += " " + str(_read(os.path.join(folder, "appraisal.json"), {}).get("decision", ""))
        matched = [t for t in tokens if t in text.lower()]
        if matched:
            entry = registry.get(name, {})
            state = f"uploaded, asset {entry['assetId']}" if entry.get("assetId") else ("built locally" if entry else "package only")
            hits.append((len(matched), name, state, (brief.get("purpose") or "")[:90]))
    for path in sorted(glob.glob(os.path.join(ROOT, "assets", "environment", "runtime", "*.rbxm*"))):
        name = os.path.basename(path)
        matched = [t for t in tokens if t in name.lower()]
        if matched:
            hits.append((len(matched), "assets/environment/runtime/" + name, "runtime model", ""))
    return [hit[1:] for hit in sorted(hits, key=lambda hit: -hit[0])]


# ---------------------------------------------------------------------- plan


def plan_path(map_name):
    return os.path.join(PLANS, slug(map_name) + ".json")


def read_plan(map_name):
    return _read(plan_path(map_name), None)


def write_plan(plan):
    _write(plan_path(plan["map"]), plan)


def plan_for(where):
    """The plan whose map this brief's `where` names, or None. 'Snow Fortress (currently MyMap)' finds snow-fortress."""
    place = slug(where)
    if not place:
        return None
    for path in glob.glob(os.path.join(PLANS, "*.json")):
        name = os.path.splitext(os.path.basename(path))[0]
        if place.startswith(name) or name.startswith(place):
            return _read(path, None)
    return None


def plan_runs(plan):
    """GPU runs already spent on this plan's assets, from the ledger."""
    names = {row["name"] for row in plan.get("assets", [])}
    return sum(1 for row in runs() if row["outcome"] == "ok" and row["kind"] in ("draft", "final") and row["asset"] in names)


def unplanned_assets(where, asset):
    """Other assets already generated for this place with no plan covering it."""
    place = slug(where)
    return sorted({row["asset"] for row in runs() if row["outcome"] == "ok" and row["kind"] in ("draft", "final") and slug(row.get("where")) == place and row["asset"] != asset})


def plan_text(plan):
    rows = plan.get("assets", [])
    lines = [f"Asset plan for {plan['map']}", ""]
    width = max([len(row["name"]) for row in rows] + [5])
    for row in rows:
        extra = f"  <- {row['reuses']}" if row.get("reuses") else ""
        lines.append(f"  {row['source']:<8} {row['name']:<{width}}  {row.get('what', '')}{extra}")
    counts = {source: sum(1 for row in rows if row["source"] == source) for source in SOURCES}
    lines += ["", f"  {counts['reuse']} reused, {counts['shapes']} built from shapes (no GPU), {counts['generate']} generated."]
    expected = counts["generate"] * RUNS_PER_GENERATED
    lines.append(f"  Expected GPU runs: about {expected} ({RUNS_PER_GENERATED} per generated asset: a 512 draft and one 1024 final).")
    approved = plan.get("approvedRuns")
    if approved is None:
        lines.append("  NOT APPROVED. Put this table to the user and record their answer:  plan <map> --approve <runs> --said \"...\"")
    else:
        lines.append(f"  Approved: {approved} runs ({plan.get('approvedSaid')!r}, {plan.get('approvedOn')}). Used so far: {plan_runs(plan)}.")
    return "\n".join(lines)
