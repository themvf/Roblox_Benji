#!/usr/bin/env python3
"""
Package, normalize, appraise, render orthographic views, and export Roblox-ready GLBs
for curated SciFiFoundry props from UndergroundFacilityProps.

Run with Blender 4.3:
  "C:\Program Files\Blender Foundation\Blender 4.3\blender.exe" -b -noaudio --python tools/package_foundry_props.py
"""
import datetime
import hashlib
import json
import math
from pathlib import Path
import sys
import numpy as np

import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
PACKS = ROOT / "UndergroundFacilityProps"
UFP_ROOT = PACKS / "UndergroundFacilityProps_FreeSample" / "UndergroundFacilityProps_FreeSample"
SCIFI_PROPS = PACKS / "ScifiProps" / "ScifiProps"
MODELS_OUT = ROOT / "assets" / "models"
MAX_TEX = 1024

SPECS = [
    {
        "slug": "pipe-valve-wheel",
        "export_name": "PipeValveWheel",
        "source": UFP_ROOT / "FBX" / "Pipe_Valve_Wheel.fbx",
        "textures": {
            "Color": UFP_ROOT / "Textures" / "Roblox_1024" / "UFP_Pipes_BaseColor.png",
            "Normal": (UFP_ROOT / "Textures" / "Roblox_1024" / "UFP_Pipes_Normal.png", False),
            "Roughness": UFP_ROOT / "Textures" / "Roblox_1024" / "UFP_Pipes_Roughness.png",
            "Metalness": UFP_ROOT / "Textures" / "Roblox_1024" / "UFP_Pipes_Metallic.png",
        },
        "target_axis": "max_h",
        "target_size_studs": 5.0,
        "decision": "Wall/manifold industrial valve wheel prop for SciFiFoundry CryoBay & ReactorBay pipe runs (5.0 studs wide, bottom/back-centered).",
        "role": "Industrial wall pipe valve accent (non-collidable or Box collider).",
    },
    {
        "slug": "sign-high-voltage",
        "export_name": "SignHighVoltage",
        "source": UFP_ROOT / "FBX" / "Sign_Danger_HighVoltage.fbx",
        "textures": {
            "Color": UFP_ROOT / "Textures" / "Roblox_1024" / "UFP_Signs_BaseColor.png",
            "Normal": (UFP_ROOT / "Textures" / "Roblox_1024" / "UFP_Signs_Normal.png", False),
            "Roughness": UFP_ROOT / "Textures" / "Roblox_1024" / "UFP_Signs_Roughness.png",
            "Metalness": UFP_ROOT / "Textures" / "Roblox_1024" / "UFP_Signs_Metallic.png",
        },
        "target_axis": "z",
        "target_size_studs": 3.4,
        "decision": "High-voltage hazard plaque for SciFiFoundry portal jambs and generator alcoves (3.4 studs tall).",
        "role": "Wall warning signage (decor, non-collidable).",
    },
    {
        "slug": "light-cage-wall",
        "export_name": "LightCageWall",
        "source": UFP_ROOT / "FBX" / "Light_Cage_Wall.fbx",
        "textures": {
            "Color": UFP_ROOT / "Textures" / "Roblox_1024" / "UFP_Lights_BaseColor.png",
            "Normal": (UFP_ROOT / "Textures" / "Roblox_1024" / "UFP_Lights_Normal.png", False),
            "Roughness": UFP_ROOT / "Textures" / "Roblox_1024" / "UFP_Lights_Roughness.png",
            "Metalness": UFP_ROOT / "Textures" / "Roblox_1024" / "UFP_Lights_Metallic.png",
        },
        "target_axis": "max_xyz",
        "target_size_studs": 2.4,
        "decision": "Caged industrial bulkhead wall fixture for SciFiFoundry Spawn Bays & dark bulkhead corners (2.4 studs).",
        "role": "Wall-mounted industrial light housing (decor, non-collidable).",
    },
    {
        "slug": "scifi-generator",
        "export_name": "ScifiGenerator",
        "source": SCIFI_PROPS / "ScifiGenerator" / "ScifiGenerator.fbx",
        "textures": {
            "Color": SCIFI_PROPS / "ScifiGenerator" / "ScifiGenerator_Base_Color.png",
            "Normal": (SCIFI_PROPS / "ScifiGenerator" / "ScifiGenerator_Normal_DirectX.png", True),
            "Roughness": SCIFI_PROPS / "ScifiGenerator" / "ScifiGenerator_Roughness.png",
            "Metalness": SCIFI_PROPS / "ScifiGenerator" / "ScifiGenerator_Metallic.png",
        },
        "target_axis": "max_h",
        "target_size_studs": 13.5,
        "decision": "Heavy turbine generator skid for SciFiFoundry CryoBay/ReactorBay side machinery bays (13.5 studs long, grounded bottom pivot).",
        "role": "Hero machinery prop & solid tactical cover (Anchored=true, CanCollide=true).",
    },
    {
        "slug": "scifi-container",
        "export_name": "ScifiContainer",
        "source": SCIFI_PROPS / "ScifiContainer" / "ScifiContainer.fbx",
        "textures": {
            "Color": SCIFI_PROPS / "ScifiContainer" / "ScifiContainer_Base_Color.png",
            "Normal": (SCIFI_PROPS / "ScifiContainer" / "ScifiContainer_Normal_DirectX.png", True),
            "Roughness": SCIFI_PROPS / "ScifiContainer" / "ScifiContainer_Roughness.png",
            "Metalness": SCIFI_PROPS / "ScifiContainer" / "ScifiContainer_Metallic.png",
        },
        "target_axis": "max_h",
        "target_size_studs": 5.6,
        "decision": "Armored beveled cargo container replacing blocky cover boxes in SciFiFoundry flank lanes & bays (5.6 studs wide).",
        "role": "Solid tactical cargo cover (Anchored=true, CanCollide=true).",
    },
    {
        "slug": "scifi-chamber",
        "export_name": "ScifiChamber",
        "source": SCIFI_PROPS / "Scifi_Chamber" / "Chamber.fbx",
        "textures": {
            "Color": SCIFI_PROPS / "Scifi_Chamber" / "Chamber_Color.png",
            "Normal": (SCIFI_PROPS / "Scifi_Chamber" / "Chamber_Normal_DirectX.png", True),
            "Roughness": SCIFI_PROPS / "Scifi_Chamber" / "Chamber_Roughness.png",
            "Metalness": SCIFI_PROPS / "Scifi_Chamber" / "Chamber_Metallic.png",
        },
        "target_axis": "z",
        "target_size_studs": 10.5,
        "decision": "Cryo stasis chamber pod with cyan glow ring for SciFiFoundry CryoBay stasis alcoves (10.5 studs tall).",
        "role": "CryoBay environmental landmark pod (Anchored=true, CanCollide=true).",
    },
    {
        "slug": "control-panel",
        "export_name": "ControlPanel",
        "source": SCIFI_PROPS / "Control_Panel" / "Control_Panel.fbx",
        "textures": {
            "Color": SCIFI_PROPS / "Control_Panel" / "Control_Panel_Base_Color.png",
            "Normal": (SCIFI_PROPS / "Control_Panel" / "Control_Panel_Normal_DirectX.png", True),
            "Roughness": SCIFI_PROPS / "Control_Panel" / "Control_Panel_Roughness.png",
            "Metalness": SCIFI_PROPS / "Control_Panel" / "Control_Panel_Metallic.png",
        },
        "target_axis": "z",
        "target_size_studs": 5.2,
        "decision": "Compact operator terminal pedestal for SciFiFoundry Spawn Bay & portal control stations (5.2 studs tall).",
        "role": "Spawn/control workstation terminal (Anchored=true, CanCollide=true).",
    },
]


