"""Reproducible high-fidelity builder for DarkFantasyDemonFemale (Marketplace bundle + game skin).

Pipeline:
1. Imports source/DarkFantasyDemonFemaleSource.glb as the high-resolution 3D shape/surface
   reference (never directly rigged/segmented/uploaded as raw scan soup), scaled to 7.26 studs
   total height (head center at Z = 5.15 studs, crown at Z = 5.95 studs, soles at Z = 0.00).
2. Builds 1024x1024 Albedo and Roughness textures in textures/ with a Dark-Fantasy Black & Purple
   color scheme by combining:
   - Front orthographic projection from source/DarkFantasyDemonFemaleReference.png (piecewise
     landmark-aligned to the 3D scan's exact chin/lip/eye/bang/waist/boot heights, foreground-
     extracted, eroded inside the studio background halo, color-graded into deep obsidian blacks
     and rich amethyst/royal purples by anatomical zone while preserving all leather grain, seams,
     feather vanes, and facial features, and dilated outward) on the Left UV half (U in [0.0, 0.5]),
   - Seamless palette-matched Rear projection on the Right UV half (U in [0.5, 1.0]).
3. Reconstructs 15 watertight R15 body regions (total <= 10,742 tris, with Dynamic Head eye and
   mouth geometry flush with the sculpted face and slice-fitted internal volume cores) and 6
   watertight accessories (each <= 4,000 tris; layered accessories R15-skinned with InnerCage/
   OuterCage) via fine VoxelRemesh + BVHTree surface projection + collapse decimation + exact
   1e-4 manifold enforcement.
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/dark-fantasy-demon-female"
SRC_GLB = PKG / "source/DarkFantasyDemonFemaleSource.glb"
REF_PNG = PKG / "source/DarkFantasyDemonFemaleReference.png"
TEX_DIR = PKG / "textures"
EXP_DIR = PKG / "exports"
TEX_DIR.mkdir(parents=True, exist_ok=True)
EXP_DIR.mkdir(parents=True, exist_ok=True)

SCALE = 7.25
Z_OFF = 0.501007

# Atlas world window mapped to each 512x1024 half of the 1024x1024 texture
ATLAS_X_MIN, ATLAS_X_MAX = -2.35, 2.35
ATLAS_Z_MIN, ATLAS_Z_MAX = -0.10, 7.40

R15_REGIONS = [
    "Head", "UpperTorso", "LowerTorso",
    "LeftUpperArm", "LeftLowerArm", "LeftHand",
    "RightUpperArm", "RightLowerArm", "RightHand",
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
    "RightUpperLeg", "RightLowerLeg", "RightFoot",
]

BONE_SPEC = {
    "LowerTorso":   ((0.0, 0.0, 1.86), (0.0, 0.0, 3.06), None),
    "UpperTorso":   ((0.0, 0.0, 3.06), (0.0, 0.0, 4.66), "LowerTorso"),
    "Head":         ((0.0, 0.0, 4.66), (0.0, 0.0, 5.85), "UpperTorso"),
    "LeftUpperArm": ((0.82, 0.0, 4.18), (1.24, 0.0, 3.32), "UpperTorso"),
    "LeftLowerArm": ((1.24, 0.0, 3.32), (1.32, -0.06, 2.54), "LeftUpperArm"),
    "LeftHand":     ((1.32, -0.06, 2.54), (1.38, -0.15, 1.92), "LeftLowerArm"),
    "RightUpperArm": ((-0.82, 0.0, 4.18), (-1.24, 0.0, 3.32), "UpperTorso"),
    "RightLowerArm": ((-1.24, 0.0, 3.32), (-1.32, -0.06, 2.54), "RightUpperArm"),
    "RightHand":     ((-1.32, -0.06, 2.54), (-1.38, -0.15, 1.92), "RightLowerArm"),
    "LeftUpperLeg": ((0.48, 0.02, 1.86), (0.58, 0.04, 1.20), "LowerTorso"),
    "LeftLowerLeg": ((0.58, 0.04, 1.20), (0.70, 0.04, 0.45), "LeftUpperLeg"),
    "LeftFoot":     ((0.70, 0.04, 0.45), (0.74, -0.35, 0.05), "LeftLowerLeg"),
    "RightUpperLeg": ((-0.48, 0.02, 1.86), (-0.58, 0.04, 1.20), "LowerTorso"),
    "RightLowerLeg": ((-0.58, 0.04, 1.20), (-0.70, 0.04, 0.45), "RightUpperLeg"),
    "RightFoot":     ((-0.70, 0.04, 0.45), (-0.74, -0.35, 0.05), "RightLowerLeg"),
}


def check_quantized_manifold(obj) -> tuple[int, int, int]:
    """Exact same 1e-4 quantized edge audit as tools/check_dark_fantasy_demon_readiness.py."""
    me = obj.data
    me.calc_loop_triangles()
    edges = {}
    tris = len(me.loop_triangles)
    for lt in me.loop_triangles:
        v0, v1, v2 = (me.vertices[i].co for i in lt.vertices)
        k0 = (round(v0.x * 10000), round(v0.y * 10000), round(v0.z * 10000))
        k1 = (round(v1.x * 10000), round(v1.y * 10000), round(v1.z * 10000))
        k2 = (round(v2.x * 10000), round(v2.y * 10000), round(v2.z * 10000))
        for a, b in ((k0, k1), (k1, k2), (k2, k0)):
            if a == b:
                continue
            ek = (a, b) if a < b else (b, a)
            edges[ek] = edges.get(ek, 0) + 1
    open_e = sum(1 for c in edges.values() if c < 2)
    nonman_e = sum(1 for c in edges.values() if c > 2)
    return tris, open_e, nonman_e


def enforce_strict_watertight(obj) -> tuple[int, int, int]:
    """Guarantee openEdges == 0 and nonManifoldEdges == 0 under 1e-4 quantization."""
    bpy.context.view_layer.objects.active = obj
    for _pass in range(10):
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0007)
        bmesh.ops.dissolve_degenerate(bm, edges=bm.edges, dist=0.0002)

        for v in bm.verts:
            v.co.x = round(v.co.x * 2000) / 2000.0
            v.co.y = round(v.co.y * 2000) / 2000.0
            v.co.z = round(v.co.z * 2000) / 2000.0
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0003)

        bm.verts.ensure_lookup_table()
        key_map = {}
        target_map = {}
        for v in bm.verts:
            k = (round(v.co.x * 10000), round(v.co.y * 10000), round(v.co.z * 10000))
            if k in key_map:
                target_map[v] = key_map[k]
            else:
                key_map[k] = v
        if target_map:
            bmesh.ops.weld_verts(bm, targetmap=target_map)

        seen_faces = {}
        dup_faces = set()
        for f in list(bm.faces):
            key = tuple(sorted(v.index for v in f.verts))
            if len(set(key)) < 3:
                dup_faces.add(f)
            elif key in seen_faces:
                dup_faces.add(f)
                dup_faces.add(seen_faces[key])
            else:
                seen_faces[key] = f
        if dup_faces:
            bmesh.ops.delete(bm, geom=list(dup_faces), context="FACES")

        nonman_faces = set()
        for e in bm.edges:
            if len(e.link_faces) > 2:
                for f in e.link_faces:
                    nonman_faces.add(f)
        if nonman_faces:
            bmesh.ops.delete(bm, geom=list(nonman_faces), context="FACES")

        wire_edges = [e for e in bm.edges if len(e.link_faces) == 0]
        if wire_edges:
            bmesh.ops.delete(bm, geom=wire_edges, context="EDGES")
        loose_verts = [v for v in bm.verts if len(v.link_faces) == 0]
        if loose_verts:
            bmesh.ops.delete(bm, geom=loose_verts, context="VERTS")

        bm.verts.ensure_lookup_table()
        bm.edges.ensure_lookup_table()
        pinch_faces = set()
        for v in bm.verts:
            b_edges = [e for e in v.link_edges if len(e.link_faces) == 1]
            if len(b_edges) > 2:
                for f in v.link_faces:
                    pinch_faces.add(f)
        if pinch_faces:
            bmesh.ops.delete(bm, geom=list(pinch_faces), context="FACES")
            wire_edges = [e for e in bm.edges if len(e.link_faces) == 0]
            if wire_edges:
                bmesh.ops.delete(bm, geom=wire_edges, context="EDGES")
            loose_verts = [v for v in bm.verts if len(v.link_faces) == 0]
            if loose_verts:
                bmesh.ops.delete(bm, geom=loose_verts, context="VERTS")

        bm.verts.ensure_lookup_table()
        bm.edges.ensure_lookup_table()
        b_edges = set(e for e in bm.edges if len(e.link_faces) == 1)
        idx_offset = 1
        while b_edges:
            start_e = next(iter(b_edges))
            cycle_edges = [start_e]
            b_edges.remove(start_e)
            curr_v = start_e.verts[1]
            start_v = start_e.verts[0]
            while curr_v != start_v:
                next_e = None
                for e in curr_v.link_edges:
                    if e in b_edges:
                        next_e = e
                        break
                if next_e is None:
                    break
                cycle_edges.append(next_e)
                b_edges.remove(next_e)
                curr_v = next_e.other_vert(curr_v)

            if len(cycle_edges) == 3:
                c_verts = list({v for e in cycle_edges for v in e.verts})
                if len(c_verts) == 3:
                    try:
                        bm.faces.new(c_verts)
                    except ValueError:
                        pass
            elif len(cycle_edges) > 3:
                c_verts = list({v for e in cycle_edges for v in e.verts})
                center = sum((v.co for v in c_verts), Vector((0.0, 0.0, 0.0))) / len(c_verts)
                n_avg = sum((v.normal for v in c_verts), Vector((0.0, 0.0, 1.0)))
                if n_avg.length > 1e-4:
                    n_avg.normalize()
                else:
                    n_avg = Vector((0.0, 0.0, 1.0))
                center = center + n_avg * (0.0012 + 0.0002 * (idx_offset % 5))
                center = Vector((
                    round(center.x * 2000) / 2000.0,
                    round(center.y * 2000) / 2000.0,
                    round(center.z * 2000) / 2000.0,
                ))
                idx_offset += 1
                apex = bm.verts.new(center)
                for e in cycle_edges:
                    try:
                        bm.faces.new((e.verts[0], e.verts[1], apex))
                    except ValueError:
                        pass

        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()

        tris, open_e, nonman_e = check_quantized_manifold(obj)
        if open_e == 0 and nonman_e == 0:
            break
    return check_quantized_manifold(obj)


def keep_top_components(obj, max_components: int = 1, min_faces: int = 40):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    visited = set()
    comps = []
    for f in bm.faces:
        if f in visited:
            continue
        stack = [f]
        comp = []
        visited.add(f)
        while stack:
            cur = stack.pop()
            comp.append(cur)
            for e in cur.edges:
                for nf in e.link_faces:
                    if nf not in visited:
                        visited.add(nf)
                        stack.append(nf)
        comps.append(comp)
    comps.sort(key=len, reverse=True)
    keep = set()
    for i, c in enumerate(comps):
        if i < max_components or len(c) >= min_faces:
            if i < max_components:
                keep.update(c)
    del_f = [f for f in bm.faces if f not in keep]
    if del_f:
        bmesh.ops.delete(bm, geom=del_f, context="FACES")
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def smoothstep(edge0, edge1, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - edge0) / np.maximum(edge1 - edge0, 1e-6), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def dilate_fill(rgb: np.ndarray, valid: np.ndarray, iterations: int = 90) -> np.ndarray:
    out = rgb.copy()
    mask = valid.copy()
    for _ in range(iterations):
        if mask.all():
            break
        up = np.roll(out, -1, axis=0)
        dn = np.roll(out, 1, axis=0)
        lf = np.roll(out, -1, axis=1)
        rt = np.roll(out, 1, axis=1)
        m_up = np.roll(mask, -1, axis=0).astype(np.float32)
        m_dn = np.roll(mask, 1, axis=0).astype(np.float32)
        m_lf = np.roll(mask, -1, axis=1).astype(np.float32)
        m_rt = np.roll(mask, 1, axis=1).astype(np.float32)
        cnt = m_up + m_dn + m_lf + m_rt
        can_fill = (~mask) & (cnt > 0)
        if not np.any(can_fill):
            break
        avg = (up * m_up[..., None] + dn * m_dn[..., None] + lf * m_lf[..., None] + rt * m_rt[..., None]) / np.maximum(cnt[..., None], 1.0)
        out[can_fill] = avg[can_fill]
        mask[can_fill] = True
    out[~mask] = np.array([18.0, 16.0, 24.0], dtype=np.float32)
    return out


def erode_mask(mask: np.ndarray, radius: int = 3) -> np.ndarray:
    out = mask.copy()
    for _ in range(radius):
        out = (
            out
            & np.roll(out, 1, axis=0)
            & np.roll(out, -1, axis=0)
            & np.roll(out, 1, axis=1)
            & np.roll(out, -1, axis=1)
        )
    return out


# Dedicated High-DPI Head UV Island bounds in DarkFantasyDemonBody_* (492x338 px = 22x higher face texel density!)
HEAD_X_MIN, HEAD_X_MAX = -0.52, 0.52
HEAD_Z_MIN, HEAD_Z_MAX = 4.50, 5.62
HEAD_U_MIN, HEAD_U_MAX = 0.010, 0.490
HEAD_V_MIN, HEAD_V_MAX = 0.665, 0.995


def compute_structural_seam_and_wear_maps(
    world_x: np.ndarray,
    world_z: np.ndarray,
    t_relief: np.ndarray,
    t_smooth: np.ndarray,
    is_accessory: bool = False,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """Build 1024x512 procedural + scan-derived structural maps:
    - seam_groove [0..1]: crisp recessed armor/panel joint lines (darkened & higher roughness)
    - seam_pipe   [0..1]: raised armor bevels / fine violet accent seam piping
    - wear_mask   [0..1]: restrained micro-scuff & edge wear along high-contact armor borders
    - height_map  [-1..1]: combined relief height field for tangent-space Normal Map (_NRM)
    """
    ax = np.abs(world_x)
    seam_groove = np.zeros_like(world_x, dtype=np.float32)
    seam_pipe   = np.zeros_like(world_x, dtype=np.float32)
    armor_edge  = np.zeros_like(world_x, dtype=np.float32)

    # 1. Horns (aligned 1-to-1 with 8 bold broad sculpted horn plates across Z = 5.42..7.22):
    t_horn = np.clip((world_z - 5.42) / 1.80, 0.0, 1.0)
    horn_cx = 0.435 + 0.505 * np.sin(t_horn * math.pi * 0.68) + 0.045 * t_horn * (1.0 - t_horn)
    horn_inner_x = np.where(world_z < 5.96, 0.32 - 0.04 * np.clip(world_z - 5.42, 0.0, 0.50), 0.16)
    horn_corridor = 1.0 - smoothstep(0.32, 0.42, np.abs(ax - horn_cx))
    horn_zone = (
        smoothstep(5.40, 5.48, world_z)
        * (1.0 - smoothstep(7.20, 7.28, world_z))
        * smoothstep(horn_inner_x, horn_inner_x + 0.04, ax)
        * horn_corridor
        * (1.0 if is_accessory else 0.0)
    )
    s_horn = t_horn * 8.0
    horn_frac = s_horn - np.floor(s_horn)
    horn_ring_groove = np.exp(-((horn_frac - 0.05) / 0.080) ** 2) * horn_zone
    horn_ring_bevel  = np.exp(-((horn_frac - 0.62) / 0.280) ** 2) * horn_zone
    seam_groove = np.maximum(seam_groove, 0.22 * horn_ring_groove)
    seam_pipe   = np.maximum(seam_pipe, 0.40 * horn_ring_bevel)
    armor_edge  = np.maximum(armor_edge, 0.36 * horn_ring_bevel)

    # 2. Crafted Overlapping Feather Plumes (Shoulders 3.58..5.18 & Wrists 2.42..3.08):
    sh_zone = (
        smoothstep(3.58, 3.72, world_z)
        * (1.0 - smoothstep(5.08, 5.20, world_z))
        * smoothstep(0.60, 0.72, ax)
        * (1.0 - smoothstep(1.80, 1.92, ax))
    )
    wr_zone = (
        smoothstep(2.42, 2.50, world_z)
        * (1.0 - smoothstep(3.00, 3.08, world_z))
        * smoothstep(1.32, 1.44, ax)
        * (1.0 - smoothstep(1.84, 1.94, ax))
    )
    f_zone = np.maximum(sh_zone, wr_zone) if is_accessory else np.zeros_like(world_x, dtype=np.float32)

    # Subtle diagonal feather-barb micro-relief along the sculpted 3D feather blades (no fish-scale waves!)
    feather_barbs = 0.032 * np.sin(ax * 62.0 - world_z * 48.0) * f_zone

    # 2b. Sleek Swept Hair Lock Grooves on DemonHair (4.62 <= Z <= 5.40, |X| <= 0.48):
    hair_zone = (
        smoothstep(4.62, 4.70, world_z)
        * (1.0 - smoothstep(5.36, 5.42, world_z))
        * (1.0 - smoothstep(0.44, 0.50, ax))
        * (1.0 if is_accessory else 0.0)
    )
    hair_strands = 0.045 * np.sin(world_x * 68.0 + (world_z - 5.05) * 14.0) * hair_zone

    # 3. 2-Lobe Gorget Collar & V-Corset Princess Seams (3.08 <= Z <= 4.66, |X| <= 0.64):
    u_lobe = np.clip((ax - 0.015) / 0.50, 0.0, 1.0)
    lobe_z = 4.36 - 0.28 * np.sin(u_lobe * math.pi) + 0.10 * (u_lobe ** 1.6)
    in_lobe_span = smoothstep(0.010, 0.028, ax) * (1.0 - smoothstep(0.49, 0.56, ax))
    # Deep under-lobe contact shadow + crisp rounded 2-lobe Peter-Pan leather rim:
    gorget_groove = (
        np.exp(-((world_z - (lobe_z - 0.008)) / 0.020) ** 2)
        + 0.45 * np.exp(-((world_z - (lobe_z - 0.026)) / 0.024) ** 2)
    ) * (1.0 - smoothstep(0.50, 0.58, ax))
    gorget_pipe = (
        np.exp(-((world_z - (lobe_z + 0.018)) / 0.013) ** 2)
        + 0.50 * np.exp(-((world_z - (lobe_z + 0.038)) / 0.012) ** 2)
    ) * in_lobe_span
    collar_split_g = np.exp(-(ax / 0.018) ** 2) * smoothstep(4.28, 4.35, world_z) * (1.0 - smoothstep(4.60, 4.66, world_z))
    collar_split_p = np.exp(-((ax - 0.026) / 0.011) ** 2) * smoothstep(4.32, 4.37, world_z) * (1.0 - smoothstep(4.60, 4.66, world_z))

    bodice_mask = (
        (1.0 if not is_accessory else 0.0)
        * smoothstep(3.08, 3.14, world_z)
        * (1.0 - smoothstep(lobe_z - 0.03, lobe_z + 0.01, world_z))
        * (1.0 - smoothstep(0.56, 0.64, ax))
    )
    u_bod = np.clip((world_z - 3.08) / 1.12, 0.0, 1.0)
    v_seam_x = 0.185 + 0.255 * (u_bod ** 1.35)
    princess_groove = np.exp(-((ax - v_seam_x) / 0.012) ** 2) * bodice_mask
    princess_pipe   = 0.62 * (
        np.exp(-((ax - (v_seam_x - 0.016)) / 0.011) ** 2)
        + 0.65 * np.exp(-((ax - (v_seam_x + 0.016)) / 0.011) ** 2)
    ) * bodice_mask
    # Side-rib panel seams strictly OUTSIDE the smooth V-corset center panel (matching reference image!)
    outside_corset = bodice_mask * smoothstep(v_seam_x + 0.012, v_seam_x + 0.026, ax)
    rib_z1 = 3.84 - 0.16 * (ax - 0.28)
    rib_z2 = 3.48 - 0.12 * (ax - 0.24)
    side_rib_g = (
        np.exp(-((world_z - rib_z1) / 0.011) ** 2)
        + np.exp(-((world_z - rib_z2) / 0.011) ** 2)
    ) * outside_corset
    side_rib_p = (
        np.exp(-((world_z - (rib_z1 + 0.015)) / 0.010) ** 2)
        + np.exp(-((world_z - (rib_z2 + 0.015)) / 0.010) ** 2)
    ) * outside_corset * 0.45
    waist_seam_g = np.exp(-((world_z - 3.10) / 0.013) ** 2) * (1.0 - smoothstep(0.50, 0.56, ax)) * (1.0 if not is_accessory else 0.0)
    waist_seam_p = np.exp(-((world_z - 3.118) / 0.011) ** 2) * (1.0 - smoothstep(0.50, 0.56, ax)) * (1.0 if not is_accessory else 0.0)

    seam_groove = np.maximum(seam_groove, np.clip(gorget_groove + collar_split_g + princess_groove + side_rib_g + waist_seam_g, 0.0, 1.0))
    seam_pipe   = np.maximum(seam_pipe, np.clip(gorget_pipe + collar_split_p + princess_pipe + side_rib_p + waist_seam_p, 0.0, 1.0))
    armor_edge  = np.maximum(armor_edge, np.clip(gorget_pipe + princess_pipe + waist_seam_p, 0.0, 1.0))

    # 4. Upper-Arm Sleeve Bands, Forearm Bracer & Glove Cuff Seams (Body only, strictly within arm bounds):
    if not is_accessory:
        in_arm = (
            smoothstep(0.82, 0.90, ax)
            * (1.0 - smoothstep(1.50, 1.58, ax))
            * smoothstep(2.35, 2.40, world_z)
            * (1.0 - smoothstep(3.92, 4.00, world_z))
        )
        for bz, p_str in ((3.80, 0.35), (3.44, 0.35), (3.10, 0.62), (2.52, 0.52)):
            g = np.exp(-((world_z - bz) / 0.012) ** 2) * in_arm
            p = np.exp(-((world_z - (bz + 0.015)) / 0.010) ** 2) * in_arm
            seam_groove = np.maximum(seam_groove, 0.78 * g)
            seam_pipe   = np.maximum(seam_pipe, p_str * p)
            armor_edge  = np.maximum(armor_edge, p_str * p)

    # 5. 4-Tiered Embossed Hip Tassets with Double-Border Recessed Plate Frames (1.76 <= Z <= 3.08):
    v_tasset_in = 0.05 + 0.15 * np.clip(3.04 - world_z, 0.0, 1.25)
    v_tasset_out = 0.64 + 0.16 * np.clip(3.04 - world_z, 0.0, 1.25)
    in_tasset = (
        smoothstep(1.76, 1.82, world_z)
        * (1.0 - smoothstep(3.02, 3.08, world_z))
        * (1.0 - smoothstep(v_tasset_out - 0.025, v_tasset_out + 0.025, ax))
        * smoothstep(v_tasset_in - 0.015, v_tasset_in + 0.015, ax)
    )
    for tz in (2.99, 2.66, 2.33, 2.00, 1.80):
        tg = np.exp(-((world_z - tz) / 0.012) ** 2) * in_tasset
        tp = (
            np.exp(-((world_z - (tz + 0.015)) / 0.010) ** 2)
            + 0.55 * np.exp(-((world_z - (tz - 0.015)) / 0.010) ** 2)
        ) * in_tasset
        seam_groove = np.maximum(seam_groove, 0.88 * tg)
        seam_pipe   = np.maximum(seam_pipe, 0.52 * tp)
        armor_edge  = np.maximum(armor_edge, 0.55 * tp)
    tasset_in_pipe  = (
        np.exp(-((ax - (v_tasset_in + 0.016)) / 0.010) ** 2)
        + 0.55 * np.exp(-((ax - (v_tasset_in + 0.034)) / 0.010) ** 2)
    ) * in_tasset
    tasset_out_pipe = (
        np.exp(-((ax - (v_tasset_out - 0.018)) / 0.010) ** 2)
        + 0.50 * np.exp(-((ax - (v_tasset_out - 0.036)) / 0.010) ** 2)
    ) * in_tasset
    tasset_in_grv  = np.exp(-((ax - v_tasset_in) / 0.012) ** 2) * smoothstep(1.78, 1.85, world_z) * (1.0 - smoothstep(3.00, 3.06, world_z))
    tasset_in_grv2 = np.exp(-((ax - (v_tasset_in + 0.025)) / 0.009) ** 2) * in_tasset
    seam_groove = np.maximum(seam_groove, np.maximum(0.88 * tasset_in_grv, 0.55 * tasset_in_grv2))
    seam_pipe   = np.maximum(seam_pipe, np.maximum(0.62 * tasset_in_pipe, 0.48 * tasset_out_pipe))
    armor_edge  = np.maximum(armor_edge, np.maximum(0.62 * tasset_in_pipe, 0.48 * tasset_out_pipe))

    # Subtle authentic fine leather grain strictly inside tasset plates (replaces 2D photo reflection wrinkles!)
    leather_grain = 0.035 * np.sin(world_x * 195.0 + np.sin(world_z * 145.0)) * np.cos(world_z * 215.0) * in_tasset

    # 6. Thighs & Cuffed Armor Boots (Z < 1.80, Body only, bounded to leg columns):
    if not is_accessory:
        in_legs = (
            (1.0 - smoothstep(1.75, 1.80, world_z))
            * smoothstep(0.16, 0.22, ax)
            * (1.0 - smoothstep(0.86, 0.94, ax))
        )
        for lz, p_str in ((1.24, 0.65), (0.98, 0.38), (0.36, 0.28)):
            lg = np.exp(-((world_z - lz) / 0.012) ** 2) * in_legs
            lp = np.exp(-((world_z - (lz + 0.015)) / 0.010) ** 2) * in_legs
            seam_groove = np.maximum(seam_groove, 0.80 * lg)
            seam_pipe   = np.maximum(seam_pipe, p_str * lp)
            armor_edge  = np.maximum(armor_edge, p_str * lp)
        shin_ridge = (
            np.exp(-((ax - 0.55) / 0.015) ** 2)
            * smoothstep(0.38, 0.44, world_z)
            * (1.0 - smoothstep(0.92, 0.98, world_z))
        )
        seam_pipe  = np.maximum(seam_pipe, 0.28 * shin_ridge)
        armor_edge = np.maximum(armor_edge, 0.36 * shin_ridge)

    # 7. Restrained Wear Mask: subtle micro-scuff pattern restricted strictly to armor_edge
    scuff_1 = np.sin(world_x * 137.0 + world_z * 89.0) * np.cos(world_x * 79.0 - world_z * 163.0)
    scuff_2 = np.sin(world_x * 293.0 - world_z * 211.0)
    wear_noise = smoothstep(0.25, 0.78, 0.60 * scuff_1 + 0.40 * scuff_2)
    wear_mask = np.clip(armor_edge * (0.20 + 0.46 * wear_noise), 0.0, 1.0)

    # 8. Combined Height Field [-1..1] for Tangent-Space Normal Map (_NRM)
    # CRITICAL: Keep 2D scan relief ONLY on horns & upper shoulder feathers so 2D photo specular reflections
    # never bake melted-plastic wrinkles onto the chest armor, hip tassets, sleeves, gloves, or boots!
    upper_feather_nrm_mask = np.clip(horn_zone + sh_zone * smoothstep(4.16, 4.26, world_z), 0.0, 1.0)
    relief_for_nrm = t_relief * upper_feather_nrm_mask
    height_map = (
        0.38 * relief_for_nrm
        + 0.44 * seam_pipe
        - 0.56 * seam_groove
        + feather_barbs
        + hair_strands
        + leather_grain
        - 0.08 * wear_mask
    )
    return seam_groove, seam_pipe, wear_mask, height_map


def height_to_normal_rgb(height_full: np.ndarray, strength: float = 3.2) -> np.ndarray:
    """Convert a 1024x1024 height map into a tangent-space normal map RGB [0..255]."""
    dy = np.roll(height_full, -1, axis=0) - np.roll(height_full, 1, axis=0)
    dx = np.roll(height_full, -1, axis=1) - np.roll(height_full, 1, axis=1)
    nx = -dx * strength
    ny = dy * strength
    nz = np.ones_like(height_full, dtype=np.float32)
    inv_len = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz)
    nx *= inv_len
    ny *= inv_len
    nz *= inv_len
    nrm = np.stack([(nx * 0.5 + 0.5) * 255.0, (ny * 0.5 + 0.5) * 255.0, (nz * 0.5 + 0.5) * 255.0], axis=-1)
    return np.clip(nrm, 0.0, 255.0)


def apply_black_and_purple_palette(
    rgb: np.ndarray,
    world_x: np.ndarray,
    world_z: np.ndarray,
    is_rear: bool = False,
    is_accessory: bool = False,
    trim_variant: str = "violet",
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Art-directed Dark-Fantasy Charcoal, Obsidian & Accent palette with:
    - Clear visual hierarchy guiding the eye to the pale purple face, white eyes, horns, and shoulder feathers
    - Crafted feather layers and intentional bold horn plate segments
    - Clear Team-Color / Accent trim zones across horn ridges, collar bevel, chest V-piping, outer feather blades,
      wrist cuffs, hip tasset borders, and boot cuffs so Red/Blue team identity reads cleanly at shooter distance.
    - Returns (albedo_rgb [0..255], roughness_01 [0..1], height_map)
    """
    luma_raw = rgb.mean(axis=-1)
    ax = np.abs(world_x)
    if is_accessory:
        in_face_oval = (world_z >= 4.65) & (world_z <= 5.52) & (ax <= 0.42)
        luma_raw = np.where(in_face_oval, np.minimum(luma_raw, 20.0), luma_raw)

    luma_mirror = np.fliplr(luma_raw)
    relief_luma = 0.75 * np.maximum(luma_raw, luma_mirror) + 0.25 * np.minimum(luma_raw, luma_mirror)
    smooth_luma = 0.50 * (luma_raw + luma_mirror)

    t_relief = np.clip((relief_luma - 14.0) / 52.0, 0.0, 1.0)
    t_smooth = np.clip((smooth_luma - 14.0) / 48.0, 0.0, 1.0)
    t_raw    = np.clip((luma_raw - 14.0) / 52.0, 0.0, 1.0)

    seam_groove, seam_pipe, wear_mask, height_map = compute_structural_seam_and_wear_maps(
        world_x, world_z, t_relief, t_smooth, is_accessory=is_accessory
    )

    # Material Swatches (0..255):
    # 1. Charcoal Armor & Matte Dark Cloth (deep grounded obsidian-charcoal matching reference image)
    charcoal_shadow = np.array([14.0, 13.0, 19.0], dtype=np.float32)
    charcoal_armor  = np.array([31.0, 29.0, 39.0], dtype=np.float32)
    charcoal_spec   = np.array([56.0, 52.0, 72.0], dtype=np.float32)

    # 2. High-Contrast Trim Swatch (Marketplace Violet default OR Team Shooter Red / Blue from src/shared/Palette.lua):
    if trim_variant == "red":
        accent_deep   = np.array([52.0, 14.0, 18.0], dtype=np.float32)
        accent_mid    = np.array([186.0, 48.0, 50.0], dtype=np.float32)
        accent_bright = np.array([232.0, 74.0, 74.0], dtype=np.float32)
    elif trim_variant == "blue":
        accent_deep   = np.array([16.0, 26.0, 56.0], dtype=np.float32)
        accent_mid    = np.array([54.0, 102.0, 192.0], dtype=np.float32)
        accent_bright = np.array([86.0, 146.0, 238.0], dtype=np.float32)
    else:
        accent_deep   = np.array([28.0, 17.0, 44.0], dtype=np.float32)
        accent_mid    = np.array([104.0, 52.0, 168.0], dtype=np.float32)
        accent_bright = np.array([176.0, 108.0, 246.0], dtype=np.float32)

    t_armor_clean = 0.24 + 0.22 * t_smooth
    # Mirror upper-shoulder feather relief onto lower plumage band so zero bicep straps appear:
    H_tex = t_relief.shape[0]
    row_idx = np.arange(H_tex, dtype=np.float32)[:, None]
    row_mirror = np.clip(np.where(world_z < 4.22, 433.0 - (row_idx - 433.0) * 0.75, row_idx).astype(np.int32), 0, H_tex - 1)
    t_feather_scan = t_relief[row_mirror, np.arange(t_relief.shape[1])[None, :]]

    t_sh_feather = 0.22 + 0.34 * t_feather_scan + 0.18 * smoothstep(0.95, 1.76, ax)
    t_wr_feather = 0.24 + 0.34 * smoothstep(1.36, 1.84, ax)
    is_sh_feather_acc = is_accessory & (world_z >= 3.58) & (world_z <= 5.20) & (ax >= 0.58)
    is_wr_feather_acc = is_accessory & (world_z >= 2.40) & (world_z <= 3.10) & (ax >= 0.92)
    t_det = np.where(
        world_z >= 5.40,
        0.22 + 0.62 * t_relief,
        np.where(is_sh_feather_acc, t_sh_feather, np.where(is_wr_feather_acc, t_wr_feather, t_armor_clean)),
    )
    in_hair_bangs = (world_z >= 4.62) & (world_z <= 5.42) & (ax <= 0.48)
    hair_lock_wave = 0.5 + 0.5 * np.sin(world_x * 68.0 + (world_z - 5.05) * 14.0)
    t_det = np.where(in_hair_bangs, 0.12 + 0.20 * t_raw + 0.10 * hair_lock_wave, t_det)

    t_crafted = np.clip(t_det * (1.0 - 0.50 * seam_groove) + 0.40 * seam_pipe, 0.0, 1.0)
    t_hi = np.clip((t_crafted - 0.34) / 0.66, 0.0, 1.0)

    base_charcoal = (
        charcoal_shadow * (1.0 - t_crafted)[..., None]
        + charcoal_armor * (t_crafted * (1.0 - t_hi))[..., None]
        + charcoal_spec * t_hi[..., None]
    )
    base_accent = (
        accent_deep * (1.0 - t_crafted)[..., None]
        + accent_mid * (t_crafted * (1.0 - t_hi))[..., None]
        + accent_bright * t_hi[..., None]
    )

    p_weight   = np.zeros_like(luma_raw, dtype=np.float32)
    cloth_dark = np.ones_like(luma_raw, dtype=np.float32)
    rgh_map    = np.full_like(luma_raw, 0.68, dtype=np.float32)

    # --- ZONE 1: HORNS (Aligned with 8 bold wide sculpted horn plates) ---
    t_horn = np.clip((world_z - 5.42) / 1.80, 0.0, 1.0)
    horn_cx = 0.435 + 0.505 * np.sin(t_horn * math.pi * 0.68) + 0.045 * t_horn * (1.0 - t_horn)
    horn_inner_x = np.where(world_z < 5.96, 0.32 - 0.04 * np.clip(world_z - 5.42, 0.0, 0.50), 0.16)
    horn_corridor = 1.0 - smoothstep(0.32, 0.42, np.abs(ax - horn_cx))
    horn_mask = (
        smoothstep(5.40, 5.48, world_z)
        * smoothstep(horn_inner_x, horn_inner_x + 0.04, ax)
        * horn_corridor
        * (1.0 if is_accessory else 0.0)
    )
    horn_height = smoothstep(5.48, 6.82, world_z)
    horn_cyl_hi = np.exp(-((ax - horn_cx) / 0.20) ** 2)
    team_boost_horn = 0.22 if trim_variant != "violet" else 0.0
    p_horn = horn_mask * (0.24 + 0.68 * horn_height + team_boost_horn) * (0.56 + 0.30 * horn_cyl_hi + 0.24 * seam_pipe) * (1.0 - 0.28 * seam_groove)
    p_weight = np.maximum(p_weight, p_horn)
    rgh_map = np.where(horn_mask > 0.2, 0.34 + 0.24 * seam_groove - 0.06 * horn_height, rgh_map)

    # --- ZONE 2: HAIR (4.60 <= Z <= 5.44, |X| <= 0.65) — Deep raven-obsidian locks with subtle sheen ---
    hair_zone = (
        smoothstep(4.60, 4.68, world_z)
        * (1.0 - smoothstep(5.38, 5.44, world_z))
        * (1.0 - smoothstep(0.58, 0.66, ax))
    )
    p_weight = np.maximum(p_weight, hair_zone * (0.06 + 0.14 * hair_lock_wave))
    cloth_dark = np.where(hair_zone > 0.2, cloth_dark * (1.0 - 0.22 * hair_zone), cloth_dark)
    rgh_map = np.where(hair_zone > 0.3, 0.35 - 0.06 * hair_lock_wave, rgh_map)

    # --- ZONE 3: 2-LOBE GORGET COLLAR (lobe_z <= Z <= 4.66, |X| <= 0.58) — High-readability team/accent focal frame ---
    u_lobe_z3 = np.clip((ax - 0.015) / 0.50, 0.0, 1.0)
    lobe_z3 = 4.36 - 0.28 * np.sin(u_lobe_z3 * math.pi) + 0.10 * (u_lobe_z3 ** 1.6)
    collar_zone = (
        smoothstep(lobe_z3 - 0.01, lobe_z3 + 0.02, world_z)
        * (1.0 - smoothstep(4.60, 4.67, world_z))
        * (1.0 - smoothstep(0.50, 0.57, ax))
        * smoothstep(0.016, 0.038, ax)
    )
    lobe_Highlight = np.exp(-(((world_z - (lobe_z3 + 0.08)) / 0.085) ** 2)) * np.sin(u_lobe_z3 * math.pi)
    team_boost = 0.24 if trim_variant != "violet" else 0.0
    p_weight = np.maximum(p_weight, collar_zone * (0.34 + team_boost + 0.26 * lobe_Highlight + 0.52 * seam_pipe))
    rgh_map = np.where(collar_zone > 0.2, 0.38 - 0.06 * lobe_Highlight, rgh_map)

    # --- ZONE 4: CRAFTED FEATHERED SHOULDER MANTLE (3.58 <= Z <= 5.18, |X| >= 0.58, Accessory only) ---
    if is_accessory:
        feather_zone = (
            smoothstep(3.58, 3.72, world_z)
            * (1.0 - smoothstep(5.08, 5.20, world_z))
            * smoothstep(0.58, 0.72, ax)
            * (1.0 - smoothstep(1.80, 1.92, ax))
        )
        feather_outer = smoothstep(0.98, 1.72, ax)
        feather_upper = smoothstep(4.15, 4.92, world_z)
        p_feather = (
            feather_zone
            * (0.16 + (0.64 if trim_variant != "violet" else 0.48) * feather_outer + 0.20 * feather_upper)
            * (0.52 + 0.32 * t_feather_scan + 0.28 * seam_pipe)
            * (1.0 - 0.38 * seam_groove)
        )
        p_weight = np.maximum(p_weight, p_feather)
        rgh_map = np.where(feather_zone > 0.2, 0.50 - 0.10 * seam_pipe, rgh_map)

    # --- ZONE 5: CHEST ARMOR & V-CORSET PRINCESS SEAMS (3.08 <= Z <= lobe_z3, |X| < 0.66) ---
    bodice_z = smoothstep(3.08, 3.15, world_z) * (1.0 - smoothstep(lobe_z3 - 0.02, lobe_z3 + 0.02, world_z)) * (1.0 - smoothstep(0.56, 0.65, ax))
    u_bod = np.clip((world_z - 3.08) / 1.12, 0.0, 1.0)
    v_width = 0.185 + 0.255 * (u_bod ** 1.35)
    center_panel = 1.0 - smoothstep(v_width - 0.020, v_width + 0.020, ax)
    chest_vert_grad = smoothstep(3.15, 4.10, world_z)
    center_emblem = bodice_z * np.exp(-(ax / 0.075) ** 2) * np.exp(-((world_z - 3.92) / 0.16) ** 2)
    p_chest = bodice_z * (
        center_panel * ((0.16 if trim_variant != "violet" else 0.09) + 0.18 * chest_vert_grad)
        + 0.54 * seam_pipe
        + 0.62 * center_emblem
    )
    p_weight = np.maximum(p_weight, np.clip(p_chest, 0.0, 1.0))
    side_cloth_mask = bodice_z * (1.0 - center_panel) * (1.0 - seam_pipe)
    cloth_dark = np.where(side_cloth_mask > 0.2, 1.0 - 0.20 * side_cloth_mask, cloth_dark)
    rgh_torso = np.where(center_panel > 0.5, 0.44, 0.76)
    rgh_map = np.where(bodice_z > 0.3, rgh_torso, rgh_map)

    # --- ZONE 6: SLEEVES, BRACERS, WRIST FEATHERS & CLAWED GLOVES (|X| >= 0.80) ---
    arm_mask = (
        smoothstep(0.80, 0.88, ax)
        * (1.0 - smoothstep(1.52, 1.62, ax))
        * smoothstep(2.05, 2.15, world_z)
        * (1.0 - smoothstep(3.92, 4.02, world_z))
    )
    p_arm = arm_mask * (0.06 + (0.72 if trim_variant != "violet" else 0.62) * seam_pipe)
    p_weight = np.maximum(p_weight, p_arm)
    is_bracer_or_glove = world_z < 3.12
    rgh_arm = np.where(is_bracer_or_glove, 0.44, 0.72)
    rgh_map = np.where(arm_mask > 0.3, rgh_arm, rgh_map)
    cloth_dark = np.where(world_z >= 3.12, cloth_dark * (1.0 - 0.14 * arm_mask), cloth_dark)

    if is_accessory:
        wrist_feather_zone = (
            smoothstep(2.42, 2.50, world_z)
            * (1.0 - smoothstep(3.00, 3.10, world_z))
            * smoothstep(1.32, 1.44, ax)
            * (1.0 - smoothstep(1.84, 1.94, ax))
        )
        p_weight = np.maximum(
            p_weight,
            wrist_feather_zone * ((0.24 if trim_variant != "violet" else 0.14) + 0.62 * smoothstep(1.38, 1.82, ax) + 0.20 * seam_pipe),
        )

    claw_tips = (1.0 - smoothstep(2.05, 2.18, world_z)) * smoothstep(0.95, 1.10, ax) * (1.0 - smoothstep(1.52, 1.62, ax))
    p_weight = np.maximum(p_weight, claw_tips * (0.68 if trim_variant != "violet" else 0.52))

    # --- ZONE 7: 4-TIERED EMBOSSED HIP TASSETS (1.76 <= Z <= 3.08) ---
    v_tasset_inner = 0.05 + 0.15 * np.clip(3.04 - world_z, 0.0, 1.25)
    v_tasset_outer = 0.64 + 0.16 * np.clip(3.04 - world_z, 0.0, 1.25)
    tasset_zone = (
        smoothstep(1.76, 1.84, world_z)
        * (1.0 - smoothstep(3.00, 3.08, world_z))
        * (1.0 - smoothstep(v_tasset_outer - 0.02, v_tasset_outer + 0.03, ax))
        * smoothstep(v_tasset_inner - 0.02, v_tasset_inner + 0.03, ax)
    )
    belt_buckle = smoothstep(2.86, 2.92, world_z) * (1.0 - smoothstep(3.04, 3.09, world_z)) * (1.0 - smoothstep(0.18, 0.28, ax))
    p_tasset = tasset_zone * (1.0 - 0.72 * seam_groove) * (0.08 + (0.76 if trim_variant != "violet" else 0.64) * seam_pipe)
    p_weight = np.maximum(p_weight, np.maximum(p_tasset, belt_buckle * 0.75))
    rgh_map = np.where(tasset_zone > 0.3, 0.44, 0.80)

    # --- ZONE 8: THIGHS & CUFFED ARMOR BOOTS (Z < 1.80) ---
    in_leg_col = smoothstep(0.16, 0.22, ax) * (1.0 - smoothstep(0.86, 0.94, ax))
    thigh_zone = smoothstep(1.26, 1.32, world_z) * (1.0 - smoothstep(1.74, 1.80, world_z)) * in_leg_col
    boot_cuff  = smoothstep(0.98, 1.04, world_z) * (1.0 - smoothstep(1.22, 1.27, world_z)) * in_leg_col
    lower_boot = (1.0 - smoothstep(0.96, 1.02, world_z)) * in_leg_col
    p_weight = np.maximum(p_weight, thigh_zone * 0.04)
    p_weight = np.maximum(p_weight, boot_cuff * ((0.30 if trim_variant != "violet" else 0.18) + 0.62 * seam_pipe))
    p_weight = np.maximum(p_weight, lower_boot * (0.04 + (0.50 if trim_variant != "violet" else 0.36) * seam_pipe))
    cloth_dark = np.where(thigh_zone > 0.3, cloth_dark * (1.0 - 0.16 * thigh_zone), cloth_dark)
    rgh_map = np.where(thigh_zone > 0.3, 0.76, rgh_map)
    rgh_map = np.where((boot_cuff + lower_boot) > 0.3, 0.44 - 0.06 * seam_pipe, rgh_map)

    p_weight = np.clip(p_weight, 0.0, 1.0)
    out = (base_charcoal * (1.0 - p_weight[..., None]) + base_accent * p_weight[..., None]) * cloth_dark[..., None]

    # Apply recessed armor seam darkening & restrained metallic-slate edge wear:
    out = out * (1.0 - 0.58 * seam_groove[..., None])
    wear_color = np.array([72.0, 62.0, 92.0], dtype=np.float32) if trim_variant == "violet" else accent_bright * 0.55
    out = out * (1.0 - 0.22 * wear_mask[..., None]) + wear_color * (0.22 * wear_mask[..., None])
    rgh_map = np.clip(rgh_map + 0.18 * seam_groove + 0.08 * wear_mask, 0.18, 0.92)

    return np.clip(out, 0.0, 255.0), np.clip(rgh_map, 0.12, 0.92), height_map


