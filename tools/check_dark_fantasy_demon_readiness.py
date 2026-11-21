"""Local Marketplace readiness & geometry audit for DarkFantasyDemonFemale.

This is a reproducible local preflight, not Roblox Avatar Setup or Marketplace approval.
Writes assets/models/dark-fantasy-demon-female/marketplace_readiness.json.
"""
from __future__ import annotations

import hashlib
import json
import struct
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] if (Path(__file__).resolve().parents[1].name == "blender") else Path(__file__).resolve().parents[1]
PKG = ROOT / "assets/models/dark-fantasy-demon-female"

BODY_BUDGET = 10_742
REGION_BUDGETS = {
    "Head": 4000,
    "Torso": 1750,       # UpperTorso + LowerTorso
    "LeftArm": 1248,     # LeftUpperArm + LeftLowerArm + LeftHand
    "RightArm": 1248,    # RightUpperArm + RightLowerArm + RightHand
    "LeftLeg": 1248,     # LeftUpperLeg + LeftLowerLeg + LeftFoot
    "RightLeg": 1248,    # RightUpperLeg + RightLowerLeg + RightFoot
}
ACCESSORY_BUDGET = 4000
MAX_TEX_DIM = 1024

R15_REGIONS = [
    "Head", "UpperTorso", "LowerTorso",
    "LeftUpperArm", "LeftLowerArm", "LeftHand",
    "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
    "RightUpperLeg", "RightLowerLeg", "RightFoot",
]


def parse_glb(path: Path) -> dict:
    raw = path.read_bytes()
    assert raw[:4] == b"glTF", f"Not a glTF binary: {path}"
    total_len = struct.unpack_from("<I", raw, 8)[0]
    assert total_len == len(raw), f"Length mismatch in {path}"
    chunk_len, chunk_type = struct.unpack_from("<II", raw, 12)
    assert chunk_type == 0x4E4F534A, f"Missing JSON chunk in {path}"
    doc = json.loads(raw[20:20 + chunk_len])

    # Extract binary buffer for watertightness check on triangles
    bin_off = 20 + chunk_len
    bin_len, bin_type = struct.unpack_from("<II", raw, bin_off)
    assert bin_type == 0x004E4942
    bin_data = raw[bin_off + 8:bin_off + 8 + bin_len]
    return doc, bin_data, hashlib.sha256(raw).hexdigest()


def check_mesh_topology(doc: dict, bin_data: bytes, mesh_idx: int) -> dict:
    mesh = doc["meshes"][mesh_idx]
    tris = 0
    has_uv = True
    edges = {}
    pos_coords = {}
    parent = {}

    def find_root(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    def union(a, b):
        ra, rb = find_root(a), find_root(b)
        if ra != rb:
            parent[rb] = ra

    for prim in mesh.get("primitives", []):
        attrs = prim.get("attributes", {})
        if "TEXCOORD_0" not in attrs:
            has_uv = False
        pos_acc = doc["accessors"][attrs["POSITION"]]
        pos_bv = doc["bufferViews"][pos_acc["bufferView"]]
        pos_off = pos_bv.get("byteOffset", 0) + pos_acc.get("byteOffset", 0)
        pos_stride = pos_bv.get("byteStride", 12)

        idx_acc = doc["accessors"][prim["indices"]]
        idx_bv = doc["bufferViews"][idx_acc["bufferView"]]
        idx_off = idx_bv.get("byteOffset", 0) + idx_acc.get("byteOffset", 0)
        ctype = idx_acc["componentType"]
        fmt, step = (("<H", 2) if ctype == 5123 else ("<I", 4))
        count = idx_acc["count"]
        tris += count // 3

        def pos_key(vi: int) -> tuple[int, int, int]:
            o = pos_off + vi * pos_stride
            x, y, z = struct.unpack_from("<fff", bin_data, o)
            k = (round(x * 10000), round(y * 10000), round(z * 10000))
            if k not in pos_coords:
                pos_coords[k] = (x, y, z)
                parent[k] = k
            return k

        indices = [struct.unpack_from(fmt, bin_data, idx_off + i * step)[0] for i in range(count)]
        for t in range(0, count, 3):
            k0, k1, k2 = pos_key(indices[t]), pos_key(indices[t + 1]), pos_key(indices[t + 2])
            union(k0, k1)
            union(k1, k2)
            for a, b in ((k0, k1), (k1, k2), (k2, k0)):
                if a == b:
                    continue
                ek = (a, b) if a < b else (b, a)
                edges[ek] = edges.get(ek, 0) + 1

    comp_pts = {}
    for k, pt in pos_coords.items():
        r = find_root(k)
        comp_pts.setdefault(r, []).append(pt)
    components = []
    for pts in comp_pts.values():
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]
        zs = [p[2] for p in pts]
        components.append({
            "vertices": len(pts),
            "bbMin": [round(min(xs), 4), round(min(ys), 4), round(min(zs), 4)],
            "bbMax": [round(max(xs), 4), round(max(ys), 4), round(max(zs), 4)],
        })
    components.sort(key=lambda c: c["vertices"], reverse=True)

    open_edges = sum(1 for c in edges.values() if c < 2)
    nonmanifold_edges = sum(1 for c in edges.values() if c > 2)
    return {
        "name": mesh.get("name", f"mesh_{mesh_idx}"),
        "vertices": len(pos_coords),
        "triangles": tris,
        "hasUV": has_uv,
        "openEdges": open_edges,
        "nonManifoldEdges": nonmanifold_edges,
        "watertight": open_edges == 0 and nonmanifold_edges == 0,
        "components": components,
    }


