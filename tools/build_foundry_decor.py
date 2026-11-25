#!/usr/bin/env python3
"""
Generate assets/environment/decor/SciFiFoundry.rbxmx from Studio-verified
PBR MeshPart assets (assets/models/*/HANDOFF.md).

Loaded automatically by MapService.lua (`authoredDecor`) for both SciFiFoundry
and SciFiFoundryTDM (`BakedMap = "SciFiFoundry"`), avoiding @lune/roblox's
MeshPart serialization limitation while keeping tactical colliders & lights
cleanly audited by tools/check_decor.luau.
"""
from __future__ import annotations

import math
from pathlib import Path
from xml.sax.saxutils import escape

ROOT = Path(__file__).resolve().parent.parent
OUT_PATH = ROOT / "assets" / "environment" / "decor" / "SciFiFoundry.rbxmx"

# Studio-verified MeshIds, MeshSizes, local bottom-center offsets, and PBR SurfaceAppearance maps
ASSETS = {
    "scifi-generator": {
        "collision_fidelity": 2,  # Box
        "can_collide": True,
        "parts": [
            {
                "name": "Generator",
                "mesh_id": "rbxassetid://131758847316064",
                "size": (13.5, 6.500018, 6.747877),
                "offset": (0.0, 3.250009, 0.0),
                "sa": {
                    "ColorMap": "rbxassetid://101163715733909",
                    "NormalMap": "rbxassetid://138353581812443",
                    "RoughnessMap": "rbxassetid://90834354473226",
                    "MetalnessMap": "rbxassetid://77221028656075",
                },
            }
        ],
    },
    "scifi-container": {
        "collision_fidelity": 2,  # Box
        "can_collide": True,
        "parts": [
            {
                "name": "Container",
                "mesh_id": "rbxassetid://130331310814567",
                "size": (5.412694, 5.326944, 5.600000),
                "offset": (0.0, 2.663472, 0.0),
                "sa": {
                    "ColorMap": "rbxassetid://76859172271463",
                    "NormalMap": "rbxassetid://72431067255628",
                    "RoughnessMap": "rbxassetid://98051894001588",
                    "MetalnessMap": "rbxassetid://91574480680855",
                },
            }
        ],
    },
    "scifi-chamber": {
        "collision_fidelity": 2,  # Box
        "can_collide": True,
        "parts": [
            {
                "name": "Base",
                "mesh_id": "rbxassetid://101858467157064",
                "size": (5.393969, 10.499999, 5.393970),
                "offset": (0.0, 5.250000, 0.0),
                "sa": {
                    "ColorMap": "rbxassetid://91652780573796",
                    "NormalMap": "rbxassetid://89692045570467",
                    "RoughnessMap": "rbxassetid://73822917005144",
                    "MetalnessMap": "rbxassetid://133120130584107",
                },
                "light": {
                    "color": (0.35, 0.88, 1.0),
                    "brightness": 1.35,
                    "range": 28.0,
                },
            },
            {
                "name": "Glass",
                "mesh_id": "rbxassetid://138562219324774",
                "size": (4.312183, 9.188552, 4.312184),
                "offset": (0.0, 5.190144, 0.0),
                "material": 1568,  # Glass
                "transparency": 0.56,
                "color3": (0.55, 0.88, 1.0),
                "can_collide": False,
            },
        ],
    },
    "control-panel": {
        "collision_fidelity": 2,  # Box
        "can_collide": True,
        "parts": [
            {
                "name": "Control_Panel",
                "mesh_id": "rbxassetid://127623062517526",
                "size": (2.330636, 5.200000, 1.580743),
                "offset": (0.0, 2.600000, 0.0),
                "sa": {
                    "ColorMap": "rbxassetid://121775128193262",
                    "NormalMap": "rbxassetid://114180133863411",
                    "RoughnessMap": "rbxassetid://103931753673895",
                    "MetalnessMap": "rbxassetid://83721507994467",
                },
            }
        ],
    },
    "pipe-valve-wheel": {
        "collision_fidelity": 1,  # Hull
        "can_collide": True,
        "parts": [
            {
                "name": "Pipe_Valve_Wheel",
                "mesh_id": "rbxassetid://140621757979021",
                "size": (5.000000, 4.275000, 1.650001),
                "offset": (0.0, 2.137500, 0.0),
                "sa": {
                    "ColorMap": "rbxassetid://96847817790126",
                    "NormalMap": "rbxassetid://78684669990179",
                    "RoughnessMap": "rbxassetid://98070482982033",
                    "MetalnessMap": "rbxassetid://127881503052053",
                },
            },
            {
                "name": "Pipe_Valve_Wheel_Handle",
                "mesh_id": "rbxassetid://116294421199609",
                "size": (1.850000, 0.400000, 1.850000),
                "offset": (0.0, 3.900001, 0.0),
                "sa": {
                    "ColorMap": "rbxassetid://96847817790126",
                    "NormalMap": "rbxassetid://78684669990179",
                    "RoughnessMap": "rbxassetid://98070482982033",
                    "MetalnessMap": "rbxassetid://127881503052053",
                },
                "can_collide": False,
            },
        ],
    },
    "sign-high-voltage": {
        "collision_fidelity": 2,
        "can_collide": False,
        "double_sided": True,
        "parts": [
            {
                "name": "Sign_Danger_HighVoltage",
                "mesh_id": "rbxassetid://78465423936111",
                "size": (2.720000, 3.400000, 0.047601),
                "offset": (0.0, 1.700000, 0.0),
                "sa": {
                    "ColorMap": "rbxassetid://104156966130379",
                    "NormalMap": "rbxassetid://74857482792648",
                    "RoughnessMap": "rbxassetid://85527548876837",
                    "MetalnessMap": "rbxassetid://133970048342429",
                },
            }
        ],
    },
    "light-cage-wall": {
        "collision_fidelity": 2,
        "can_collide": False,
        "parts": [
            {
                "name": "Light_Cage_Wall",
                "mesh_id": "rbxassetid://104104323610061",
                "size": (2.400000, 2.400000, 2.127273),
                "offset": (0.0, 1.200000, 0.027271),
                "sa": {
                    "ColorMap": "rbxassetid://81295133992292",
                    "NormalMap": "rbxassetid://106809109272131",
                    "RoughnessMap": "rbxassetid://74066780797341",
                    "MetalnessMap": "rbxassetid://132765954272792",
                },
            },
            {
                "name": "Light_Cage_Wall_Glow",
                "mesh_id": "rbxassetid://78457213058005",
                "size": (1.810909, 1.810909, 1.090909),
                "offset": (-0.000004, 1.200000, -0.545453),
                "material": 288,  # Neon
                "color3": (0.65, 0.90, 1.0),
                "light": {
                    "color": (0.78, 0.90, 1.0),
                    "brightness": 1.45,
                    "range": 34.0,
                },
            },
        ],
    },
}

