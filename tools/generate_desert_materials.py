#!/usr/bin/env python3
"""
Procedural tileable 1024x1024 PBR texture generator for Middle Eastern desert canyon maps
(ChokeRidge / ChokeRidgeTDM).

Outputs seamless Color, Normal, Roughness, and Metalness PNGs for 4 Roblox MaterialVariants:
  - Desert_Sandstone      (BaseMaterial: Rock)
  - Desert_SandstoneDark  (BaseMaterial: Basalt)
  - Desert_Boulder        (BaseMaterial: Slate)
  - Desert_SandFloor      (BaseMaterial: Sand)

Usage:
  python tools/generate_desert_materials.py
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

SIZE = 1024
OUT_DIR = Path("assets/environment/materials/desert-ridge-v1")


def periodic_noise(size: int, octaves: list[tuple[int, float]], seed: int) -> np.ndarray:
    """Generate seamlessly tileable multi-octave value noise in [0, 1]."""
    rng = np.random.default_rng(seed)
    acc = np.zeros((size, size), dtype=np.float32)
    weight_sum = 0.0
    for freq, weight in octaves:
        grid = rng.random((freq, freq), dtype=np.float32)
        tiled = np.tile(grid, (3, 3))
        img = Image.fromarray((tiled * 255.0).astype(np.uint8), mode="L")
        up = np.asarray(img.resize((size * 3, size * 3), Image.Resampling.BICUBIC), dtype=np.float32) / 255.0
        acc += up[size : size * 2, size : size * 2] * weight
        weight_sum += weight
    return np.clip(acc / max(weight_sum, 1e-6), 0.0, 1.0)


def periodic_voronoi(
    size: int,
    cells_x: int,
    cells_y: int,
    seed: int,
    jitter: float = 0.85,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """
    Compute tileable Voronoi F1, edge distance (F2 - F1), and per-cell random value in [0, 1].
    Produces crisp angular rock facets and fractures with zero contour loops.
    """
    rng = np.random.default_rng(seed)
    pts_x = (np.arange(cells_x)[:, None] + 0.5 + (rng.random((cells_x, cells_y)) - 0.5) * jitter) / cells_x
    pts_y = (np.arange(cells_y)[None, :] + 0.5 + (rng.random((cells_x, cells_y)) - 0.5) * jitter) / cells_y
    cell_val = rng.random((cells_x, cells_y), dtype=np.float32)

    pts_x = pts_x.ravel().astype(np.float32)
    pts_y = pts_y.ravel().astype(np.float32)
    cell_val = cell_val.ravel()

    yy, xx = np.mgrid[0:size, 0:size]
    ux = (xx.astype(np.float32) / size)[..., None]
    uy = (yy.astype(np.float32) / size)[..., None]

    # Periodic toroidal distance
    dx = np.abs(ux - pts_x[None, None, :])
    dx = np.minimum(dx, 1.0 - dx) * float(cells_x)
    dy = np.abs(uy - pts_y[None, None, :])
    dy = np.minimum(dy, 1.0 - dy) * float(cells_y)
    dist = np.sqrt(dx * dx + dy * dy)

    idx_min = np.argmin(dist, axis=-1)
    sorted_d = np.partition(dist, 1, axis=-1)
    f1 = sorted_d[..., 0]
    f2 = sorted_d[..., 1]
    edge = f2 - f1
    cid = cell_val[idx_min]
    return f1, edge, cid


def height_to_normal(height: np.ndarray, strength: float = 5.0) -> np.ndarray:
    """Convert a tileable [0, 1] heightmap into a tangent-space RGB normal map (OpenGL +Y up)."""
    h = height.astype(np.float32)
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5 * strength
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5 * strength
    nx = -dx
    ny = -dy
    nz = np.ones_like(h)
    inv_len = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz + 1e-8)
    rgb = np.stack([(nx * inv_len * 0.5 + 0.5), (ny * inv_len * 0.5 + 0.5), (nz * inv_len * 0.5 + 0.5)], axis=-1)
    return np.clip(rgb * 255.0, 0, 255).astype(np.uint8)


def save_pbr_set(
    name: str,
    color: np.ndarray,
    height: np.ndarray,
    rough: np.ndarray,
    metal: np.ndarray,
    normal_strength: float,
) -> Image.Image:
    mat_dir = OUT_DIR / name
    mat_dir.mkdir(parents=True, exist_ok=True)
    color_u8 = np.clip(color * 255.0, 0, 255).astype(np.uint8)
    normal_u8 = height_to_normal(height, normal_strength)
    rough_u8 = np.clip(rough * 255.0, 0, 255).astype(np.uint8)
    metal_u8 = np.clip(metal * 255.0, 0, 255).astype(np.uint8)

    c_img = Image.fromarray(color_u8, mode="RGB")
    c_img.save(mat_dir / f"{name}_Color.png")
    Image.fromarray(normal_u8, mode="RGB").save(mat_dir / f"{name}_Normal.png")
    Image.fromarray(rough_u8, mode="L").save(mat_dir / f"{name}_Roughness.png")
    Image.fromarray(metal_u8, mode="L").save(mat_dir / f"{name}_Metalness.png")
    return c_img


def build_sandstone(
    name: str,
    seed_base: int,
    base_rgb_low: tuple[float, float, float],
    base_rgb_high: tuple[float, float, float],
    bands: float,
    normal_strength: float,
) -> Image.Image:
    yy, _ = np.mgrid[0:SIZE, 0:SIZE]
    y_norm = yy.astype(np.float32) / float(SIZE)

    warp_x = periodic_noise(SIZE, [(2, 0.55), (5, 0.30), (11, 0.15)], seed=seed_base)
    n_macro = periodic_noise(SIZE, [(3, 0.45), (8, 0.35), (20, 0.20)], seed=seed_base + 1)
    n_mid = periodic_noise(SIZE, [(18, 0.50), (42, 0.50)], seed=seed_base + 2)
    n_grain = periodic_noise(SIZE, [(64, 0.40), (140, 0.35), (280, 0.25)], seed=seed_base + 3)

    # Horizontally stretched rock pitting / wind-carved pockets
    n_pockets = periodic_noise(SIZE, [(6, 0.5), (16, 0.5)], seed=seed_base + 4)
    pockets = np.clip((0.38 - n_pockets) * 2.6, 0.0, 1.0) * n_mid

    # Multi-layer sedimentary strata with irregular thickness & asymmetric ledge undercuts
    phase = 2.0 * np.pi * (bands * y_norm + 0.35 * (warp_x - 0.5) + 0.10 * (n_macro - 0.5) + 0.03 * (n_mid - 0.5))
    phase_mod = phase + 0.85 * np.sin(phase * 0.35 + 2.2 * warp_x)
    strata_broad = 0.5 + 0.5 * np.sin(phase_mod)
    strata_shelf = np.clip(0.5 + 0.5 * np.tanh(2.8 * np.sin(phase_mod + 0.45 * np.sin(2.0 * phase_mod))), 0.0, 1.0)
    strata_fine = 0.5 + 0.5 * np.sin(phase_mod * 2.5 + 1.6 * n_macro + 0.7 * n_mid)

    # Undercut crevice where a hard shelf overhangs the layer below it (broken by grain)
    undercut = np.clip(1.0 - np.abs(np.sin(phase_mod + 0.35)) * 8.0, 0.0, 1.0) * (0.35 + 0.65 * n_mid)

    # Subtle irregular rock fracture planes (smooth f1 + broken hairline cracks, no hard cell tint jumps)
    f1_a, edge_a, _ = periodic_voronoi(SIZE, cells_x=4, cells_y=5, seed=seed_base + 12, jitter=0.90)
    edge_w = edge_a + (n_mid - 0.5) * 0.16 + (n_grain - 0.5) * 0.06
    hairline = np.clip(1.0 - edge_w / 0.030, 0.0, 1.0) * 0.45
    facet_var = (0.5 - f1_a) * 0.12

    band_mix = np.clip(0.38 * strata_broad + 0.40 * strata_shelf + 0.22 * strata_fine, 0.0, 1.0)
    weathering = np.clip(0.50 * undercut + 0.50 * pockets + 0.55 * hairline, 0.0, 1.0)

    rgb = np.zeros((SIZE, SIZE, 3), dtype=np.float32)
    for c in range(3):
        tone = base_rgb_low[c] + (base_rgb_high[c] - base_rgb_low[c]) * band_mix
        tone += facet_var + (n_macro - 0.5) * 0.08 + (n_grain - 0.5) * 0.09
        tone *= 1.0 - 0.34 * weathering
        rgb[..., c] = tone

    height = np.clip(
        0.44 + 0.24 * strata_shelf + 0.14 * facet_var + 0.12 * n_mid + 0.10 * n_grain - 0.30 * undercut - 0.24 * pockets - 0.22 * hairline,
        0.0,
        1.0,
    )
    rough = np.clip(0.75 + 0.14 * n_grain + 0.12 * weathering - 0.06 * strata_shelf, 0.58, 0.98)
    metal = np.full((SIZE, SIZE), 0.02, dtype=np.float32)
    return save_pbr_set(name, rgb, height, rough, metal, normal_strength=normal_strength)


def build_boulder() -> Image.Image:
    n_macro = periodic_noise(SIZE, [(3, 0.50), (7, 0.35), (16, 0.15)], seed=701)
    n_mid = periodic_noise(SIZE, [(20, 0.50), (48, 0.50)], seed=702)
    n_grain = periodic_noise(SIZE, [(72, 0.40), (160, 0.35), (280, 0.25)], seed=703)

    # Monolithic rock fracture planes via smooth Voronoi slope (NO dark polygon grid)
    f1_a, edge_a, cid_a = periodic_voronoi(SIZE, cells_x=4, cells_y=4, seed=704, jitter=0.90)
    _, edge_b, _ = periodic_voronoi(SIZE, cells_x=8, cells_y=8, seed=705, jitter=0.92)

    slope_plane = np.clip(1.0 - f1_a * 0.72 + (cid_a - 0.5) * 0.32, 0.0, 1.0)
    # Subtle hairline cracks broken up by rock grain (no thick cobblestone borders)
    edge_w = edge_a + (n_mid - 0.5) * 0.14 + (n_grain - 0.5) * 0.06
    hairline = np.clip(1.0 - edge_w / 0.032, 0.0, 1.0) * 0.55
    hairline = np.maximum(hairline, np.clip(1.0 - (edge_b + (n_mid - 0.5) * 0.12) / 0.024, 0.0, 1.0) * 0.30)
    pitting = np.clip((0.35 - n_mid) * 2.8, 0.0, 1.0) * 0.45

    rgb = np.zeros((SIZE, SIZE, 3), dtype=np.float32)
    rgb[..., 0] = 0.56 + 0.18 * slope_plane + 0.08 * (n_macro - 0.5) + 0.08 * (n_grain - 0.5) - 0.18 * hairline - 0.10 * pitting
    rgb[..., 1] = 0.35 + 0.13 * slope_plane + 0.06 * (n_macro - 0.5) + 0.06 * (n_grain - 0.5) - 0.13 * hairline - 0.08 * pitting
    rgb[..., 2] = 0.22 + 0.09 * slope_plane + 0.04 * (n_macro - 0.5) + 0.04 * (n_grain - 0.5) - 0.09 * hairline - 0.06 * pitting

    height = np.clip(0.38 + 0.38 * slope_plane + 0.14 * n_mid + 0.10 * n_grain - 0.26 * hairline - 0.22 * pitting, 0.0, 1.0)
    rough = np.clip(0.76 + 0.12 * n_grain + 0.10 * pitting + 0.08 * hairline, 0.60, 0.98)
    metal = np.full((SIZE, SIZE), 0.02, dtype=np.float32)
    return save_pbr_set("Desert_Boulder", rgb, height, rough, metal, normal_strength=6.2)


def build_sand_floor() -> Image.Image:
    yy, xx = np.mgrid[0:SIZE, 0:SIZE]
    x_norm = xx.astype(np.float32) / float(SIZE)
    y_norm = yy.astype(np.float32) / float(SIZE)

    n_dune = periodic_noise(SIZE, [(3, 0.6), (8, 0.4)], seed=801)
    n_warp = periodic_noise(SIZE, [(6, 0.55), (18, 0.45)], seed=802)
    n_grain = periodic_noise(SIZE, [(64, 0.45), (192, 0.55)], seed=803)

    ripple_phase = 2.0 * np.pi * (18.0 * x_norm + 6.0 * y_norm + 0.65 * (n_warp - 0.5))
    ripple = 0.5 + 0.5 * np.sin(ripple_phase + 0.25 * np.sin(ripple_phase))
    pebbles = np.clip((n_grain - 0.80) * 5.0, 0.0, 1.0)

    rgb = np.zeros((SIZE, SIZE, 3), dtype=np.float32)
    rgb[..., 0] = 0.79 + 0.08 * ripple + 0.05 * n_dune + 0.04 * (n_grain - 0.5) - 0.14 * pebbles
    rgb[..., 1] = 0.60 + 0.07 * ripple + 0.04 * n_dune + 0.03 * (n_grain - 0.5) - 0.13 * pebbles
    rgb[..., 2] = 0.41 + 0.06 * ripple + 0.03 * n_dune + 0.02 * (n_grain - 0.5) - 0.10 * pebbles

    height = np.clip(0.45 + 0.28 * ripple + 0.12 * n_dune + 0.10 * n_grain + 0.16 * pebbles, 0.0, 1.0)
    rough = np.clip(0.84 + 0.10 * n_grain - 0.06 * ripple, 0.72, 0.98)
    metal = np.full((SIZE, SIZE), 0.01, dtype=np.float32)
    return save_pbr_set("Desert_SandFloor", rgb, height, rough, metal, normal_strength=3.6)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    previews = [
        (
            "Sandstone",
            build_sandstone(
                "Desert_Sandstone",
                seed_base=501,
                base_rgb_low=(0.56, 0.33, 0.20),
                base_rgb_high=(0.82, 0.55, 0.34),
                bands=6.0,
                normal_strength=6.2,
            ),
        ),
        (
            "SandstoneDark",
            build_sandstone(
                "Desert_SandstoneDark",
                seed_base=601,
                base_rgb_low=(0.39, 0.21, 0.13),
                base_rgb_high=(0.64, 0.37, 0.22),
                bands=7.0,
                normal_strength=7.0,
            ),
        ),
        ("Boulder", build_boulder()),
        ("SandFloor", build_sand_floor()),
    ]
    sheet = Image.new("RGB", (1024, 1024))
    draw = ImageDraw.Draw(sheet)
    positions = [(0, 0), (512, 0), (0, 512), (512, 512)]
    for (label, im), (px, py) in zip(previews, positions):
        sheet.paste(im.resize((512, 512), Image.Resampling.LANCZOS), (px, py))
        draw.rectangle([px + 8, py + 8, px + 210, py + 34], fill=(28, 20, 16))
        draw.text((px + 14, py + 14), f"Desert_{label}", fill=(255, 210, 140))
    sheet.save(OUT_DIR / "preview_sheet.png")
    print(f"Generated 4 tileable 1024x1024 PBR sets in {OUT_DIR} (+ preview_sheet.png)")


if __name__ == "__main__":
    main()
