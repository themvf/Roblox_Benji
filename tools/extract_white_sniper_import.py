"""Record Studio-uploaded White Sniper mesh and texture IDs for repeatable builds."""

import json
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/models/white-sniper/source/WhiteSniperImported.rbxmx"
OUT = ROOT / "assets/models/white-sniper/studio_import.json"


def prop(item, name):
    return item.find(f"./Properties/*[@name='{name}']")


def content(item, name):
    field = prop(item, name)
    if field is None or len(field) == 0 or field[0].tag == "null":
        return ""
    return field[0].text or ""


def vector(item, name):
    field = prop(item, name)
    return [float(field.findtext(axis)) for axis in ("X", "Y", "Z")]


tree = ET.parse(SOURCE)
parts = []
for item in tree.iter("Item"):
    if item.get("class") != "MeshPart":
        continue
    surface = next((child for child in item.findall("Item") if child.get("class") == "SurfaceAppearance"), None)
    assert surface is not None
    cf = prop(item, "CFrame")
    parts.append({
        "name": prop(item, "Name").text,
        "meshId": content(item, "MeshId"),
        "size": vector(item, "InitialSize"),
        "position": [float(cf.findtext(axis)) for axis in ("X", "Y", "Z")],
        "colorMap": content(surface, "ColorMap"),
        "metalnessMap": content(surface, "MetalnessMap"),
        "roughnessMap": content(surface, "RoughnessMap"),
        "normalMap": content(surface, "NormalMap"),
    })

assert len(parts) == 8, f"Expected eight mesh sections, got {len(parts)}"
assert all(part["meshId"] and part["colorMap"] for part in parts)
center = [sum(p["position"][i] for p in parts) / len(parts) for i in range(3)]
for part in parts:
    part["offset"] = [round(part["position"][i] - center[i], 7) for i in range(3)]
    del part["position"]
OUT.write_text(json.dumps({"source": str(SOURCE.relative_to(ROOT)).replace("\\", "/"), "parts": parts}, indent=2) + "\n")
print(f"Recorded {len(parts)} uploaded mesh sections in {OUT}")