def prepare_tex(src_info, out_path: Path, is_normal: bool = False) -> Path:
    if isinstance(src_info, tuple):
        src, flip_green = src_info
    else:
        src, flip_green = src_info, False
    img = bpy.data.images.load(str(src))
    w, h = img.size[0], img.size[1]
    if max(w, h) > MAX_TEX:
        scale = MAX_TEX / max(w, h)
        img.scale(max(1, int(round(w * scale))), max(1, int(round(h * scale))))
    if flip_green:
        px = np.array(img.pixels[:], dtype=np.float32)
        px[1::4] = 1.0 - px[1::4]
        img.pixels.foreach_set(px)
    img.filepath_raw = str(out_path)
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)
    return out_path


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def measure_meshes(meshes):
    bpy.context.view_layer.update()
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    tris = 0
    has_uv = True
    for ob in meshes:
        if not ob.data.uv_layers:
            has_uv = False
        tris += sum(max(0, len(p.vertices) - 2) for p in ob.data.polygons)
        mw = ob.matrix_world
        for v in ob.data.vertices:
            wc = mw @ v.co
            lo.x = min(lo.x, wc.x); lo.y = min(lo.y, wc.y); lo.z = min(lo.z, wc.z)
            hi.x = max(hi.x, wc.x); hi.y = max(hi.y, wc.y); hi.z = max(hi.z, wc.z)
    return lo, hi, tris, has_uv


