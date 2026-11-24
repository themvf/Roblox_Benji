"""Repaint the Pulse Rifle's muzzle window as a violet glow, in place in source/PulseRifle.glb.

Meshy baked the reflection in the user's picture (blue sky, a red stripe) into the window.
This selects the window faces (the recess inside the dark muzzle frame at the -X end of the
Meshy source, which the build turns to -Z), fills their texels with a radial gradient from
bright lavender to deep violet, and swaps only the base-colour image inside the GLB.

    python assets/models/pulse-rifle/paint_muzzle.py [--preview out.png]

The untouched Meshy model stays at trials/seed-201/candidate.glb; rerunning starts from it.
"""

import argparse
import io
import json
import struct
from pathlib import Path

import numpy as np
import trimesh
from PIL import Image

PKG = Path(__file__).resolve().parent
ORIGINAL = PKG / "trials/seed-201/candidate.glb"
SOURCE = PKG / "source/PulseRifle.glb"

# Window opening in the Meshy source's own axes (studs before scaling; x is the barrel).
X_RANGE = (-0.925, -0.84)
Y_RANGE = (-0.005, 0.15)
Z_RANGE = (-0.072, 0.066)
CENTRE = np.array([0.072, -0.003])  # y, z
INNER = np.array([255, 236, 255], float)  # hot core
OUTER = np.array([132, 48, 236], float)  # deep violet at the frame
PAD = 3  # texels grown past each triangle so filtering does not bleed sky back in


def window_faces(mesh):
    c = mesh.triangles_center
    return np.where(
        (c[:, 0] > X_RANGE[0])
        & (c[:, 0] < X_RANGE[1])
        & (c[:, 1] > Y_RANGE[0])
        & (c[:, 1] < Y_RANGE[1])
        & (c[:, 2] > Z_RANGE[0])
        & (c[:, 2] < Z_RANGE[1])
    )[0]


def paint(mesh, image):
    W, H = image.size
    px = np.asarray(image.convert("RGB")).astype(float).copy()
    painted = np.zeros((H, W), bool)
    half = np.array([(Y_RANGE[1] - Y_RANGE[0]) / 2, (Z_RANGE[1] - Z_RANGE[0]) / 2])
    for f in window_faces(mesh):
        tri = mesh.faces[f]
        uv = mesh.visual.uv[tri] * [W, H]
        uv[:, 1] = H - uv[:, 1]
        pos = mesh.vertices[tri][:, 1:3]
        x0, y0 = np.floor(uv.min(0)).astype(int) - PAD
        x1, y1 = np.ceil(uv.max(0)).astype(int) + PAD
        xs, ys = np.meshgrid(np.arange(max(x0, 0), min(x1, W)), np.arange(max(y0, 0), min(y1, H)))
        p = np.stack([xs.ravel() + 0.5, ys.ravel() + 0.5], 1)
        a, b, c = uv
        m = np.array([b - a, c - a]).T
        if abs(np.linalg.det(m)) < 1e-9:
            continue
        l12 = np.linalg.solve(m, (p - a).T).T
        bary = np.column_stack([1 - l12.sum(1), l12])
        # Inside, or within PAD texels of an edge (approximated in barycentric terms).
        tol = PAD / max(np.linalg.norm(b - a), np.linalg.norm(c - a), np.linalg.norm(c - b), 1)
        keep = (bary > -tol).all(1)
        if not keep.any():
            continue
        yz = np.clip(bary[keep], 0, None)
        yz = (yz / yz.sum(1, keepdims=True)) @ pos
        r = np.clip(np.linalg.norm((yz - CENTRE) / half, axis=1), 0, 1) ** 1.4
        colour = INNER * (1 - r[:, None]) + OUTER * r[:, None]
        X, Y = p[keep, 0].astype(int), p[keep, 1].astype(int)
        px[Y, X] = colour
        painted[Y, X] = True
    return Image.fromarray(px.clip(0, 255).astype(np.uint8)), painted.sum()


def replace_base_colour(glb_in, glb_out, image):
    data = glb_in.read_bytes()
    magic, version, _ = struct.unpack_from("<III", data, 0)
    assert magic == 0x46546C67, "not a GLB"
    jlen, jtype = struct.unpack_from("<II", data, 12)
    gltf = json.loads(data[20 : 20 + jlen])
    blen, _ = struct.unpack_from("<II", data, 20 + jlen)
    binary = data[28 + jlen : 28 + jlen + blen]

    mat = gltf["materials"][0]["pbrMetallicRoughness"]["baseColorTexture"]["index"]
    img_index = gltf["textures"][mat]["source"]
    img = gltf["images"][img_index]
    buf = io.BytesIO()
    if img.get("mimeType") == "image/png":
        image.save(buf, "PNG")
    else:
        image.save(buf, "JPEG", quality=95)
    new = buf.getvalue()

    # Rebuild the binary chunk with the one view resized; shift the views after it.
    target = img["bufferView"]
    views = gltf["bufferViews"]
    order = sorted(range(len(views)), key=lambda i: views[i].get("byteOffset", 0))
    out = bytearray()
    for i in order:
        v = views[i]
        chunk = new if i == target else binary[v.get("byteOffset", 0) : v.get("byteOffset", 0) + v["byteLength"]]
        while len(out) % 4:
            out.append(0)
        v["byteOffset"] = len(out)
        v["byteLength"] = len(chunk)
        out += chunk
    while len(out) % 4:
        out.append(0)
    gltf["buffers"][0]["byteLength"] = len(out)

    js = json.dumps(gltf, separators=(",", ":")).encode()
    js += b" " * (-len(js) % 4)
    total = 12 + 8 + len(js) + 8 + len(out)
    glb_out.write_bytes(
        struct.pack("<III", magic, version, total)
        + struct.pack("<II", len(js), 0x4E4F534A)
        + js
        + struct.pack("<II", len(out), 0x004E4942)
        + bytes(out)
    )


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", help="also save a crop of the painted texture here")
    a = ap.parse_args()
    scene = trimesh.load(ORIGINAL, force="scene")
    mesh = next(iter(scene.geometry.values()))
    texture = mesh.visual.material.baseColorTexture
    painted, n = paint(mesh, texture)
    print(f"window faces: {len(window_faces(mesh))}; texels painted: {n}")
    replace_base_colour(ORIGINAL, SOURCE, painted)
    print(f"wrote {SOURCE.relative_to(PKG.parents[2])}")
    if a.preview:
        painted.save(a.preview)


if __name__ == "__main__":
    main()