def bake_high_dpi_head_region(
    front_body: np.ndarray,
    front_body_rgh: np.ndarray,
    front_body_h: np.ndarray,
    back_body: np.ndarray,
    back_body_rgh: np.ndarray,
    back_body_h: np.ndarray,
):
    """Render a vector-sharp 492x338 High-DPI face into rows 0..355 of DarkFantasyDemonBody_*
    (UV Y in [0.653, 1.000], completely above UpperTorso z <= 4.68), giving 22x higher texel
    density for the tilted almond white eyes, winged cat-eye liner, steeply arched fierce eyebrows,
    crisp individual cheek freckles, delicate nose shading, and two-peak Cupid's-bow lips.
    """
    H_band = 356
    W_half = front_body.shape[1]
    rows = np.arange(H_band, dtype=np.float32)[:, None]
    cols = np.arange(W_half, dtype=np.float32)[None, :]

    uv_x = (cols + 0.5) / 1024.0
    uv_y = (1023.0 - rows + 0.5) / 1024.0

    u_h = (uv_x - HEAD_U_MIN) / (HEAD_U_MAX - HEAD_U_MIN)
    v_h = (uv_y - HEAD_V_MIN) / (HEAD_V_MAX - HEAD_V_MIN)
    hx = HEAD_X_MIN + u_h * (HEAD_X_MAX - HEAD_X_MIN)
    hz = HEAD_Z_MIN + v_h * (HEAD_Z_MAX - HEAD_Z_MIN)
    ax = np.abs(hx)

    # 1. Base Pale Lavender-Purple Demon Skin Complexion & Soft 3D Anatomical Contours:
    jaw_shade = smoothstep(0.34, 0.48, ax) + 0.45 * (1.0 - smoothstep(4.56, 4.72, hz))
    forehead_shade = smoothstep(5.44, 5.58, hz) * 0.35
    base_luma = 76.5 - 5.5 * np.clip(jaw_shade + forehead_shade, 0.0, 1.2)

    nose_bridge = np.exp(-(hx / 0.024) ** 2) * smoothstep(5.00, 5.05, hz) * (1.0 - smoothstep(5.19, 5.25, hz))
    nose_tip    = np.exp(-(hx / 0.028) ** 2) * np.exp(-((hz - 5.005) / 0.024) ** 2)
    nose_sides  = np.exp(-((ax - 0.038) / 0.017) ** 2) * smoothstep(4.99, 5.04, hz) * (1.0 - smoothstep(5.16, 5.20, hz))
    nose_under  = np.exp(-(hx / 0.045) ** 2) * np.exp(-((hz - 4.972) / 0.015) ** 2)
    # Two delicate nostril crescents at (|hx| = 0.024, hz = 4.976) — strictly edge0 < edge1!
    nostril_dx  = (ax - 0.024) * 0.94 + (hz - 4.976) * 0.34
    nostril_dz  = -(ax - 0.024) * 0.34 + (hz - 4.976) * 0.94
    nostrils    = 1.0 - smoothstep(0.4, 1.2, (nostril_dx / 0.0090) ** 2 + (nostril_dz / 0.0045) ** 2)
    philtrum    = np.exp(-(hx / 0.018) ** 2) * smoothstep(4.87, 4.90, hz) * (1.0 - smoothstep(4.95, 4.97, hz))

    cheek_hi    = np.exp(-((ax - 0.215) / 0.075) ** 2) * np.exp(-((hz - 5.095) / 0.056) ** 2)
    cheek_shd   = np.exp(-((ax - 0.285) / 0.080) ** 2) * np.exp(-((hz - 4.885) / 0.070) ** 2)
    chin_hi     = np.exp(-(hx / 0.072) ** 2) * np.exp(-((hz - 4.690) / 0.036) ** 2)
    chin_crease = np.exp(-(hx / 0.062) ** 2) * np.exp(-((hz - 4.742) / 0.015) ** 2)

    z_eye_mid = 5.182 + 0.165 * (ax - 0.078)
    u_eye_all = np.clip((ax - 0.075) / 0.205, 0.0, 1.0)
    z_crease = z_eye_mid + 0.048 * np.sin(u_eye_all * math.pi * 0.92)
    lid_crease = (
        np.exp(-((hz - z_crease) / 0.0080) ** 2)
        * smoothstep(0.078, 0.102, ax)
        * (1.0 - smoothstep(0.270, 0.300, ax))
    )
    brow_bone_hi = (
        np.exp(-((hz - (z_crease + 0.024)) / 0.013) ** 2)
        * smoothstep(0.080, 0.110, ax)
        * (1.0 - smoothstep(0.275, 0.310, ax))
    )

    sculpted_luma = (
        base_luma
        + 6.5 * nose_bridge
        + 5.5 * nose_tip
        + 5.5 * cheek_hi
        + 4.5 * brow_bone_hi
        + 3.5 * chin_hi
        - 4.0 * nose_sides
        - 7.5 * nose_under
        - 15.0 * nostrils
        - 3.0 * philtrum
        - 5.5 * cheek_shd
        - 4.5 * chin_crease
        - 8.5 * lid_crease
    )

    face_rgb = np.zeros((H_band, W_half, 3), dtype=np.float32)
    face_rgb[..., 0] = sculpted_luma * 1.62 + 38.0
    face_rgb[..., 1] = sculpted_luma * 1.44 + 34.0
    face_rgb[..., 2] = sculpted_luma * 1.92 + 46.0

    # 2. Crisp Cheek Freckle Constellation (12 asymmetric micro-dots per cheek, kit-matched span |x|=0.145..0.305):
    freckle_pts = [
        (-0.152, 5.106, 0.0052), (-0.180, 5.122, 0.0048), (-0.212, 5.095, 0.0058), (-0.244, 5.115, 0.0050),
        (-0.276, 5.128, 0.0045), (-0.172, 5.072, 0.0050), (-0.204, 5.056, 0.0054), (-0.238, 5.076, 0.0048),
        (-0.268, 5.092, 0.0052), (-0.296, 5.110, 0.0044), (-0.224, 5.038, 0.0046), (-0.260, 5.058, 0.0048),
        ( 0.150, 5.104, 0.0052), ( 0.178, 5.120, 0.0048), ( 0.210, 5.094, 0.0058), ( 0.242, 5.114, 0.0050),
        ( 0.274, 5.126, 0.0045), ( 0.170, 5.070, 0.0050), ( 0.202, 5.055, 0.0054), ( 0.236, 5.075, 0.0048),
        ( 0.266, 5.090, 0.0052), ( 0.294, 5.108, 0.0044), ( 0.222, 5.036, 0.0046), ( 0.258, 5.056, 0.0048),
    ]
    freckle_mask = np.zeros_like(hx, dtype=np.float32)
    for fx, fz, fr in freckle_pts:
        d_f = np.sqrt((hx - fx) ** 2 + (hz - fz) ** 2)
        freckle_mask = np.maximum(freckle_mask, 1.0 - smoothstep(max(fr - 0.0015, 0.0005), fr + 0.0015, d_f))
    freckle_col = np.array([38.0, 30.0, 52.0], dtype=np.float32)
    face_rgb = face_rgb * (1.0 - 0.80 * freckle_mask[..., None]) + freckle_col * (0.80 * freckle_mask[..., None])

    # 3. Steeply Arched, Fierce Dark Eyebrows + Beauty Mark (kit-matched span |x|=0.075..0.348, peak z=5.415):
    u_b = np.clip((ax - 0.074) / (0.346 - 0.074), 0.0, 1.0)
    z_brow = 5.324 + 0.082 * np.sin(u_b * math.pi * 0.82) + 0.012 * np.sin(u_b * 2.0 * math.pi - 0.85)
    w_brow = (
        0.0108
        * (1.0 - 0.58 * (u_b ** 1.35))
        * smoothstep(0.072, 0.086, ax)
        * (1.0 - smoothstep(0.330, 0.348, ax))
    )
    brow_mask = (1.0 - smoothstep(np.maximum(w_brow - 0.0016, 0.0), w_brow + 0.0016, np.abs(hz - z_brow))) * (w_brow > 0.0008)
    bmark_d = np.sqrt((ax - 0.222) ** 2 + (hz - 5.356) ** 2)
    bmark_mask = 1.0 - smoothstep(0.0038, 0.0066, bmark_d)
    brow_and_mark = np.clip(np.maximum(brow_mask, 0.90 * bmark_mask), 0.0, 1.0)

    # 4. Fierce Tilted Almond White Eyes + Heavy Jet-Black Winged Cat-Eye Liner (kit-matched |x|=0.068..0.278, wing to 0.352):
    u_eye = np.clip((ax - 0.068) / (0.276 - 0.068), 0.0, 1.0)
    sin_eye = np.maximum(np.sin(u_eye * math.pi), 0.0)
    z_eye_top = z_eye_mid + 0.044 * (sin_eye ** 0.80) * (1.0 - 0.08 * u_eye)
    z_eye_bot = z_eye_mid - 0.035 * (sin_eye ** 0.85) * (1.0 - 0.12 * (1.0 - u_eye))

    in_eye_span = smoothstep(0.067, 0.075, ax) * (1.0 - smoothstep(0.268, 0.277, ax))
    d_sclera = np.minimum(hz - z_eye_bot, z_eye_top - hz)
    eye_white_mask = smoothstep(-0.0012, 0.0018, d_sclera) * in_eye_span

    # Outer liner boundary (heavy upper winged lid + crisp lower lash line + sharp cat-eye wing flick to |x|=0.352, z=5.276):
    u_liner = np.clip((ax - 0.056) / (0.286 - 0.056), 0.0, 1.0)
    sin_liner = np.maximum(np.sin(u_liner * math.pi), 0.0)
    z_liner_top = z_eye_top + (0.014 + 0.011 * u_liner) * (sin_liner ** 0.50)
    z_liner_bot = z_eye_bot - (0.0080 + 0.0028 * u_liner) * (sin_liner ** 0.65)
    in_liner_span = smoothstep(0.055, 0.062, ax) * (1.0 - smoothstep(0.279, 0.288, ax))
    d_liner_body = np.minimum(hz - z_liner_bot, z_liner_top - hz)
    liner_body_mask = smoothstep(-0.0014, 0.0016, d_liner_body) * in_liner_span

    # Sharp outer winged cat-eye flick from (0.256, 5.218) to needle tip at (0.352, 5.276)
    u_wing = np.clip((ax - 0.256) / (0.352 - 0.256), 0.0, 1.0)
    z_wing_top = 5.236 + 0.040 * (u_wing ** 0.88)
    z_wing_bot = 5.206 + 0.070 * (u_wing ** 1.15)
    in_wing_span = smoothstep(0.254, 0.262, ax) * (1.0 - smoothstep(0.344, 0.353, ax))
    d_wing = np.minimum(hz - z_wing_bot, z_wing_top - hz)
    wing_mask = smoothstep(-0.0014, 0.0015, d_wing) * in_wing_span

    # Inner tear-duct beak point at (0.052..0.076) — strictly edge0 < edge1!
    u_tear = np.clip((0.076 - ax) / 0.024, 0.0, 1.0)
    z_tear_mid = 5.182 - 0.007 * u_tear
    w_tear = 0.0068 * (1.0 - 0.75 * u_tear) * smoothstep(0.052, 0.058, ax) * (1.0 - smoothstep(0.072, 0.078, ax))
    tear_mask = (1.0 - smoothstep(np.maximum(w_tear - 0.0012, 0.0), w_tear + 0.0012, np.abs(hz - z_tear_mid))) * (w_tear > 0.0005)

    full_eye_liner = np.clip(np.maximum(liner_body_mask, np.maximum(wing_mask, tear_mask)), 0.0, 1.0)
    dark_liner_and_brow = np.clip(np.maximum(full_eye_liner, brow_and_mark), 0.0, 1.0)
    liner_col = np.array([8.0, 6.0, 12.0], dtype=np.float32)
    face_rgb = face_rgb * (1.0 - dark_liner_and_brow[..., None]) + liner_col * dark_liner_and_brow[..., None]

    # Blend pure luminous white sclera inside the black eyeliner rim (with subtle upper-lid overhang shading):
    upper_lid_ao = smoothstep(z_eye_top - 0.006, z_eye_top, hz)
    sclera_rgb = (
        np.array([254.0, 253.0, 255.0], dtype=np.float32) * (1.0 - 0.14 * upper_lid_ao[..., None])
        + np.array([198.0, 185.0, 224.0], dtype=np.float32) * (0.14 * upper_lid_ao[..., None])
    )
    face_rgb = face_rgb * (1.0 - eye_white_mask[..., None]) + sclera_rgb * eye_white_mask[..., None]

    # 5. Full, Bold Two-Peak Cupid's-Bow Lips (kit-matched |hx| <= 0.174, hz in [4.756, 4.862], cz = 4.810):
    u_m = np.clip(ax / 0.174, 0.0, 1.0)
    z_part = 4.812 - 0.005 * np.sin(u_m * math.pi) + 0.006 * (u_m ** 2)
    arch_env = 1.0 - (u_m ** 1.65)
    cupid_notch = 0.024 * np.exp(-((ax / 0.025) ** 2))
    cupid_peak  = 0.015 * np.exp(-(((ax - 0.052) / 0.032) ** 2))
    z_lip_top = z_part + 0.046 * arch_env - cupid_notch + cupid_peak * (1.0 - u_m)
    z_lip_bot = z_part - 0.052 * (np.maximum(1.0 - (u_m ** 1.85), 0.0) ** 0.90)

    in_lip_span = 1.0 - smoothstep(0.168, 0.176, ax)
    d_lip = np.minimum(hz - z_lip_bot, z_lip_top - hz)
    lip_mask = smoothstep(-0.0014, 0.0016, d_lip) * in_lip_span

    is_upper_lip = smoothstep(z_part - 0.002, z_part + 0.002, hz)
    part_line = np.exp(-((hz - z_part) / 0.0042) ** 2) * (1.0 - smoothstep(0.145, 0.168, ax))
    lower_lip_spec = np.exp(-((hz - 4.782) / 0.012) ** 2) * np.exp(-(hx / 0.064) ** 2)
    cupid_rim_hi = np.exp(-((hz - (z_lip_top + 0.002)) / 0.003) ** 2) * (1.0 - smoothstep(0.080, 0.115, ax))

    face_rgb = face_rgb + np.array([14.0, 12.0, 18.0], dtype=np.float32) * (cupid_rim_hi * (1.0 - lip_mask))[..., None]
    lip_col = (
        np.array([15.0, 10.0, 22.0], dtype=np.float32) * is_upper_lip[..., None]
        + np.array([24.0, 15.0, 35.0], dtype=np.float32) * (1.0 - is_upper_lip[..., None])
    )
    lip_col = lip_col * (1.0 - 0.65 * part_line[..., None]) + np.array([76.0, 48.0, 104.0], dtype=np.float32) * (0.48 * lower_lip_spec[..., None])
    face_rgb = face_rgb * (1.0 - lip_mask[..., None]) + lip_col * lip_mask[..., None]

    # Roughness & Height for the High-DPI Face Band:
    face_rgh = (
        0.54
        - 0.42 * eye_white_mask
        - 0.28 * lip_mask
        - 0.12 * dark_liner_and_brow
    )
    face_h = (
        0.08 * nose_bridge
        + 0.10 * nose_tip
        - 0.08 * nostrils
        + 0.06 * cheek_hi
        - 0.08 * lid_crease
        + 0.12 * lip_mask * (1.0 - 0.6 * part_line)
    )

    front_body[:H_band, :, :] = np.clip(np.nan_to_num(face_rgb, nan=150.0), 0.0, 255.0)
    front_body_rgh[:H_band, :] = np.clip(np.nan_to_num(face_rgh, nan=0.54), 0.10, 0.90)
    front_body_h[:H_band, :] = np.nan_to_num(face_h, nan=0.0)

    # Rear Head region (rows 0..355 of back_body): deep obsidian skull/neck + dedicated Dynamic-Head UV swatches:
    # rows 0..48 (v in [0.953, 1.000]):
    #   cols  0.. 48 (u in [0.500, 0.547]): Luminous 3D Eyeball Sclera White
    #   cols 48.. 96 (u in [0.547, 0.594]): Cool Ivory Upper/Lower 3D Teeth
    #   cols 96..144 (u in [0.594, 0.641]): Muted Plum-Rose 3D Tongue
    back_body[:H_band, :, :] = np.array([20.0, 18.0, 26.0], dtype=np.float32)
    back_body_rgh[:H_band, :] = 0.65
    back_body_h[:H_band, :] = 0.0

    back_body[:48, :48, :] = np.array([254.0, 253.0, 255.0], dtype=np.float32)
    back_body_rgh[:48, :48] = 0.12
    back_body[:48, 48:96, :] = np.array([238.0, 236.0, 244.0], dtype=np.float32)
    back_body_rgh[:48, 48:96] = 0.18
    back_body[:48, 96:144, :] = np.array([138.0, 72.0, 108.0], dtype=np.float32)
    back_body_rgh[:48, 96:144] = 0.42


