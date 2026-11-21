import io
import json
import struct
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance
from scipy import ndimage, spatial
import trimesh


def _extract_source_rgba(glb_path: Path) -> Image.Image:
    glb = glb_path.read_bytes()
    c0_len, _ = struct.unpack_from("<II", glb, 12)
    doc = json.loads(glb[20 : 20 + c0_len])
    c1_len, _ = struct.unpack_from("<II", glb, 20 + c0_len)
    blob = glb[28 + c0_len : 28 + c0_len + c1_len]
    bv0 = doc["bufferViews"][doc["images"][0]["bufferView"]]
    png0 = blob[bv0["byteOffset"] : bv0["byteOffset"] + bv0["byteLength"]]
    return Image.open(io.BytesIO(png0)).convert("RGBA")


def _compute_uv_shade_map(export_glb: Path, tex_size: int = 1024) -> np.ndarray:
    """Compute 3D directional sky/underside lighting + cKDTree canopy self-AO in UV space."""
    scene = trimesh.load(export_glb)
    meshes = list(scene.geometry.values())

    all_verts = np.vstack([m.vertices for m in meshes])
    # Point-cloud spatial self-occlusion + crown underside shadow (fast pure-SciPy AO)
    tree = spatial.cKDTree(all_verts)

    shade_sum = np.zeros((tex_size, tex_size), dtype=np.float64)
    shade_cnt = np.zeros((tex_size, tex_size), dtype=np.float64)

    sun_dir = np.array([0.40, 0.85, 0.34], dtype=np.float64)
    sun_dir /= np.linalg.norm(sun_dir)

    for m in meshes:
        v = m.vertices
        n = m.vertex_normals
        uv = m.visual.uv

        # Probe slightly along outward surface normal to test canopy/trunk self-occlusion
        probe = v + n * 0.45
        near_counts = np.array([len(x) for x in tree.query_ball_point(probe, r=1.15)], dtype=np.float64)
        ao = np.clip(1.0 - (near_counts - 2.0) / 38.0, 0.42, 1.0)

        # Directional sky light + crisp underside darkening on downward-facing fronds & inner crown
        ndotl = np.clip((n @ sun_dir) * 0.5 + 0.5, 0.0, 1.0)
        up_bias = np.clip(n[:, 1] * 0.5 + 0.5, 0.0, 1.0)
        # Frond crown shadow near top of trunk (y in 12.5..16.8, radial < 1.6)
        radial = np.hypot(v[:, 0], v[:, 2])
        under_crown = np.exp(-((v[:, 1] - 15.2) ** 2) / 3.2) * np.clip(1.0 - radial / 1.9, 0.0, 1.0)

        v_shade = (0.48 + 0.52 * ndotl) * (0.62 + 0.38 * ao) * (0.72 + 0.28 * up_bias) * (1.0 - 0.35 * under_crown)
        v_shade = np.clip(v_shade, 0.36, 1.08)

        # Rasterize triangle vertices & midpoints onto UV grid for dense texel coverage
        faces = m.faces
        f_uv = uv[faces]
        f_sh = v_shade[faces]
        # Barycentric sample weights across each triangle (corners, edge mids, center, inner thirds)
        weights = np.array([
            [1.0, 0.0, 0.0], [0.0, 1.0, 0.0], [0.0, 0.0, 1.0],
            [0.5, 0.5, 0.0], [0.0, 0.5, 0.5], [0.5, 0.0, 0.5],
            [0.333, 0.333, 0.334],
            [0.6, 0.2, 0.2], [0.2, 0.6, 0.2], [0.2, 0.2, 0.6],
        ])
        s_uv = np.einsum("sc,fcj->fsj", weights, f_uv).reshape(-1, 2)
        s_sh = np.einsum("sc,fc->fs", weights, f_sh).reshape(-1)

        px = np.clip(np.round(s_uv[:, 0] * (tex_size - 1)).astype(np.int32), 0, tex_size - 1)
        py = np.clip(np.round((1.0 - s_uv[:, 1]) * (tex_size - 1)).astype(np.int32), 0, tex_size - 1)
        np.add.at(shade_sum, (py, px), s_sh)
        np.add.at(shade_cnt, (py, px), 1.0)

    valid = shade_cnt > 0
    shade_map = np.ones((tex_size, tex_size), dtype=np.float32)
    shade_map[valid] = (shade_sum[valid] / shade_cnt[valid]).astype(np.float32)
    if valid.any() and not valid.all():
        _, nearest_idx = ndimage.distance_transform_edt(~valid, return_distances=True, return_indices=True)
        shade_map = shade_map[nearest_idx[0], nearest_idx[1]]

    # Smooth UV shade slightly to avoid faceted triangle stepping while keeping crisp frond pockets
    shade_map = ndimage.gaussian_filter(shade_map, sigma=1.8)
    return shade_map