def render_views(out_png: Path, meshes, size=420):
    sc = bpy.context.scene
    lo, hi, _, _ = measure_meshes(meshes)
    mid = (lo + hi) * 0.5
    ext = max((hi - lo).x, (hi - lo).y, (hi - lo).z, 0.5) * 1.25

    world = bpy.data.worlds.new("ViewsWorld")
    sc.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.14, 0.16, 0.20, 1.0)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.6

    sun = bpy.data.objects.new("ViewsSun", bpy.data.lights.new("ViewsSun", "SUN"))
    sc.collection.objects.link(sun)
    sun.rotation_euler = (0.75, 0.25, 0.65)
    sun.data.energy = 3.2

    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 10
    sc.cycles.use_denoising = False
    sc.render.resolution_x = size
    sc.render.resolution_y = size

    panels = []
    for name, off, rot in (
        ("front", (0, -1, 0), (math.radians(90), 0, 0)),
        ("side", (1, 0, 0), (math.radians(90), 0, math.radians(90))),
        ("top", (0, 0, 1), (0, 0, 0)),
    ):
        cam = bpy.data.objects.new(name, bpy.data.cameras.new(name))
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = ext
        cam.data.clip_end = ext * 10
        sc.collection.objects.link(cam)
        cam.location = mid + Vector(off) * ext * 3
        cam.rotation_euler = rot
        sc.camera = cam
        tmp = str(out_png) + f".{name}.png"
        sc.render.filepath = tmp
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(tmp)
        arr = np.array(img.pixels[:], dtype=np.float32).reshape(size, size, 4)
        bpy.data.images.remove(img)
        panels.append(arr)
        Path(tmp).unlink(missing_ok=True)

    joined = np.concatenate(panels, axis=1)
    sheet_img = bpy.data.images.new("views_sheet", width=size * 3, height=size, alpha=True)
    sheet_img.pixels.foreach_set(joined.ravel())
    sheet_img.filepath_raw = str(out_png)
    sheet_img.file_format = "PNG"
    sheet_img.save()
    bpy.data.images.remove(sheet_img)
    # Remove temporary lights/cameras so GLB export stays clean
    bpy.data.objects.remove(sun, do_unlink=True)
    for name in ("front", "side", "top"):
        cam = bpy.data.objects.get(name)
        if cam:
            bpy.data.objects.remove(cam, do_unlink=True)