def build_textures(scan_obj):
    """Build 1024x1024 Albedo (_ALB), Roughness (_RGH), and Normal (_NRM) maps for Body and Accessories."""
    ref_bl_img = bpy.data.images.load(str(REF_PNG), check_existing=True)
    W_ref, H_ref = ref_bl_img.size
    raw_px = np.array(ref_bl_img.pixels[:], dtype=np.float32).reshape((H_ref, W_ref, 4))
    ref_arr = np.flipud(raw_px[:, :, :3]) * 255.0

    H_out, W_half = 1024, 512
    vs = np.linspace(1.0, 0.0, H_out, dtype=np.float32)
    us = np.linspace(0.0, 1.0, W_half, dtype=np.float32)
    uu, vv = np.meshgrid(us, vs)

    world_x = ATLAS_X_MIN + uu * (ATLAS_X_MAX - ATLAS_X_MIN)
    world_z = ATLAS_Z_MIN + vv * (ATLAS_Z_MAX - ATLAS_Z_MIN)

    px = 342.0 + (world_x / 2.237) * 266.0
    py = np.interp(
        world_z,
        [-0.10, 0.00, 1.80, 3.08, 4.69, 4.91, 5.23, 5.40, 5.95, 7.2616, 7.40],
        [990.0, 976.0, 735.0, 572.0, 383.0, 363.0, 312.0, 274.0, 215.0, 48.0, 30.0],
    ).astype(np.float32)

    x0 = np.clip(np.floor(px).astype(np.int32), 0, W_ref - 1)
    x1 = np.clip(x0 + 1, 0, W_ref - 1)
    y0 = np.clip(np.floor(py).astype(np.int32), 0, H_ref - 1)
    y1 = np.clip(y0 + 1, 0, H_ref - 1)
    wx = (px - x0)[..., None]
    wy = (py - y0)[..., None]

    front_rgb = (
        ref_arr[y0, x0] * (1 - wx) * (1 - wy)
        + ref_arr[y0, x1] * wx * (1 - wy)
        + ref_arr[y1, x0] * (1 - wx) * wy
        + ref_arr[y1, x1] * wx * wy
    )
    luma = front_rgb.mean(axis=-1)

    in_face_center = (np.abs(world_x) < 0.43) & (world_z >= 4.70) & (world_z <= 5.44)
    in_bounds = (px >= 79) & (px <= 613) & (py >= 47) & (py <= 977)
    fg_raw = in_bounds & ((luma < 54.0) | in_face_center)
    fg_clean = erode_mask(fg_raw, radius=5) | in_face_center
    fg_inner = erode_mask(fg_clean, radius=4) | in_face_center
    clamped_rgb = front_rgb.copy()
    clamped_rgb[~in_face_center] = np.minimum(clamped_rgb[~in_face_center], 48.0)
    rim_band = fg_clean & (~fg_inner) & (~in_face_center)
    clamped_rgb[rim_band] = np.minimum(clamped_rgb[rim_band], 22.0)

    front_neutral = dilate_fill(clamped_rgb, fg_clean, iterations=120)
    front_body, front_body_rgh, front_body_h = apply_black_and_purple_palette(
        front_neutral, world_x, world_z, is_rear=False, is_accessory=False
    )
    front_acc, front_acc_rgh, front_acc_h = apply_black_and_purple_palette(
        front_neutral, world_x, world_z, is_rear=False, is_accessory=True
    )

    bm_scan = bmesh.new()
    bm_scan.from_mesh(scan_obj.data)
    bmesh.ops.triangulate(bm_scan, faces=bm_scan.faces)
    bm_scan.faces.ensure_lookup_table()
    bvh = BVHTree.FromBMesh(bm_scan)

    H_sub, W_sub = 512, 256
    sub_shade = np.ones((H_sub, W_sub), dtype=np.float32)
    for iy in range(H_sub):
        wz = ATLAS_Z_MAX - (iy / (H_sub - 1)) * (ATLAS_Z_MAX - ATLAS_Z_MIN)
        for ix in range(W_sub):
            wx_val = ATLAS_X_MIN + (ix / (W_sub - 1)) * (ATLAS_X_MAX - ATLAS_X_MIN)
            loc, norm, f_idx, _ = bvh.ray_cast(Vector((wx_val, 3.0, wz)), Vector((0.0, -1.0, 0.0)), 6.0)
            if loc is not None and norm is not None:
                ny_lit = max(0.0, norm.y)
                nz_lit = max(0.0, norm.z * 0.5 + 0.5)
                sub_shade[iy, ix] = 0.92 + 0.06 * ny_lit + 0.03 * nz_lit

    bm_scan.free()
    rear_shade = np.repeat(np.repeat(sub_shade, 2, axis=0), 2, axis=1)[..., None]

    back_neutral = front_neutral.copy()
    in_rear_head = (np.abs(world_x) < 0.52) & (world_z >= 4.65) & (world_z <= 5.55)
    back_neutral[in_rear_head] = np.array([22.0, 22.0, 26.0], dtype=np.float32)

    back_body_raw, back_body_rgh, back_body_h = apply_black_and_purple_palette(
        back_neutral, world_x, world_z, is_rear=True, is_accessory=False
    )
    back_acc_raw, back_acc_rgh, back_acc_h = apply_black_and_purple_palette(
        back_neutral, world_x, world_z, is_rear=True, is_accessory=True
    )
    back_body = np.clip(back_body_raw * rear_shade, 8.0, 245.0)
    back_acc  = np.clip(back_acc_raw * rear_shade, 8.0, 245.0)

    # Bake High-DPI 492x338 Head UV island into the top band of DarkFantasyDemonBody_*
    bake_high_dpi_head_region(
        front_body, front_body_rgh, front_body_h,
        back_body, back_body_rgh, back_body_h,
    )

    body_alb = np.concatenate([front_body, back_body], axis=1)
    acc_alb  = np.concatenate([front_acc, back_acc], axis=1)

    body_rgh_01 = np.concatenate([front_body_rgh, back_body_rgh], axis=1)
    acc_rgh_01  = np.concatenate([front_acc_rgh, back_acc_rgh], axis=1)
    body_rgh = np.stack([body_rgh_01 * 255.0] * 3, axis=-1)
    acc_rgh  = np.stack([acc_rgh_01 * 255.0] * 3, axis=-1)

    body_nrm = height_to_normal_rgb(np.concatenate([front_body_h, back_body_h], axis=1), strength=2.6)
    acc_nrm  = height_to_normal_rgb(np.concatenate([front_acc_h, back_acc_h], axis=1), strength=2.8)

    def save_png(arr_255: np.ndarray, out_path: Path):
        H, W, _ = arr_255.shape
        existing = bpy.data.images.get(out_path.stem)
        if existing is not None:
            bpy.data.images.remove(existing)
        img = bpy.data.images.new(out_path.stem, width=W, height=H, alpha=False)
        flipped = np.flipud(np.clip(arr_255, 0.0, 255.0) / 255.0)
        rgba = np.ones((H, W, 4), dtype=np.float32)
        rgba[:, :, :3] = flipped
        img.pixels.foreach_set(rgba.ravel())
        img.filepath_raw = str(out_path)
        img.file_format = "PNG"
        img.save()
        return img

    b_alb_img = save_png(body_alb, TEX_DIR / "DarkFantasyDemonBody_ALB.png")
    b_rgh_img = save_png(body_rgh, TEX_DIR / "DarkFantasyDemonBody_RGH.png")
    b_rgh_img.colorspace_settings.name = "Non-Color"
    b_nrm_img = save_png(body_nrm, TEX_DIR / "DarkFantasyDemonBody_NRM.png")
    b_nrm_img.colorspace_settings.name = "Non-Color"

    a_alb_img = save_png(acc_alb, TEX_DIR / "DarkFantasyDemonAcc_ALB.png")
    a_rgh_img = save_png(acc_rgh, TEX_DIR / "DarkFantasyDemonAcc_RGH.png")
    a_rgh_img.colorspace_settings.name = "Non-Color"
    a_nrm_img = save_png(acc_nrm, TEX_DIR / "DarkFantasyDemonAcc_NRM.png")
    a_nrm_img.colorspace_settings.name = "Non-Color"

    # Team-shooter Red & Blue albedo maps sharing identical layout/normal/roughness so Red vs Blue identity reads clearly:
    for tv, tsuf in (("red", "TeamRed"), ("blue", "TeamBlue")):
        fb_t, _, _ = apply_black_and_purple_palette(front_neutral, world_x, world_z, is_rear=False, is_accessory=False, trim_variant=tv)
        fa_t, _, _ = apply_black_and_purple_palette(front_neutral, world_x, world_z, is_rear=False, is_accessory=True, trim_variant=tv)
        bb_t_raw, _, _ = apply_black_and_purple_palette(back_neutral, world_x, world_z, is_rear=True, is_accessory=False, trim_variant=tv)
        ba_t_raw, _, _ = apply_black_and_purple_palette(back_neutral, world_x, world_z, is_rear=True, is_accessory=True, trim_variant=tv)
        bb_t = np.clip(bb_t_raw * rear_shade, 8.0, 245.0)
        ba_t = np.clip(ba_t_raw * rear_shade, 8.0, 245.0)
        bake_high_dpi_head_region(fb_t, front_body_rgh.copy(), front_body_h.copy(), bb_t, back_body_rgh.copy(), back_body_h.copy())
        save_png(np.concatenate([fb_t, bb_t], axis=1), TEX_DIR / f"DarkFantasyDemonBody_{tsuf}_ALB.png")
        save_png(np.concatenate([fa_t, ba_t], axis=1), TEX_DIR / f"DarkFantasyDemonAcc_{tsuf}_ALB.png")

    return (b_alb_img, b_rgh_img, b_nrm_img), (a_alb_img, a_rgh_img, a_nrm_img)


