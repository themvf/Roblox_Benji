#!/usr/bin/env python3
"""
Procedural tileable 1024x1024 PBR texture generator for Industrial / Sci-Fi Foundry maps.

Outputs seamless Color, Normal, Roughness, and Metalness PNGs for 4 Roblox MaterialVariants:
  - Ind_ConcreteFloor  (BaseMaterial: Concrete)
  - Ind_GunmetalWall   (BaseMaterial: Metal)
  - Ind_DiamondTread   (BaseMaterial: DiamondPlate)
  - Ind_ForgeSootMetal (BaseMaterial: Basalt)

Usage:
  python tools/generate_pbr_materials.py
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

SIZE = 1024
OUT_DIR = Path("assets/environment/materials/industrial-foundry-v1")


def periodic_noise(size: int, octaves: list[tuple[int, float]], seed: int) -> np.ndarray:
    """Generate seamlessly tileable multi-octave value noise in [0, 1]."""
    rng = np.random.default_rng(seed)
    acc = np.zeros((size, size), dtype=np.float32)
    weight_sum = 0.0
    for freq, weight in octaves:
        grid = rng.random((freq, freq), dtype=np.float32)
        # Upsample with periodic wrapping via 3x3 tiling + bilinear PIL resize
        tiled = np.tile(grid, (3, 3))
        img = Image.fromarray((tiled * 255.0).astype(np.uint8), mode="L")
        up = np.asarray(img.resize((size * 3, size * 3), Image.Resampling.BICUBIC), dtype=np.float32) / 255.0
        acc += up[size : size * 2, size : size * 2] * weight
        weight_sum += weight
    out = acc / max(weight_sum, 1e-6)
    return np.clip(out, 0.0, 1.0)


def height_to_normal(height: np.ndarray, strength: float = 4.0) -> np.ndarray:
    """Convert a tileable [0, 1] heightmap into a tangent-space RGB normal map (OpenGL +Y up / Roblox)."""
    h = height.astype(np.float32)
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5 * strength
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5 * strength
    nx = -dx
    ny = -dy
    nz = np.ones_like(h)
    inv_len = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz + 1e-8)
    nx *= inv_len
    ny *= inv_len
    nz *= inv_len
    rgb = np.stack([(nx * 0.5 + 0.5), (ny * 0.5 + 0.5), (nz * 0.5 + 0.5)], axis=-1)
    return np.clip(rgb * 255.0, 0, 255).astype(np.uint8)


def save_pbr_set(name: str, color: np.ndarray, height: np.ndarray, rough: np.ndarray, metal: np.ndarray, normal_strength: float) -> Image.Image:
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


def panel_seam_mask(size: int, step: int, seam_width: int = 3) -> tuple[np.ndarray, np.ndarray]:
    """Return (seam_depth [0..1], edge_wear [0..1]) aligned to periodic square tiles."""
    yy, xx = np.mgrid[0:size, 0:size]
    mx = np.minimum(xx % step, step - (xx % step))
    my = np.minimum(yy % step, step - (yy % step))
    d = np.minimum(mx, my).astype(np.float32)
    seam = np.clip(1.0 - d / float(seam_width), 0.0, 1.0)
    edge = np.clip(1.0 - np.abs(d - float(seam_width + 3)) / 5.0, 0.0, 1.0)
    return seam, edge


def rivet_mask(size: int, step: int, offset: int = 18, spacing: int = 64, radius: float = 5.0) -> np.ndarray:
    """Periodic rivets stamped along panel borders."""
    mask = np.zeros((size, size), dtype=np.float32)
    yy, xx = np.mgrid[0:size, 0:size]
    pts: list[tuple[int, int]] = []
    for base_y in range(0, size, step):
        for p in range(offset, step - offset + 1, spacing):
            pts.append((base_y + offset, (base_y * 0 + p) % size))
        for base_x in range(0, size, step):
            for p in range(offset, step - offset + 1, spacing):
                pts.append(((base_y + p) % size, (base_x + offset) % size))
                pts.append(((base_y + step - offset) % size, (base_x + p) % size))
                pts.append(((base_y + offset) % size, (base_x + p) % size))
                pts.append(((base_y + p) % size, (base_x + step - offset) % size))
    pts = list(set((y % size, x % size) for y, x in pts))
    r2 = radius * radius
    pad = int(radius + 2)
    for ry, rx in pts:
        for dy in range(-pad, pad + 1):
            for dx in range(-pad, pad + 1):
                dist2 = dx * dx + dy * dy
                if dist2 <= r2:
                    mask[(ry + dy) % size, (rx + dx) % size] = max(
                        mask[(ry + dy) % size, (rx + dx) % size],
                        1.0 - (dist2 / r2) ** 1.4,
                    )
    return mask


def build_concrete_floor() -> Image.Image:
    n_macro = periodic_noise(SIZE, [(4, 0.55), (10, 0.3), (24, 0.15)], seed=101)
    n_micro = periodic_noise(SIZE, [(32, 0.5), (96, 0.5)], seed=102)
    n_oil = periodic_noise(SIZE, [(3, 0.6), (7, 0.4)], seed=103)
    seam, edge = panel_seam_mask(SIZE, 256, seam_width=4)

    # Dark oiled patches + chalky worn centers + dark expansion joints
    oil_patch = np.clip((n_oil - 0.54) * 3.2, 0.0, 1.0)
    grime = seam * 0.65 + oil_patch * 0.45

    base_rgb = np.zeros((SIZE, SIZE, 3), dtype=np.float32)
    base_rgb[..., 0] = 0.25 + 0.09 * n_macro + 0.05 * n_micro - 0.12 * grime + 0.05 * edge * n_micro
    base_rgb[..., 1] = 0.27 + 0.09 * n_macro + 0.05 * n_micro - 0.13 * grime + 0.05 * edge * n_micro
    base_rgb[..., 2] = 0.31 + 0.09 * n_macro + 0.05 * n_micro - 0.13 * grime + 0.05 * edge * n_micro

    height = np.clip(0.6 + 0.18 * n_micro + 0.12 * n_macro - 0.55 * seam, 0.0, 1.0)
    rough = np.clip(0.84 - 0.42 * oil_patch + 0.10 * (n_micro - 0.5) - 0.08 * edge, 0.18, 0.96)
    metal = np.full((SIZE, SIZE), 0.04, dtype=np.float32)
    return save_pbr_set("Ind_ConcreteFloor", base_rgb, height, rough, metal, normal_strength=4.5)


def build_gunmetal_wall() -> Image.Image:
    n_macro = periodic_noise(SIZE, [(4, 0.5), (12, 0.35), (28, 0.15)], seed=201)
    n_scuff = periodic_noise(SIZE, [(24, 0.45), (72, 0.55)], seed=202)
    # Vertical condensation / oil drip streaks (stretch vertically)
    n_streaks_base = periodic_noise(SIZE, [(18, 0.6), (48, 0.4)], seed=203)
    streak = np.clip(np.roll(n_streaks_base, 12, axis=0) * 0.5 + n_streaks_base * 0.5 - 0.48, 0.0, 0.5) * 1.8
    seam_big, edge_big = panel_seam_mask(SIZE, 512, seam_width=5)
    seam_sub, edge_sub = panel_seam_mask(SIZE, 256, seam_width=3)
    seam = np.maximum(seam_big, seam_sub * 0.7)
    edge = np.maximum(edge_big, edge_sub * 0.65)
    rivets = rivet_mask(SIZE, 256, offset=18, spacing=64, radius=4.8)

    wear = np.clip(edge * (0.4 + 0.8 * n_scuff) + np.clip((n_scuff - 0.72) * 3.0, 0.0, 0.6), 0.0, 1.0)
    soot = np.clip(seam * 0.75 + streak * 0.55 + (1.0 - n_macro) * 0.25, 0.0, 1.0)

    base_rgb = np.zeros((SIZE, SIZE, 3), dtype=np.float32)
    base_rgb[..., 0] = 0.20 + 0.08 * n_macro - 0.10 * soot + 0.24 * wear + 0.10 * rivets
    base_rgb[..., 1] = 0.23 + 0.08 * n_macro - 0.11 * soot + 0.25 * wear + 0.11 * rivets
    base_rgb[..., 2] = 0.28 + 0.09 * n_macro - 0.11 * soot + 0.26 * wear + 0.12 * rivets

    height = np.clip(0.55 + 0.08 * n_scuff + 0.36 * rivets - 0.52 * seam, 0.0, 1.0)
    rough = np.clip(0.52 + 0.28 * soot - 0.26 * wear - 0.18 * rivets, 0.16, 0.92)
    metal = np.clip(0.76 - 0.35 * soot + 0.20 * wear, 0.25, 0.98)
    return save_pbr_set("Ind_GunmetalWall", base_rgb, height, rough, metal, normal_strength=6.0)


def build_diamond_tread() -> Image.Image:
    n_wear = periodic_noise(SIZE, [(6, 0.55), (20, 0.3), (64, 0.15)], seed=301)
    yy, xx = np.mgrid[0:SIZE, 0:SIZE]
    cell = 64.0
    u = ((xx % cell) / cell) - 0.5
    v = ((yy % cell) / cell) - 0.5
    # Alternating 45-deg / -45-deg raised diamond lugs per checkerboard subcell
    checker = ((xx // int(cell)) + (yy // int(cell))) % 2
    p1 = u * 0.7071 + v * 0.7071
    p2 = -u * 0.7071 + v * 0.7071
    along = np.where(checker == 0, p1, p2)
    across = np.where(checker == 0, p2, p1)
    lug = np.clip(1.0 - (np.abs(along) / 0.34) ** 2 - (np.abs(across) / 0.13) ** 2, 0.0, 1.0)
    lug = np.power(lug, 0.55)

    valley_grime = (1.0 - lug) * (0.45 + 0.45 * (1.0 - n_wear))
    peak_polish = lug * (0.45 + 0.55 * n_wear)

    base_rgb = np.zeros((SIZE, SIZE, 3), dtype=np.float32)
    base_rgb[..., 0] = 0.18 + 0.28 * peak_polish - 0.09 * valley_grime
    base_rgb[..., 1] = 0.20 + 0.30 * peak_polish - 0.10 * valley_grime
    base_rgb[..., 2] = 0.24 + 0.32 * peak_polish - 0.10 * valley_grime

    height = np.clip(0.25 + 0.70 * lug + 0.05 * n_wear, 0.0, 1.0)
    rough = np.clip(0.72 - 0.46 * peak_polish + 0.16 * valley_grime, 0.18, 0.94)
    metal = np.clip(0.55 + 0.42 * peak_polish - 0.30 * valley_grime, 0.20, 0.98)
    return save_pbr_set("Ind_DiamondTread", base_rgb, height, rough, metal, normal_strength=7.5)


def build_forge_soot_metal() -> Image.Image:
    n_macro = periodic_noise(SIZE, [(3, 0.45), (9, 0.35), (24, 0.2)], seed=401)
    n_micro = periodic_noise(SIZE, [(28, 0.5), (84, 0.5)], seed=402)
    seam, edge = panel_seam_mask(SIZE, 256, seam_width=4)
    rivets = rivet_mask(SIZE, 256, offset=20, spacing=85, radius=4.2)

    rust = np.clip((n_macro - 0.48) * 2.4, 0.0, 1.0)
    soot = np.clip(seam * 0.8 + (1.0 - n_macro) * 0.45, 0.0, 1.0)
    wear = np.clip(edge * n_micro * 1.1, 0.0, 1.0)

    base_rgb = np.zeros((SIZE, SIZE, 3), dtype=np.float32)
    base_rgb[..., 0] = 0.22 + 0.18 * rust - 0.11 * soot + 0.16 * wear
    base_rgb[..., 1] = 0.16 + 0.08 * rust - 0.09 * soot + 0.15 * wear
    base_rgb[..., 2] = 0.15 + 0.03 * rust - 0.08 * soot + 0.14 * wear

    height = np.clip(0.54 + 0.14 * n_micro + 0.32 * rivets - 0.50 * seam, 0.0, 1.0)
    rough = np.clip(0.58 + 0.28 * soot + 0.18 * rust - 0.30 * wear, 0.20, 0.95)
    metal = np.clip(0.72 - 0.45 * soot - 0.35 * rust + 0.22 * wear, 0.15, 0.96)
    return save_pbr_set("Ind_ForgeSootMetal", base_rgb, height, rough, metal, normal_strength=6.5)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    previews = [
        ("ConcreteFloor", build_concrete_floor()),
        ("GunmetalWall", build_gunmetal_wall()),
        ("DiamondTread", build_diamond_tread()),
        ("ForgeSootMetal", build_forge_soot_metal()),
    ]
    sheet = Image.new("RGB", (1024, 1024))
    draw = ImageDraw.Draw(sheet)
    positions = [(0, 0), (512, 0), (0, 512), (512, 512)]
    for (label, im), (px, py) in zip(previews, positions):
        sheet.paste(im.resize((512, 512), Image.Resampling.LANCZOS), (px, py))
        draw.rectangle([px + 8, py + 8, px + 180, py + 34], fill=(16, 20, 26))
        draw.text((px + 14, py + 14), f"Ind_{label}", fill=(0, 210, 255))
    sheet.save(OUT_DIR / "preview_sheet.png")
    print(f"Generated 4 tileable 1024x1024 PBR sets in {OUT_DIR} (+ preview_sheet.png)")


if __name__ == "__main__":
    main()