def check_png_size(path: Path) -> tuple[int, int]:
    raw = path.read_bytes()
    assert raw[:8] == b"\x89PNG\r\n\x1a\n", f"Not PNG: {path}"
    w, h = struct.unpack_from(">II", raw, 16)
    return w, h


def main():
    game_skin_failures = []
    marketplace_local_failures = []

    # 1. Source hashes
    source_hashes = {}
    for sname in ("source/DarkFantasyDemonFemaleSource.glb", "source/DarkFantasyDemonFemaleReference.png"):
        p = PKG / sname
        if not p.exists():
            game_skin_failures.append(f"Missing source: {sname}")
        else:
            source_hashes[sname] = hashlib.sha256(p.read_bytes()).hexdigest()

    # 2. Textures <= 1024x1024 + required team-color shooter variants
    textures = {}
    for tp in sorted((PKG / "textures").glob("*.png")):
        w, h = check_png_size(tp)
        ok = w <= MAX_TEX_DIM and h <= MAX_TEX_DIM
        if not ok:
            game_skin_failures.append(f"Texture {tp.name} exceeds {MAX_TEX_DIM}: {w}x{h}")
        textures[tp.name] = {"width": w, "height": h, "within1024": ok, "sha256": hashlib.sha256(tp.read_bytes()).hexdigest()}

    for req_t in (
        "DarkFantasyDemonBody_ALB.png", "DarkFantasyDemonAcc_ALB.png",
        "DarkFantasyDemonBody_TeamRed_ALB.png", "DarkFantasyDemonAcc_TeamRed_ALB.png",
        "DarkFantasyDemonBody_TeamBlue_ALB.png", "DarkFantasyDemonAcc_TeamBlue_ALB.png",
    ):
        if req_t not in textures:
            game_skin_failures.append(f"Missing texture variant: textures/{req_t}")

    # 3. Body GLB (renderable 15 R15 parts separated cleanly from official *_OuterCage meshes)
    body_path = PKG / "exports/DarkFantasyDemonFemaleBody.glb"
    b_doc, b_bin, b_sha = parse_glb(body_path)
    all_b_meshes = {m["name"]: m for m in [check_mesh_topology(b_doc, b_bin, i) for i in range(len(b_doc.get("meshes", [])))]}
    b_meshes = {k: v for k, v in all_b_meshes.items() if not k.endswith(("_InnerCage", "_OuterCage"))}
    b_cages = {k: v for k, v in all_b_meshes.items() if k.endswith("_OuterCage")}

    missing_regions = [r for r in R15_REGIONS if r not in b_meshes]
    if missing_regions:
        game_skin_failures.append(f"Missing R15 regions in Body GLB: {missing_regions}")

    for rname, m in b_meshes.items():
        if not m["watertight"]:
            game_skin_failures.append(f"Body region {rname} not watertight (open={m['openEdges']}, nonmanifold={m['nonManifoldEdges']})")
        if not m["hasUV"]:
            game_skin_failures.append(f"Body region {rname} missing UVs")

    region_totals = {
        "Head": b_meshes.get("Head", {}).get("triangles", 0),
        "Torso": b_meshes.get("UpperTorso", {}).get("triangles", 0) + b_meshes.get("LowerTorso", {}).get("triangles", 0),
        "LeftArm": sum(b_meshes.get(k, {}).get("triangles", 0) for k in ("LeftUpperArm", "LeftLowerArm", "LeftHand")),
        "RightArm": sum(b_meshes.get(k, {}).get("triangles", 0) for k in ("RightUpperArm", "RightLowerArm", "RightHand")),
        "LeftLeg": sum(b_meshes.get(k, {}).get("triangles", 0) for k in ("LeftUpperLeg", "LeftLowerLeg", "LeftFoot")),
        "RightLeg": sum(b_meshes.get(k, {}).get("triangles", 0) for k in ("RightUpperLeg", "RightLowerLeg", "RightFoot")),
    }
    total_body_tris = sum(region_totals.values())
    if total_body_tris > BODY_BUDGET:
        game_skin_failures.append(f"Body triangles {total_body_tris} > {BODY_BUDGET}")
    for grp, tris in region_totals.items():
        if tris > REGION_BUDGETS[grp]:
            game_skin_failures.append(f"Body group {grp} triangles {tris} > {REGION_BUDGETS[grp]}")

    skin_joints = []
    if b_doc.get("skins"):
        skin_joints = [b_doc["nodes"][j]["name"] for j in b_doc["skins"][0]["joints"]]
    missing_bones = [r for r in R15_REGIONS if r not in skin_joints]
    if missing_bones:
        game_skin_failures.append(f"Missing R15 bones in Body GLB skin: {missing_bones}")

    # Strict Dynamic Head Geometry Check (must have visible anterior eyeballs & anterior inner mouth teeth/tongue!)
    head_comps = b_meshes.get("Head", {}).get("components", [])
    # In glTF Y-up: height=Y, anterior forward=+Z (Blender -Y). Visible eyes: Y ~ 5.14..5.26, maxZ >= 0.35.
    eye_comps = [
        c for c in head_comps[1:]
        if 5.12 <= 0.5 * (c["bbMin"][1] + c["bbMax"][1]) <= 5.28 and c["bbMax"][2] >= 0.35
    ]
    mouth_comps = [
        c for c in head_comps[1:]
        if 4.74 <= 0.5 * (c["bbMin"][1] + c["bbMax"][1]) <= 4.86 and c["bbMax"][2] >= 0.34
    ]
    has_dynamic_head_geo = len(eye_comps) >= 2 and len(mouth_comps) >= 3
    if not has_dynamic_head_geo:
        marketplace_local_failures.append(
            f"Head lacks visible 3D anterior eye/mouth geometry (eyeComps={len(eye_comps)}/2, mouthComps={len(mouth_comps)}/3)"
        )

    # Strict Body OuterCages Check (must have all 15 official Body_Cage_Template *_OuterCage meshes, not placeholders)
    missing_body_cages = [f"{r}_OuterCage" for r in R15_REGIONS if f"{r}_OuterCage" not in b_cages]
    if missing_body_cages:
        marketplace_local_failures.append(f"Missing body outer cages for Layered Clothing: {missing_body_cages}")
    for cname, cm in b_cages.items():
        if not cm["hasUV"] or cm["triangles"] < 100:
            marketplace_local_failures.append(f"Body cage {cname} appears placeholder or lacks template UVs (tris={cm['triangles']}, uv={cm['hasUV']})")

    # Facial FACS bones check (honest status: Avatar Setup generates FaceControls if absent; cannot pass local FACS animation!)
    facial_bones = [j for j in skin_joints if j not in R15_REGIONS]
    facial_rig_status = (
        f"authored_facial_bones ({len(facial_bones)})" if facial_bones
        else "no_facial_bones (requires Roblox Studio Avatar Setup to generate 17-pose FACS FaceControls)"
    )

    body_report = {
        "path": "exports/DarkFantasyDemonFemaleBody.glb",
        "sha256": b_sha,
        "totalTriangles": total_body_tris,
        "budget": BODY_BUDGET,
        "withinBudget": total_body_tris <= BODY_BUDGET,
        "regionGroupTotals": region_totals,
        "regionBudgets": REGION_BUDGETS,
        "regions": {k: {rk: rv for rk, rv in v.items() if rk != "components"} for k, v in b_meshes.items()},
        "bodyOuterCagesCount": len(b_cages),
        "dynamicHeadGeo": {
            "passed": has_dynamic_head_geo,
            "componentCount": len(head_comps),
            "anteriorEyeComponents": len(eye_comps),
            "anteriorMouthComponents": len(mouth_comps),
            "facialRigStatus": facial_rig_status,
        },
        "r15Bones": skin_joints,
        "orientation": "glTF Y-up, Roblox forward -Z",
    }

    # 4. Accessory GLBs + strict template-cage validation (reject 80-tri icosphere placeholders!)
    acc_specs = {
        "DemonHorns.glb": {"layered": False},
        "DemonHair.glb": {"layered": False},
        "FeatheredShoulderMantle.glb": {"layered": True},
        "HipTassets.glb": {"layered": True},
        "LeftWristFeathers.glb": {"layered": False},
        "RightWristFeathers.glb": {"layered": False},
    }
    acc_reports = {}
    for fname, spec in acc_specs.items():
        ap = PKG / "exports" / fname
        a_doc, a_bin, a_sha = parse_glb(ap)
        meshes = [check_mesh_topology(a_doc, a_bin, i) for i in range(len(a_doc.get("meshes", [])))]
        main_meshes = [m for m in meshes if not m["name"].endswith(("_InnerCage", "_OuterCage"))]
        cage_meshes = [m for m in meshes if m["name"].endswith(("_InnerCage", "_OuterCage"))]

        for m in main_meshes:
            if m["triangles"] > ACCESSORY_BUDGET:
                game_skin_failures.append(f"Accessory {fname} mesh {m['name']} has {m['triangles']} tris > {ACCESSORY_BUDGET}")
            if not m["watertight"]:
                game_skin_failures.append(f"Accessory {fname} mesh {m['name']} not watertight (open={m['openEdges']}, nonmanifold={m['nonManifoldEdges']})")
            if not m["hasUV"]:
                game_skin_failures.append(f"Accessory {fname} mesh {m['name']} missing UVs")

        has_skin = len(a_doc.get("skins", [])) > 0
        if spec["layered"]:
            if not has_skin:
                game_skin_failures.append(f"Layered accessory {fname} missing R15 skinning")
            if len(cage_meshes) < 2:
                marketplace_local_failures.append(f"Layered accessory {fname} missing InnerCage/OuterCage")
            for cm in cage_meshes:
                if cm["vertices"] < 1000 or not cm["hasUV"]:
                    marketplace_local_failures.append(
                        f"Placeholder/non-template cage {cm['name']} in {fname} (verts={cm['vertices']} < 1000, uv={cm['hasUV']})"
                    )

        acc_reports[fname] = {
            "sha256": a_sha,
            "layered": spec["layered"],
            "hasR15Skin": has_skin,
            "cageCount": len(cage_meshes),
            "cagesTemplateValid": (not spec["layered"]) or (len(cage_meshes) >= 2 and all(cm["vertices"] >= 1000 and cm["hasUV"] for cm in cage_meshes)),
            "meshes": [{mk: mv for mk, mv in m.items() if mk != "components"} for m in meshes],
        }

    game_skin_passed = len(game_skin_failures) == 0
    marketplace_precheck_passed = game_skin_passed and len(marketplace_local_failures) == 0

    studio_blockers = [
        "Dynamic Head FACS animation poses (17+ poses / FaceControls) require Roblox Studio Avatar Setup / Character Auto-Setup execution & verification",
        "Layered Accessory cage deformation and Studio Character Validation pass must be confirmed inside Roblox Studio before Marketplace submission",
    ]

    report = {
        "checkedAt": datetime.now(timezone.utc).isoformat(),
        "gameSkinPassed": game_skin_passed,
        "marketplaceLocalPrecheckPassed": marketplace_precheck_passed,
        "marketplaceUploadReady": False,
        "passed": marketplace_precheck_passed,
        "gameSkinFailures": game_skin_failures,
        "marketplaceLocalFailures": marketplace_local_failures,
        "remainingStudioBlockers": studio_blockers,
        "sourceHashes": source_hashes,
        "textures": textures,
        "body": body_report,
        "accessories": acc_reports,
        "notLocallyVerifiable": [
            "Avatar Setup Platform Avatar processing and generated dynamic head FACS FaceControls",
            "Studio animation playback (idle/run/jump/swim/emotes) and layered clothing fitting",
            "Roblox Marketplace creator eligibility, upload fees, and moderation",
        ],
    }

    out_path = PKG / "marketplace_readiness.json"
    out_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

    val_path = PKG / "validation.json"
    if val_path.exists():
        val = json.loads(val_path.read_text(encoding="utf-8"))
        val["checkedAt"] = report["checkedAt"]
        val["palette"] = (
            "Dark-Fantasy Charcoal, Obsidian & Accent Trim (Violet default + TeamRed / TeamBlue shooter variants, "
            "3D Dynamic Head orbital sockets/eyeballs/teeth/tongue, 8-plate wide U-horns, sculpted multi-tier shoulder & wrist feather blades, "
            "official Roblox Clothing_Cage_Template & Body_Cage_Template conformal cages)"
        )
        val["gameSkinPassed"] = game_skin_passed
        val["marketplaceLocalPrecheckPassed"] = marketplace_precheck_passed
        val["marketplaceUploadReady"] = False
        val["localReadinessPassed"] = marketplace_precheck_passed
        val["remainingStudioBlockers"] = studio_blockers
        val["bodyTriangles"] = total_body_tris
        val["accessoryTriangles"] = {
            k: sum(m["triangles"] for m in v["meshes"] if not m["name"].endswith(("_InnerCage", "_OuterCage")))
            for k, v in acc_reports.items()
        }
        val["exports"] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((PKG / "exports").glob("*.glb"))}
        val["textures"] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((PKG / "textures").glob("*.png"))}
        val["review"] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted((PKG / "review").glob("*.png")) if p.name != "views.png"}
        val_path.write_text(json.dumps(val, indent=2) + "\n", encoding="utf-8")

    print(json.dumps({
        "gameSkinPassed": game_skin_passed,
        "marketplaceLocalPrecheckPassed": marketplace_precheck_passed,
        "marketplaceUploadReady": False,
        "gameSkinFailures": game_skin_failures,
        "marketplaceLocalFailures": marketplace_local_failures,
        "dynamicHeadGeo": body_report["dynamicHeadGeo"],
        "bodyOuterCagesCount": len(b_cages),
        "bodyTriangles": total_body_tris,
        "regionTotals": region_totals,
        "accessories": {
            k: {
                "tris": sum(m["triangles"] for m in v["meshes"] if not m["name"].endswith(("_InnerCage", "_OuterCage"))),
                "cagesTemplateValid": v["cagesTemplateValid"],
            }
            for k, v in acc_reports.items()
        },
        "remainingStudioBlockers": studio_blockers,
    }, indent=2))
    if not marketplace_precheck_passed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