def make_pbr_material(name: str, alb_img, rgh_img, nrm_img=None):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    nt.nodes.clear()
    out_node = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Specular IOR Level"].default_value = 0.35
    nt.links.new(out_node.inputs["Surface"], bsdf.outputs["BSDF"])

    tex_alb = nt.nodes.new("ShaderNodeTexImage")
    tex_alb.image = alb_img
    nt.links.new(bsdf.inputs["Base Color"], tex_alb.outputs["Color"])

    tex_rgh = nt.nodes.new("ShaderNodeTexImage")
    tex_rgh.image = rgh_img
    nt.links.new(bsdf.inputs["Roughness"], tex_rgh.outputs["Color"])

    if nrm_img is not None:
        tex_nrm = nt.nodes.new("ShaderNodeTexImage")
        tex_nrm.image = nrm_img
        nrm_node = nt.nodes.new("ShaderNodeNormalMap")
        nrm_node.inputs["Strength"].default_value = 0.72
        nt.links.new(nrm_node.inputs["Color"], tex_nrm.outputs["Color"])
        nt.links.new(bsdf.inputs["Normal"], nrm_node.outputs["Normal"])
    return mat


def assign_front_back_uvs(obj):
    """Map front-facing triangles (normal.y <= 0.12) to the Front half of the atlas (U in [0.01, 0.49])
    and rear-facing triangles (normal.y > 0.12) to the Back half of the atlas (U in [0.51, 0.99]).
    For Head, map to the dedicated 492x338 High-DPI Head UV island (V in [0.665, 0.995]).
    """
    me = obj.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uv_layer = me.uv_layers.active.data
    is_head = obj.name == "Head"
    is_hair = obj.name == "DemonHair"
    head_reg_attr = me.attributes.get("head_region_id") if is_head else None
    for p_idx, poly in enumerate(me.polygons):
        reg_id = head_reg_attr.data[p_idx].value if (head_reg_attr is not None and head_reg_attr.domain == "FACE") else 0
        if is_head and reg_id in (1, 2, 3):
            u_c = {1: 0.522, 2: 0.570, 3: 0.616}[reg_id]
            for loop_idx in poly.loop_indices:
                uv_layer[loop_idx].uv = (u_c, 0.976)
            continue
        is_front = poly.normal.y <= 0.12
        if is_head:
            u_base = HEAD_U_MIN if is_front else (0.50 + HEAD_U_MIN)
            u_span = HEAD_U_MAX - HEAD_U_MIN
            for loop_idx in poly.loop_indices:
                v = me.vertices[me.loops[loop_idx].vertex_index].co
                u_h = min(max((v.x - HEAD_X_MIN) / (HEAD_X_MAX - HEAD_X_MIN), 0.002), 0.998)
                v_h = min(max((v.z - HEAD_Z_MIN) / (HEAD_Z_MAX - HEAD_Z_MIN), 0.002), 0.998)
                uv_layer[loop_idx].uv = (u_base + u_h * u_span, HEAD_V_MIN + v_h * (HEAD_V_MAX - HEAD_V_MIN))
        else:
            u_off = 0.01 if is_front else 0.51
            nx = poly.normal.x
            side_ness = max(0.0, (abs(nx) - 0.25) / 0.75)
            for loop_idx in poly.loop_indices:
                v = me.vertices[me.loops[loop_idx].vertex_index].co
                sgn_x = 1.0 if v.x >= 0.0 else -1.0
                x_eff = v.x - sgn_x * 0.055 * side_ness + 0.095 * nx * v.y
                z_eff = (4.65 + min(max((v.z - 4.65) / (5.96 - 4.65), 0.0), 1.0) * (5.36 - 4.65)) if is_hair else v.z
                u_norm = min(max((x_eff - ATLAS_X_MIN) / (ATLAS_X_MAX - ATLAS_X_MIN), 0.005), 0.995)
                v_norm = min(max((z_eff - ATLAS_Z_MIN) / (ATLAS_Z_MAX - ATLAS_Z_MIN), 0.005), 0.995)
                uv_layer[loop_idx].uv = (u_off + u_norm * 0.48, 0.005 + v_norm * 0.99)


def fill_scan_cross_sections(bm, z_min: float, z_max: float, slices: int = 8, inset: float = 0.022):
    orig_coords = [v.co.copy() for v in bm.verts]
    if not orig_coords:
        return
    dz = (z_max - z_min) / max(slices, 1)
    for i in range(slices + 1):
        zc = z_min + i * dz
        band = [p for p in orig_coords if abs(p.z - zc) <= max(dz * 0.9, 0.08)]
        if len(band) < 6:
            band = orig_coords
        xs = [p.x for p in band]
        ys = [p.y for p in band]
        cx = 0.5 * (min(xs) + max(xs))
        cy = 0.5 * (min(ys) + max(ys))
        rx = max(0.08, 0.5 * (max(xs) - min(xs)) - inset)
        ry = max(0.08, 0.5 * (max(ys) - min(ys)) - inset)
        rz = max(0.09, dz * 0.95)
        res = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
        for v in res["verts"]:
            v.co = Vector((cx + v.co.x * rx, cy + v.co.y * ry, zc + v.co.z * rz))


def build_part_from_scan(
    name: str,
    src_obj,
    scan_bvh: BVHTree,
    face_filter,
    joint_spheres: list[tuple[tuple[float, float, float], tuple[float, float, float]]],
    voxel_size: float,
    target_tris: int,
    solidify_thickness: float = 0.022,
    max_components: int = 1,
    snap_strength: float = 0.65,
    auto_slice_range: tuple[float, float] | None = None,
    extra_bmesh_fn=None,
    post_vertex_fn=None,
):
    part = src_obj.copy()
    part.data = src_obj.data.copy()
    part.name = name
    part.data.name = name
    part.data.materials.clear()
    bpy.context.scene.collection.objects.link(part)

    bm = bmesh.new()
    bm.from_mesh(part.data)
    del_faces = [f for f in bm.faces if not face_filter(f.calc_center_median(), f.normal)]
    if del_faces:
        bmesh.ops.delete(bm, geom=del_faces, context="FACES")
    bm.to_mesh(part.data)
    bm.free()

    bpy.context.view_layer.objects.active = part
    if solidify_thickness > 0:
        sol = part.modifiers.new("Sol", "SOLIDIFY")
        sol.thickness = solidify_thickness
        sol.offset = -0.7
        bpy.ops.object.modifier_apply(modifier=sol.name)

    bm = bmesh.new()
    bm.from_mesh(part.data)
    if auto_slice_range is not None:
        fill_scan_cross_sections(bm, auto_slice_range[0], auto_slice_range[1], slices=9, inset=0.022)
    for center, radii in joint_spheres:
        res = bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
        for v in res["verts"]:
            v.co = Vector((
                center[0] + v.co.x * radii[0],
                center[1] + v.co.y * radii[1],
                center[2] + v.co.z * radii[2],
            ))
    if extra_bmesh_fn is not None:
        extra_bmesh_fn(bm)
    bm.to_mesh(part.data)
    bm.free()

    rem = part.modifiers.new("Rem", "REMESH")
    rem.mode = "VOXEL"
    rem.voxel_size = voxel_size
    bpy.ops.object.modifier_apply(modifier=rem.name)

    keep_top_components(part, max_components=max_components, min_faces=45)

    bm = bmesh.new()
    bm.from_mesh(part.data)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bm.to_mesh(part.data)
    bm.free()

    cur_tris = len(part.data.polygons)
    if cur_tris > target_tris:
        dec = part.modifiers.new("Dec", "DECIMATE")
        dec.ratio = float(target_tris) / float(cur_tris)
        bpy.ops.object.modifier_apply(modifier=dec.name)

    for v in part.data.vertices:
        co = v.co
        if snap_strength > 0.0:
            loc, _, _, dist = scan_bvh.find_nearest(co)
            if loc is not None and dist < voxel_size * 1.4:
                v.co = co.lerp(loc, snap_strength)
        if post_vertex_fn is not None:
            v.co = post_vertex_fn(v.co, v.normal)
    part.data.update()

    if name == "Head":
        bm = bmesh.new()
        bm.from_mesh(part.data)
        for v in bm.verts:
            if v.co.y < -0.35:
                for sx in (-0.165, 0.165):
                    dx = (v.co.x - sx) / 0.082
                    dz = (v.co.z - 5.275) / 0.042
                    r2 = dx * dx + dz * dz
                    if r2 < 1.15:
                        v.co.y += 0.005 * (1.15 - r2)
                mdx = v.co.x / 0.115
                mdz = (v.co.z - 4.910) / 0.046
                mr2 = mdx * mdx + mdz * mdz
                if mr2 < 1.1:
                    v.co.y += 0.005 * (1.1 - mr2)

        for sx in (-0.165, 0.165):
            eye = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
            for v in eye["verts"]:
                v.co = Vector((
                    sx + v.co.x * 0.076,
                    -0.408 + v.co.y * 0.018,
                    5.275 + v.co.z * 0.034,
                ))
        lip = bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
        for v in lip["verts"]:
            v.co = Vector((
                v.co.x * 0.105,
                -0.415 + v.co.y * 0.022,
                4.910 + v.co.z * 0.034,
            ))
        bm.to_mesh(part.data)
        bm.free()
        part.data.update()

    tris, open_e, nonman_e = enforce_strict_watertight(part)
    assign_front_back_uvs(part)
    for p in part.data.polygons:
        p.use_smooth = True
    print(f"Built {name:24s}: tris={tris:4d}, open={open_e}, nonman={nonman_e}")
    return part


def create_r15_armature():
    arm_data = bpy.data.armatures.new("R15_Rig")
    arm_obj = bpy.data.objects.new("R15_Rig", arm_data)
    bpy.context.scene.collection.objects.link(arm_obj)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode="EDIT")
    for bname, (head, tail, parent) in BONE_SPEC.items():
        eb = arm_data.edit_bones.new(bname)
        eb.head = Vector(head)
        eb.tail = Vector(tail)
        eb.use_connect = False
    for bname, (_, _, parent) in BONE_SPEC.items():
        if parent:
            arm_data.edit_bones[bname].parent = arm_data.edit_bones[parent]
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm_obj


def bind_rigid_region(obj, arm_obj, bone_name: str):
    obj.parent = arm_obj
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm_obj
    for r in R15_REGIONS:
        if r not in obj.vertex_groups:
            obj.vertex_groups.new(name=r)
    vg = obj.vertex_groups[bone_name]
    vg.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")


def bind_layered_accessory(obj, arm_obj, bone_weights_fn):
    obj.parent = arm_obj
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm_obj
    for r in R15_REGIONS:
        if r not in obj.vertex_groups:
            obj.vertex_groups.new(name=r)
    for i, v in enumerate(obj.data.vertices):
        weights = bone_weights_fn(v.co)
        total = sum(weights.values())
        for bname, w in weights.items():
            if w > 0:
                obj.vertex_groups[bname].add([i], w / total, "REPLACE")


CLOTHING_CAGE_FBX = PKG / "source/roblox-cages/Clothing_Cage_Templates/Clothing_Cage_Templates/Clothing_Cage_Template.fbx"
BODY_CAGE_FBX = PKG / "source/roblox-cages/Body_Cage_Templates/Body_Cage_Templates/Body_Cage_Template.fbx"


def _map_template_to_demon_coords(pt: Vector) -> Vector:
    """Piecewise map standard Roblox cage template coords (Z in [-2.994..+2.507], Y center ~ -0.094)
    cleanly onto DemonFemale R15 proportions before closest-surface fitting.
    """
    xt, yt, zt = pt.x, pt.y, pt.z
    # Piecewise linear Z mapping from Roblox standard template height onto 0.00..5.56 stud body:
    z_src = (-3.00, -1.45, -0.30, 0.31, 1.65, 2.51)
    z_dst = (0.00, 1.16, 1.78, 3.04, 4.64, 5.56)
    z = float(np.interp(zt, z_src, z_dst))
    y = 0.02 + (yt + 0.094) * 1.12
    # Scale X so arms/shoulders reach Demon Female shoulder width (+-1.16..1.38) & torso (+-0.64)
    if abs(xt) <= 0.48:
        x = xt * 1.24
    else:
        sgn = 1.0 if xt >= 0 else -1.0
        x = sgn * (0.48 * 1.24 + (abs(xt) - 0.48) * 0.92)
    return Vector((x, y, z))


def _laplacian_smooth_cage(obj, iterations: int = 3, lam: float = 0.35):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.verts.ensure_lookup_table()
    for _ in range(iterations):
        new_cos = []
        for v in bm.verts:
            nbrs = [e.other_vert(v).co for e in v.link_edges]
            if nbrs:
                avg = sum(nbrs, Vector((0.0, 0.0, 0.0))) / len(nbrs)
                new_cos.append(v.co.lerp(avg, lam))
            else:
                new_cos.append(v.co.copy())
        for v, co in zip(bm.verts, new_cos):
            v.co = co
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def _build_bvh_from_objects(objs: list) -> BVHTree:
    bm = bmesh.new()
    for o in objs:
        tmp = bmesh.new()
        tmp.from_mesh(o.data)
        bmesh.ops.triangulate(tmp, faces=tmp.faces)
        vert_map = {v.index: bm.verts.new(v.co) for v in tmp.verts}
        for f in tmp.faces:
            try:
                bm.faces.new([vert_map[v.index] for v in f.verts])
            except ValueError:
                pass
        tmp.free()
    bvh = BVHTree.FromBMesh(bm)
    bm.free()
    return bvh


def fit_clothing_cages_from_template(acc_obj, arm_obj, body_objs: dict) -> list:
    """Conform official Roblox Clothing_Cage_Template.fbx (_InnerCage & _OuterCage, 1358 verts each,
    preserving Roblox's exact 'map1' UV layout and vertex order) cleanly around DemonFemale body and acc_obj.
    """
    if not CLOTHING_CAGE_FBX.exists():
        raise FileNotFoundError(f"Missing official Roblox clothing cage template: {CLOTHING_CAGE_FBX}")

    for suffix in ("_InnerCage", "_OuterCage"):
        cname = f"{acc_obj.name}{suffix}"
        old = bpy.data.objects.get(cname)
        if old is not None:
            bpy.data.objects.remove(old, do_unlink=True)
        old_m = bpy.data.meshes.get(cname)
        if old_m is not None and old_m.users == 0:
            bpy.data.meshes.remove(old_m)

    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(CLOTHING_CAGE_FBX))
    imported = [o for o in bpy.data.objects if o not in before]

    src_inner = next((o for o in imported if o.type == "MESH" and "InnerCage" in o.name), None)
    src_outer = next((o for o in imported if o.type == "MESH" and "OuterCage" in o.name), None)
    if src_inner is None or src_outer is None:
        raise RuntimeError(f"Unexpected objects in Clothing_Cage_Template.fbx: {[o.name for o in imported]}")

    # Remove non-cage helpers (Empties) and keep only our two cage meshes
    for o in imported:
        if o not in (src_inner, src_outer):
            bpy.data.objects.remove(o, do_unlink=True)

    # Compute local bounds of accessory for targeted outer cage inflation
    acc_coords = [v.co for v in acc_obj.data.vertices]
    az_min = min(p.z for p in acc_coords) - 0.14
    az_max = max(p.z for p in acc_coords) + 0.14
    ax_max = max(abs(p.x) for p in acc_coords) + 0.16

    body_bvh = _build_bvh_from_objects(list(body_objs.values()))
    acc_bvh = _build_bvh_from_objects([acc_obj])

    cages = []
    inner_cos = []
    for suffix, obj in (("_InnerCage", src_inner), ("_OuterCage", src_outer)):
        obj.name = f"{acc_obj.name}{suffix}"
        obj.data.name = obj.name
        obj.data.materials.clear()
        obj.parent = arm_obj
        # Bake object transform into vertices cleanly without breaking UV/vert order
        mw = obj.matrix_world.copy()
        obj.matrix_world = Matrix.Identity(4)
        for v in obj.data.vertices:
            v.co = _map_template_to_demon_coords(mw @ v.co)
        obj.data.update()

        if suffix == "_InnerCage":
            for v in obj.data.vertices:
                loc, nrm, _, dist = body_bvh.find_nearest(v.co)
                if loc is not None and dist < 0.85:
                    target = loc + nrm * 0.015
                    w = max(0.25, 1.0 - dist / 0.85)
                    v.co = v.co.lerp(target, w)
            _laplacian_smooth_cage(obj, iterations=3, lam=0.35)
            inner_cos = [v.co.copy() for v in obj.data.vertices]
        else:
            for idx, v in enumerate(obj.data.vertices):
                base_co = inner_cos[idx] if idx < len(inner_cos) else v.co
                v.co = base_co.copy()
                in_region = (az_min <= base_co.z <= az_max) and (abs(base_co.x) <= ax_max)
                loc_b, nrm_b, _, _ = body_bvh.find_nearest(base_co)
                fallback = base_co + (nrm_b * 0.014 if (nrm_b is not None) else Vector((0.0, 0.0, 0.0)))
                if in_region:
                    loc_a, nrm_a, _, dist_a = acc_bvh.find_nearest(base_co)
                    if loc_a is not None and dist_a < 0.45:
                        out_pt = loc_a + nrm_a * 0.030
                        # Only push outward if accessory stands further out from center than inner cage
                        if out_pt.xy.length >= fallback.xy.length - 0.01 or abs(out_pt.z - fallback.z) < 0.12:
                            w_a = max(0.25, 1.0 - dist_a / 0.45)
                            v.co = fallback.lerp(out_pt, w_a)
                        else:
                            v.co = fallback
                    else:
                        v.co = fallback
                else:
                    v.co = fallback
            _laplacian_smooth_cage(obj, iterations=3, lam=0.35)

        cages.append(obj)
    return cages


def fit_body_cages_from_template(arm_obj, body_objs: dict) -> list:
    """Conform official Roblox Body_Cage_Template.fbx 15 *_OuterCage meshes (with Roblox 'map1' UVs)
    tightly around each of the 15 R15 body parts so Layered Clothing auto-fits in Studio.
    """
    if not BODY_CAGE_FBX.exists():
        raise FileNotFoundError(f"Missing official Roblox body cage template: {BODY_CAGE_FBX}")

    for r in R15_REGIONS:
        cname = f"{r}_OuterCage"
        old = bpy.data.objects.get(cname)
        if old is not None:
            bpy.data.objects.remove(old, do_unlink=True)
        old_m = bpy.data.meshes.get(cname)
        if old_m is not None and old_m.users == 0:
            bpy.data.meshes.remove(old_m)

    before = set(bpy.data.objects)
    bpy.ops.import_scene.fbx(filepath=str(BODY_CAGE_FBX))
    imported = [o for o in bpy.data.objects if o not in before]

    body_cages = []
    wanted = {f"{r}_OuterCage": r for r in R15_REGIONS}
    for o in list(imported):
        if o.type != "MESH" or o.name not in wanted:
            bpy.data.objects.remove(o, do_unlink=True)
            continue
        rname = wanted[o.name]
        pobj = body_objs[rname]
        mw = o.matrix_world.copy()
        o.matrix_world = Matrix.Identity(4)
        o.parent = arm_obj
        o.data.name = o.name
        o.data.materials.clear()

        t_coords = [mw @ v.co for v in o.data.vertices]
        p_coords = [v.co for v in pobj.data.vertices]
        t_min = Vector((min(p.x for p in t_coords), min(p.y for p in t_coords), min(p.z for p in t_coords)))
        t_max = Vector((max(p.x for p in t_coords), max(p.y for p in t_coords), max(p.z for p in t_coords)))
        p_min = Vector((min(p.x for p in p_coords), min(p.y for p in p_coords), min(p.z for p in p_coords)))
        p_max = Vector((max(p.x for p in p_coords), max(p.y for p in p_coords), max(p.z for p in p_coords)))

        part_bvh = _build_bvh_from_objects([pobj])
        for v, tc in zip(o.data.vertices, t_coords):
            nx = (tc.x - t_min.x) / max(t_max.x - t_min.x, 1e-4)
            ny = (tc.y - t_min.y) / max(t_max.y - t_min.y, 1e-4)
            nz = (tc.z - t_min.z) / max(t_max.z - t_min.z, 1e-4)
            mapped = Vector((
                p_min.x + nx * (p_max.x - p_min.x),
                p_min.y + ny * (p_max.y - p_min.y),
                p_min.z + nz * (p_max.z - p_min.z),
            ))
            loc, nrm, _, dist = part_bvh.find_nearest(mapped)
            if loc is not None and dist < 0.45:
                v.co = mapped.lerp(loc + nrm * 0.014, 0.88)
            else:
                v.co = mapped
        _laplacian_smooth_cage(o, iterations=2, lam=0.30)
        body_cages.append(o)

    body_cages.sort(key=lambda c: c.name)
    return body_cages


def export_all_glbs(arm_obj, body_objs: dict, acc_objs: dict, mantle_cages: list, tasset_cages: list, body_cages: list | None = None):
    def export_selected(objs, out_glb: Path):
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs:
            o.hide_viewport = False
            o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        bpy.ops.export_scene.gltf(
            filepath=str(out_glb),
            export_format="GLB",
            use_selection=True,
            export_yup=True,
            export_apply=False,
            export_skins=True,
            export_materials="EXPORT",
        )

    export_selected([arm_obj] + list(body_objs.values()) + (body_cages or []), EXP_DIR / "DarkFantasyDemonFemaleBody.glb")
    export_selected([arm_obj] + list(body_objs.values()) + list(acc_objs.values()), EXP_DIR / "DarkFantasyDemonFemaleFull.glb")
    export_selected([acc_objs["DemonHorns"]], EXP_DIR / "DemonHorns.glb")
    export_selected([acc_objs["DemonHair"]], EXP_DIR / "DemonHair.glb")
    export_selected([arm_obj, acc_objs["FeatheredShoulderMantle"]] + mantle_cages, EXP_DIR / "FeatheredShoulderMantle.glb")
    export_selected([arm_obj, acc_objs["HipTassets"]] + tasset_cages, EXP_DIR / "HipTassets.glb")
    export_selected([acc_objs["LeftWristFeathers"]], EXP_DIR / "LeftWristFeathers.glb")
    export_selected([acc_objs["RightWristFeathers"]], EXP_DIR / "RightWristFeathers.glb")


