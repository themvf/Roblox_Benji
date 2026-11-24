"""Clean hard-surface build of the Prism Blaster, modelled from the user's concept art. Blender 4.3, headless.

    blender -b -noaudio --python tools/blender/build_prism_blaster.py
    blender -b -noaudio --python tools/blender/build_prism_blaster.py -- --no-render

History: a first shape build was too plain, and a Meshy scan came out soft (wobbly panel lines, a
flat crystal) however it was cut or tinted (2026-11-22/23, "It still looks bad"). This build traces
the concept's side view (source/reference.png) with crisp chamfered blocks instead.

Units are studs. Blender Z is up and the muzzle points down -Y, which exports to glTF +Z and
arrives in Roblox facing -Z. Profile tables are (u, v): u runs from the stock butt (0) to the
muzzle face (4.0), v from the bottom of the grip (0) up. They were read off the concept at
284 px per stud along the gun and 322 px per stud up it (the picture is a three-quarter view).

Three meshes are exported, so Studio can give each its own material:
  Body    -- palette texture, SmoothPlastic;
  Crystal -- the faceted gem, each facet painted a light, mid or dark lavender so it reads as cut
             stone under any light; Glass at Transparency about 0.3 in Studio;
  Glow    -- the gem's core and the plate behind it in the window; Neon in Studio.
"""

import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "assets/models/prism-blaster"
EXPORT = PKG / "exports/PrismBlasterClean.glb"
PALETTE_PNG = PKG / "textures/PrismBlasterClean_Palette.png"
REVIEW = PKG / "review"

W = 0.33  # half width of the white shell
BORE_V = 1.18  # height of the muzzle axis
GEM = dict(u0=1.74, u1=2.98, v=0.955, half_height=0.30, half_width=0.40)

# Flat colours, sRGB 0-255, sampled from the concept.
PALETTE = [
    ("white", (232, 222, 230)),
    ("white_shade", (200, 188, 200)),
    ("plum", (112, 36, 86)),
    ("plum_dark", (74, 22, 58)),
    ("dark", (64, 61, 70)),
    ("black", (30, 28, 34)),
    ("bezel", (44, 38, 58)),
    ("gem_hi", (226, 206, 255)),
    ("gem_mid", (178, 146, 240)),
    ("gem_lo", (128, 94, 206)),
    ("glow", (150, 104, 240)),
    ("seam", (150, 138, 152)),
]
COLS, ROWS, SWATCH = 4, 3, 16
INDEX = {name: i for i, (name, _) in enumerate(PALETTE)}