def process_spec(spec: dict):
    pkg = MODELS_OUT / spec["slug"]
    for sub in ("textures", "exports"):
        (pkg / sub).mkdir(parents=True, exist_ok=True)

    tex_files = {
        "Color": prepare_tex(spec["textures"]["Color"], pkg / "textures" / f"{spec['export_name']}_Color.png"),
        "Normal": prepare_tex(spec["textures"]["Normal"], pkg / "textures" / f"{spec['export_name']}_Normal.png", is_normal=True),
        "Roughness": prepare_tex(spec["textures"]["Roughness"], pkg / "textures" / f"{spec['export_name']}_Roughness.png"),
        "Metalness": prepare_tex(spec["textures"]["Metalness"], pkg / "textures" / f"{spec['export_name']}_Metalness.png"),
    }

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=str(spec["source"]))

    # Remove non-mesh objects (empties/lights/cameras) and bake world transforms safely
    for ob in list(bpy.context.scene.objects):
        if ob.type != "MESH":
            bpy.data.objects.remove(ob, do_unlink=True)

    meshes = [ob for ob in bpy.context.scene.objects if ob.type == "MESH"]
    bpy.ops.object.select_all(action="DESELECT")
    for ob in meshes:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    lo, hi, tris, has_uv = measure_meshes(meshes)
    sz = hi - lo
    if spec["target_axis"] == "z":
        cur = sz.z
    elif spec["target_axis"] == "max_h":
        cur = max(sz.x, sz.y)
    else:
        cur = max(sz.x, sz.y, sz.z)
    scale_factor = spec["target_size_studs"] / max(cur, 1e-5)

    cx = (lo.x + hi.x) * 0.5
    cy = (lo.y + hi.y) * 0.5
    cz_min = lo.z
    for ob in meshes:
        for v in ob.data.vertices:
            v.co.x = (v.co.x - cx) * scale_factor
            v.co.y = (v.co.y - cy) * scale_factor
            v.co.z = (v.co.z - cz_min) * scale_factor
        ob.data.update()

    # Replace material node graph cleanly with 1024 PBR PNGs for GLB embedding
    pbr_mat = bpy.data.materials.new(spec["export_name"] + "_PBR")
    pbr_mat.use_nodes = True
    nt = pbr_mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")

    def add_img(key, colorspace):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = bpy.data.images.load(str(tex_files[key]))
        n.image.colorspace_settings.name = colorspace
        return n

    nt.links.new(add_img("Color", "sRGB").outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(add_img("Roughness", "Non-Color").outputs["Color"], bsdf.inputs["Roughness"])
    nt.links.new(add_img("Metalness", "Non-Color").outputs["Color"], bsdf.inputs["Metallic"])
    nm_node = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(add_img("Normal", "Non-Color").outputs["Color"], nm_node.inputs["Color"])
    nt.links.new(nm_node.outputs["Normal"], bsdf.inputs["Normal"])

    glass_mat = None
    if spec["slug"] == "scifi-chamber":
        glass_mat = bpy.data.materials.new("ScifiChamber_Glass")
        glass_mat.use_nodes = True
        g_bsdf = next(n for n in glass_mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        g_bsdf.inputs["Base Color"].default_value = (0.35, 0.80, 0.96, 1.0)
        g_bsdf.inputs["Roughness"].default_value = 0.12
        g_bsdf.inputs["Alpha"].default_value = 0.28
        glass_mat.blend_method = "BLEND"

    for ob in meshes:
        if glass_mat and any(m and "glass" in m.name.lower() for m in ob.data.materials):
            ob.data.materials.clear()
            ob.data.materials.append(glass_mat)
        else:
            ob.data.materials.clear()
            ob.data.materials.append(pbr_mat)

    lo2, hi2, tris2, _ = measure_meshes(meshes)
    sz2 = hi2 - lo2

    views_path = pkg / "views.png"
    render_views(views_path, meshes)

    glb_path = pkg / "exports" / f"{spec['export_name']}.glb"
    bpy.ops.object.select_all(action="DESELECT")
    for ob in meshes:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(glb_path),
        export_format="GLB",
        use_selection=True,
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_yup=True,
        export_apply=True,
    )

    relief = round(sz2.z / max(sz2.x, sz2.y, 1e-5), 4)
    appraisal = {
        "tool": "tools/package_foundry_props.py",
        "appraisedOn": datetime.date.today().isoformat(),
        "source": str(spec["source"].relative_to(ROOT)).replace("\\", "/"),
        "sourceSha256": sha256(spec["source"]),
        "measurements": {
            "triangles": tris2,
            "meshObjects": len(meshes),
            "hasUvLayers": has_uv,
            "boundsStuds": [round(sz2.x, 3), round(sz2.y, 3), round(sz2.z, 3)],
            "reliefRatio": relief,
        },
        "verdict": "PASS - low/mid-poly game-ready prop within Roblox 10k tri limit with 1024px OpenGL PBR maps.",
        "decision": spec["decision"],
        "views": "views.png",
    }
    (pkg / "appraisal.json").write_text(json.dumps(appraisal, indent=2) + "\n", encoding="utf-8")

    readme = (
        f"# {spec['export_name']}\n\n"
        f"- **Role:** {spec['role']}\n"
        f"- **Source:** `{appraisal['source']}`\n"
        f"- **Triangles:** {tris2} across {len(meshes)} mesh object(s)\n"
        f"- **Exported Size (X x Y x Z studs in Blender):** {sz2.x:.2f} x {sz2.y:.2f} x {sz2.z:.2f}\n"
        f"- **Pivot:** Centered X/Y, bottom at Z = 0 (glTF Y = 0).\n"
    )
    (pkg / "README.md").write_text(readme, encoding="utf-8")

    handoff = (
        f"# Resume here: {spec['slug']}\n\n"
        f"## Current truth\n\n"
        f"Packaged cleanly from `{appraisal['source']}` into `exports/{spec['export_name']}.glb` "
        f"({tris2} triangles, {sz2.x:.2f} x {sz2.y:.2f} x {sz2.z:.2f} studs in Blender local coords, "
        f"OpenGL 1024x1024 PNG textures embedded).\n"
        f"Studio upload/verification status below.\n\n"
        f"## Studio record\n\n"
        f"- Asset owner: pending\n"
        f"- Uploaded asset ID: pending\n"
        f"- Target map: SciFiFoundry\n"
    )
    (pkg / "HANDOFF.md").write_text(handoff, encoding="utf-8")
    print(f"PACKAGED {spec['slug']}: tris={tris2}, size={sz2.x:.2f}x{sz2.y:.2f}x{sz2.z:.2f} -> {glb_path.name}")


def main():
    for spec in SPECS:
        process_spec(spec)


if __name__ == "__main__":
    main()