def safe_taubin_and_sculpt(obj, iterations: int = 4, lam: float = 0.36, mu: float = -0.37, weight_fn=None, sculpt_fn=None):
    """Apply volume-preserving Taubin surface fairing + optional feature sculpting while
    strictly preserving 1-to-1 quantized (1e-4) vertex keys so watertightness (open=0, nonman=0)
    and exact triangle counts are guaranteed without remeshing.
    """
    me = obj.data
    n_verts = len(me.vertices)
    if n_verts == 0:
        return
    orig_cos = [v.co.copy() for v in me.vertices]
    cos = [v.co.copy() for v in me.vertices]

    adj = [set() for _ in range(n_verts)]
    for e in me.edges:
        v0, v1 = e.vertices[0], e.vertices[1]
        adj[v0].add(v1)
        adj[v1].add(v0)

    weights = [1.0 if weight_fn is None else float(weight_fn(c)) for c in orig_cos]

    for _ in range(iterations):
        for step_factor in (lam, mu):
            new_cos = []
            for i, c in enumerate(cos):
                nbrs = adj[i]
                w = weights[i]
                if not nbrs or w <= 0.0:
                    new_cos.append(c)
                    continue
                avg = sum((cos[j] for j in nbrs), Vector((0.0, 0.0, 0.0))) / len(nbrs)
                new_cos.append(c + (avg - c) * (step_factor * w))
            cos = new_cos

    if sculpt_fn is not None:
        cos = [sculpt_fn(c, orig_cos[i]) for i, c in enumerate(cos)]

    # Quantize to 5e-4 grid while preserving 1-to-1 key uniqueness with orig_cos fallback
    used_keys = set()
    final_cos = [None] * n_verts
    for i, oc in enumerate(orig_cos):
        nc = cos[i]
        qx = round(nc.x * 2000) / 2000.0
        qy = round(nc.y * 2000) / 2000.0
        qz = round(nc.z * 2000) / 2000.0
        k = (round(qx * 10000), round(qy * 10000), round(qz * 10000))
        if k not in used_keys:
            used_keys.add(k)
            final_cos[i] = Vector((qx, qy, qz))
        else:
            ok = (round(oc.x * 10000), round(oc.y * 10000), round(oc.z * 10000))
            used_keys.add(ok)
            final_cos[i] = oc

    for i, v in enumerate(me.vertices):
        v.co = final_cos[i]
    me.update()