class Builder:
    def __init__(self):
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    def _paint(self, faces, colour):
        i = INDEX[colour]
        u = (i % COLS + 0.5) / COLS
        v = 1 - (i // COLS + 0.5) / ROWS
        for face in faces:
            for loop in face.loops:
                loop[self.uv].uv = (u, v)

    def _finish(self, faces, colour):
        bmesh.ops.recalc_face_normals(self.bm, faces=faces)
        if colour:
            self._paint(faces, colour)
        return faces

    def loft(self, stations, colour, axis="y"):
        """Skin a closed shape through cross-sections, capped at both ends.

        axis "y": each station is (u, ring of (x, z)), placed at Blender y = -u.
        axis "x": each station is (x, ring of (u, v)), the side profile at that width.
        """
        rings = []
        for pos, ring in stations:
            if axis == "y":
                rings.append([self.bm.verts.new((a, -pos, b)) for a, b in ring])
            else:
                rings.append([self.bm.verts.new((pos, -a, b)) for a, b in ring])
        faces = []
        count = len(rings[0])
        for r0, r1 in zip(rings, rings[1:]):
            for i in range(count):
                j = (i + 1) % count
                faces.append(self.bm.faces.new((r0[i], r0[j], r1[j], r1[i])))
        faces.append(self.bm.faces.new(rings[0]))
        faces.append(self.bm.faces.new(list(reversed(rings[-1]))))
        return self._finish(faces, colour)

    def lathe(self, profile, colour, cz=BORE_V, cx=0.0, sides=24):
        """Revolve a (u, r) profile round a lengthwise axis; r == 0 is a single vertex on the axis."""
        rings = []
        for u, r in profile:
            if r <= 1e-6:
                rings.append(self.bm.verts.new((cx, -u, cz)))
            else:
                rings.append(
                    [self.bm.verts.new((cx + r * math.cos(2 * math.pi * k / sides), -u, cz + r * math.sin(2 * math.pi * k / sides))) for k in range(sides)]
                )
        faces = []
        for a, b in zip(rings, rings[1:]):
            for k in range(sides):
                n = (k + 1) % sides
                if isinstance(a, list) and isinstance(b, list):
                    faces.append(self.bm.faces.new((a[k], a[n], b[n], b[k])))
                elif isinstance(a, list):
                    faces.append(self.bm.faces.new((a[k], a[n], b)))
                elif isinstance(b, list):
                    faces.append(self.bm.faces.new((a, b[n], b[k])))
        return self._finish(faces, colour)

    def slab(self, profile, half_width, colour, bevel=0.03, x0=0.0):
        """Extrude a side profile (u, v) across the width, with chamfered side edges.
        The profile must be star-shaped about its centroid (the chamfer shrinks toward it)."""
        cu = sum(p[0] for p in profile) / len(profile)
        cv = sum(p[1] for p in profile) / len(profile)
        extent = min(max(p[0] for p in profile) - min(p[0] for p in profile), max(p[1] for p in profile) - min(p[1] for p in profile))
        bevel = min(bevel, half_width * 0.45)
        k = max(0.0, 1 - 2 * bevel / extent)
        small = [(cu + (u - cu) * k, cv + (v - cv) * k) for u, v in profile]
        stations = [
            (x0 - half_width, small),
            (x0 - half_width + bevel, profile),
            (x0 + half_width - bevel, profile),
            (x0 + half_width, small),
        ]
        return self.loft(stations, colour, axis="x")

    def block(self, u0, u1, z0, z1, half_width, colour, chamfer=0.04, x0=0.0):
        """A lengthwise block with chamfered long edges."""
        w, c = half_width, min(chamfer, half_width * 0.5, (z1 - z0) * 0.3)
        ring = [(x0 + p, q) for p, q in [(-w + c, z0), (w - c, z0), (w, z0 + c), (w, z1 - c), (w - c, z1), (-w + c, z1), (-w, z1 - c), (-w, z0 + c)]]
        return self.loft([(u0, ring), (u1, ring)], colour)

    def decal(self, profile, colour, x=W, depth=0.006):
        """A thin plate standing just proud of both sides of the shell: panel lines, marks, buttons."""
        for side in (-1, 1):
            self.slab(profile, depth, colour, bevel=depth * 0.4, x0=(x + depth * 0.5) * side)

    def shade_by_normal(self, faces, names):
        """Paint each facet light, mid or dark by how it faces a light above and to the side, so the
        cut reads on a flat-coloured or Glass part and not only under a real light."""
        for face in faces:
            n = face.normal
            d = 0.75 * n.z + 0.45 * abs(n.x) - 0.25 * n.y
            self._paint([face], names[0] if d > 0.62 else names[1] if d > 0.2 else names[2])


def gem_stations(scale_w=1.0, scale_h=1.0, scale_l=1.0):
    """Two lobed hexagonal crystals end to end, as in the concept's window."""
    cu = (GEM["u0"] + GEM["u1"]) / 2
    half_l = (GEM["u1"] - GEM["u0"]) / 2 * scale_l
    table = [
        (0.00, 0.34, 0.45),
        (0.12, 1.00, 1.00),
        (0.36, 1.00, 1.00),
        (0.47, 0.80, 0.82),
        (0.58, 1.00, 1.00),
        (0.86, 1.00, 1.00),
        (1.00, 0.34, 0.45),
    ]
    stations = []
    for frac, ws, hs in table:
        w = GEM["half_width"] * ws * scale_w
        h = GEM["half_height"] * hs * scale_h
        z = GEM["v"]
        ring = [  # a flat-sided hexagon: broad facets, like the concept's cut stone
            (0.0, z - h),
            (w, z - 0.45 * h),
            (w, z + 0.45 * h),
            (0.0, z + h),
            (-w, z + 0.45 * h),
            (-w, z - 0.45 * h),
        ]
        stations.append((cu - half_l + 2 * half_l * frac, ring))
    return stations


def build_body():
    b = Builder()

    # --- Stock: an open triangle of dark bars, as in the concept. ---
    b.slab([(0.00, 1.44), (0.80, 1.46), (0.80, 1.36), (0.05, 1.34)], 0.13, "dark", bevel=0.03)
    b.slab([(0.00, 1.44), (0.10, 1.40), (0.37, 0.77), (0.27, 0.71)], 0.13, "dark", bevel=0.03)
    b.slab([(0.27, 0.71), (0.37, 0.77), (0.70, 1.20), (0.60, 1.27)], 0.13, "dark", bevel=0.03)
    b.slab([(-0.02, 1.47), (0.04, 1.47), (0.06, 1.33), (0.30, 0.70), (0.24, 0.68)], 0.14, "black", bevel=0.02)  # butt pad
    b.block(0.66, 0.90, 1.12, 1.48, 0.20, "dark", chamfer=0.05)  # stock hinge

    # --- Receiver: the white rear body. ---
    b.slab([(0.80, 1.47), (1.66, 1.48), (1.66, 0.92), (0.90, 0.94), (0.80, 1.10)], W, "white", bevel=0.05)
    b.decal([(0.84, 1.27), (0.97, 1.27), (0.97, 1.19), (0.84, 1.19)], "black", depth=0.02)  # side switch
    b.decal([(1.02, 1.26), (1.08, 1.26), (1.08, 1.19), (1.02, 1.19)], "black", depth=0.02)
    b.decal([(1.24, 1.06), (1.35, 1.06), (1.30, 0.97)], "black", depth=0.015)  # trigger-side mark
    b.decal([(0.86, 1.36), (1.60, 1.38), (1.60, 1.37), (0.86, 1.35)], "seam")  # panel lines
    b.decal([(1.40, 1.37), (1.41, 1.37), (1.48, 0.93), (1.47, 0.93)], "seam")
    b.decal([(1.48, 1.12), (1.66, 1.12), (1.66, 1.11), (1.48, 1.11)], "seam")
    b.decal([(1.58, 1.30), (1.66, 1.30), (1.66, 1.00), (1.58, 1.00)], "dark", depth=0.01)  # bolt catch

    # --- Upper body over the crystal window, top rail and sights. ---
    b.block(1.62, 3.05, 1.28, 1.48, W, "white", chamfer=0.05)
    b.decal([(1.80, 1.405), (3.50, 1.405), (3.50, 1.39), (1.80, 1.39)], "seam")
    b.block(1.09, 3.66, 1.47, 1.55, 0.17, "dark", chamfer=0.025)
    b.block(1.12, 3.60, 1.545, 1.56, 0.08, "black", chamfer=0.005)
    b.slab([(1.20, 1.53), (1.58, 1.53), (1.56, 1.64), (1.24, 1.66)], 0.14, "dark", bevel=0.03)  # rear sight
    b.block(1.26, 1.54, 1.63, 1.665, 0.10, "white_shade", chamfer=0.01)
    b.slab([(3.20, 1.53), (3.62, 1.53), (3.64, 1.64), (3.48, 1.64)], 0.13, "dark", bevel=0.03)  # front sight
    b.slab([(3.52, 1.66), (3.62, 1.66), (3.62, 1.54), (3.55, 1.54)], 0.02, "black", bevel=0.008, x0=0.0)

    # --- Crystal window: dark bezel, a narrow dark core, end caps. The gem itself is its own mesh. ---
    b.block(1.70, 3.02, 1.25, 1.30, W + 0.01, "bezel", chamfer=0.015)
    b.block(1.70, 3.02, 0.62, 0.67, W + 0.01, "bezel", chamfer=0.015)
    b.block(1.70, 3.02, 0.66, 1.26, 0.12, "bezel", chamfer=0.02)
    b.slab([(1.58, 1.30), (1.78, 1.27), (1.70, 0.96), (1.78, 0.65), (1.58, 0.62)], W + 0.01, "bezel", bevel=0.04)
    b.slab([(2.94, 1.27), (3.10, 1.30), (3.10, 0.62), (2.94, 0.65), (3.02, 0.96)], W + 0.01, "bezel", bevel=0.04)

    # --- Front upper housing round the muzzle. ---
    b.slab([(3.04, 1.48), (3.70, 1.48), (3.78, 1.38), (3.78, 0.98), (3.70, 0.95), (3.04, 0.95)], W, "white", bevel=0.05)
    b.decal([(3.20, 1.30), (3.62, 1.30), (3.62, 1.29), (3.20, 1.29)], "seam")
    b.decal([(3.50, 1.12), (3.60, 1.12), (3.60, 1.08), (3.50, 1.08)], "black", depth=0.012)
    # Muzzle: a thick dark ring with a stepped bore.
    b.lathe(
        [(3.70, 0.0), (3.70, 0.21), (3.75, 0.23), (3.95, 0.23), (4.00, 0.21), (4.00, 0.16), (3.97, 0.15), (3.97, 0.11), (3.86, 0.0)],
        "dark",
    )
    b.lathe([(3.90, 0.0), (3.90, 0.10), (3.92, 0.10), (3.92, 0.0)], "black")
    b.lathe([(3.72, 0.0), (3.72, 0.245), (3.78, 0.245), (3.78, 0.0)], "black")  # collar

    # --- Lower body: long white belly under the window, front box and the dark emitter. ---
    b.slab([(1.56, 0.66), (3.56, 0.66), (3.62, 0.56), (3.56, 0.40), (3.40, 0.36), (1.82, 0.36), (1.56, 0.50)], W, "white", bevel=0.05)
    b.decal([(1.90, 0.47), (3.40, 0.47), (3.40, 0.46), (1.90, 0.46)], "seam")
    b.decal([(2.60, 0.62), (2.61, 0.62), (2.61, 0.37), (2.60, 0.37)], "seam")
    b.block(2.96, 3.70, 0.60, 0.99, 0.24, "black", chamfer=0.03)  # dark gap between the front boxes
    b.slab([(2.92, 0.88), (3.60, 0.88), (3.66, 0.80), (3.66, 0.66), (2.92, 0.66)], W, "white", bevel=0.05)
    b.decal([(3.44, 0.80), (3.52, 0.80), (3.52, 0.74), (3.44, 0.74)], "black", depth=0.012)
    b.slab([(3.60, 0.86), (3.86, 0.86), (3.92, 0.76), (3.92, 0.50), (3.86, 0.40), (3.60, 0.40)], 0.26, "dark", bevel=0.04)
    b.block(3.88, 3.935, 0.50, 0.76, 0.16, "black", chamfer=0.02)

    # --- Plum grip with its thumb hole, trigger and the white trigger-guard strut. ---
    b.slab([(0.62, 1.08), (1.36, 1.08), (1.36, 0.92), (0.70, 0.90)], 0.17, "plum", bevel=0.04)  # web under the receiver
    b.slab([(0.58, 1.06), (0.72, 1.02), (0.86, 0.28), (0.72, 0.22)], 0.17, "plum", bevel=0.04)  # back strap
    b.slab([(0.84, 0.94), (1.32, 0.94), (1.38, 0.06), (0.88, 0.02)], 0.17, "plum", bevel=0.05)  # hand grip
    b.slab([(0.72, 0.22), (0.88, 0.30), (0.90, 0.02), (0.76, 0.05)], 0.17, "plum", bevel=0.04)  # heel
    b.decal([(0.94, 0.86), (1.24, 0.86), (1.28, 0.14), (0.98, 0.12)], "plum_dark", x=0.17, depth=0.012)
    b.decal([(1.00, 0.70), (1.24, 0.70), (1.24, 0.68), (1.00, 0.68)], "plum", x=0.18, depth=0.008)  # finger grooves
    b.decal([(1.01, 0.50), (1.25, 0.50), (1.25, 0.48), (1.01, 0.48)], "plum", x=0.18, depth=0.008)
    b.decal([(1.02, 0.30), (1.26, 0.30), (1.26, 0.28), (1.02, 0.28)], "plum", x=0.18, depth=0.008)
    b.slab([(0.86, 0.04), (1.40, 0.08), (1.40, -0.0), (0.88, -0.04)], 0.18, "black", bevel=0.02)  # base plate
    b.slab([(1.38, 0.92), (1.46, 0.92), (1.48, 0.74), (1.42, 0.72)], 0.04, "black", bevel=0.012)  # trigger
    b.slab([(1.36, 0.08), (1.52, 0.04), (1.72, 0.64), (1.58, 0.68)], 0.16, "white", bevel=0.04)  # strut
    return b


def build_crystal():
    b = Builder()
    faces = b.loft(gem_stations(), None)
    b.bm.normal_update()
    b.shade_by_normal(faces, ("gem_hi", "gem_mid", "gem_lo"))
    return b


def build_glow():
    b = Builder()
    b.loft(gem_stations(scale_w=0.62, scale_h=0.8, scale_l=0.9), "glow")  # the core, seen through the Glass
    b.block(1.76, 2.96, 0.67, 1.25, 0.16, "glow", chamfer=0.02)  # the light behind the gem, seen round its pointed ends
    return b


def to_mesh(builder, name):
    mesh = bpy.data.meshes.new(name)
    bmesh.ops.triangulate(builder.bm, faces=builder.bm.faces[:])
    builder.bm.to_mesh(mesh)
    builder.bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = False
    return mesh


def write_palette():
    width, height = COLS * SWATCH, ROWS * SWATCH
    pixels = [0.0] * (width * height * 4)
    for i, (_, rgb) in enumerate(PALETTE):
        col, row = i % COLS, ROWS - 1 - i // COLS  # image rows run bottom-up
        for py in range(row * SWATCH, (row + 1) * SWATCH):
            for px in range(col * SWATCH, (col + 1) * SWATCH):
                o = (py * width + px) * 4
                pixels[o : o + 4] = [c / 255 for c in rgb] + [1.0]
    image = bpy.data.images.new("PrismBlasterClean_Palette", width, height, alpha=False)
    image.pixels = pixels
    PALETTE_PNG.parent.mkdir(parents=True, exist_ok=True)
    image.filepath_raw = str(PALETTE_PNG)
    image.file_format = "PNG"
    image.save()
    return bpy.data.images.load(str(PALETTE_PNG), check_existing=False)


def material(image, name, emission=0.0, roughness=0.45):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = 0.0
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Closest"
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    if emission:
        links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def preview_glass(mat):
    """Review renders only (after export): show the Crystal about as Studio's Glass will."""
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Alpha"].default_value = 0.85
    bsdf.inputs["Roughness"].default_value = 0.05
    bsdf.inputs["Specular IOR Level"].default_value = 0.9


def render(name, location, target, lens=50, size=(1200, 760)):
    sc = bpy.context.scene
    cam = bpy.data.objects.new(name, bpy.data.cameras.new(name))
    cam.data.lens = lens
    cam.data.clip_start = 0.01
    sc.collection.objects.link(cam)
    cam.location = location
    cam.rotation_euler = (Vector(target) - Vector(location)).to_track_quat("-Z", "Y").to_euler()
    sc.camera = cam
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.render.filepath = str(REVIEW / ("clean-" + name + ".png"))
    bpy.ops.render.render(write_still=True)


def main():
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    bpy.ops.wm.read_factory_settings(use_empty=True)
    palette = write_palette()
    body = bpy.data.objects.new("Body", to_mesh(build_body(), "Body"))
    crystal = bpy.data.objects.new("Crystal", to_mesh(build_crystal(), "Crystal"))
    glow = bpy.data.objects.new("Glow", to_mesh(build_glow(), "Glow"))
    body.data.materials.append(material(palette, "PrismBlasterPalette"))
    crystal_mat = material(palette, "PrismBlasterCrystal", roughness=0.15)
    crystal.data.materials.append(crystal_mat)
    glow.data.materials.append(material(palette, "PrismBlasterGlow", emission=1.6))
    parts = [body, crystal, glow]
    for ob in parts:
        bpy.context.scene.collection.objects.link(ob)

    # Centre every mesh on the shared bounding box (pivot: center).
    verts = [v.co for ob in parts for v in ob.data.vertices]
    lo = [min(v[i] for v in verts) for i in range(3)]
    hi = [max(v[i] for v in verts) for i in range(3)]
    mid = Vector([(lo[i] + hi[i]) / 2 for i in range(3)])
    for ob in parts:
        for v in ob.data.vertices:
            v.co -= mid
        ob.data.update()

    def roblox(u, v):
        """A profile point as a Roblox offset from the pivot (+Y up, -Z forward)."""
        return (0.0, round(v - mid.z, 3), round(-(u + mid.y), 3))

    tris = [len(ob.data.polygons) for ob in parts]
    print(
        "prism blaster: %s triangles (%d total), %.2f wide x %.2f long x %.2f tall studs"
        % (tris, sum(tris), hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2])
    )
    print("mount Grip=%s,%s,%s" % roblox(1.08, 0.55))
    print("mount Muzzle=%s,%s,%s" % roblox(4.00, BORE_V))
    assert max(tris) <= 10000, "over Roblox's per-mesh cap"

    EXPORT.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in parts:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.export_scene.gltf(
        filepath=str(EXPORT), export_format="GLB", use_selection=True, export_yup=True, export_apply=True, export_materials="EXPORT"
    )
    print("wrote %s (%.0f KB)" % (EXPORT, EXPORT.stat().st_size / 1024))

    if "--no-render" in args:
        return
    preview_glass(crystal_mat)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.device = "CPU"
    sc.cycles.samples = 48
    sc.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("review")
    sc.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.44, 0.52, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sc.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(40), math.radians(10), math.radians(-60))
    sun.data.energy = 3.0
    REVIEW.mkdir(parents=True, exist_ok=True)
    # The concept's angle: muzzle to the right, seen from the gun's left, a little in front and above.
    render("quarter", (-6.6, -3.4, 1.6), (0, -0.2, 0), lens=55)
    render("side", (-10.0, 0, 0), (0, 0, 0), lens=55)
    render("other-side", (10.0, 0, 0), (0, 0, 0), lens=55)
    render("front", (0.8, -7.0, 0.5), (0, 0, 0), lens=70, size=(700, 600))
    render("top", (0, 0.001, 9.0), (0, 0, 0), lens=50, size=(700, 1100))


main()
