"""Downscale source textures to Roblox's 1024 upload ceiling and flip DirectX
normal maps to the OpenGL convention Roblox expects.

    python tools/blender/resize_textures.py <out_dir> <src.png>[:normal_dx] ...
"""
import os
import sys

from PIL import Image

MAX = 1024


def convert(src, out_dir, flip_green):
    im = Image.open(src)
    before = im.size
    if im.mode not in ("RGB", "RGBA", "L"):
        im = im.convert("L" if flip_green is False and im.mode == "I;16" else "RGBA")
    if im.mode == "I;16":
        im = im.convert("L")
    if max(im.size) > MAX:
        im.thumbnail((MAX, MAX), Image.LANCZOS)
    if flip_green:
        if im.mode == "L":
            raise SystemExit(f"{src}: normal map is single channel, cannot flip green")
        bands = list(im.split())
        bands[1] = bands[1].point(lambda v: 255 - v)
        im = Image.merge(im.mode, tuple(bands))
    name = os.path.basename(src)
    dst = os.path.join(out_dir, name)
    os.makedirs(out_dir, exist_ok=True)
    im.save(dst, optimize=True)
    print(f"  {name}: {before[0]}x{before[1]} -> {im.size[0]}x{im.size[1]}"
          f"{' (green flipped)' if flip_green else ''} "
          f"{os.path.getsize(src) / 1e6:.2f}MB -> {os.path.getsize(dst) / 1e6:.2f}MB")
    return dst


def main():
    out_dir = sys.argv[1]
    for spec in sys.argv[2:]:
        src, _, tag = spec.partition("::")
        convert(src, out_dir, tag == "normal_dx")


if __name__ == "__main__":
    main()