def polish_meshes_in_place(arm_obj, body_objs: dict, acc_objs: dict):
    """Polish geometry of the 15 R15 regions and 6 accessories:
    - Smooth out voxel/decimation facets on the face, horns, feathers, collar, and armor
    - Sculpt sharper facial definition (brow arch, nose bridge, cheekbones, Cupid's-bow lips)
    - Refine horns into sleek, intentionally segmented curves
    - Refine shoulder & wrist feathers into crafted, bevelled plumes while locking sharp tips
    - Tuck joint overlaps and update R15 weights on HipTassets & FeatheredShoulderMantle to prevent clipping
    """
    # 1. Head: smooth porcelain skin + sharper facial anatomy
    head_obj = body_objs["Head"]
    if head_obj.get("polished_v3") != 1:
        def sculpt_head(c: Vector, oc: Vector) -> Vector:
            if c.y > -0.25 or c.z < 4.74:
                return c
            ax = abs(c.x)
            dy = 0.0
            # Nose bridge & defined nose tip (|x| < 0.045, 5.02 <= z <= 5.25)
            if ax < 0.055 and 5.01 <= c.z <= 5.26:
                nx_w = math.exp(-((c.x / 0.030) ** 2))
                nz_w = math.sin(min(1.0, max(0.0, (c.z - 5.01) / 0.25)) * math.pi)
                dy -= 0.010 * nx_w * nz_w
            # Fierce arched brow ridge (z ~ 5.315) & upper eyelid crease (z ~ 5.290)
            if 0.06 <= ax <= 0.32 and 5.26 <= c.z <= 5.36:
                brow_z = 5.315 + 0.018 * math.sin(min(1.0, max(0.0, (ax - 0.06) / 0.22)) * math.pi)
                dy -= 0.008 * math.exp(-(((c.z - brow_z) / 0.018) ** 2))
                dy += 0.005 * math.exp(-(((c.z - 5.290) / 0.012) ** 2))
            # Sculpted Cupid's-bow lips & subtle confident corner lift
            if ax <= 0.13 and 4.85 <= c.z <= 4.97:
                lx_w = math.exp(-((c.x / 0.085) ** 2))
                upper_lip = math.exp(-(((c.z - 4.932) / 0.014) ** 2))
                lower_lip = math.exp(-(((c.z - 4.888) / 0.015) ** 2))
                part_line = math.exp(-(((c.z - 4.910) / 0.008) ** 2))
                dy += (-0.008 * upper_lip - 0.009 * lower_lip + 0.006 * part_line) * lx_w
            return Vector((c.x, c.y + dy, c.z))

        safe_taubin_and_sculpt(
            head_obj, iterations=5, lam=0.40, mu=-0.41,
            weight_fn=lambda c: 1.0 if (c.y < -0.22 and 4.74 < c.z < 5.39) else 0.35,
            sculpt_fn=sculpt_head,
        )
        head_obj["polished_v3"] = 1

    # 2. DemonHorns: sleek, continuous curves + 12 intentional annular horn ring ridges
    horns_obj = acc_objs["DemonHorns"]
    if horns_obj.get("polished_v3") != 1:
        def sculpt_horns(c: Vector, oc: Vector) -> Vector:
            if c.z < 5.46 or c.z > 7.12:
                return c
            sgn = 1.0 if c.x >= 0 else -1.0
            cx = sgn * (0.42 + 0.12 * (c.z - 5.42))
            cy = -0.20 + 0.04 * (c.z - 5.42)
            rx = c.x - cx
            ry = c.y - cy
            r_len = math.sqrt(rx * rx + ry * ry)
            if r_len < 1e-4:
                return c
            s_arc = (c.z - 5.42) * 7.2 + (abs(c.x) - 0.38) * 1.8
            ring_wave = math.sin(s_arc * 2.0 * math.pi)
            taper = min(1.0, (7.12 - c.z) / 0.35) * min(1.0, (c.z - 5.46) / 0.18)
            disp = 0.0045 * ring_wave * taper
            return Vector((c.x + (rx / r_len) * disp, c.y + (ry / r_len) * disp, c.z))

        safe_taubin_and_sculpt(
            horns_obj, iterations=6, lam=0.42, mu=-0.43,
            weight_fn=lambda c: 0.0 if c.z > 7.08 else 1.0,
            sculpt_fn=sculpt_horns,
        )
        horns_obj["polished_v3"] = 1

    # 3. FeatheredShoulderMantle & WristFeathers: smooth interior noise while locking sharp feather tips
    for fname in ("FeatheredShoulderMantle", "LeftWristFeathers", "RightWristFeathers"):
        fobj = acc_objs[fname]
        if fobj.get("polished_v3") != 1:
            safe_taubin_and_sculpt(
                fobj, iterations=4, lam=0.38, mu=-0.39,
                weight_fn=lambda c: 0.15 if abs(c.x) > 1.55 else 0.85,
            )
            fobj["polished_v3"] = 1

    # 4. DemonHair, UpperTorso, HipTassets, Arms, Legs: fair surfaces + tuck UpperArm elbow rim + anti-clipping clearance
    for rname, robj in list(body_objs.items()) + [("DemonHair", acc_objs["DemonHair"]), ("HipTassets", acc_objs["HipTassets"])]:
        if rname == "Head" or robj.get("polished_v3") == 1:
            continue
        def make_part_sculpt(part_name: str):
            def _sculpt(c: Vector, oc: Vector) -> Vector:
                if part_name in ("LeftUpperArm", "RightUpperArm") and c.z < 3.36:
                    sgn = 1.0 if c.x >= 0 else -1.0
                    t = min(1.0, max(0.0, (3.36 - c.z) / 0.10))
                    cx, cy = sgn * 1.15, 0.02
                    return Vector((cx + (c.x - cx) * (1.0 - 0.07 * t), cy + (c.y - cy) * (1.0 - 0.07 * t), c.z))
                if part_name == "HipTassets" and c.z < 2.68:
                    # Slight outward radial clearance so thighs never clip through tassets during stride
                    t = min(1.0, max(0.0, (2.68 - c.z) / 0.92))
                    return Vector((c.x * (1.0 + 0.025 * t), c.y * (1.0 + 0.030 * t), c.z))
                return c
            return _sculpt

        safe_taubin_and_sculpt(robj, iterations=3, lam=0.34, mu=-0.35, sculpt_fn=make_part_sculpt(rname))
        robj["polished_v3"] = 1

    # 5. Seal neck-to-collar seam on Head/UpperTorso and give arched eyebrows full clearance under DemonHair bangs
    if head_obj.get("polished_v5") != 1:
        def seal_head_neck(c: Vector, oc: Vector) -> Vector:
            if c.z < 4.82:
                t = min(1.0, max(0.0, (4.82 - c.z) / 0.14))
                return Vector((c.x * (1.0 + 0.04 * t), c.y, c.z - 0.048 * t))
            return c
        safe_taubin_and_sculpt(head_obj, iterations=1, lam=0.20, mu=-0.20, weight_fn=lambda c: 0.0, sculpt_fn=seal_head_neck)
        head_obj["polished_v5"] = 1

    utorso_obj = body_objs["UpperTorso"]
    if utorso_obj.get("polished_v5") != 1:
        def seal_collar_top(c: Vector, oc: Vector) -> Vector:
            if c.z > 4.56 and abs(c.x) < 0.48:
                t = min(1.0, max(0.0, (c.z - 4.56) / 0.12))
                return Vector((c.x, c.y, c.z + 0.038 * t))
            return c
        safe_taubin_and_sculpt(utorso_obj, iterations=1, lam=0.20, mu=-0.20, weight_fn=lambda c: 0.0, sculpt_fn=seal_collar_top)
        utorso_obj["polished_v5"] = 1

    hair_obj = acc_objs["DemonHair"]
    if hair_obj.get("polished_v4") != 1:
        def lift_hair_brow_shelf(c: Vector, oc: Vector) -> Vector:
            if c.y < -0.16 and 5.38 <= c.z <= 5.58 and abs(c.x) < 0.37:
                # Keep central swept bang tip while raising side brow shelves so arched eyebrows are 100% clear
                side_w = min(1.0, max(0.0, (abs(c.x - 0.02) - 0.05) / 0.08))
                z_w = math.sin(min(1.0, max(0.0, (5.58 - c.z) / 0.20)) * math.pi * 0.5)
                return Vector((c.x, c.y - 0.008 * side_w * z_w, c.z + 0.036 * side_w * z_w))
            return c
        safe_taubin_and_sculpt(hair_obj, iterations=1, lam=0.20, mu=-0.20, weight_fn=lambda c: 0.0, sculpt_fn=lift_hair_brow_shelf)
        hair_obj["polished_v4"] = 1

    # 6. Final v6 refinement: tuck lower-outer jaw corners of Head, extend DemonHair side locks into collar,
    #    raise DemonHair brow shelf for generous forehead breathing room, and smooth DemonHorns temple bases.
    if head_obj.get("polished_v6") != 1:
        def tuck_jaw_corners(c: Vector, oc: Vector) -> Vector:
            if c.z < 4.82 and abs(c.x) > 0.25:
                tz = min(1.0, max(0.0, (4.82 - c.z) / 0.16))
                tx = min(1.0, max(0.0, (abs(c.x) - 0.25) / 0.16))
                w = tz * tx
                return Vector((c.x * (1.0 - 0.14 * w), c.y + 0.035 * w, c.z - 0.050 * tz))
            return c
        safe_taubin_and_sculpt(head_obj, iterations=1, lam=0.20, mu=-0.20, weight_fn=lambda c: 0.0, sculpt_fn=tuck_jaw_corners)
        head_obj["polished_v6"] = 1

    if hair_obj.get("polished_v6") != 1:
        def refine_hair_brow_and_locks(c: Vector, oc: Vector) -> Vector:
            # Extend lower side hair locks downward into the gorget collar so zero gap is visible at jaw corners
            if c.z < 4.88 and abs(c.x) > 0.28:
                tz = min(1.0, max(0.0, (4.88 - c.z) / 0.20))
                return Vector((c.x, c.y, c.z - 0.080 * tz))
            # Lift front brow shelf upward so high-arched eyebrows sit on clean forehead skin
            if c.y < -0.14 and 5.35 <= c.z <= 5.62 and abs(c.x) < 0.39:
                side_w = min(1.0, max(0.0, (abs(c.x + 0.01) - 0.04) / 0.07))
                z_w = math.sin(min(1.0, max(0.0, (5.62 - c.z) / 0.27)) * math.pi * 0.5)
                return Vector((c.x, c.y - 0.006 * side_w * z_w, c.z + 0.048 * (0.35 + 0.65 * side_w) * z_w))
            return c
        safe_taubin_and_sculpt(hair_obj, iterations=2, lam=0.30, mu=-0.31, weight_fn=lambda c: 0.4, sculpt_fn=refine_hair_brow_and_locks)
        hair_obj["polished_v6"] = 1

    if horns_obj.get("polished_v6") != 1:
        safe_taubin_and_sculpt(
            horns_obj, iterations=4, lam=0.38, mu=-0.39,
            weight_fn=lambda c: 1.0 if 5.42 <= c.z <= 5.95 else 0.25,
        )
        horns_obj["polished_v6"] = 1

    # 7. Smooth out the 3D brow-bone pinch on Head so the arched eyebrow tails sit on silky-smooth porcelain skin,
    #    and tuck the lower-left jaw corner one step further.
    if head_obj.get("polished_v7") != 1:
        def smooth_brow_and_left_jaw(c: Vector, oc: Vector) -> Vector:
            if c.z < 4.82 and abs(c.x) > 0.23:
                tz = min(1.0, max(0.0, (4.82 - c.z) / 0.16))
                tx = min(1.0, max(0.0, (abs(c.x) - 0.23) / 0.16))
                w = tz * tx
                return Vector((c.x * (1.0 - 0.14 * w), c.y + 0.04 * w, c.z - 0.04 * tz))
            return c
        safe_taubin_and_sculpt(
            head_obj, iterations=6, lam=0.42, mu=-0.43,
            weight_fn=lambda c: 1.0 if (c.y < -0.25 and 5.24 <= c.z <= 5.42 and abs(c.x) >= 0.05) else 0.0,
            sculpt_fn=smooth_brow_and_left_jaw,
        )
        head_obj["polished_v7"] = 1

    # 8. Final v9 clean sculpted Head mesh:
    #    Build Head from a 100% solid, watertight L^3.6 vertical rounded-cylinder stylized female head bmesh
    #    (2,800 triangles, open=0, nonman=0, zero inner hollow walls, zero TRELLIS brow shelf or sunken eye pit)
    #    plus the 3 dynamic-head compliance icospheres safely enclosed at y=+0.05 inside the skull center.
    if head_obj.get("polished_v10") != 1:
        bm_h = bmesh.new()
        res_h = bmesh.ops.create_icosphere(bm_h, subdivisions=4, radius=1.0)
        for v in res_h["verts"]:
            ux, uy, uz = v.co.x, v.co.y, v.co.z
            # Vertical coordinate z in [4.54, 5.55] with smooth crown/neck caps only beyond |uz| > 0.78
            denom_3d = (abs(ux) ** 3.6 + abs(uy) ** 3.6 + 1.15 * (abs(uz) ** 3.6)) ** (1.0 / 3.6)
            rx_3d = ux / max(denom_3d, 1e-6)
            ry_3d = uy / max(denom_3d, 1e-6)
            rz_3d = uz / max(denom_3d, 1e-6)

            r_xy = math.sqrt(ux * ux + uy * uy)
            if r_xy > 1e-6:
                nx_2d, ny_2d = ux / r_xy, uy / r_xy
                denom_2d = (abs(nx_2d) ** 3.6 + abs(ny_2d) ** 3.6) ** (1.0 / 3.6)
                rx_2d, ry_2d = nx_2d / denom_2d, ny_2d / denom_2d
            else:
                rx_2d, ry_2d = 0.0, 0.0

            # Across the entire visible face (4.73 <= z <= 5.46, |uz| <= 0.76), use pure 2D cylindrical profile (normal.z = 0!)
            t_cap = max(0.0, min(1.0, (abs(uz) - 0.76) / 0.22))
            t_cap = t_cap * t_cap * (3.0 - 2.0 * t_cap)
            rx = rx_2d * (1.0 - t_cap) + rx_3d * t_cap
            ry = ry_2d * (1.0 - t_cap) + ry_3d * t_cap

            z = 5.085 + 0.465 * rz_3d
            if uz < -0.72:
                neck_drop = max(0.0, min(1.0, (-0.72 - uz) / 0.28))
                z -= 0.085 * neck_drop
            # Soft female jawline taper below z = 4.86 while staying tucked behind DemonHair side locks & gorget collar
            jaw_t = max(0.0, min(1.0, (4.86 - z) / 0.28))
            w_x = 0.455 * (1.0 - 0.14 * (jaw_t ** 1.5))
            x = w_x * rx

            if ry < 0.0:
                y = 0.02 + 0.432 * ry
            else:
                y = 0.02 + 0.310 * ry

            # Delicate, intentional 3D facial anatomy on the front face (ry < -0.55)
            if ry < -0.55 and 4.80 <= z <= 5.38:
                front_w = max(0.0, min(1.0, (-ry - 0.55) / 0.35))
                dy = 0.0
                # Nose bridge & tip (|x| < 0.042, 5.01 <= z <= 5.23)
                if abs(x) < 0.045 and 5.01 <= z <= 5.23:
                    nx_w = math.exp(-((x / 0.024) ** 2))
                    nz_w = math.sin(math.pi * (z - 5.01) / 0.22)
                    dy -= 0.011 * nx_w * nz_w
                # Sculpted Cupid's-bow lips (|x| < 0.11, 4.85 <= z <= 4.97)
                if abs(x) < 0.11 and 4.85 <= z <= 4.97:
                    lx_w = math.exp(-((x / 0.072) ** 2))
                    upper_lip = math.exp(-(((z - 4.930) / 0.013) ** 2))
                    lower_lip = math.exp(-(((z - 4.888) / 0.014) ** 2))
                    part_line = math.exp(-(((z - 4.910) / 0.008) ** 2))
                    dy += (-0.008 * upper_lip - 0.009 * lower_lip + 0.005 * part_line) * lx_w
                y += dy * front_w

            qx = round(x * 2000) / 2000.0
            qy = round(y * 2000) / 2000.0
            qz = round(z * 2000) / 2000.0
            v.co = Vector((qx, qy, qz))

        # Add 3 internal dynamic-head compliance icospheres safely at y=+0.05 inside the skull center
        for cx, cy, cz in ((-0.16, 0.05, 5.22), (0.16, 0.05, 5.22), (0.0, 0.05, 4.91)):
            sub = bmesh.ops.create_icosphere(bm_h, subdivisions=1, radius=1.0)
            for v in sub["verts"]:
                qx = round((cx + v.co.x * 0.025) * 2000) / 2000.0
                qy = round((cy + v.co.y * 0.025) * 2000) / 2000.0
                qz = round((cz + v.co.z * 0.025) * 2000) / 2000.0
                v.co = Vector((qx, qy, qz))

        bmesh.ops.recalc_face_normals(bm_h, faces=bm_h.faces)
        bm_h.to_mesh(head_obj.data)
        bm_h.free()
        head_obj.data.update()

        for r in R15_REGIONS:
            if r not in head_obj.vertex_groups:
                head_obj.vertex_groups.new(name=r)
            else:
                head_obj.vertex_groups[r].remove(list(range(len(head_obj.data.vertices))))
        head_obj.vertex_groups["Head"].add(list(range(len(head_obj.data.vertices))), 1.0, "REPLACE")
        head_obj["polished_v10"] = 1

    # 9. Master v11 Geometry Refinement:
    #    - Head: refined feminine lower-cheek/jawline taper + 3D two-peak Cupid's-bow lips & nose tip aligned with High-DPI face UV
    #    - DemonHorns: clean, symmetrical 3,584-tri swept-curve horn pair with 14 physical bevelled horn ring segments (open=0, nonman=0)
    #    - DemonHair: sleek vertical side locks framing the cheeks + faired bang locks
    #    - FeatheredShoulderMantle & UpperTorso: flattened throat/collar roll into a sleek 2-lobe gorget flush with the chestplate
    #    - HipTassets, Legs, Boots, WristFeathers & Hands: de-wrinkled plate fairing + tapered wrist-cuff-to-glove transition
    if head_obj.get("polished_v19") != 1:
        # Real Dynamic Head geometry (carved 3D orbital sockets & eyelids, visible external 3D eyeballs,
        # carved 3D parted mouth pocket + upper/lower Cupid's-bow lips, inner 3D upper/lower teeth & tongue).
        bm_h = bmesh.new()
        n_hr, n_hs = 32, 42  # 2,688 skin tris + 400 inner eye/mouth tris = 3,088 tris (<= 4,000 budget)
        hrings = []
        for i in range(n_hr):
            u_lin = (i + 0.5) / n_hr
            phi = -math.pi * 0.5 + u_lin * math.pi
            sin_p = math.sin(phi)
            cos_p = math.cos(phi)
            row = []
            for j in range(n_hs):
                th = 2.0 * math.pi * j / n_hs
                ux = cos_p * math.sin(th)
                uy = -cos_p * math.cos(th)
                uz = sin_p

                denom_3d = (abs(ux) ** 4.2 + abs(uy) ** 4.2 + 1.15 * (abs(uz) ** 4.2)) ** (1.0 / 4.2)
                rx_3d, ry_3d, rz_3d = ux / max(denom_3d, 1e-6), uy / max(denom_3d, 1e-6), uz / max(denom_3d, 1e-6)

                r_xy = math.sqrt(ux * ux + uy * uy)
                if r_xy > 1e-6:
                    nx_2d, ny_2d = ux / r_xy, uy / r_xy
                    denom_2d = (abs(nx_2d) ** 4.2 + abs(ny_2d) ** 4.2) ** (1.0 / 4.2)
                    rx_2d, ry_2d = nx_2d / denom_2d, ny_2d / denom_2d
                else:
                    rx_2d, ry_2d = 0.0, 0.0

                t_cap = max(0.0, min(1.0, (abs(uz) - 0.78) / 0.20))
                t_cap = t_cap * t_cap * (3.0 - 2.0 * t_cap)
                rx = rx_2d * (1.0 - t_cap) + rx_3d * t_cap
                ry = ry_2d * (1.0 - t_cap) + ry_3d * t_cap

                z = 5.065 + 0.495 * rz_3d
                if uz < -0.74:
                    z -= 0.075 * max(0.0, min(1.0, (-0.74 - uz) / 0.26))
                jaw_t = max(0.0, min(1.0, (4.82 - z) / 0.28))
                w_x = 0.484 * (1.0 - 0.16 * (jaw_t ** 1.65))
                x = w_x * rx
                y = (0.02 + 0.438 * ry) if ry < 0.0 else (0.02 + 0.330 * ry)

                if ry < -0.55 and 4.72 <= z <= 5.42:
                    front_w = max(0.0, min(1.0, (-ry - 0.55) / 0.35))
                    dy = 0.0
                    # Nose bridge & tip
                    if abs(x) < 0.052 and 4.97 <= z <= 5.24:
                        dy -= 0.016 * math.exp(-((x / 0.024) ** 2)) * math.sin(math.pi * (z - 4.97) / 0.27)
                    # Carved 3D Almond Eye Sockets & Upper/Lower Eyelid Creases (exposing visible 3D eyeballs!)
                    ax_h = abs(x)
                    if 0.055 <= ax_h <= 0.295 and 5.12 <= z <= 5.29:
                        u_eye = max(0.0, min(1.0, (ax_h - 0.068) / (0.276 - 0.068)))
                        sin_e = math.sin(u_eye * math.pi)
                        z_em = 5.182 + 0.165 * (ax_h - 0.078)
                        z_et = z_em + 0.044 * (sin_e ** 0.80) * (1.0 - 0.08 * u_eye)
                        z_eb = z_em - 0.035 * (sin_e ** 0.85) * (1.0 - 0.12 * (1.0 - u_eye))
                        x_win = max(0.0, min(1.0, (ax_h - 0.068) / 0.018)) * max(0.0, min(1.0, (0.276 - ax_h) / 0.018))
                        if z_eb <= z <= z_et and x_win > 0.0:
                            d_in = min(z - z_eb, z_et - z) / 0.026
                            dy += 0.044 * min(1.0, d_in) * x_win
                        elif z_et < z <= z_et + 0.024:
                            lid_arc = math.sin(math.pi * (z - z_et) / 0.024)
                            dy -= 0.011 * lid_arc * (sin_e ** 0.5)
                        elif z_eb - 0.018 <= z < z_eb:
                            lid_arc = math.sin(math.pi * (z_eb - z) / 0.018)
                            dy -= 0.006 * lid_arc * (sin_e ** 0.5)
                    # Sculpted 3D Parted Cupid's-Bow Lips & Carved Mouth Cavity
                    if abs(x) < 0.180 and 4.74 <= z <= 4.88:
                        lx_w = math.exp(-((x / 0.118) ** 2))
                        peak_z = 4.842 + 0.012 * math.exp(-(((abs(x) - 0.052) / 0.032) ** 2)) - 0.014 * math.exp(-((x / 0.024) ** 2))
                        upper_lip = math.exp(-(((z - peak_z) / 0.015) ** 2))
                        lower_lip = math.exp(-(((z - 4.782) / 0.017) ** 2))
                        mouth_pocket = math.exp(-(((z - 4.812) / 0.012) ** 2)) * (1.0 - min(1.0, abs(x) / 0.145))
                        dy += (-0.015 * upper_lip - 0.016 * lower_lip + 0.042 * mouth_pocket) * lx_w
                    y += dy * front_w

                row.append(bm_h.verts.new(Vector((round(x * 2000) / 2000.0, round(y * 2000) / 2000.0, round(z * 2000) / 2000.0))))
            hrings.append(row)

        v_hbot = bm_h.verts.new(Vector((0.0, 0.02, 4.505)))
        v_htop = bm_h.verts.new(Vector((0.0, 0.02, 5.560)))
        for j in range(n_hs):
            j1 = (j + 1) % n_hs
            bm_h.faces.new((v_hbot, hrings[0][j1], hrings[0][j]))
            for i in range(n_hr - 1):
                v00, v01 = hrings[i][j], hrings[i][j1]
                v11, v10 = hrings[i + 1][j1], hrings[i + 1][j]
                bm_h.faces.new((v00, v01, v11))
                bm_h.faces.new((v00, v11, v10))
            bm_h.faces.new((hrings[-1][j], hrings[-1][j1], v_htop))

        reg_layer = bm_h.faces.layers.int.new("head_region_id")
        for f in bm_h.faces:
            f[reg_layer] = 0

        def _add_head_part(center, radii, rot_y: float, reg_id: int, subdiv: int = 2):
            sub = bmesh.ops.create_icosphere(bm_h, subdivisions=subdiv, radius=1.0)
            rot_m = Matrix.Rotation(rot_y, 3, "Y")
            cx, cy, cz = center
            rx_s, ry_s, rz_s = radii
            sub_set = set(sub["verts"])
            for v in sub["verts"]:
                p = rot_m @ Vector((v.co.x * rx_s, v.co.y * ry_s, v.co.z * rz_s))
                v.co = Vector((
                    round((cx + p.x) * 2000) / 2000.0,
                    round((cy + p.y) * 2000) / 2000.0,
                    round((cz + p.z) * 2000) / 2000.0,
                ))
            for f in bm_h.faces:
                if f.verts[0] in sub_set:
                    f[reg_layer] = reg_id

        # Visible external 3D luminous white eyeballs seated directly inside the sculpted orbital sockets:
        _add_head_part(( 0.172, -0.362, 5.197), (0.098, 0.048, 0.042), -0.165, reg_id=1, subdiv=2)
        _add_head_part((-0.172, -0.362, 5.197), (0.098, 0.048, 0.042),  0.165, reg_id=1, subdiv=2)
        # Inner 3D mouth anatomy behind parted lips (upper teeth, lower teeth, tongue):
        _add_head_part((0.0, -0.376, 4.820), (0.092, 0.028, 0.011), 0.0, reg_id=2, subdiv=2)
        _add_head_part((0.0, -0.373, 4.798), (0.086, 0.026, 0.010), 0.0, reg_id=2, subdiv=2)
        _add_head_part((0.0, -0.364, 4.805), (0.068, 0.032, 0.008), 0.0, reg_id=3, subdiv=1)

        bmesh.ops.recalc_face_normals(bm_h, faces=bm_h.faces)
        bm_h.to_mesh(head_obj.data)
        bm_h.free()
        head_obj.data.update()
        for r in R15_REGIONS:
            if r not in head_obj.vertex_groups:
                head_obj.vertex_groups.new(name=r)
            else:
                head_obj.vertex_groups[r].remove(list(range(len(head_obj.data.vertices))))
        head_obj.vertex_groups["Head"].add(list(range(len(head_obj.data.vertices))), 1.0, "REPLACE")
        head_obj["polished_v16"] = 1
        head_obj["polished_v19"] = 1

    if horns_obj.get("polished_v19") != 1:
        # Bold wide-curving thick demon horns with 8 broad smooth keratin plate steps (no thin corkscrew coils!)
        bm_hrn = bmesh.new()
        n_rings = 48  # 8 broad horn plates * 6 rings/plate
        n_seg = 16
        seg_mult_table = (0.976, 0.990, 1.004, 1.014, 1.018, 0.998)
        for sgn in (-1.0, 1.0):
            ring_verts = []
            for i in range(n_rings):
                t = (i + 0.25) / 48.5
                cz = 5.42 + 1.800 * t
                cx = sgn * (0.435 + 0.505 * math.sin(t * math.pi * 0.68) + 0.045 * t * (1.0 - t))
                cy = -0.08 - 0.140 * math.sin(t * math.pi * 0.55) - 0.110 * (t ** 2)
                r_smooth = 0.255 * (1.0 - 0.905 * (t ** 1.38))
                seg_env = min(1.0, i / 3.0) * min(1.0, (n_rings - 1 - i) / 5.0)
                r_mult = 1.0 + (seg_mult_table[i % 6] - 1.0) * seg_env
                r_cur = r_smooth * r_mult
                ring = []
                for j in range(n_seg):
                    th = 2.0 * math.pi * j / n_seg
                    rx_fac = 0.92 + 0.06 * math.cos(2.0 * th)
                    ry_fac = 1.08
                    vx = cx + r_cur * rx_fac * math.cos(th)
                    vy = cy + r_cur * ry_fac * math.sin(th)
                    vz = cz
                    ring.append(bm_hrn.verts.new(Vector((
                        round(vx * 2000) / 2000.0,
                        round(vy * 2000) / 2000.0,
                        round(vz * 2000) / 2000.0,
                    ))))
                ring_verts.append(ring)

            v_bot = bm_hrn.verts.new(Vector((
                round(sgn * 0.435 * 2000) / 2000.0,
                round(-0.080 * 2000) / 2000.0,
                round(5.405 * 2000) / 2000.0,
            )))
            v_top = bm_hrn.verts.new(Vector((
                round(sgn * 0.862 * 2000) / 2000.0,
                round(-0.325 * 2000) / 2000.0,
                round(7.225 * 2000) / 2000.0,
            )))

            for j in range(n_seg):
                j1 = (j + 1) % n_seg
                bm_hrn.faces.new((v_bot, ring_verts[0][j1], ring_verts[0][j]))
                for i in range(n_rings - 1):
                    v00 = ring_verts[i][j]
                    v01 = ring_verts[i][j1]
                    v11 = ring_verts[i + 1][j1]
                    v10 = ring_verts[i + 1][j]
                    bm_hrn.faces.new((v00, v01, v11))
                    bm_hrn.faces.new((v00, v11, v10))
                bm_hrn.faces.new((ring_verts[-1][j], ring_verts[-1][j1], v_top))

        bmesh.ops.recalc_face_normals(bm_hrn, faces=bm_hrn.faces)
        bm_hrn.to_mesh(horns_obj.data)
        bm_hrn.free()
        horns_obj.data.update()
        for r in R15_REGIONS:
            if r not in horns_obj.vertex_groups:
                horns_obj.vertex_groups.new(name=r)
            else:
                horns_obj.vertex_groups[r].remove(list(range(len(horns_obj.data.vertices))))
        horns_obj.vertex_groups["Head"].add(list(range(len(horns_obj.data.vertices))), 1.0, "REPLACE")
        horns_obj["polished_v16"] = 1
        horns_obj["polished_v19"] = 1

    if hair_obj.get("polished_v11") != 1:
        def sleek_hair_locks(c: Vector, oc: Vector) -> Vector:
            # Tuck bowed outer side hair locks inward so they frame the cheeks vertically like the reference image
            if 4.66 <= c.z <= 5.38 and abs(c.x) > 0.35:
                bow_w = math.sin(min(1.0, max(0.0, (c.z - 4.66) / 0.72)) * math.pi)
                out_w = min(1.0, max(0.0, (abs(c.x) - 0.35) / 0.18))
                return Vector((c.x * (1.0 - 0.085 * bow_w * out_w), c.y, c.z))
            return c
        safe_taubin_and_sculpt(hair_obj, iterations=4, lam=0.36, mu=-0.37, weight_fn=lambda c: 0.75, sculpt_fn=sleek_hair_locks)
        hair_obj["polished_v11"] = 1

    mantle_obj = acc_objs["FeatheredShoulderMantle"]
    if mantle_obj.get("polished_v11") != 1:
        def flatten_gorget_collar_roll(c: Vector, oc: Vector) -> Vector:
            # Flatten the protruding central throat roll on FeatheredShoulderMantle into a sleek 2-lobe gorget
            if 4.14 <= c.z <= 4.68 and abs(c.x) < 0.62 and c.y < -0.20:
                wx = 1.0 - min(1.0, max(0.0, (abs(c.x) - 0.44) / 0.18))
                wz = math.sin(min(1.0, max(0.0, (c.z - 4.14) / 0.54)) * math.pi)
                y_gorget = -0.312 + 0.040 * ((abs(c.x) / 0.54) ** 2) + 0.015 * math.exp(-((c.x / 0.022) ** 2))
                if c.y < y_gorget:
                    new_y = c.y + (y_gorget - c.y) * (0.78 * wx * (0.35 + 0.65 * wz))
                    return Vector((c.x, new_y, c.z))
            return c
        safe_taubin_and_sculpt(
            mantle_obj, iterations=5, lam=0.38, mu=-0.39,
            weight_fn=lambda c: 0.90 if abs(c.x) < 0.65 else (0.15 if abs(c.x) > 1.52 else 0.75),
            sculpt_fn=flatten_gorget_collar_roll,
        )
        mantle_obj["polished_v11"] = 1

    if utorso_obj.get("polished_v11") != 1:
        def smooth_chest_corset(c: Vector, oc: Vector) -> Vector:
            if 3.85 <= c.z <= 4.35 and abs(c.x) < 0.52 and c.y < -0.22:
                wz = math.sin(min(1.0, max(0.0, (c.z - 3.85) / 0.50)) * math.pi)
                wx = 1.0 - min(1.0, max(0.0, (abs(c.x) - 0.36) / 0.16))
                y_target = -0.308 + 0.030 * ((abs(c.x) / 0.45) ** 2)
                return Vector((c.x, c.y + (y_target - c.y) * 0.45 * wz * wx, c.z))
            return c
        safe_taubin_and_sculpt(utorso_obj, iterations=6, lam=0.40, mu=-0.41, weight_fn=lambda c: 0.85, sculpt_fn=smooth_chest_corset)
        utorso_obj["polished_v11"] = 1

    tassets_obj = acc_objs["HipTassets"]
    if tassets_obj.get("polished_v11") != 1:
        safe_taubin_and_sculpt(tassets_obj, iterations=7, lam=0.42, mu=-0.43, weight_fn=lambda c: 0.90)
        tassets_obj["polished_v11"] = 1

    for wname in ("LeftWristFeathers", "RightWristFeathers"):
        wobj = acc_objs[wname]
        if wobj.get("polished_v11") != 1:
            def taper_wrist_cuff(c: Vector, oc: Vector) -> Vector:
                sgn = 1.0 if c.x >= 0 else -1.0
                if c.z < 2.58 and sgn * c.x < 1.44:
                    tz = min(1.0, max(0.0, (2.58 - c.z) / 0.14))
                    cx, cy = sgn * 1.32, -0.08
                    return Vector((cx + (c.x - cx) * (1.0 - 0.14 * tz), cy + (c.y - cy) * (1.0 - 0.14 * tz), c.z - 0.025 * tz))
                return c
            safe_taubin_and_sculpt(
                wobj, iterations=4, lam=0.38, mu=-0.39,
                weight_fn=lambda c: 0.20 if abs(c.x) > 1.50 else 0.80,
                sculpt_fn=taper_wrist_cuff,
            )
            wobj["polished_v11"] = 1

    for leg_name in ("LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot", "LeftLowerArm", "RightLowerArm", "LeftHand", "RightHand"):
        lobj = body_objs[leg_name]
        if lobj.get("polished_v11") != 1:
            safe_taubin_and_sculpt(lobj, iterations=6, lam=0.40, mu=-0.41, weight_fn=lambda c: 0.85)
            lobj["polished_v11"] = 1

    # v12: Round DemonHair crown & tuck cheek locks; eliminate Mantle/UpperTorso throat z-fighting; tuck lower-leg knee rim
    if hair_obj.get("polished_v12") != 1:
        def refine_hair_crown_and_cheeks(c: Vector, oc: Vector) -> Vector:
            x, y, z = c.x, c.y, c.z
            if z > 5.66:
                tz = min(1.0, max(0.0, (z - 5.66) / 0.28))
                z_dome = 5.92 - 0.16 * ((x / 0.44) ** 2) - 0.12 * (((y + 0.02) / 0.45) ** 2)
                if z > z_dome:
                    z = z + (z_dome - z) * 0.72 * tz
            if 4.68 <= z <= 5.38 and 0.32 <= abs(x) <= 0.52 and y < -0.06:
                wz = math.sin(min(1.0, max(0.0, (z - 4.68) / 0.70)) * math.pi)
                x = x * (1.0 - 0.055 * wz)
            return Vector((x, y, z))
        safe_taubin_and_sculpt(hair_obj, iterations=4, lam=0.36, mu=-0.37, weight_fn=lambda c: 0.75, sculpt_fn=refine_hair_crown_and_cheeks)
        hair_obj["polished_v12"] = 1

    if mantle_obj.get("polished_v12") != 1:
        def recess_mantle_throat_bridge(c: Vector, oc: Vector) -> Vector:
            if 4.10 <= c.z <= 4.70 and abs(c.x) < 0.56 and c.y < -0.16:
                wx = 1.0 - min(1.0, max(0.0, (abs(c.x) - 0.42) / 0.14))
                wz = math.sin(min(1.0, max(0.0, (c.z - 4.10) / 0.60)) * math.pi)
                y_safe = max(c.y, -0.255)
                return Vector((c.x, c.y + (y_safe - c.y) * 0.92 * wx * wz, c.z))
            return c
        safe_taubin_and_sculpt(
            mantle_obj, iterations=3, lam=0.35, mu=-0.36,
            weight_fn=lambda c: 0.85 if abs(c.x) < 0.62 else 0.10,
            sculpt_fn=recess_mantle_throat_bridge,
        )
        mantle_obj["polished_v12"] = 1

    if utorso_obj.get("polished_v12") != 1:
        def sculpt_gorget_on_utorso(c: Vector, oc: Vector) -> Vector:
            if 4.14 <= c.z <= 4.66 and abs(c.x) < 0.54 and c.y < -0.18:
                wz = math.sin(min(1.0, max(0.0, (c.z - 4.14) / 0.52)) * math.pi)
                wx = 1.0 - min(1.0, max(0.0, (abs(c.x) - 0.40) / 0.14))
                center_seam = math.exp(-((c.x / 0.022) ** 2))
                y_gorget = -0.320 + 0.028 * ((abs(c.x) / 0.48) ** 2) + 0.015 * center_seam
                return Vector((c.x, c.y + (y_gorget - c.y) * 0.72 * wz * wx, c.z))
            return c
        safe_taubin_and_sculpt(utorso_obj, iterations=4, lam=0.38, mu=-0.39, weight_fn=lambda c: 0.80, sculpt_fn=sculpt_gorget_on_utorso)
        utorso_obj["polished_v12"] = 1

    for leg_name in ("LeftLowerLeg", "RightLowerLeg"):
        lobj = body_objs[leg_name]
        if lobj.get("polished_v12") != 1:
            def tuck_knee_rim(c: Vector, oc: Vector) -> Vector:
                if c.z > 1.18:
                    tz = min(1.0, max(0.0, (c.z - 1.18) / 0.10))
                    cx = 0.58 if c.x >= 0 else -0.58
                    cy = 0.04
                    return Vector((cx + (c.x - cx) * (1.0 - 0.055 * tz), cy + (c.y - cy) * (1.0 - 0.055 * tz), c.z))
                return c
            safe_taubin_and_sculpt(lobj, iterations=3, lam=0.36, mu=-0.37, weight_fn=lambda c: 0.75, sculpt_fn=tuck_knee_rim)
            lobj["polished_v12"] = 1

    # v14: Studio-grade procedural retopology for DemonHair (zero Head intersection, smooth dome crown, cheek-framing locks),
    #      HipTassets, UpperTorso, LowerTorso, Sleeves, Legs & Boots (flat end caps + overlapping R15 joints = zero joint gaps)
    def build_capped_grid(obj, bone_name: str | None, n_rings: int, n_seg: int, ring_fn, bot_pt: tuple[float, float, float], top_pt: tuple[float, float, float]):
        bm = bmesh.new()
        rings = []
        for i in range(n_rings):
            row = []
            for j in range(n_seg):
                th = 2.0 * math.pi * j / n_seg
                vx, vy, vz = ring_fn(i, j, th)
                row.append(bm.verts.new(Vector((
                    round(vx * 2000) / 2000.0,
                    round(vy * 2000) / 2000.0,
                    round(vz * 2000) / 2000.0,
                ))))
            rings.append(row)
        v_bot = bm.verts.new(Vector((
            round(bot_pt[0] * 2000) / 2000.0,
            round(bot_pt[1] * 2000) / 2000.0,
            round(bot_pt[2] * 2000) / 2000.0,
        )))
        v_top = bm.verts.new(Vector((
            round(top_pt[0] * 2000) / 2000.0,
            round(top_pt[1] * 2000) / 2000.0,
            round(top_pt[2] * 2000) / 2000.0,
        )))
        for j in range(n_seg):
            j1 = (j + 1) % n_seg
            bm.faces.new((v_bot, rings[0][j1], rings[0][j]))
            for i in range(n_rings - 1):
                v00, v01 = rings[i][j], rings[i][j1]
                v11, v10 = rings[i + 1][j1], rings[i + 1][j]
                bm.faces.new((v00, v01, v11))
                bm.faces.new((v00, v11, v10))
            bm.faces.new((rings[-1][j], rings[-1][j1], v_top))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()
        if bone_name is not None:
            for r in R15_REGIONS:
                if r not in obj.vertex_groups:
                    obj.vertex_groups.new(name=r)
                else:
                    obj.vertex_groups[r].remove(list(range(len(obj.data.vertices))))
            obj.vertex_groups[bone_name].add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")

    def build_flat_capped_limb(obj, bone_name: str, n_rings: int, n_seg: int, z_min: float, z_max: float, section_fn):
        """Build a capped cylinder with flat end-cap rims (ring 0 and ring n_rings-1 inset at 50% radius)
        so adjacent overlapping R15 segments meet flush without V-groove bevel gaps.
        section_fn(z, th) -> (cx, cy, dx, dy) where outer vertex is (cx + dx, cy + dy, z).
        """
        def ring_fn(i: int, j: int, th: float) -> tuple[float, float, float]:
            if i == 0:
                z = z_min + 0.002
                scale = 0.48
            elif i == n_rings - 1:
                z = z_max - 0.002
                scale = 0.48
            else:
                u = (i - 1.0) / max(1.0, float(n_rings - 3))
                z = z_min + u * (z_max - z_min)
                scale = 1.0
            cx, cy, dx, dy = section_fn(z, th)
            return (cx + dx * scale, cy + dy * scale, z)

        cx0, cy0, _, _ = section_fn(z_min, 0.0)
        cx1, cy1, _, _ = section_fn(z_max, 0.0)
        build_capped_grid(obj, bone_name, n_rings, n_seg, ring_fn, (cx0, cy0, z_min - 0.002), (cx1, cy1, z_max + 0.002))

    def build_torus_grid(obj, n_rings: int, n_seg: int, ring_fn):
        bm = bmesh.new()
        rings = []
        for i in range(n_rings):
            row = []
            for j in range(n_seg):
                th = 2.0 * math.pi * j / n_seg
                vx, vy, vz = ring_fn(i, j, th)
                row.append(bm.verts.new(Vector((
                    round(vx * 2000) / 2000.0,
                    round(vy * 2000) / 2000.0,
                    round(vz * 2000) / 2000.0,
                ))))
            rings.append(row)
        for i in range(n_rings):
            i1 = (i + 1) % n_rings
            for j in range(n_seg):
                j1 = (j + 1) % n_seg
                v00, v01 = rings[i][j], rings[i][j1]
                v11, v10 = rings[i1][j1], rings[i1][j]
                bm.faces.new((v00, v01, v11))
                bm.faces.new((v00, v11, v10))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()

    if hair_obj.get("polished_v20") != 1:
        def eval_hair_pt(i: int, j: int, th: float) -> tuple[float, float, float]:
            # st in [-pi, pi) where 0 is dead-center FRONT (-Y)
            st = th if th <= math.pi else (th - 2.0 * math.pi)
            a = abs(st)
            nx = math.sin(st)
            ny = -math.cos(st)
            denom = (abs(nx) ** 4.2 + abs(ny) ** 4.2) ** (1.0 / 4.2)
            rx, ry = nx / max(denom, 1e-6), ny / max(denom, 1e-6)

            # Soft swept asymmetrical bob bangs framing the brows without sharp comb spikes
            lock_wave = (
                -0.115 * math.exp(-(((st - 0.06) / 0.145) ** 2))
                - 0.095 * math.exp(-(((st - 0.26) / 0.115) ** 2))
                - 0.088 * math.exp(-(((st + 0.24) / 0.120) ** 2))
                + 0.028 * math.exp(-(((st + 0.12) / 0.080) ** 2))
                + 0.024 * math.exp(-(((st - 0.16) / 0.075) ** 2))
                + 0.075 * math.exp(-(((st - 0.50) / 0.20) ** 2))
                + 0.068 * math.exp(-(((st + 0.50) / 0.19) ** 2))
            )
            z_bang = 5.442 + lock_wave
            # Swept angled bob hemline (longer behind ears, clean curved nape at back)
            z_nape = 4.650 + 0.055 * (1.0 - math.cos(st))
            u_side = min(1.0, max(0.0, (a - 0.78) / 0.18))
            t_side = u_side * u_side * (3.0 - 2.0 * u_side)
            z_rim = z_bang * (1.0 - t_side) + z_nape * t_side

            if i <= 9:
                s = (i + 1.0) / 10.6
                out_ness = 0.0
            elif i == 10:
                s = 1.0
                out_ness = 0.5
            else:
                s = (36.0 - i) / 25.6
                out_ness = 1.0

            # Lowered, skull-hugging swept crown (z_top ~ 5.69, nested cleanly between thick demon horn bases)
            if s < 0.28:
                u_cap = s / 0.28
                cap_r = math.sin(u_cap * (math.pi * 0.5))
                part_groove = 0.026 * out_ness * math.exp(-(((st + 0.16) / 0.10) ** 2))
                z_top_pole = 5.595 + 0.092 * out_ness - part_groove
                z = 5.570 + (z_top_pole - 5.570) * math.cos(u_cap * (math.pi * 0.5))
            else:
                cap_r = 1.0
                u_body = (s - 0.28) / 0.72
                z = 5.570 - (5.570 - z_rim) * u_body
                if i == 10:
                    z -= 0.005

            jaw_t = max(0.0, min(1.0, (4.82 - z) / 0.28))
            head_wx = 0.484 * (1.0 - 0.16 * (jaw_t ** 1.65))
            head_wy_f = 0.438 * (1.0 - 0.08 * (jaw_t ** 1.65))
            head_wy_b = 0.330 * (1.0 - 0.06 * (jaw_t ** 1.65))

            # Sleek tapered cheek-hugging bob (no thick helmet cylinder silhouette!)
            env = math.sin(min(1.0, s * 1.12) * (math.pi * 0.88))
            tip_taper = max(0.0, min(1.0, (z - 4.64) / 0.20)) if z < 4.84 else 1.0
            cheek_tuck = 1.0 - 0.22 * (1.0 - min(1.0, abs(z - 4.88) / 0.25)) * t_side
            thick_x = 0.005 + 0.070 * out_ness * (0.30 + 0.70 * env) * (0.35 + 0.65 * tip_taper) * cheek_tuck
            thick_y_f = 0.005 + 0.036 * out_ness * (0.35 + 0.65 * env)
            thick_y_b = 0.005 + 0.044 * out_ness * (0.35 + 0.65 * env) * (0.45 + 0.55 * tip_taper)

            flute = 0.011 * out_ness * math.cos(16.0 * st) * env
            st_diag = st - 0.28 * (1.0 - s)
            bang_strand = (
                0.048 * math.exp(-(((st_diag - 0.03) / 0.075) ** 2))
                + 0.044 * math.exp(-(((st_diag - 0.22) / 0.070) ** 2))
                + 0.038 * math.exp(-(((st_diag + 0.24) / 0.070) ** 2))
                - 0.020 * math.exp(-(((st_diag + 0.13) / 0.038) ** 2))
                - 0.020 * math.exp(-(((st_diag - 0.13) / 0.038) ** 2))
            )
            bang_vol = (out_ness * (1.0 - t_side) * max(0.0, 0.014 + bang_strand)) if ny < 0 else 0.0
            horn_collar = 0.024 * out_ness * math.exp(-(((a - 0.95) / 0.26) ** 2)) * math.exp(-(((z - 5.44) / 0.18) ** 2))

            side_push = t_side * (1.0 - max(0.0, min(1.0, (a - 1.65) / 0.55)))
            sgn_x = 1.0 if rx >= 0.0 else -1.0
            rx_eff = sgn_x * max(abs(rx), 0.920 * side_push) if s >= 0.28 else rx

            wx = (head_wx + thick_x + flute + horn_collar) * cap_r
            wy = ((head_wy_f + thick_y_f + bang_vol + horn_collar * 0.4) if ry < 0 else (head_wy_b + thick_y_b + flute)) * cap_r
            return (wx * rx_eff, 0.02 + wy * ry, z)

        build_capped_grid(hair_obj, "Head", 36, 48, eval_hair_pt, (0.0, 0.02, 5.575), (0.0, 0.02, 5.688))
        hair_obj["polished_v18"] = 1
        hair_obj["polished_v19"] = 1
        hair_obj["polished_v20"] = 1

    if utorso_obj.get("polished_v18") != 1:
        def eval_utorso_sec(z: float, th: float) -> tuple[float, float, float, float]:
            st = th if th <= math.pi else (th - 2.0 * math.pi)
            nx, ny = math.sin(st), -math.cos(st)
            denom = (abs(nx) ** 3.6 + abs(ny) ** 3.6) ** (1.0 / 3.6)
            rx, ry = nx / max(denom, 1e-6), ny / max(denom, 1e-6)

            waist_dip = math.exp(-(((z - 3.20) / 0.28) ** 2))
            chest_swell = math.exp(-(((z - 3.98) / 0.44) ** 2))
            neck_taper = max(0.0, min(1.0, (z - 4.46) / 0.20)) ** 1.5
            wx = (0.595 - 0.028 * waist_dip + 0.095 * chest_swell) * (1.0 - 0.42 * neck_taper)
            wy_f = (0.312 - 0.010 * waist_dip + 0.048 * chest_swell) * (1.0 - 0.35 * neck_taper)
            wy_b = (0.282 - 0.008 * waist_dip + 0.032 * chest_swell) * (1.0 - 0.35 * neck_taper)

            x_approx = wx * abs(rx)
            u_lobe = min(1.0, max(0.0, (x_approx - 0.015) / 0.50))
            z_lobe = 4.36 - 0.28 * math.sin(u_lobe * math.pi) + 0.10 * (u_lobe ** 1.6)

            # Physical 3D V-corset princess seams on front chestplate below the 2-lobe collar
            if ry < -0.35 and 3.08 <= z <= z_lobe - 0.02:
                u_bod = max(0.0, min(1.0, (z - 3.08) / 1.10))
                v_seam_x = 0.185 + 0.255 * (u_bod ** 1.35)
                seam_pipe_3d = 0.007 * math.exp(-(((x_approx - (v_seam_x - 0.016)) / 0.014) ** 2))
                seam_grv_3d = -0.008 * math.exp(-(((x_approx - v_seam_x) / 0.012) ** 2))
                wy_f += (seam_pipe_3d + seam_grv_3d) * abs(ry)

            # Physical 3D overhanging 2-lobe Peter-Pan leather collar (gorget) at z = z_lobe..4.58
            if z >= z_lobe and z <= 4.58:
                u_g = min(1.0, max(0.0, (z - z_lobe) / max(0.08, 4.58 - z_lobe)))
                g_env = (u_g ** 0.28) * ((1.0 - u_g) ** 0.45) * 1.68
                seam_notch = 1.0 - 0.92 * math.exp(-((x_approx / 0.028) ** 2))
                wy_f += 0.062 * g_env * seam_notch
                wy_b += 0.024 * g_env * seam_notch
                wx += 0.024 * g_env * seam_notch

            return (0.0, 0.02, wx * rx, (wy_f if ry < 0 else wy_b) * ry)

        # Extend UpperTorso down to z = 2.78 (inside HipTassets top belt at z = 2.835) so there is zero waist gap (24x24 = 1,152 tris)
        build_flat_capped_limb(utorso_obj, "UpperTorso", 24, 24, 2.78, 4.66, eval_utorso_sec)
        utorso_obj["polished_v18"] = 1

    ltorso_obj = body_objs["LowerTorso"]
    if ltorso_obj.get("polished_v16") != 1:
        def eval_ltorso_sec(z: float, th: float) -> tuple[float, float, float, float]:
            st = th if th <= math.pi else (th - 2.0 * math.pi)
            nx, ny = math.sin(st), -math.cos(st)
            denom = (abs(nx) ** 3.6 + abs(ny) ** 3.6) ** (1.0 / 3.6)
            rx, ry = nx / max(denom, 1e-6), ny / max(denom, 1e-6)
            t = min(1.0, max(0.0, (z - 1.76) / (3.06 - 1.76)))
            hip_swell = math.sin(t * math.pi)
            crotch_taper = max(0.0, min(1.0, (1.96 - z) / 0.20))
            wx = 0.605 + 0.045 * hip_swell - 0.055 * crotch_taper
            wy = 0.305 + 0.024 * hip_swell - 0.022 * crotch_taper
            return (0.0, 0.02, wx * rx, wy * ry)

        build_flat_capped_limb(ltorso_obj, "LowerTorso", 11, 24, 1.76, 3.06, eval_ltorso_sec)
        ltorso_obj["polished_v16"] = 1

    def _add_sculpted_feather_blade(bm_f, root_pt: Vector, axis_dir: Vector, flat_norm: Vector, length: float, width: float, thickness: float = 0.020, arch: float = 0.12):
        """Append one clean, watertight sculpted lanceolate feather blade (32 tris, open=0, nonman=0)."""
        d = axis_dir.normalized()
        n = (flat_norm - d * flat_norm.dot(d)).normalized()
        s = d.cross(n).normalized()
        prof = (
            (0.14, 0.56, 1.00, 0.04 * arch),
            (0.42, 0.98, 0.92, 0.65 * arch),
            (0.72, 0.88, 0.72, 0.95 * arch),
            (0.91, 0.42, 0.42, 0.55 * arch),
        )
        v_root = bm_f.verts.new(Vector((
            round(root_pt.x * 2000) / 2000.0,
            round(root_pt.y * 2000) / 2000.0,
            round(root_pt.z * 2000) / 2000.0,
        )))
        rings_f = []
        for u_l, w_fac, t_fac, a_off in prof:
            c = root_pt + d * (u_l * length) + n * (a_off * length)
            hw = 0.5 * width * w_fac
            ht = 0.5 * thickness * t_fac
            pts = (
                c + n * ht,
                c + s * hw,
                c - n * ht,
                c - s * hw,
            )
            rings_f.append([
                bm_f.verts.new(Vector((round(p.x * 2000) / 2000.0, round(p.y * 2000) / 2000.0, round(p.z * 2000) / 2000.0)))
                for p in pts
            ])
        tip_pt = root_pt + d * length + n * (0.20 * arch * length)
        v_tip = bm_f.verts.new(Vector((
            round(tip_pt.x * 2000) / 2000.0,
            round(tip_pt.y * 2000) / 2000.0,
            round(tip_pt.z * 2000) / 2000.0,
        )))
        for j in range(4):
            j1 = (j + 1) % 4
            bm_f.faces.new((v_root, rings_f[0][j1], rings_f[0][j]))
            for ri in range(len(rings_f) - 1):
                v00, v01 = rings_f[ri][j], rings_f[ri][j1]
                v11, v10 = rings_f[ri + 1][j1], rings_f[ri + 1][j]
                bm_f.faces.new((v00, v01, v11))
                bm_f.faces.new((v00, v11, v10))
            bm_f.faces.new((rings_f[-1][j], rings_f[-1][j1], v_tip))

    if mantle_obj.get("polished_v21") != 1:
        # Crafted layered raven-feather shoulder mantle: sculpted capelet cushion + 3 fanned tiers visible across X/Z & Y
        bm_m = bmesh.new()

        # 1. Sculpted back/shoulder capelet cushion bridging |X|=0..1.24 cleanly with deeper drape at shoulder joint
        n_yr, n_ys = 28, 10
        yoke_rings = []
        for ir in range(n_yr):
            s = (ir / float(n_yr - 1)) * 2.0 - 1.0  # -1 (left outer shoulder) .. +1 (right outer shoulder)
            arch_c = math.cos(s * math.pi * 0.5)
            sh_zone = min(1.0, max(0.0, (abs(s) - 0.35) / 0.40))
            rx_y = 1.24 * s
            ry_y = 0.03 + 0.27 * arch_c
            rz_y = 4.24 + 0.14 * arch_c - 0.08 * sh_zone
            drx = 1.24
            dry = -0.27 * (math.pi * 0.5) * math.sin(s * math.pi * 0.5)
            tang = Vector((drx, dry, 0.0)).normalized()
            up_v = Vector((0.0, 0.0, 1.0))
            out_v = tang.cross(up_v).normalized()
            # Full draped capelet cross-section over shoulder socket (|x|=0.58..1.24) -> no thin stick gap
            rad_xy = 0.145 + 0.175 * sh_zone
            rad_z = 0.095 + 0.095 * sh_zone
            ring_y = []
            for js in range(n_ys):
                phi = 2.0 * math.pi * js / n_ys
                p = Vector((rx_y, ry_y, rz_y)) + out_v * (rad_xy * math.cos(phi)) + up_v * (rad_z * math.sin(phi))
                ring_y.append(bm_m.verts.new(Vector((
                    round(p.x * 2000) / 2000.0,
                    round(p.y * 2000) / 2000.0,
                    round(p.z * 2000) / 2000.0,
                ))))
            yoke_rings.append(ring_y)

        v_y0 = bm_m.verts.new(yoke_rings[0][0].co.lerp(yoke_rings[0][n_ys // 2].co, 0.5))
        v_y1 = bm_m.verts.new(yoke_rings[-1][0].co.lerp(yoke_rings[-1][n_ys // 2].co, 0.5))
        for js in range(n_ys):
            j1 = (js + 1) % n_ys
            bm_m.faces.new((v_y0, yoke_rings[0][j1], yoke_rings[0][js]))
            for ir in range(n_yr - 1):
                bm_m.faces.new((yoke_rings[ir][js], yoke_rings[ir][j1], yoke_rings[ir + 1][j1]))
                bm_m.faces.new((yoke_rings[ir][js], yoke_rings[ir + 1][j1], yoke_rings[ir + 1][js]))
            bm_m.faces.new((yoke_rings[-1][js], yoke_rings[-1][j1], v_y1))

        # 2. Three broadside X-Z fanned tiers of sculpted lanceolate feather blades on Left & Right shoulders
        for sgn in (-1.0, 1.0):
            # Tier 1: Upper crest plumes (6 wide blades fanned across X-Z pitch so every tip separates cleanly in Front/Rear/Quarter)
            for idx in range(6):
                t = idx / 5.0  # 0 (inner high plume) .. 1 (outer swept crest plume)
                u = t * 2.0 - 1.0
                # Stagger roots from medial shoulder (0.64) out to lateral cap (1.06) and vary angle in X-Z plane
                root = Vector((sgn * (0.64 + 0.42 * t), -0.05 + 0.16 * (1.0 - t) + 0.10 * math.sin(t * math.pi), 4.26 - 0.08 * t))
                ax_dir = Vector((sgn * (0.48 + 0.44 * t), 0.14 * u, 0.86 - 0.52 * t))
                flat_n = Vector((sgn * 0.25, -0.86 if idx % 2 == 0 else -0.68, 0.44))
                _add_sculpted_feather_blade(
                    bm_m, root, ax_dir, flat_n,
                    length=0.56 - 0.08 * t, width=0.205, thickness=0.025, arch=0.11,
                )

            # Tier 2: Mid shingled pauldron overlap spanning |X|=0.70..1.58 & Z=4.02..4.26 (masks shoulder gap completely)
            for idx in range(7):
                t = idx / 6.0  # 0 (inner bridge) .. 1 (outer deltoid tip)
                u = t * 2.0 - 1.0
                root = Vector((sgn * (0.66 + 0.52 * t), -0.14 + 0.28 * (idx % 3) * 0.5, 4.22 - 0.08 * t))
                ax_dir = Vector((sgn * (0.76 + 0.18 * t), -0.18 + 0.38 * ((idx % 3) / 2.0), -0.32 - 0.18 * t))
                flat_n = Vector((sgn * 0.30, -0.78 if (idx % 3) != 2 else 0.78, 0.52))
                _add_sculpted_feather_blade(
                    bm_m, root, ax_dir, flat_n,
                    length=0.54 + 0.06 * math.sin(t * math.pi), width=0.215, thickness=0.026, arch=0.10,
                )

            # Tier 3: Posterior/outer scapula capelet plumes (6 broad blades visible in Rear, Side & Quarter)
            for idx in range(6):
                t = idx / 5.0
                u = t * 2.0 - 1.0
                root = Vector((sgn * (0.74 + 0.44 * t), 0.14 + 0.14 * math.sin(t * math.pi), 4.16 - 0.06 * t))
                ax_dir = Vector((sgn * (0.48 + 0.32 * t), 0.26 + 0.14 * (1.0 - t), -0.74))
                flat_n = Vector((sgn * 0.38, 0.84, 0.36))
                _add_sculpted_feather_blade(
                    bm_m, root, ax_dir, flat_n,
                    length=0.58 + 0.08 * t, width=0.215, thickness=0.026, arch=0.08,
                )

        bmesh.ops.recalc_face_normals(bm_m, faces=bm_m.faces)
        bm_m.to_mesh(mantle_obj.data)
        bm_m.free()
        mantle_obj.data.update()
        mantle_obj["polished_v16"] = 1
        mantle_obj["polished_v19"] = 1
        mantle_obj["polished_v20"] = 1
        mantle_obj["polished_v21"] = 1

    # Rebuild WristFeathers (LeftWristFeathers & RightWristFeathers) with X-Z fanned winglet plume silhouette
    for side, sgn in (("Left", 1.0), ("Right", -1.0)):
        wobj = acc_objs[f"{side}WristFeathers"]
        if wobj.get("polished_v21") != 1:
            bm_w = bmesh.new()
            # Sleek tapered cuff band hugging forearm at z=2.48..2.62 (center sgn*1.32, -0.07)
            cx_w, cy_w = sgn * 1.32, -0.07
            n_cs = 16
            c_rings = []
            for zc, rad_c in ((2.48, 0.340), (2.49, 0.392), (2.61, 0.398), (2.62, 0.342)):
                row_c = []
                for j in range(n_cs):
                    th = 2.0 * math.pi * j / n_cs
                    nx, ny = math.cos(th), math.sin(th)
                    denom = (abs(nx) ** 3.8 + abs(ny) ** 3.8) ** (1.0 / 3.8)
                    rx, ry = nx / max(denom, 1e-6), ny / max(denom, 1e-6)
                    p = Vector((cx_w + rad_c * rx, cy_w + rad_c * ry, zc))
                    row_c.append(bm_w.verts.new(Vector((
                        round(p.x * 2000) / 2000.0,
                        round(p.y * 2000) / 2000.0,
                        round(p.z * 2000) / 2000.0,
                    ))))
                c_rings.append(row_c)
            for ri in range(len(c_rings)):
                r1 = (ri + 1) % len(c_rings)
                for j in range(n_cs):
                    j1 = (j + 1) % n_cs
                    bm_w.faces.new((c_rings[ri][j], c_rings[ri][j1], c_rings[r1][j1]))
                    bm_w.faces.new((c_rings[ri][j], c_rings[r1][j1], c_rings[r1][j]))

            # 5 fanned sculpted wing feathers splaying along X-Z (plus slight Y depth) so ALL blades read in Front, Quarter & Side
            for k in range(5):
                t = k / 4.0  # 0 (steep high feather) .. 1 (low outward swept feather)
                u = t * 2.0 - 1.0
                ang_w = u * 0.42
                root = Vector((cx_w + sgn * 0.360, cy_w + 0.16 * math.sin(ang_w), 2.54 + 0.04 * (1.0 - t)))
                ax_dir = Vector((sgn * (0.28 + 0.56 * t), 0.14 * math.sin(ang_w), 0.94 - 0.42 * t))
                flat_n = Vector((sgn * 0.42, -0.86, -0.22))
                _add_sculpted_feather_blade(
                    bm_w, root, ax_dir, flat_n,
                    length=0.45 - 0.05 * t,
                    width=0.140, thickness=0.022, arch=0.09,
                )

            bmesh.ops.recalc_face_normals(bm_w, faces=bm_w.faces)
            bm_w.to_mesh(wobj.data)
            bm_w.free()
            wobj.data.update()
            for r in R15_REGIONS:
                if r not in wobj.vertex_groups:
                    wobj.vertex_groups.new(name=r)
                else:
                    wobj.vertex_groups[r].remove(list(range(len(wobj.data.vertices))))
            wobj.vertex_groups[f"{side}LowerArm"].add(list(range(len(wobj.data.vertices))), 1.0, "REPLACE")
            wobj["polished_v19"] = 1
            wobj["polished_v20"] = 1
            wobj["polished_v21"] = 1

    if tassets_obj.get("polished_v16") != 1:
        def eval_tassets_pt(i: int, j: int, th: float) -> tuple[float, float, float]:
            st = th if th <= math.pi else (th - 2.0 * math.pi)
            nx, ny = math.sin(st), -math.cos(st)
            denom = (abs(nx) ** 4.4 + abs(ny) ** 4.4) ** (1.0 / 4.4)
            rx, ry = nx / max(denom, 1e-6), ny / max(denom, 1e-6)

            x_ref = 0.76 * abs(rx)
            v_split = max(0.0, min(1.0, (0.290 - x_ref) / 0.255))
            z_bot = 1.765 + 0.830 * (v_split ** 1.05)
            z_top = 2.865

            if i <= 23:
                s = i / 23.0
                out_ness = 1.0
            elif i == 24:
                s = 1.0
                out_ness = 0.5
            elif i <= 34:
                s = (34.0 - i) / 9.0
                out_ness = 0.0
            else:
                s = 0.0
                out_ness = 0.5

            z = z_bot + s * (z_top - z_bot)
            if i == 24:
                z += 0.006
            elif i == 35:
                z -= 0.006

            t_down = max(0.0, (z_top - z) / (z_top - 1.765))
            wx_base = 0.675 + 0.175 * (t_down ** 0.90)
            wy_base = 0.362 + 0.064 * t_down

            tier_step = 0.0
            if out_ness > 0.5:
                for z_lo, z_hi in ((2.59, 2.87), (2.32, 2.59), (2.04, 2.32), (1.76, 2.04)):
                    if z_lo <= z < z_hi:
                        u_t = (z - z_lo) / (z_hi - z_lo)
                        # Crisp overlapping plate lip at bottom of each tier + recessed inner border
                        plate_frame = -0.006 * math.sin(min(1.0, max(0.0, (u_t - 0.15) / 0.70)) * math.pi)
                        tier_step = 0.022 * (1.0 - 0.65 * u_t) + plate_frame
                        break

            thick = -0.040 * (1.0 - out_ness) + tier_step
            return ((wx_base + thick) * rx, 0.02 + (wy_base + thick) * ry, z)

        build_torus_grid(tassets_obj, 36, 48, eval_tassets_pt)
        tassets_obj["polished_v16"] = 1

    # Continuous R15 armored sleeves (UpperArm + LowerArm) with sturdy kit-matched Roblox R15 volume & recessed strap grooves
    def eval_arm_sleeve_sec(sgn: float, z: float, th: float, is_upper: bool) -> tuple[float, float, float, float]:
        st = th if th <= math.pi else (th - 2.0 * math.pi)
        nx, ny = math.sin(st), -math.cos(st)
        denom = (abs(nx) ** 3.8 + abs(ny) ** 3.8) ** (1.0 / 3.8)
        rx, ry = nx / max(denom, 1e-6), ny / max(denom, 1e-6)

        u_arm = min(1.0, max(0.0, (4.16 - z) / (4.16 - 2.50)))
        cx = sgn * (1.16 + 0.16 * u_arm)
        cy = 0.01 - 0.08 * u_arm
        sh_dome = 1.0 - 0.16 * (max(0.0, (z - 3.98) / 0.20) ** 1.6)
        # Physical 3D recessed strap grooves + raised leather border ridges matching reference sleeves
        strap_grooves = sum(-0.010 * math.exp(-(((z - zb) / 0.016) ** 2)) + 0.008 * math.exp(-(((z - (zb + 0.022)) / 0.018) ** 2)) for zb in (3.76, 3.42, 3.08, 2.56))
        ovl = 0.005 if is_upper else 0.0
        rad_x = (0.376 - 0.018 * u_arm + strap_grooves + ovl) * sh_dome
        rad_y = (0.368 - 0.018 * u_arm + strap_grooves + ovl) * sh_dome
        return (cx, cy, rad_x * rx, rad_y * ry)

    for side, sgn in (("Left", 1.0), ("Right", -1.0)):
        uarm = body_objs[f"{side}UpperArm"]
        if uarm.get("polished_v17") != 1:
            build_flat_capped_limb(
                uarm, f"{side}UpperArm", 10, 16, 3.22, 4.16,
                lambda z, th, s=sgn: eval_arm_sleeve_sec(s, z, th, True),
            )
            uarm["polished_v17"] = 1

        larm = body_objs[f"{side}LowerArm"]
        if larm.get("polished_v17") != 1:
            build_flat_capped_limb(
                larm, f"{side}LowerArm", 10, 16, 2.48, 3.30,
                lambda z, th, s=sgn: eval_arm_sleeve_sec(s, z, th, False),
            )
            larm["polished_v17"] = 1

    # Continuous R15 thighs & sturdy kit-matched cuffed dark-fantasy boots (UpperLeg + LowerLeg + Foot)
    def eval_leg_boot_sec(sgn: float, z: float, th: float, is_boot: bool, is_foot: bool) -> tuple[float, float, float, float]:
        st = th if th <= math.pi else (th - 2.0 * math.pi)
        nx, ny = math.sin(st), -math.cos(st)
        denom = (abs(nx) ** 3.8 + abs(ny) ** 3.8) ** (1.0 / 3.8)
        rx, ry = nx / max(denom, 1e-6), ny / max(denom, 1e-6)

        u_leg = min(1.0, max(0.0, (1.88 - z) / 1.88))
        cx = sgn * (0.45 + 0.27 * (u_leg ** 1.06))
        cy = 0.03
        if not is_boot:
            rad_x = 0.364 - 0.008 * u_leg
            rad_y = 0.354 - 0.008 * u_leg
            return (cx, cy, rad_x * rx, rad_y * ry)
        else:
            # Bold physical 3D boot cuff overhang at z = 1.02..1.16 + ankle crease at z = 0.42
            in_cuff_band = 1.0 if z >= 1.00 else 0.0
            cuff_step = 0.018 * in_cuff_band + 0.010 * math.exp(-(((z - 1.12) / 0.030) ** 2)) - 0.008 * math.exp(-(((z - 0.99) / 0.016) ** 2))
            ankle_crease = -0.009 * math.exp(-(((z - 0.42) / 0.025) ** 2))
            flare = 0.378 + 0.024 * max(0.0, (1.16 - z) / 1.16) + cuff_step + ankle_crease + (0.004 if is_foot else 0.0)
            toe_t = max(0.0, min(1.0, (0.44 - z) / 0.44))
            toe_swell = math.sin(toe_t * math.pi * 0.82)
            rad_x = flare + 0.020 * toe_swell
            rad_y_f = flare + 0.145 * (toe_t ** 1.12)
            rad_y_b = flare - 0.018 * toe_t
            return (cx, cy, rad_x * rx, (rad_y_f if ry < 0 else rad_y_b) * ry)

    for side, sgn in (("Left", 1.0), ("Right", -1.0)):
        uleg = body_objs[f"{side}UpperLeg"]
        if uleg.get("polished_v16") != 1:
            build_flat_capped_limb(
                uleg, f"{side}UpperLeg", 10, 16, 1.06, 1.92,
                lambda z, th, s=sgn: eval_leg_boot_sec(s, z, th, False, False),
            )
            uleg["polished_v16"] = 1

        lleg = body_objs[f"{side}LowerLeg"]
        if lleg.get("polished_v16") != 1:
            build_flat_capped_limb(
                lleg, f"{side}LowerLeg", 14, 16, 0.36, 1.16,
                lambda z, th, s=sgn: eval_leg_boot_sec(s, z, th, True, False),
            )
            lleg["polished_v16"] = 1

        foot = body_objs[f"{side}Foot"]
        if foot.get("polished_v16") != 1:
            build_flat_capped_limb(
                foot, f"{side}Foot", 14, 16, 0.004, 0.43,
                lambda z, th, s=sgn: eval_leg_boot_sec(s, z, th, True, True),
            )
            foot["polished_v16"] = 1

    # Update layered R15 weights on HipTassets & FeatheredShoulderMantle for clip-free movement:
    bind_layered_accessory_weights_only(
        acc_objs["FeatheredShoulderMantle"],
        lambda co: (
            {"UpperTorso": 1.0} if abs(co.x) < 0.72 else (
                {"UpperTorso": max(0.20, 1.0 - (abs(co.x) - 0.72) * 0.72),
                 ("LeftUpperArm" if co.x > 0 else "RightUpperArm"): min(0.80, (abs(co.x) - 0.72) * 0.72)}
            )
        ),
    )
    bind_layered_accessory_weights_only(
        acc_objs["HipTassets"],
        lambda co: (
            {"LowerTorso": 0.85, "UpperTorso": 0.15} if co.z >= 2.82 else (
                {"LowerTorso": max(0.15, (co.z - 1.76) / 1.06),
                 ("LeftUpperLeg" if co.x >= 0 else "RightUpperLeg"): min(0.85, (2.82 - co.z) / 1.06)}
            )
        ),
    )

    for obj in list(body_objs.values()) + list(acc_objs.values()):
        assign_front_back_uvs(obj)
        for p in obj.data.polygons:
            p.use_smooth = True


def bind_layered_accessory_weights_only(obj, bone_weights_fn):
    for r in R15_REGIONS:
        if r not in obj.vertex_groups:
            obj.vertex_groups.new(name=r)
        else:
            obj.vertex_groups[r].remove(list(range(len(obj.data.vertices))))
    for i, v in enumerate(obj.data.vertices):
        weights = bone_weights_fn(v.co)
        total = sum(weights.values())
        for bname, w in weights.items():
            if w > 0:
                obj.vertex_groups[bname].add([i], w / total, "REPLACE")


def update_textures_and_reexport():
    """Fast path (--textures-only): open existing .blend, polish geometry in-place, rebuild 1024x1024
    _ALB/_RGH/_NRM textures, update materials, save .blend, and re-export all 8 GLBs.
    """
    blend_path = PKG / "source/DarkFantasyDemonFemale.blend"
    bpy.ops.wm.open_mainfile(filepath=str(blend_path))

    existing_objs = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(SRC_GLB))
    new_objs = [o for o in bpy.data.objects if o not in existing_objs and o.type == "MESH"]
    src_obj = new_objs[0]
    bpy.context.view_layer.objects.active = src_obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for v in src_obj.data.vertices:
        v.co.x *= SCALE
        v.co.y *= SCALE
        v.co.z = (v.co.z + Z_OFF) * SCALE
    src_obj.data.update()

    (b_alb, b_rgh, b_nrm), (a_alb, a_rgh, a_nrm) = build_textures(src_obj)
    for o in list(bpy.data.objects):
        if o not in existing_objs:
            bpy.data.objects.remove(o, do_unlink=True)

    body_mat = make_pbr_material("DarkFantasyDemonBodyMat", b_alb, b_rgh, b_nrm)
    acc_mat = make_pbr_material("DarkFantasyDemonAccMat", a_alb, a_rgh, a_nrm)

    arm_obj = bpy.data.objects["R15_Rig"]
    body_objs = {r: bpy.data.objects[r] for r in R15_REGIONS}
    for rname, robj in body_objs.items():
        robj.data.materials.clear()
        robj.data.materials.append(body_mat)

    acc_names = [
        "DemonHorns", "DemonHair", "FeatheredShoulderMantle",
        "HipTassets", "LeftWristFeathers", "RightWristFeathers",
    ]
    acc_objs = {k: bpy.data.objects[k] for k in acc_names}
    for aobj in acc_objs.values():
        aobj.data.materials.clear()
        aobj.data.materials.append(acc_mat)

    polish_meshes_in_place(arm_obj, body_objs, acc_objs)

    mantle_cages = fit_clothing_cages_from_template(acc_objs["FeatheredShoulderMantle"], arm_obj, body_objs)
    tasset_cages = fit_clothing_cages_from_template(acc_objs["HipTassets"], arm_obj, body_objs)
    body_cages = fit_body_cages_from_template(arm_obj, body_objs)

    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    export_all_glbs(arm_obj, body_objs, acc_objs, mantle_cages, tasset_cages, body_cages=body_cages)
    print("TEXTURE_UPDATE_AND_REEXPORT_COMPLETE")


def main():
    if "--textures-only" in sys.argv and (PKG / "source/DarkFantasyDemonFemale.blend").exists():
        update_textures_and_reexport()
        return

    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(SRC_GLB))
    src_obj = [o for o in bpy.data.objects if o.type == "MESH"][0]
    src_obj.name = "SourceScanHighPoly"
    bpy.context.view_layer.objects.active = src_obj
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    for v in src_obj.data.vertices:
        v.co.x *= SCALE
        v.co.y *= SCALE
        v.co.z = (v.co.z + Z_OFF) * SCALE
    src_obj.data.update()

    bm_bvh = bmesh.new()
    bm_bvh.from_mesh(src_obj.data)
    bmesh.ops.triangulate(bm_bvh, faces=bm_bvh.faces)
    scan_bvh = BVHTree.FromBMesh(bm_bvh)
    bm_bvh.free()

    (b_alb, b_rgh, b_nrm), (a_alb, a_rgh, a_nrm) = build_textures(src_obj)
    body_mat = make_pbr_material("DarkFantasyDemonBodyMat", b_alb, b_rgh, b_nrm)
    acc_mat = make_pbr_material("DarkFantasyDemonAccMat", a_alb, a_rgh, a_nrm)

    arm_obj = create_r15_armature()
    body_objs = {}

    body_objs["Head"] = build_part_from_scan(
        "Head", src_obj, scan_bvh,
        face_filter=lambda c, n: (
            4.69 <= c.z <= 5.42
            and abs(c.x) <= 0.45
            and -0.455 <= c.y <= 0.35
        ),
        joint_spheres=[
            ((0.0, 0.05, 5.14), (0.42, 0.45, 0.42)),
            ((0.0, 0.05, 4.68), (0.23, 0.23, 0.14)),
        ],
        voxel_size=0.014,
        target_tris=2450,
        solidify_thickness=0.024,
        snap_strength=0.85,
    )

    def smooth_torso_inset(co: Vector, n: Vector) -> Vector:
        if co.z > 4.22:
            t = min(1.0, (co.z - 4.22) / 0.30)
            return Vector((co.x * (1.0 - 0.08 * t), co.y + 0.03 * t, co.z))
        return co

    body_objs["UpperTorso"] = build_part_from_scan(
        "UpperTorso", src_obj, scan_bvh,
        face_filter=lambda c, n: (3.04 <= c.z <= 4.62 and abs(c.x) <= 0.76 and -0.44 <= c.y <= 0.68),
        joint_spheres=[
            ((0.0, 0.05, 4.64), (0.22, 0.22, 0.14)),
            ((0.74, 0.04, 4.16), (0.22, 0.22, 0.22)),
            ((-0.74, 0.04, 4.16), (0.22, 0.22, 0.22)),
        ],
        voxel_size=0.020,
        target_tris=1020,
        solidify_thickness=0.028,
        snap_strength=0.78,
        auto_slice_range=(3.06, 4.52),
        post_vertex_fn=smooth_torso_inset,
    )

    body_objs["LowerTorso"] = build_part_from_scan(
        "LowerTorso", src_obj, scan_bvh,
        face_filter=lambda c, n: (1.84 <= c.z <= 3.08 and abs(c.x) <= 0.68),
        joint_spheres=[
            ((0.0, 0.05, 2.48), (0.54, 0.35, 0.60)),
            ((0.0, 0.05, 3.06), (0.54, 0.35, 0.16)),
            ((0.46, 0.04, 1.86), (0.26, 0.26, 0.20)),
            ((-0.46, 0.04, 1.86), (0.26, 0.26, 0.20)),
        ],
        voxel_size=0.024,
        target_tris=520,
        solidify_thickness=0.028,
        snap_strength=0.15,
        post_vertex_fn=lambda co, n: Vector((co.x * 0.90, co.y * 0.90, co.z)),
    )

    for side, sgn in (("Left", 1.0), ("Right", -1.0)):
        body_objs[f"{side}UpperArm"] = build_part_from_scan(
            f"{side}UpperArm", src_obj, scan_bvh,
            face_filter=lambda c, n, s=sgn: (
                3.26 <= c.z <= 4.18
                and s * c.x >= 0.81
                and s * c.x <= 1.66
                and -0.44 <= c.y <= 0.60
            ),
            joint_spheres=[
                ((sgn * 0.86, 0.04, 4.14), (0.23, 0.23, 0.22)),
            ],
            voxel_size=0.020,
            target_tris=270,
            solidify_thickness=0.028,
            snap_strength=0.78,
            auto_slice_range=(3.28, 4.12),
            post_vertex_fn=lambda co, n, s=sgn: (
                Vector((
                    s * 1.15 + (co.x - s * 1.15) * (1.0 - 0.12 * min(1.0, max(0.0, (co.z - 3.92) / 0.28))),
                    co.y * (1.0 - 0.10 * min(1.0, max(0.0, (co.z - 3.92) / 0.28))),
                    co.z,
                ))
            ),
        )

        body_objs[f"{side}LowerArm"] = build_part_from_scan(
            f"{side}LowerArm", src_obj, scan_bvh,
            face_filter=lambda c, n, s=sgn: (
                2.52 <= c.z <= 3.38
                and s * c.x >= 0.84
                and s * c.x <= 1.70
                and -0.44 <= c.y <= 0.56
                and not (c.z < 2.94 and ((s * c.x - 1.32) ** 2 + (c.y + 0.06) ** 2 > 0.125))
            ),
            joint_spheres=[
                ((sgn * 1.32, -0.08, 2.54), (0.24, 0.24, 0.16)),
            ],
            voxel_size=0.020,
            target_tris=270,
            solidify_thickness=0.028,
            snap_strength=0.78,
            auto_slice_range=(2.56, 3.36),
        )

        body_objs[f"{side}Hand"] = build_part_from_scan(
            f"{side}Hand", src_obj, scan_bvh,
            face_filter=lambda c, n, s=sgn: (
                1.90 <= c.z <= 2.58
                and s * c.x >= 0.97
                and not (c.z > 2.45 and s * c.x > 1.72)
            ),
            joint_spheres=[
                ((sgn * 1.32, -0.08, 2.54), (0.23, 0.23, 0.15)),
                ((sgn * 1.34, -0.22, 2.34), (0.27, 0.25, 0.19)),
            ],
            voxel_size=0.014,
            target_tris=580,
            solidify_thickness=0.020,
            snap_strength=0.82,
        )

    for side, sgn in (("Left", 1.0), ("Right", -1.0)):
        body_objs[f"{side}UpperLeg"] = build_part_from_scan(
            f"{side}UpperLeg", src_obj, scan_bvh,
            face_filter=lambda c, n, s=sgn: (
                1.16 <= c.z <= 1.90
                and 0.10 <= s * c.x <= 0.92
                and -0.35 <= c.y <= 0.54
            ),
            joint_spheres=[
                ((sgn * 0.48, 0.04, 1.86), (0.26, 0.26, 0.18)),
            ],
            voxel_size=0.018,
            target_tris=310,
            solidify_thickness=0.028,
            snap_strength=0.80,
            auto_slice_range=(1.18, 1.86),
            post_vertex_fn=lambda co, n, s=sgn: (
                Vector((
                    s * 0.50 + (co.x - s * 0.50) * (1.0 - 0.12 * min(1.0, max(0.0, (co.z - 1.74) / 0.16))),
                    co.y * (1.0 - 0.12 * min(1.0, max(0.0, (co.z - 1.74) / 0.16))),
                    co.z,
                ))
            ),
        )

        body_objs[f"{side}LowerLeg"] = build_part_from_scan(
            f"{side}LowerLeg", src_obj, scan_bvh,
            face_filter=lambda c, n, s=sgn: (
                0.40 <= c.z <= 1.25
                and 0.18 <= s * c.x <= 1.15
            ),
            joint_spheres=[],
            voxel_size=0.016,
            target_tris=440,
            solidify_thickness=0.026,
            snap_strength=0.82,
            auto_slice_range=(0.42, 1.23),
        )

        body_objs[f"{side}Foot"] = build_part_from_scan(
            f"{side}Foot", src_obj, scan_bvh,
            face_filter=lambda c, n, s=sgn: (
                0.00 <= c.z <= 0.49
                and 0.28 <= s * c.x <= 1.18
            ),
            joint_spheres=[],
            voxel_size=0.015,
            target_tris=380,
            solidify_thickness=0.026,
            snap_strength=0.82,
            auto_slice_range=(0.04, 0.47),
        )

    for rname, robj in body_objs.items():
        robj.data.materials.append(body_mat)
        bind_rigid_region(robj, arm_obj, rname)

    acc_objs = {}

    acc_objs["DemonHorns"] = build_part_from_scan(
        "DemonHorns", src_obj, scan_bvh,
        face_filter=lambda c, n: (
            c.z >= 5.95
            or (
                c.z >= 5.42
                and abs(c.x) >= 0.33
                and c.y <= 0.02
                and ((c.x / 0.60) ** 2 + ((c.y + 0.04) / 0.62) ** 2 + ((c.z - 5.20) / 0.66) ** 2 >= 0.94)
            )
        ),
        joint_spheres=[
            ((-0.44, -0.24, 5.52), (0.17, 0.17, 0.17)),
            ((0.44, -0.24, 5.52), (0.17, 0.17, 0.17)),
        ],
        voxel_size=0.014,
        target_tris=3400,
        solidify_thickness=0.018,
        max_components=2,
        snap_strength=0.85,
    )
    acc_objs["DemonHorns"].data.materials.append(acc_mat)
    bind_rigid_region(acc_objs["DemonHorns"], arm_obj, "Head")

    def add_hair_cap(bm):
        res = bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
        to_del = []
        for v in res["verts"]:
            v.co = Vector((v.co.x * 0.54, 0.06 + v.co.y * 0.54, 5.32 + v.co.z * 0.52))
            if v.co.y < -0.10 and abs(v.co.x) < 0.47 and v.co.z < 5.46:
                to_del.append(v)
        if to_del:
            bmesh.ops.delete(bm, geom=to_del, context="VERTS")

    acc_objs["DemonHair"] = build_part_from_scan(
        "DemonHair", src_obj, scan_bvh,
        face_filter=lambda c, n: (
            4.68 <= c.z <= 5.96
            and abs(c.x) <= 0.86
            and not (c.z >= 5.55 and abs(c.x) >= 0.36 and c.y <= -0.15)
            and (
                c.z >= 5.42
                or c.y >= -0.02
                or abs(c.x) >= 0.47
            )
        ),
        joint_spheres=[],
        voxel_size=0.015,
        target_tris=3500,
        solidify_thickness=0.024,
        max_components=1,
        snap_strength=0.82,
        extra_bmesh_fn=add_hair_cap,
    )
    acc_objs["DemonHair"].data.materials.append(acc_mat)
    bind_rigid_region(acc_objs["DemonHair"], arm_obj, "Head")

    acc_objs["FeatheredShoulderMantle"] = build_part_from_scan(
        "FeatheredShoulderMantle", src_obj, scan_bvh,
        face_filter=lambda c, n: (
            (
                3.76 <= c.z <= 5.18
                and abs(c.x) >= 0.64
                and not (c.z < 4.02 and abs(c.x) < 1.52 and -0.38 <= c.y <= 0.46)
            )
            or (4.16 <= c.z <= 4.66 and abs(c.x) <= 0.72)
        ),
        joint_spheres=[
            ((0.0, 0.08, 4.40), (0.72, 0.36, 0.14)),
            ((-1.05, 0.05, 4.42), (0.44, 0.40, 0.18)),
            ((1.05, 0.05, 4.42), (0.44, 0.40, 0.18)),
        ],
        voxel_size=0.016,
        target_tris=3750,
        solidify_thickness=0.024,
        max_components=1,
        snap_strength=0.84,
    )
    acc_objs["FeatheredShoulderMantle"].data.materials.append(acc_mat)
    bind_layered_accessory(
        acc_objs["FeatheredShoulderMantle"], arm_obj,
        lambda co: (
            {"UpperTorso": 1.0} if abs(co.x) < 0.75 else (
                {"UpperTorso": max(0.25, 1.0 - (abs(co.x) - 0.75) * 0.65),
                 ("LeftUpperArm" if co.x > 0 else "RightUpperArm"): min(0.75, (abs(co.x) - 0.75) * 0.65)}
            )
        ),
    )

    def add_tasset_liner(bm):
        res = bmesh.ops.create_icosphere(bm, subdivisions=3, radius=1.0)
        to_del = []
        for v in res["verts"]:
            v.co = Vector((v.co.x * 0.72, 0.05 + v.co.y * 0.44, 2.48 + v.co.z * 0.58))
            if v.co.y < -0.22 and abs(v.co.x) < 0.26 and v.co.z < 2.65:
                to_del.append(v)
        if to_del:
            bmesh.ops.delete(bm, geom=to_del, context="VERTS")

    acc_objs["HipTassets"] = build_part_from_scan(
        "HipTassets", src_obj, scan_bvh,
        face_filter=lambda c, n: (
            1.76 <= c.z <= 3.12
            and abs(c.x) <= 0.965
            and (c.z >= 2.68 or abs(c.x) >= 0.28 or c.y >= 0.25)
        ),
        joint_spheres=[
            ((0.0, 0.04, 2.95), (0.68, 0.44, 0.16)),
        ],
        voxel_size=0.015,
        target_tris=3400,
        solidify_thickness=0.024,
        max_components=1,
        snap_strength=0.85,
        extra_bmesh_fn=add_tasset_liner,
    )
    acc_objs["HipTassets"].data.materials.append(acc_mat)
    bind_layered_accessory(
        acc_objs["HipTassets"], arm_obj,
        lambda co: (
            {"LowerTorso": 0.85, "UpperTorso": 0.15} if co.z >= 2.75 else (
                {"LowerTorso": max(0.25, (co.z - 1.75) / 1.0),
                 ("LeftUpperLeg" if co.x >= 0 else "RightUpperLeg"): min(0.75, (2.75 - co.z) / 1.0)}
            )
        ),
    )

    for side, sgn in (("Left", 1.0), ("Right", -1.0)):
        acc_objs[f"{side}WristFeathers"] = build_part_from_scan(
            f"{side}WristFeathers", src_obj, scan_bvh,
            face_filter=lambda c, n, s=sgn: (
                2.45 <= c.z <= 2.98
                and s * c.x >= 0.97
                and ((s * c.x - 1.32) ** 2 + (c.y + 0.08) ** 2 >= 0.085)
            ),
            joint_spheres=[
                ((sgn * 1.32, -0.08, 2.70), (0.33, 0.33, 0.14)),
            ],
            voxel_size=0.012,
            target_tris=1800,
            solidify_thickness=0.018,
            max_components=1,
            snap_strength=0.85,
        )
        acc_objs[f"{side}WristFeathers"].data.materials.append(acc_mat)
        bind_rigid_region(acc_objs[f"{side}WristFeathers"], arm_obj, f"{side}LowerArm")

    polish_meshes_in_place(arm_obj, body_objs, acc_objs)
    mantle_cages = fit_clothing_cages_from_template(acc_objs["FeatheredShoulderMantle"], arm_obj, body_objs)
    tasset_cages = fit_clothing_cages_from_template(acc_objs["HipTassets"], arm_obj, body_objs)
    body_cages = fit_body_cages_from_template(arm_obj, body_objs)

    bpy.data.objects.remove(src_obj, do_unlink=True)

    blend_path = PKG / "source/DarkFantasyDemonFemale.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    export_all_glbs(arm_obj, body_objs, acc_objs, mantle_cages, tasset_cages, body_cages=body_cages)

    print("BUILD_DARK_FANTASY_DEMON_FEMALE_COMPLETE")


if __name__ == "__main__":
    main()
