"""Write the hub's parts to hub_parts.json for tools/lobbyauthor/walk_in_hub.luau.

    python docs/design/lobby-experience/hub-concept/export_parts.py

hub_design.py stays the one source: the plan, the renders and the game lobby all read it.
"""

import json
import os

import hub_design as hub

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    out = []
    for part in hub.parts:
        item = {k: v for k, v in part.items() if k != "plan"}
        item["colour"] = list(part["colour"])
        out.append(item)
    path = os.path.join(HERE, "hub_parts.json")
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump({"scale": hub.SCALE, "wallHeight": hub.WALL_H, "parts": out}, handle, indent=1)
        handle.write("\n")
    print("wrote %s (%d parts)" % (path, len(out)))


main()