# (instance_name, asset_slug, (x, bottom_y, z), yaw_deg, uniform_scale, optional_light_color)
# Scaled to natural player proportions (~5.5-stud character height):
# - ControlPanel: 0.72x (~1.68 x 3.74 x 1.14 studs)
# - ScifiContainer: 0.55x (~2.98 x 2.93 x 3.08 studs, crisp chest cover)
# - ScifiChamber: 0.55x (~2.97 x 5.77 x 2.97 studs, human-scale cryo pod)
# - ScifiGenerator: 0.62x (~8.37 x 4.03 x 4.18 studs)
# - PipeValveWheel: 0.68x (~3.40 x 2.91 x 1.26 studs)
# - SignHighVoltage: 0.62x (~1.69 x 2.11 x 0.03 studs)
# - LightCageWall: 0.68x (~1.63 x 1.63 x 1.48 studs)
PLACEMENTS = [
    # --- Control Panels (scaled 0.72x to natural terminal height) ---
    ("Red_CryoTelemetryPanel", "control-panel", (-78.0, 0.32, -113.0), 122.0, 0.72, None),
    ("Blue_CryoTelemetryPanel", "control-panel", (78.0, 0.32, -113.0), -122.0, 0.72, None),
    ("Red_CryoTubeConsole", "control-panel", (-42.0, 0.32, -118.0), 12.0, 0.72, None),
    ("Blue_CryoTubeConsole", "control-panel", (42.0, 0.32, -118.0), -12.0, 0.72, None),
    ("Red_PortalControl", "control-panel", (-24.0, 0.32, -26.5), -20.0, 0.72, None),
    ("Blue_PortalControl", "control-panel", (24.0, 0.32, -26.5), 20.0, 0.72, None),
    ("Red_ReactorTelemetryPanel", "control-panel", (-80.0, 0.32, 116.0), 32.0, 0.72, None),
    ("Blue_ReactorTelemetryPanel", "control-panel", (80.0, 0.32, 116.0), -32.0, 0.72, None),

    # --- Solid Hazard Cargo Containers (scaled 0.55x -> compact ~3x3x3 tactical boxes) ---
    ("Red_CryoContainer", "scifi-container", (-24.5, 0.32, -55.5), 90.0, 0.55, None),
    ("Blue_CryoContainer", "scifi-container", (24.5, 0.32, -55.5), -90.0, 0.55, None),
    ("Red_CryoCornerContainer", "scifi-container", (-66.0, 0.32, -116.0), -25.0, 0.55, None),
    ("Blue_CryoCornerContainer", "scifi-container", (66.0, 0.32, -116.0), 25.0, 0.55, None),
    ("Red_ForgeContainer", "scifi-container", (-14.0, 0.32, 118.0), 180.0, 0.55, None),
    ("Blue_ForgeContainer", "scifi-container", (14.0, 0.32, 118.0), 180.0, 0.55, None),
    ("Red_SpawnCrateN", "scifi-container", (-122.0, 0.32, -24.0), 30.0, 0.50, None),
    ("Blue_SpawnCrateN", "scifi-container", (122.0, 0.32, -24.0), -30.0, 0.50, None),
    ("Red_SpawnCrateS", "scifi-container", (-122.0, 0.32, 24.0), -30.0, 0.50, None),
    ("Blue_SpawnCrateS", "scifi-container", (122.0, 0.32, 24.0), 30.0, 0.50, None),
    ("Red_GantryNCrate", "scifi-container", (-44.0, 11.5, -82.0), 35.0, 0.50, None),
    ("Blue_GantryNCrate", "scifi-container", (44.0, 11.5, -82.0), -35.0, 0.50, None),
    ("Red_GantrySCrate", "scifi-container", (-40.0, 11.5, 110.0), -35.0, 0.50, None),
    ("Blue_GantrySCrate", "scifi-container", (40.0, 11.5, 110.0), 35.0, 0.50, None),

    # --- Heavy Industrial Turbine Generators (scaled 0.62x) ---
    ("Red_CryoGenerator", "scifi-generator", (-48.0, 0.32, -104.0), 0.0, 0.62, None),
    ("Blue_CryoGenerator", "scifi-generator", (48.0, 0.32, -104.0), 0.0, 0.62, None),
    ("Red_ReactorGenerator", "scifi-generator", (-62.0, 0.32, 74.0), 0.0, 0.62, None),
    ("Blue_ReactorGenerator", "scifi-generator", (62.0, 0.32, 74.0), 0.0, 0.62, None),

    # --- Backlit Translucent Glass Containment Chambers (scaled 0.55x -> human-scale cylinders) ---
    ("Red_CryoChamber", "scifi-chamber", (-64.0, 0.32, -56.0), 20.0, 0.55, (0.35, 0.88, 1.0)),
    ("Blue_CryoChamber", "scifi-chamber", (64.0, 0.32, -56.0), -20.0, 0.55, (0.35, 0.88, 1.0)),
    ("Red_WingChamber", "scifi-chamber", (-106.0, 0.32, -58.0), 0.0, 0.55, (0.35, 0.88, 1.0)),
    ("Blue_WingChamber", "scifi-chamber", (106.0, 0.32, -58.0), 0.0, 0.55, (0.35, 0.88, 1.0)),
    ("Red_ReactorWingChamber", "scifi-chamber", (-106.0, 0.32, 58.0), 0.0, 0.55, (1.0, 0.56, 0.22)),
    ("Blue_ReactorWingChamber", "scifi-chamber", (106.0, 0.32, 58.0), 0.0, 0.55, (1.0, 0.56, 0.22)),

    # --- Perimeter Wall & Bulkhead Pipe Manifold Valves (scaled 0.68x, clear of WallRib I-beams) ---
    ("CryoWallValve_W", "pipe-valve-wheel", (-126.82, 0.0, -62.0), -90.0, 0.68, None),
    ("CryoWallValve_E", "pipe-valve-wheel", (126.82, 0.0, -62.0), 90.0, 0.68, None),
    ("ReactorWallValve_W", "pipe-valve-wheel", (-126.82, 0.0, 62.0), -90.0, 0.68, None),
    ("ReactorWallValve_E", "pipe-valve-wheel", (126.82, 0.0, 62.0), 90.0, 0.68, None),
    ("CryoBulkheadValve_W", "pipe-valve-wheel", (-28.0, 0.0, -29.82), 0.0, 0.68, None),
    ("CryoBulkheadValve_E", "pipe-valve-wheel", (28.0, 0.0, -29.82), 0.0, 0.68, None),

    # --- Center Blast Portal Jamb High-Voltage Warning Signage (scaled 0.62x) ---
    ("Sign_CryoPortalN_W", "sign-high-voltage", (-17.4, 3.6, -34.56), 180.0, 0.62, None),
    ("Sign_CryoPortalN_E", "sign-high-voltage", (17.4, 3.6, -34.56), 180.0, 0.62, None),
    ("Sign_CryoPortalS_W", "sign-high-voltage", (-17.4, 3.6, -29.44), 0.0, 0.62, None),
    ("Sign_CryoPortalS_E", "sign-high-voltage", (17.4, 3.6, -29.44), 0.0, 0.62, None),
    ("Sign_ReactorPortalN_W", "sign-high-voltage", (-17.4, 3.6, 29.44), 180.0, 0.62, None),
    ("Sign_ReactorPortalN_E", "sign-high-voltage", (17.4, 3.6, 29.44), 180.0, 0.62, None),
    ("Sign_ReactorPortalS_W", "sign-high-voltage", (-17.4, 3.6, 34.56), 0.0, 0.62, None),
    ("Sign_ReactorPortalS_E", "sign-high-voltage", (17.4, 3.6, 34.56), 0.0, 0.62, None),

    # --- Spawn Bay & Perimeter Bulkhead Wall Cage Lights (scaled 0.68x, flush to outer walls) ---
    ("LightCage_RedSpawnN", "light-cage-wall", (-127.05, 7.6, -14.0), -90.0, 0.68, (0.72, 0.90, 1.0)),
    ("LightCage_RedSpawnS", "light-cage-wall", (-127.05, 7.6, 14.0), -90.0, 0.68, (1.0, 0.78, 0.56)),
    ("LightCage_BlueSpawnN", "light-cage-wall", (127.05, 7.6, -14.0), 90.0, 0.68, (0.72, 0.90, 1.0)),
    ("LightCage_BlueSpawnS", "light-cage-wall", (127.05, 7.6, 14.0), 90.0, 0.68, (1.0, 0.78, 0.56)),
    ("LightCage_CryoW", "light-cage-wall", (-127.05, 7.6, -56.0), -90.0, 0.68, (0.65, 0.88, 1.0)),
    ("LightCage_CryoE", "light-cage-wall", (127.05, 7.6, -56.0), 90.0, 0.68, (0.65, 0.88, 1.0)),
    ("LightCage_ReactorW", "light-cage-wall", (-127.05, 7.6, 56.0), -90.0, 0.68, (1.0, 0.76, 0.52)),
    ("LightCage_ReactorE", "light-cage-wall", (127.05, 7.6, 56.0), 90.0, 0.68, (1.0, 0.76, 0.52)),
]


