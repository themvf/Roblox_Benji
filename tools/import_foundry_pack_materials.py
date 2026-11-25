#!/usr/bin/env python3
"""
Package curated seamless PBR textures from UndergroundFacilityProps/eU_Textures
into assets/environment/materials/industrial-foundry-v1/ at Roblox's 1024x1024
ceiling with OpenGL (+Y up) normal orientation and calibrated Color/Metalness maps.

Usage:
  python tools/import_foundry_pack_materials.py
"""
from pathlib import Path
import shutil
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
EU_DIR = ROOT / "UndergroundFacilityProps" / "eU_Textures" / "eU_Textures" / "textures"
OUT_DIR = ROOT / "assets" / "environment" / "materials" / "industrial-foundry-v1"
BACKUP_DIR = ROOT / ".mapbuild" / "industrial-foundry-v1-backup"
SIZE = 1024

TARGETS = [
    {
        "variant": "Ind_ConcreteFloor",
        "src_stem": "eU_floortile2",
        "metal_base": 0.14,
        "metal_range": (0.04, 0.28),
        "gamma": 0.80,
    },
    {
        "variant": "Ind_GunmetalWall",
        "src_stem": "eU_wallpanel3",
        "metal_base": 0.72,
        "metal_range": (0.25, 0.90),
        "gamma": 0.78,
    },
    {
        "variant": "Ind_DiamondTread",
        "src_stem": "eU_floorclang2",
        "metal_base": 0.78,
        "metal_range": (0.35, 0.94),
        "gamma": 0.78,
    },
    {
        "variant": "Ind_ForgeSootMetal",
        "src_stem": "eU_floordiamond",
        "metal_base": 0.66,
        "metal_range": (0.20, 0.88),
        "gamma": 0.78,
    },
]


def backup_existing() -> None:
    if not OUT_DIR.exists():
        return
    if BACKUP_DIR.exists():
        shutil.rmtree(BACKUP_DIR)
    shutil.copytree(OUT_DIR, BACKUP_DIR)
    print(f"Backed up previous materials to {BACKUP_DIR.relative_to(ROOT)}")


def load_resized(path: Path, mode: str) -> Image.Image:
    with Image.open(path) as im:
        conv = im.convert(mode)
        if conv.size != (SIZE, SIZE):
            conv = conv.resize((SIZE, SIZE), Image.Resampling.LANCZOS)
        return conv


def convert_variant(spec: dict) -> tuple[str, Image.Image]:
    stem = spec["src_stem"]
    variant = spec["variant"]
    mat_dir = OUT_DIR / variant
    mat_dir.mkdir(parents=True, exist_ok=True)

    # Color: gentle gamma lift so dark Part.Color modulation doesn't crush seam details
    bc_img = load_resized(EU_DIR / f"{stem}_BaseColor.png", "RGB")
    bc_arr = np.asarray(bc_img, dtype=np.float32) / 255.0
    bc_lifted = np.clip(np.power(bc_arr, spec["gamma"]), 0.0, 1.0)
    color_out = Image.fromarray((bc_lifted * 255.0).astype(np.uint8), mode="RGB")
    color_out.save(mat_dir / f"{variant}_Color.png", optimize=True)

    # Normal: eU_Textures stores DirectX (+dH/dy_screen in G); flip G for Roblox OpenGL
    nm_img = load_resized(EU_DIR / f"{stem}_Normal.png", "RGB")
    r, g, b = nm_img.split()
    g = g.point(lambda v: 255 - v)
    Image.merge("RGB", (r, g, b)).save(mat_dir / f"{variant}_Normal.png", optimize=True)

    # Roughness
    rg_img = load_resized(EU_DIR / f"{stem}_Roughness.png", "L")
    rg_img.save(mat_dir / f"{variant}_Roughness.png", optimize=True)

    # Metalness: higher on polished steel ridges (low roughness), lower in grime/rust valleys
    rg_arr = np.asarray(rg_img, dtype=np.float32) / 255.0
    m_lo, m_hi = spec["metal_range"]
    metal_arr = np.clip(spec["metal_base"] + (0.55 - rg_arr) * 0.45, m_lo, m_hi)
    Image.fromarray((metal_arr * 255.0).astype(np.uint8), mode="L").save(
        mat_dir / f"{variant}_Metalness.png", optimize=True
    )
    print(f"Prepared {variant} from {stem} -> {mat_dir.relative_to(ROOT)}")
    return variant, color_out


def main() -> None:
    if not EU_DIR.exists():
        raise SystemExit(f"Missing eU_Textures folder: {EU_DIR}")
    backup_existing()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGB", (1024, 1024))
    draw = ImageDraw.Draw(sheet)
    positions = [(0, 0), (512, 0), (0, 512), (512, 512)]
    for spec, (px, py) in zip(TARGETS, positions):
        variant, c_img = convert_variant(spec)
        sheet.paste(c_img.resize((512, 512), Image.Resampling.LANCZOS), (px, py))
        draw.rectangle([px + 8, py + 8, px + 260, py + 36], fill=(16, 20, 26))
        draw.text((px + 14, py + 14), f"{variant} ({spec['src_stem']})", fill=(0, 210, 255))
    sheet.save(OUT_DIR / "preview_sheet.png")
    print(f"Updated preview sheet: {(OUT_DIR / 'preview_sheet.png').relative_to(ROOT)}")


if __name__ == "__main__":
    main()
