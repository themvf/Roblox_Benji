"""Hand-modelled parts, bored muzzles and surface maps for the Plasma Blaster's Meshy scan, run by
scene_kit's `extraParts` step.

Source: Meshy image-to-3D at 30,000 triangles (seed 202), collapsed to 8,000 under a budget waiver, with
a normal map baked from the full mesh (`bakeNormals`). The scan's painted plasma swirl is split into its
own mesh `Plasma` by the brief's `split` (colour inside the window box). This file adds:

    Core       a Neon-ready glowing loft inside the window, narrower than the swirl so the swirl stays
               in front from the side, but tall enough to fill the dark gaps above and below it.
    bores      both muzzles were solid caps. Each is cut open with a boolean and lined with a dark
               inward-facing tube and a closed back, so head-on it reads as a deep hole.
    surface    a metallic-roughness map from the base colour: gunmetal greys get some metal, rust paint
               stays matte, the plasma is smooth. The Roblox importer turns it into a SurfaceAppearance.
    paint      rust pixels get a modest saturation lift toward the concept's (168, 66, 42).

Frame: the export's frame after `pivot` (Blender, Z up, muzzle toward -Y), measured on the 8,000-triangle
export on 2026-11-23: plasma swirl y -0.75..0.30, z 0.13..0.44, x within +-0.07 at the front and +-0.15 at
the back; window side walls open between z 0.22 and 0.48; top barrel face y -2.073, axis z 0.345,
radius 0.10; lower emitter face y -1.995, axis z 0.09, radius 0.03.
"""

import colorsys
import math
from pathlib import Path

import bmesh
import bpy
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
PALETTE_PNG = ROOT / "assets/models/plasma-blaster/textures/PlasmaBlasterParts_Palette.png"

PALETTE = [("plasma", (255, 120, 24)), ("bore", (8, 8, 10)), ("spare", (0, 0, 0)), ("spare2", (0, 0, 0))]
COLS, SWATCH = 4, 8
SATURATION_GAIN = 1.15

# (face y, axis z, radius of the opening, depth) for each muzzle
BORES = [("BoreTop", -2.073, 0.345, 0.066, 0.13, 16), ("BoreLow", -1.995, 0.09, 0.02, 0.06, 10)]


def finish(bm, name, colour):
    uv = bm.loops.layers.uv.new("UVMap")
    i = [p[0] for p in PALETTE].index(colour)
    for face in bm.faces:
        for loop in face.loops:
            loop[uv].uv = ((i + 0.5) / COLS, 0.5)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = False
    ob = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(ob)
    return ob


def ring(bm, y, cx, cz, rx, rz, sides=8):
    return [
        bm.verts.new((cx + rx * math.cos(2 * math.pi * (k + 0.5) / sides), y, cz + rz * math.sin(2 * math.pi * (k + 0.5) / sides)))
        for k in range(sides)
    ]


def loft_bm(stations, sides=8, cap_front=True, cap_back=True):
    """stations: (y, cx, cz, rx, rz) cross-sections along the gun; outward normals."""
    bm = bmesh.new()
    rings = [ring(bm, *s, sides=sides) for s in stations]
    for a, b in zip(rings, rings[1:]):
        for k in range(sides):
            n = (k + 1) % sides
            bm.faces.new((a[k], a[n], b[n], b[k]))
    if cap_front:
        bm.faces.new(rings[0])
    if cap_back:
        bm.faces.new(list(reversed(rings[-1])))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return bm


def loft(name, stations, colour, sides=8):
    return finish(loft_bm(stations, sides), name, colour)


def liner(name, face_y, z, r, depth, sides):
    """A tube open at the muzzle, closed at the back, normals facing in: the inside of a bore."""
    bm = bmesh.new()
    a = ring(bm, face_y + 0.002, 0.0, z, r, r, sides)
    b = ring(bm, face_y + depth, 0.0, z, r, r, sides)
    for k in range(sides):
        n = (k + 1) % sides
        bm.faces.new((a[k], b[k], b[n], a[n]))
    bm.faces.new(b)
    bm.normal_update()
    # Face toward the axis and toward the muzzle; recalc would point them outward.
    for f in bm.faces:
        c = f.calc_center_median()
        inward = (0.0 - c.x, 0.0, z - c.z) if f.calc_area() and abs(f.normal.y) < 0.5 else (0.0, -1.0, 0.0)
        if f.normal.dot(inward) < 0:
            f.normal_flip()
    return finish(bm, name, "bore")