def convert_to_opaque_shaded_matte(export_path: Path, source_path: Path | None = None) -> None:
    """Flatten GLB baseColorTexture into dilated opaque RGB PNG with baked 3D self-AO,
    directional top/underside foliage shading, and matte organic PBR (metallic=0.0, roughness=0.90)."""
    tex_source = source_path if (source_path and source_path.exists()) else export_path
    im = _extract_source_rgba(tex_source).resize((1024, 1024), Image.Resampling.LANCZOS)

    arr = np.array(im)
    rgb = arr[:, :, :3].astype(np.float32)
    alpha = arr[:, :, 3]

    valid = (alpha >= 20) & (rgb.sum(axis=2) > 15)
    if valid.any() and not valid.all():
        _, nearest_idx = ndimage.distance_transform_edt(~valid, return_distances=True, return_indices=True)
        rgb = rgb[nearest_idx[0], nearest_idx[1]]

    # Add subtle local detail contrast (bark crevices & leaf veins) before applying 3D AO shade
    blurred = ndimage.gaussian_filter(rgb, sigma=(2.2, 2.2, 0))
    rgb_detail = np.clip(rgb + 0.45 * (rgb - blurred), 0, 255)

    shade_map = _compute_uv_shade_map(export_path, tex_size=1024)
    # Apply rich 3D shading + balanced storm-day exposure
    shaded_rgb = np.clip(rgb_detail * shade_map[:, :, None] * 0.96, 0, 255).astype(np.uint8)
    out_im = ImageEnhance.Color(Image.fromarray(shaded_rgb, mode="RGB")).enhance(1.08)

    out_buf = io.BytesIO()
    out_im.save(out_buf, format="PNG", optimize=True)
    new_png = out_buf.getvalue()

    glb = export_path.read_bytes()
    c0_len, _ = struct.unpack_from("<II", glb, 12)
    doc = json.loads(glb[20 : 20 + c0_len])
    c1_len, _ = struct.unpack_from("<II", glb, 20 + c0_len)
    blob = glb[28 + c0_len : 28 + c0_len + c1_len]

    kept_views = []
    new_chunks = bytearray()

    def append_aligned(data: bytes) -> tuple[int, int]:
        while len(new_chunks) % 4 != 0:
            new_chunks.append(0)
        off = len(new_chunks)
        new_chunks.extend(data)
        return off, len(data)

    img_view_set = {img["bufferView"] for img in doc.get("images", [])}
    bv_remap = {}
    for idx, bv in enumerate(doc["bufferViews"]):
        if idx in img_view_set:
            continue
        chunk = blob[bv["byteOffset"] : bv["byteOffset"] + bv["byteLength"]]
        off, ln = append_aligned(chunk)
        bv_remap[idx] = len(kept_views)
        kept_views.append(dict(bv, buffer=0, byteOffset=off, byteLength=ln))

    for acc in doc.get("accessors", []):
        if "bufferView" in acc:
            acc["bufferView"] = bv_remap[acc["bufferView"]]

    off_img, ln_img = append_aligned(new_png)
    img_bv_idx = len(kept_views)
    kept_views.append({"buffer": 0, "byteOffset": off_img, "byteLength": ln_img})

    while len(new_chunks) % 4 != 0:
        new_chunks.append(0)

    doc["bufferViews"] = kept_views
    doc["images"] = [{"mimeType": "image/png", "bufferView": img_bv_idx}]
    doc["textures"] = [{"sampler": doc["textures"][0].get("sampler", 0), "source": 0}] if doc.get("textures") else [{"source": 0}]
    for mat in doc.get("materials", []):
        mat["pbrMetallicRoughness"] = {
            "baseColorTexture": {"index": 0},
            "metallicFactor": 0.0,
            "roughnessFactor": 0.90,
        }
        mat["alphaMode"] = "OPAQUE"

    doc["buffers"] = [{"byteLength": len(new_chunks)}]
    json_bytes = json.dumps(doc, separators=(",", ":")).encode("utf-8")
    while len(json_bytes) % 4 != 0:
        json_bytes += b" "

    total_len = 12 + 8 + len(json_bytes) + 8 + len(new_chunks)
    out_glb = (
        struct.pack("<III", 0x46546C67, 2, total_len)
        + struct.pack("<II", len(json_bytes), 0x4E4F534A)
        + json_bytes
        + struct.pack("<II", len(new_chunks), 0x004E4942)
        + bytes(new_chunks)
    )
    export_path.write_bytes(out_glb)
    print(f"Wrote shaded matte opaque {export_path} ({len(out_glb) / 1e6:.2f} MB), PNG {len(new_png) // 1024} KB")


if __name__ == "__main__":
    pkg_dir = Path(__file__).resolve().parent
    convert_to_opaque_shaded_matte(
        pkg_dir / "exports" / "PalmTree1.glb",
        pkg_dir / "source" / "Palm_Tree_1.glb",
    )
