"""Device test results -> a table, the slow windows, and measured ceilings for budgets.

    python tools/perf_report.py docs/design/performance/results/<day>.txt [more files]

Input is the `PERF <key> <json>` lines printed by the command-bar snippet in
docs/design/performance/DEVICE_TEST.md (Studio adds a timestamp in front; that is fine).
Each line is one player session recorded by PerfProbeService.

Windows are grouped by device class and map. A window "meets target" when its average
and low frame rate and its memory are inside TARGETS. The ceilings printed at the end are
the largest triangle and draw-call counts seen in windows that met the target on each
device class: evidence for what a view can hold, to set against ROLE_BUDGETS in
tools/asset_rules.py. They are observations, not limits: a view can be heavier than
anything that happened to be recorded.
"""

import json
import re
import sys
from collections import defaultdict

# Keep in step with the Targets table in docs/design/performance/DEVICE_TEST.md.
TARGETS = {
    "Phone": {"fpsAvg": 30, "fpsLow": 20, "memoryMb": 1200},
    "Tablet": {"fpsAvg": 30, "fpsLow": 20, "memoryMb": 1500},
    "Desktop": {"fpsAvg": 60, "fpsLow": 40, "memoryMb": None},
    "Console": {"fpsAvg": 30, "fpsLow": 20, "memoryMb": None},
}
MEMORY_GROWTH_MB = 150  # first window to last in one session; more than this looks like a leak


def read_sessions(paths):
    sessions = []
    for path in paths:
        with open(path, encoding="utf-8", errors="replace") as handle:
            for line in handle:
                found = re.search(r"PERF (\S+) (\{.*\})\s*$", line)
                if not found:
                    continue
                try:
                    record = json.loads(found.group(2))
                except json.JSONDecodeError:
                    print(f"skipped an unreadable line for {found.group(1)}")
                    continue
                record["key"] = found.group(1)
                sessions.append(record)
    return sessions


def misses(window, target):
    out = []
    if window.get("fpsAvg", 1e9) < target["fpsAvg"]:
        out.append(f"avg {window['fpsAvg']:g} fps")
    if window.get("fpsLow", 1e9) < target["fpsLow"]:
        out.append(f"low {window['fpsLow']:g} fps")
    limit = target["memoryMb"]
    if limit and window.get("memoryMbMax", 0) > limit:
        out.append(f"{window['memoryMbMax']:g} MB")
    return out


def mean(values):
    values = [v for v in values if v is not None]
    return sum(values) / len(values) if values else None


def show(value, digits=0):
    return "-" if value is None else f"{value:,.{digits}f}"


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    sessions = read_sessions(sys.argv[1:])
    if not sessions:
        sys.exit("no PERF lines found; see docs/design/performance/DEVICE_TEST.md")

    groups = defaultdict(list)
    slow = []
    ceilings = defaultdict(lambda: {"triangles": 0, "drawCalls": 0, "windows": 0})
    for session in sessions:
        device = session.get("device", {})
        klass = device.get("class", "unknown")
        target = TARGETS.get(klass, TARGETS["Phone"])
        windows = session.get("windows") or []
        for window in windows:
            groups[(klass, window.get("map", "unknown"))].append(window)
            missed = misses(window, target)
            if missed:
                slow.append((klass, window, missed, session["key"]))
            else:
                best = ceilings[klass]
                best["windows"] += 1
                best["triangles"] = max(best["triangles"], window.get("trianglesMax") or 0)
                best["drawCalls"] = max(best["drawCalls"], window.get("drawCallsMax") or 0)
        if len(windows) >= 4:
            first, last = windows[0].get("memoryMbAvg"), windows[-1].get("memoryMbAvg")
            if first and last and last - first > MEMORY_GROWTH_MB:
                minutes = (windows[-1].get("at", 0) - windows[0].get("at", 0)) / 60
                print(f"MEMORY GROWTH  {session['key']} ({klass}): {first:,.0f} -> {last:,.0f} MB over {minutes:.0f} min")

    print(f"{len(sessions)} sessions, {sum(len(v) for v in groups.values())} windows\n")
    print(f"{'device':<8} {'map':<22} {'win':>4} {'fps':>6} {'low':>6} {'mem MB':>8} {'tex MB':>7} {'tris':>10} {'draws':>7} {'players':>7}")
    for (klass, name), windows in sorted(groups.items()):
        print(
            f"{klass:<8} {name[:22]:<22} {len(windows):>4} "
            f"{show(mean(w.get('fpsAvg') for w in windows), 1):>6} "
            f"{show(min((w['fpsLow'] for w in windows if 'fpsLow' in w), default=None), 1):>6} "
            f"{show(max((w['memoryMbMax'] for w in windows if 'memoryMbMax' in w), default=None)):>8} "
            f"{show(max((w['textureMbMax'] for w in windows if 'textureMbMax' in w), default=None)):>7} "
            f"{show(max((w['trianglesMax'] for w in windows if 'trianglesMax' in w), default=None)):>10} "
            f"{show(max((w['drawCallsMax'] for w in windows if 'drawCallsMax' in w), default=None)):>7} "
            f"{show(mean(w.get('players') for w in windows), 1):>7}"
        )
    print("  (fps is the mean of window averages; low, memory, triangles and draws are the worst window)")

    print(f"\n{len(slow)} window(s) missed their target")
    for klass, window, missed, key in sorted(slow, key=lambda item: item[1].get("fpsLow", 0))[:25]:
        print(
            f"  {klass:<8} {str(window.get('map'))[:22]:<22} {', '.join(missed):<34} "
            f"tris {show(window.get('trianglesMax'))}, draws {show(window.get('drawCallsMax'))}, "
            f"players {window.get('players')}, vehicles {window.get('vehicles')}  [{key}]"
        )

    print("\nHeaviest views that still met the target (evidence for budgets, not limits):")
    for klass, best in sorted(ceilings.items()):
        if best["windows"]:
            print(f"  {klass:<8} {best['triangles']:>10,.0f} triangles, {best['drawCalls']:>6,.0f} draw calls, from {best['windows']} good windows")
    missing = [k for k in ("Phone", "Tablet") if not ceilings[k]["windows"] and not any(s[0] == k for s in slow)]
    if missing:
        print("  not tested yet: " + ", ".join(missing))
    if any(w.get("trianglesMax") is None for windows in groups.values() for w in windows):
        print("  note: some windows have no triangle or draw-call figure; that client did not expose them.")


if __name__ == "__main__":
    main()