def bore_out(body, face_y, z, r, depth, sides):
    """Cut the muzzle open: boolean a cylinder out of the scan body."""
    cutter = finish(loft_bm([(face_y - 0.05, 0.0, z, r, r), (face_y + depth, 0.0, z, r, r)], sides), "cutter", "bore")
    mod = body.modifiers.new("bore", "BOOLEAN")
    mod.operation = "DIFFERENCE"
    mod.solver = "EXACT"
    mod.object = cutter
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(cutter, do_unlink=True)


def palette_image():
    width, height = COLS * SWATCH, SWATCH
    pixels = []
    for _ in range(height):
        for col in range(width):
            pixels += [c / 255 for c in PALETTE[col // SWATCH][1]] + [1.0]
    image = bpy.data.images.new("PlasmaBlasterParts_Palette", width, height, alpha=False)
    image.pixels = pixels
    PALETTE_PNG.parent.mkdir(parents=True, exist_ok=True)
    image.filepath_raw = str(PALETTE_PNG)
    image.file_format = "PNG"
    image.save()
    return bpy.data.images.load(str(PALETTE_PNG), check_existing=False)


def material(image, name, roughness=0.5):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes["Principled BSDF"].inputs["Roughness"].default_value = roughness
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Closest"
    links.new(tex.outputs["Color"], nodes["Principled BSDF"].inputs["Base Color"])
    return mat


def scan_texture(ob):
    for slot in ob.material_slots:
        mat = slot.material
        if mat and mat.use_nodes:
            for node in mat.node_tree.nodes:
                if node.type == "TEX_IMAGE" and node.image:
                    return mat, node.image
    return None, None


def hsv(px):
    rgb = px[..., :3]
    top, low = rgb.max(-1), rgb.min(-1)
    span = top - low
    safe = np.where(span == 0, 1, span)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hue = np.where(top == r, ((g - b) / safe) % 6, np.where(top == g, (b - r) / safe + 2, (r - g) / safe + 4)) * 60.0
    hue = np.where(span == 0, 0, hue)
    sat = np.where(top == 0, 0, span / np.where(top == 0, 1, top))
    return hue, sat, top


def surface_maps(body):
    """Saturate the rust, and add a metallic-roughness map read from the base colour."""
    mat, image = scan_texture(body)
    if image is None:
        raise SystemExit("parts_plasma_blaster: the scan has no texture")
    w, h = image.size
    px = np.array(image.pixels[:], dtype=np.float32).reshape(h, w, 4)
    hue, sat, val = hsv(px)
    rust = ((hue <= 20) | (hue >= 340)) & (sat > 0.3) & (val > 0.15) & (val < 0.85)
    for y, x in zip(*np.nonzero(rust)):
        r, g, b = colorsys.hsv_to_rgb((10 if hue[y, x] <= 20 else hue[y, x]) / 360, min(1.0, sat[y, x] * SATURATION_GAIN), val[y, x])
        px[y, x, :3] = (r, g, b)
    image.pixels[:] = px.ravel()
    image.update()
    image.pack()
    print("  paint    %s: %d rust pixels saturated x%.2f" % (image.name, int(rust.sum()), SATURATION_GAIN))

    # Metal only on the dark gunmetal: light greys at metal 0.45 read as chrome stripes on the window
    # frame (first glow preview, 2026-11-23).
    grey = sat < 0.25
    dark = grey & (val < 0.45)
    hot = (hue >= 20) & (hue <= 60) & (sat > 0.45) & (val > 0.6)
    metal = np.where(dark, 0.35, 0.0)
    rough = np.where(dark, 0.45, np.where(grey, 0.58, np.where(hot, 0.3, 0.62)))
    mr = np.ones((h, w, 4), dtype=np.float32)
    mr[..., 0] = 0.0
    mr[..., 1] = rough
    mr[..., 2] = metal
    mr_image = bpy.data.images.new("PlasmaBlaster_MetalRough", w, h, alpha=False)
    mr_image.colorspace_settings.name = "Non-Color"
    mr_image.pixels[:] = mr.ravel()
    mr_image.pack()
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = mr_image
    split = nodes.new("ShaderNodeSeparateColor")
    links.new(tex.outputs["Color"], split.inputs["Color"])
    links.new(split.outputs["Green"], bsdf.inputs["Roughness"])
    links.new(split.outputs["Blue"], bsdf.inputs["Metallic"])
    print("  surface  metal-rough map: %.0f%% gunmetal, %.0f%% plasma" % (100 * grey.mean(), 100 * hot.mean()))


def uv_mask(ob, w, h):
    """Texels covered by a mesh's UV triangles."""
    mask = np.zeros((h, w), dtype=bool)
    uv = ob.data.uv_layers.active.data
    for poly in ob.data.polygons:
        pts = [(uv[i].uv.x * w, uv[i].uv.y * h) for i in poly.loop_indices]
        for k in range(1, len(pts) - 1):
            (ax, ay), (bx, by), (cx, cy) = pts[0], pts[k], pts[k + 1]
            x0, x1 = int(max(0, min(ax, bx, cx) - 1)), int(min(w - 1, max(ax, bx, cx) + 1))
            y0, y1 = int(max(0, min(ay, by, cy) - 1)), int(min(h - 1, max(ay, by, cy) + 1))
            if x1 < x0 or y1 < y0:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
            d = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
            if abs(d) < 1e-9:
                continue
            l1 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / d
            l2 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / d
            inside = (l1 >= -0.02) & (l2 >= -0.02) & (1 - l1 - l2 >= -0.02)
            mask[y0 : y1 + 1, x0 : x1 + 1] |= inside
    return mask


def molten(final):
    """Lift the painted swirl toward molten yellow-orange, only inside the split Plasma mesh's texels: the
    Meshy swirl was dark red with yellow streaks and read as meat beside the Neon core."""
    plasma = next((o for o in final if o.name == "Plasma"), None)
    if plasma is None:
        return
    _, image = scan_texture(plasma)
    w, h = image.size
    mask = uv_mask(plasma, w, h)
    px = np.array(image.pixels[:], dtype=np.float32).reshape(h, w, 4)
    hue, sat, val = hsv(px)
    for y, x in zip(*np.nonzero(mask)):
        hh = hue[y, x]
        hh = hh + (28 - hh) * 0.5 if hh < 60 or hh > 300 else hh  # pull reds and yellows toward orange
        r, g, b = colorsys.hsv_to_rgb((hh % 360) / 360, min(1.0, sat[y, x] * 0.95), min(1.0, 0.45 + val[y, x] * 0.75))
        px[y, x, :3] = (r, g, b)
    image.pixels[:] = px.ravel()
    image.update()
    image.pack()
    print("  molten   %d swirl texels brightened" % int(mask.sum()))


def add(final):
    body = final[0]
    surface_maps(body)
    molten(final)
    for name, face_y, z, r, depth, sides in BORES:
        bore_out(body, face_y, z, r, depth, sides)
    image = palette_image()
    core = loft(
        "Core",
        [
            (-0.70, 0.0, 0.33, 0.03, 0.06),
            (-0.62, 0.0, 0.335, 0.05, 0.125),
            (-0.30, 0.0, 0.335, 0.06, 0.135),
            (0.00, 0.0, 0.33, 0.08, 0.14),
            (0.22, 0.0, 0.32, 0.09, 0.14),
            (0.30, 0.0, 0.32, 0.06, 0.09),
        ],
        "plasma",
        sides=10,
    )
    core.data.materials.append(material(image, "PlasmaBlasterCore", 0.3))
    added = [core]
    bore_mat = material(image, "PlasmaBlasterBore", 0.8)
    for name, face_y, z, r, depth, sides in BORES:
        ob = liner(name, face_y, z, r * 0.98, depth, sides)
        ob.data.materials.append(bore_mat)
        added.append(ob)
    return added
