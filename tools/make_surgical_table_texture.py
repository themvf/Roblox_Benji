"""Create a deterministic subtle blue vinyl map for the surgical table."""
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/models/surgical-table/textures"
OUT.mkdir(parents=True, exist_ok=True)
size = 1024
rng = np.random.default_rng(8019)
noise = rng.normal(0, 1.25, (size, size, 1))
yy, xx = np.mgrid[:size, :size]
weave = 0.85 * np.sin(xx * np.pi / 3) * np.sin(yy * np.pi / 3)
shade = noise + weave[:, :, None]
base = np.array([70, 120, 151], dtype=np.float32)
rgb = np.uint8(np.clip(base + shade, 0, 255))
rgba = np.concatenate([rgb, np.full((size, size, 1), 255, dtype=np.uint8)], axis=2)
Image.fromarray(rgba, "RGBA").save(OUT / "SurgicalTable_BlueVinyl_Color.png")