class RefCounter:
    def __init__(self) -> None:
        self.n = 0

    def next(self) -> str:
        val = f"RBX{self.n}"
        self.n += 1
        return val


def yaw_cframe(pos: tuple[float, float, float], yaw_deg: float, offset: tuple[float, float, float], scale: float):
    rad = math.radians(yaw_deg)
    c = math.cos(rad)
    s = math.sin(rad)
    ox, oy, oz = offset[0] * scale, offset[1] * scale, offset[2] * scale
    # R_y(rad) * (ox, oy, oz)
    wx = pos[0] + c * ox + s * oz
    wy = pos[1] + oy
    wz = pos[2] - s * ox + c * oz
    return (wx, wy, wz, c, 0.0, s, 0.0, 1.0, 0.0, -s, 0.0, c)


def fmt_cframe(cf: tuple[float, ...], indent: str) -> str:
    keys = ["X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22"]
    inner = "\n".join(f"{indent}  <{k}>{v:.6f}</{k}>" for k, v in zip(keys, cf))
    return f'{indent}<CoordinateFrame name="CFrame">\n{inner}\n{indent}</CoordinateFrame>'


def build_xml() -> str:
    refs = RefCounter()
    lines = [
        '<roblox version="4">',
        f'  <Item class="Folder" referent="{refs.next()}">',
        "    <Properties>",
        "      <string name=\"Name\">SciFiFoundry</string>",
        "    </Properties>",
    ]

    for inst_name, slug, pos, yaw, scale, light_rgb in PLACEMENTS:
        spec = ASSETS[slug]
        is_model = len(spec["parts"]) > 1
        base_indent = "      " if is_model else "    "
        if is_model:
            lines.append(f'    <Item class="Model" referent="{refs.next()}">')
            lines.append("      <Properties>")
            lines.append(f'        <string name="Name">{escape(inst_name)}</string>')
            lines.append("      </Properties>")

        for part in spec["parts"]:
            item_name = part["name"] if is_model else inst_name
            cf = yaw_cframe(pos, yaw, part["offset"], scale)
            sx, sy, sz = (part["size"][0] * scale, part["size"][1] * scale, part["size"][2] * scale)
            can_collide = part.get("can_collide", spec["can_collide"])
            col_fid = spec["collision_fidelity"]
            mat = part.get("material", 256)
            trans = part.get("transparency", 0.0)
            double_sided = spec.get("double_sided", False)
            c3 = light_rgb if (slug == "scifi-chamber" and part["name"] == "Glass" and light_rgb) else part.get("color3")

            lines.append(f'{base_indent}<Item class="MeshPart" referent="{refs.next()}">')
            lines.append(f"{base_indent}  <Properties>")
            lines.append(f'{base_indent}    <string name="Name">{escape(item_name)}</string>')
            lines.append(f'{base_indent}    <bool name="Anchored">true</bool>')
            lines.append(f'{base_indent}    <bool name="CanCollide">{"true" if can_collide else "false"}</bool>')
            lines.append(f'{base_indent}    <bool name="CanQuery">{"true" if can_collide else "false"}</bool>')
            lines.append(f'{base_indent}    <bool name="CanTouch">false</bool>')
            lines.append(f'{base_indent}    <bool name="CastShadow">true</bool>')
            lines.append(f'{base_indent}    <bool name="DoubleSided">{"true" if double_sided else "false"}</bool>')
            lines.append(f'{base_indent}    <token name="CollisionFidelity">{col_fid}</token>')
            lines.append(f'{base_indent}    <token name="Material">{mat}</token>')
            lines.append(f'{base_indent}    <float name="Transparency">{trans:.3f}</float>')
            if c3:
                lines.append(
                    f'{base_indent}    <Color3 name="Color3uint8"><R>{c3[0]:.4f}</R><G>{c3[1]:.4f}</G><B>{c3[2]:.4f}</B></Color3>'
                )
            lines.append(f'{base_indent}    <Content name="MeshId"><url>{part["mesh_id"]}</url></Content>')
            lines.append(f'{base_indent}    <Vector3 name="Size"><X>{sx:.6f}</X><Y>{sy:.6f}</Y><Z>{sz:.6f}</Z></Vector3>')
            lines.append(fmt_cframe(cf, base_indent + "    "))
            lines.append(f"{base_indent}  </Properties>")

            if "sa" in part:
                sa = part["sa"]
                lines.append(f'{base_indent}  <Item class="SurfaceAppearance" referent="{refs.next()}">')
                lines.append(f"{base_indent}    <Properties>")
                lines.append(f'{base_indent}      <string name="Name">SurfaceAppearance</string>')
                lines.append(f'{base_indent}      <token name="AlphaMode">0</token>')
                lines.append(f'{base_indent}      <Content name="ColorMap"><url>{sa["ColorMap"]}</url></Content>')
                lines.append(f'{base_indent}      <Content name="MetalnessMap"><url>{sa["MetalnessMap"]}</url></Content>')
                lines.append(f'{base_indent}      <Content name="NormalMap"><url>{sa["NormalMap"]}</url></Content>')
                lines.append(f'{base_indent}      <Content name="RoughnessMap"><url>{sa["RoughnessMap"]}</url></Content>')
                lines.append(f"{base_indent}    </Properties>")
                lines.append(f"{base_indent}  </Item>")

            lt = part.get("light")
            if lt:
                rgb = light_rgb or lt["color"]
                lines.append(f'{base_indent}  <Item class="PointLight" referent="{refs.next()}">')
                lines.append(f"{base_indent}    <Properties>")
                lines.append(f'{base_indent}      <string name="Name">FixtureLight</string>')
                lines.append(f'{base_indent}      <bool name="Enabled">true</bool>')
                lines.append(f'{base_indent}      <bool name="Shadows">false</bool>')
                lines.append(f'{base_indent}      <float name="Brightness">{lt["brightness"]:.2f}</float>')
                lines.append(f'{base_indent}      <float name="Range">{lt["range"]:.1f}</float>')
                lines.append(
                    f'{base_indent}      <Color3 name="Color"><R>{rgb[0]:.4f}</R><G>{rgb[1]:.4f}</G><B>{rgb[2]:.4f}</B></Color3>'
                )
                lines.append(f"{base_indent}    </Properties>")
                lines.append(f"{base_indent}  </Item>")

            lines.append(f"{base_indent}</Item>")

        if is_model:
            lines.append("    </Item>")

    lines.append("  </Item>")
    lines.append("</roblox>")
    return "\n".join(lines) + "\n"


def main() -> None:
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text(build_xml(), encoding="utf-8")
    print(f"Wrote {len(PLACEMENTS)} hero prop placements to {OUT_PATH}")


if __name__ == "__main__":
    main()
